/// Next Best Actions (NBA) Hook Engine — the intelligent layer that transforms
/// captured context (notes, scans, text, insights) into ranked, actionable suggestions.
///
/// Architecture:
///   1. A [NbaContext] is broadcast to the [ActionHookRegistry].
///   2. Each registered [ActionHook] declares which [HookTrigger]s it listens to.
///   3. Matching hooks run a fast [canHandle] pre-filter, then a [score] check.
///   4. Hooks above the score threshold call [generateActions] to produce [ActionCard]s.
///   5. Results are merged, deduplicated, scored, and sorted into [RankedAction]s.
///
/// This engine plugs into existing Fikr flows:
///   - VisionController: after vision.analyse returns, enrich scan actions.
///   - AppController (voice): after note creation, suggest next steps.
///   - Insights: after ai.insights, surface follow-up actions.
library;

import 'package:get/get.dart';

import '../../controllers/subscription_controller.dart';
import '../../models/action_card.dart';
import '../../models/analysis_result.dart';
import '../../models/note.dart';
import '../../models/scan.dart';
import '../tool_interface.dart';

// ---------------------------------------------------------------------------
// Enums
// ---------------------------------------------------------------------------

/// Where in the app lifecycle a hook can be triggered.
enum HookTrigger {
  /// A new note was just created (voice capture, manual entry, etc.).
  onNoteCreated,

  /// A new image scan was just analyzed.
  onScanCreated,

  /// A new task was created or extracted.
  onTaskCreated,

  /// Free-text input from the user (e.g., search bar, quick capture).
  onFreeText,

  /// Insights were just generated (ai.insights completed).
  onInsightGenerated,

  /// Periodic background check (e.g., morning briefing, stale-task resurface).
  onPeriodicCheck,

  /// Explicit user gesture — "Suggest Actions" button tap.
  onUserGesture,

  /// Always run for every context broadcast.
  onAll,
}

/// Source type of the captured content.
enum NbaSource {
  note,
  scan,
  task,
  freeText,
  image,
  reminder,
  insight,
}

/// How urgent is this action?
enum ActionUrgency {
  /// Do it now — time-sensitive or explicitly urgent.
  now,

  /// Do it soon — within a day or two.
  soon,

  /// Do it later — whenever convenient.
  later,

  /// Background — informational or low-priority.
  background,
}

/// Priority level for ranking.
enum ActionPriority {
  high,
  medium,
  low,
}

// ---------------------------------------------------------------------------
// NbaContext — rich context passed to hooks
// ---------------------------------------------------------------------------

/// Ambient context object that carries all information a hook might need
/// to decide whether it's relevant and what actions to suggest.
class NbaContext {
  const NbaContext({
    required this.source,
    this.text,
    this.analysis,
    this.scan,
    this.note,
    this.existingActions,
    this.toolContext,
    this.trigger,
    this.metadata = const {},
  });

  /// What kind of content triggered this context.
  final NbaSource source;

  /// Raw or analyzed text content.
  final String? text;

  /// AI analysis result (intent, bucket, topics).
  final AnalysisResult? analysis;

  /// Scan object if source is an image.
  final Scan? scan;

  /// Note object if source is a note.
  final Note? note;

  /// Actions already generated (e.g., by LLM). Hooks can supplement or replace.
  final List<ActionCard>? existingActions;

  /// Tool execution context (user tier, config, storage).
  final ToolContext? toolContext;

  /// Which trigger fired this context.
  final HookTrigger? trigger;

  /// Arbitrary metadata for hook-specific data.
  final Map<String, dynamic> metadata;

  /// Convenience: combined text from note or analysis.
  String get combinedText {
    final parts = <String>[];
    if (analysis?.cleanedText.isNotEmpty ?? false) {
      parts.add(analysis!.cleanedText);
    }
    if (note?.text.isNotEmpty ?? false) {
      parts.add(note!.text);
    }
    if (note?.transcript.isNotEmpty ?? false) {
      parts.add(note!.transcript);
    }
    if (text?.isNotEmpty ?? false) {
      parts.add(text!);
    }
    return parts.join('\n\n');
  }

  /// Convenience: all topics from analysis or note.
  List<String> get allTopics {
    final topics = <String>{};
    if (analysis?.topics.isNotEmpty ?? false) {
      topics.addAll(analysis!.topics);
    }
    if (note?.topics.isNotEmpty ?? false) {
      topics.addAll(note!.topics);
    }
    return topics.toList();
  }

  /// Convenience: intent string.
  String get intent => analysis?.intent ?? note?.intent ?? text ?? '';

  /// Convenience: bucket string.
  String get bucket => analysis?.bucket ?? note?.bucket ?? 'General';

  /// Convenience: scan category.
  String get scanCategory => scan?.category ?? '';
}

// ---------------------------------------------------------------------------
// RankedAction — action + ranking metadata
// ---------------------------------------------------------------------------

/// A scored action ready for UI display.
class RankedAction {
  const RankedAction({
    required this.action,
    required this.score,
    required this.hookName,
    this.urgency = ActionUrgency.later,
    this.priority = ActionPriority.medium,
  });

