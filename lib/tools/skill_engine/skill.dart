/// Skill model — declarative recipes that chain tools together.
///
/// A [Skill] is defined as a sequence of [SkillStep]s, each referencing a
/// tool by name and mapping inputs/outputs through a variable context.
/// Steps can run sequentially, in parallel, conditionally, or iterate.
library;



import '../tool_interface.dart';

// ---------------------------------------------------------------------------
// SkillStep — one unit of work in a skill
// ---------------------------------------------------------------------------

/// How a step's output feeds into the variable context.
enum StepOutputMode {
  /// Store output under a named key (default).
  store,

  /// Merge output map into the variable context.
  merge,

  /// Discard the output.
  discard,
}

/// A single step in a skill definition.
class SkillStep {
  const SkillStep({
    required this.toolName,
    this.input = const {},
    this.outputKey,
    this.outputMode = StepOutputMode.store,
    this.condition,
    this.forEach,
    this.parallel = false,
    this.onError = StepErrorPolicy.fail,
  });

  /// Tool name from the registry, e.g. `notes.create`.
  final String toolName;

  /// Input map — values can be literals or `$variable` references.
  ///
  /// Variable references are resolved at runtime from the skill context.
  /// E.g. `{ "transcript": "$transcript" }` pulls the value set by a
  /// previous step that had `outputKey: "transcript"`.
  ///
  /// Nested access: `$analysis.intent` resolves `context["analysis"]["intent"]`.
  final Map<String, dynamic> input;

  /// Key under which to store the step's output in the variable context.
  final String? outputKey;

  /// How to handle the step output.
  final StepOutputMode outputMode;

  /// Expression that must be truthy for this step to run.
  ///
  /// If null, the step always runs.
  /// Supports simple variable checks: `$user.canSync` → must be truthy.
  final String? condition;

  /// If set, this step is invoked once per item in the referenced array variable.
  ///
  /// E.g. `forEach: "$actions"` → the step runs N times, once for each action.
  /// Inside the step, `$item` refers to the current array element.
  final String? forEach;

  /// If true, this step can run concurrently with adjacent parallel steps.
  final bool parallel;

  /// What to do when this step fails.
  final StepErrorPolicy onError;

  /// Create from JSON (for remote skill definitions).
  factory SkillStep.fromJson(Map<String, dynamic> json) {
    return SkillStep(
      toolName: json['tool'] as String,
      input: (json['input'] as Map<String, dynamic>?) ?? {},
      outputKey: json['output'] as String?,
      outputMode: StepOutputMode.values.firstWhere(
        (e) => e.name == (json['outputMode'] as String? ?? 'store'),
        orElse: () => StepOutputMode.store,
      ),
      condition: json['condition'] as String?,
      forEach: json['forEach'] as String?,
      parallel: json['parallel'] as bool? ?? false,
      onError: StepErrorPolicy.values.firstWhere(
        (e) => e.name == (json['onError'] as String? ?? 'fail'),
        orElse: () => StepErrorPolicy.fail,
      ),
    );
  }

  Map<String, dynamic> toJson() => {
    'tool': toolName,
    if (input.isNotEmpty) 'input': input,
    if (outputKey != null) 'output': outputKey,
    if (outputMode != StepOutputMode.store)
      'outputMode': outputMode.name,
    if (condition != null) 'condition': condition,
    if (forEach != null) 'forEach': forEach,
    if (parallel) 'parallel': parallel,
    if (onError != StepErrorPolicy.fail) 'onError': onError.name,
  };
}

/// What to do when a step fails.
enum StepErrorPolicy {
  /// Abort the entire skill.
  fail,

  /// Log the error and continue to the next step.
  skip,

  /// Retry once, then fail.
  retryOnce,
}

// ---------------------------------------------------------------------------
// Skill — the full recipe
// ---------------------------------------------------------------------------

/// A declarative skill definition.
class Skill {
  const Skill({
    required this.name,
    required this.description,
    required this.steps,
    this.triggers = const [],
    this.requiredTier = ToolTier.free,
  });

  /// Unique skill name, e.g. `voice_note_capture`.
  final String name;

  /// Human-readable description for discovery.
  final String description;

  /// Ordered list of steps to execute.
  final List<SkillStep> steps;

  /// Trigger patterns that can activate this skill.
  ///
  /// E.g. `["voice_command:take a note", "ui_action:record_button_tap"]`
  final List<String> triggers;

  /// Minimum tier to use this skill.
  final ToolTier requiredTier;

  factory Skill.fromJson(Map<String, dynamic> json) {
    return Skill(
      name: json['name'] as String,
      description: json['description'] as String? ?? '',
      steps: (json['steps'] as List<dynamic>)
          .map((s) => SkillStep.fromJson(s as Map<String, dynamic>))
          .toList(),
      triggers: (json['triggers'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      requiredTier: ToolTier.values.firstWhere(
        (e) => e.name == (json['requiredTier'] as String? ?? 'free'),
        orElse: () => ToolTier.free,
      ),
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'description': description,
    'steps': steps.map((s) => s.toJson()).toList(),
    'triggers': triggers,
    'requiredTier': requiredTier.name,
  };
}

// ---------------------------------------------------------------------------
// SkillExecutionResult — result of running a full skill
// ---------------------------------------------------------------------------

/// Result of executing a complete skill.
class SkillExecutionResult {
  const SkillExecutionResult({
    required this.skillName,
    required this.success,
    required this.variables,
    this.failedStep,
    this.error,
    this.stepResults = const [],
  });

  final String skillName;
  final bool success;

  /// All variables accumulated during execution.
  final Map<String, dynamic> variables;

  /// Index of the step that failed (if any).
  final int? failedStep;

  /// Error message if the skill failed.
  final String? error;

  /// Individual step results.
  final List<StepExecutionResult> stepResults;
}

/// Result of executing a single step.
class StepExecutionResult {
  const StepExecutionResult({
    required this.stepIndex,
    required this.toolName,
    required this.result,
    this.skipped = false,
  });

  final int stepIndex;
  final String toolName;
  final ToolResult result;
  final bool skipped;
}
