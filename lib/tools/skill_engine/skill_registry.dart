/// Skill Registry — central catalogue of built-in and remote skills.
library;

import '../tool_interface.dart';
import 'skill.dart';

class SkillRegistry {
  SkillRegistry._();

  static final SkillRegistry instance = SkillRegistry._();

  final Map<String, Skill> _skills = {};

  // ── Registration ──────────────────────────────────────────────────

  void register(Skill skill) {
    _skills[skill.name] = skill;
  }

  void registerAll(List<Skill> skills) {
    for (final skill in skills) {
      register(skill);
    }
  }

  void unregister(String name) => _skills.remove(name);

  // ── Discovery ─────────────────────────────────────────────────────

  Skill? get(String name) => _skills[name];

  List<Skill> get all => List.unmodifiable(_skills.values);

  /// Skills available for a given tier.
  List<Skill> skillsForTier(ToolTier tier) {
    return _skills.values
        .where((s) => s.requiredTier.index <= tier.index)
        .toList();
  }

  /// Find skills that match a trigger pattern.
  List<Skill> findByTrigger(String trigger) {
    return _skills.values.where((s) => s.triggers.contains(trigger)).toList();
  }

  int get count => _skills.length;

  bool has(String name) => _skills.containsKey(name);

  /// Export skill schemas for LLM prompts.
  List<Map<String, dynamic>> schemaForTier(ToolTier tier) {
    return skillsForTier(tier).map((s) {
      return {
        'name': s.name,
        'description': s.description,
        'triggers': s.triggers,
        'requiredTier': s.requiredTier.name,
        'steps': s.steps.length,
      };
    }).toList();
  }

  void clear() => _skills.clear();
}