  /// The UI-facing action card.
  final ActionCard action;

  /// Relevance score from the hook (0.0–1.0).
  final double score;

  /// Name of the hook that produced this action.
  final String hookName;

  /// How urgent is this action?
  final ActionUrgency urgency;

  /// Priority level.
  final ActionPriority priority;

  /// Composite score for final sorting.
  /// Formula: score * 0.6 + urgencyWeight * 0.2 + priorityWeight * 0.2
  double get compositeScore {
    final urgencyWeight = switch (urgency) {
      ActionUrgency.now      => 1.0,
      ActionUrgency.soon     => 0.7,
      ActionUrgency.later    => 0.4,
      ActionUrgency.background => 0.1,
    };
    final priorityWeight = switch (priority) {
      ActionPriority.high   => 1.0,
      ActionPriority.medium => 0.5,
      ActionPriority.low    => 0.2,
    };
    return score * 0.6 + urgencyWeight * 0.2 + priorityWeight * 0.2;
  }
}

// ---------------------------------------------------------------------------
// ActionHook — base class for all NBA hooks
// ---------------------------------------------------------------------------

/// Base class for all Next Best Action hooks.
///
/// Each hook declares which triggers it listens to, implements a fast
/// pre-filter ([canHandle]), a relevance scorer ([score]), and an action
/// generator ([generateActions]).
///
/// Subclass example:
/// ```dart
/// class EcommerceHook extends ActionHook {
///   @override String get name => 'ecommerce';
///   @override Set<HookTrigger> get triggers => {HookTrigger.onScanCreated, HookTrigger.onNoteCreated};
///   @override ToolTier get requiredTier => ToolTier.plus;
///
///   @override bool canHandle(NbaContext ctx) => ctx.scanCategory == 'product' || _hasPurchaseIntent(ctx);
///   @override Future<double> score(NbaContext ctx) async => /* ... */;
///   @override Future<List<RankedAction>> generateActions(NbaContext ctx) async => /* ... */;
/// }
/// ```
abstract class ActionHook {
  /// Unique hook name (lowercase, no spaces).
  String get name;

  /// Human-readable description for discovery and debugging.
  String get description;

  /// Which triggers activate this hook.
  Set<HookTrigger> get triggers;

  /// Minimum subscription tier required.
  ToolTier get requiredTier;

  /// Where the hook runs.
  HookLocation get location => HookLocation.local;

  /// Minimum score threshold. Actions below this are discarded.
  double get minScore => 0.3;

  /// Maximum actions this hook can produce per context.
  int get maxActions => 5;

  /// Fast pre-filter: can this hook handle this context at all?
  /// Should be a cheap check (no I/O, no network).
  bool canHandle(NbaContext context);

  /// Score how relevant this hook is for the context (0.0–1.0).
  /// Called only if [canHandle] returns true.
  /// Can use rule-based, keyword, or lightweight LLM scoring.
  Future<double> score(NbaContext context);

  /// Generate ranked actions. Called only if score >= [minScore].
  /// Should return at most [maxActions] actions.
  Future<List<RankedAction>> generateActions(NbaContext context);

  /// Optional warm-up called at app startup (e.g., cache API keys).
  Future<void> warmUp() async {}

  /// Check if this hook responds to a given trigger.
  bool respondsTo(HookTrigger trigger) => triggers.contains(trigger) || triggers.contains(HookTrigger.onAll);
}

/// Where the hook executes.
enum HookLocation {
  /// Runs entirely on the client device.
  local,

  /// Requires a round-trip to fikr.one cloud API.
  cloud,

  /// Hybrid: some logic local, some cloud.
  hybrid,
}

// ---------------------------------------------------------------------------
// ActionHookRegistry — singleton that manages hook lifecycle & execution
// ---------------------------------------------------------------------------

/// Central registry for all NBA hooks.
///
/// Handles registration, trigger filtering, scoring, ranking,
/// deduplication, and tier-aware execution.
class ActionHookRegistry {
  ActionHookRegistry._();

  static final ActionHookRegistry instance = ActionHookRegistry._();

  final Map<String, ActionHook> _hooks = {};

  // ── Registration ──────────────────────────────────────────────────

  /// Register a single hook.
  void register(ActionHook hook) {
    if (_hooks.containsKey(hook.name)) {
      throw StateError(
        'Hook "${hook.name}" is already registered. '
        'Use replace() for intentional overrides.',
      );
    }
    _hooks[hook.name] = hook;
  }

  /// Register a list of hooks.
  void registerAll(List<ActionHook> hooks) {
    for (final hook in hooks) {
      register(hook);
    }
  }

  /// Replace an existing hook.
  void replace(ActionHook hook) {
    _hooks[hook.name] = hook;
  }

  /// Unregister a hook by name.
  void unregister(String name) {
    _hooks.remove(name);
  }

  /// Clear all registrations.
  void clear() => _hooks.clear();

  // ── Discovery ─────────────────────────────────────────────────────

  /// Get a hook by name.
  ActionHook? get(String name) => _hooks[name];

  /// All registered hooks (unfiltered).
  List<ActionHook> get all => List.unmodifiable(_hooks.values);

  /// Hooks available for a given tier.
  List<ActionHook> hooksForTier(ToolTier tier) {
    return _hooks.values
        .where((h) => h.requiredTier.index <= tier.index)
        .toList();
  }

  /// Hooks that respond to a specific trigger.
  List<ActionHook> getHooksForTrigger(HookTrigger trigger, {ToolTier? tier}) {
    var hooks = _hooks.values.where((h) => h.respondsTo(trigger)).toList();
    if (tier != null) {
      hooks = hooks.where((h) => h.requiredTier.index <= tier.index).toList();
    }
    return hooks;
  }

  /// Number of registered hooks.
  int get count => _hooks.length;

  /// Whether a hook is registered.
  bool has(String name) => _hooks.containsKey(name);

  // ── Execution ─────────────────────────────────────────────────────

  /// Run all matching hooks against the context and return ranked actions.
  ///
  /// [minScore] — global minimum score threshold (defaults to 0.3).
  /// [maxActions] — maximum total actions returned (defaults to 10).
  /// [excludedHooks] — hook names to skip.
  /// [tier] — user's subscription tier for filtering.
  Future<List<RankedAction>> run(
    NbaContext context, {
    double minScore = 0.3,
    int maxActions = 10,
    List<String>? excludedHooks,
    ToolTier? tier,
  }) async {
    // Determine which trigger to use
    final trigger = context.trigger ?? HookTrigger.onUserGesture;

    // Get hooks for this trigger and tier
    var hooks = getHooksForTrigger(trigger, tier: tier);

    // Exclude specified hooks
    if (excludedHooks != null && excludedHooks.isNotEmpty) {
      hooks = hooks.where((h) => !excludedHooks.contains(h.name)).toList();
    }

    // Phase 1: Fast pre-filter (canHandle)
    final eligibleHooks = hooks.where((h) => h.canHandle(context)).toList();

    if (eligibleHooks.isEmpty) return [];

    // Phase 2: Score all eligible hooks in parallel
    final scoredHooks = await Future.wait(
      eligibleHooks.map((hook) async {
        final double hookScore = await hook.score(context);
        return hookScore >= minScore ? hook : null;
      }).toList(),
    );

    final passingHooks = scoredHooks
        .whereType<ActionHook>()
        .toList();

    if (passingHooks.isEmpty) return [];

    // Phase 3: Generate actions from passing hooks in parallel
    final actionFutures = passingHooks.map((hook) async {
      try {
        final actions = await hook.generateActions(context);
        return actions.take(hook.maxActions).toList();
      } catch (e) {
        // Log and skip failed hooks
        return <RankedAction>[];
      }
    }).toList();

    final allActions = (await Future.wait(actionFutures))
        .expand((list) => list)
        .toList();

    // Phase 4: Merge existing LLM actions if present
    if (context.existingActions != null && context.existingActions!.isNotEmpty) {
      for (final existing in context.existingActions!) {
        // Only add if not already present from a hook
        final alreadyPresent = allActions.any(
          (ra) => ra.action.title == existing.title && ra.action.type == existing.type,
        );
        if (!alreadyPresent) {
          allActions.add(
            RankedAction(
              action: existing,
              score: 0.5, // Default score for LLM-generated actions
              hookName: 'llm_default',
            ),
          );
        }
      }
    }

    // Phase 5: Deduplicate by type + title
    final deduped = _deduplicate(allActions);

    // Phase 6: Sort by composite score descending
    deduped.sort((a, b) => b.compositeScore.compareTo(a.compositeScore));

    // Phase 7: Trim to max actions
    return deduped.take(maxActions).toList();
  }

  /// Deduplicate actions by (type, title) — keep the highest scored.
  List<RankedAction> _deduplicate(List<RankedAction> actions) {
    final map = <String, RankedAction>{};
    for (final action in actions) {
      final key = '${action.action.type}.${action.action.title.toLowerCase().trim()}';
      final existing = map[key];
      if (existing == null || action.compositeScore > existing.compositeScore) {
        map[key] = action;
      }
    }
    return map.values.toList();
  }

  // ── Warm-up ───────────────────────────────────────────────────────

  /// Call warmUp on all hooks (at app startup).
  Future<void> warmUpAll() async {
    await Future.wait(_hooks.values.map((h) => h.warmUp()).toList());
  }
}

// ---------------------------------------------------------------------------
// Utility: get current tier from app state
// ---------------------------------------------------------------------------

/// Helper to resolve current user tier from GetX services.
/// Mirrors the same pattern used in EngineController._currentTier().
ToolTier resolveCurrentTier() {
  try {
    final sub = Get.find<SubscriptionController>();
    if (sub.isPro) return ToolTier.pro;
    if (sub.isPlus) return ToolTier.plus;
  } catch (_) {}
  return ToolTier.free;
}
