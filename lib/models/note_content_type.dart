/// The 13 canonical content types from Fikr Studio.
///
/// These mirror the "Change Type" taxonomy in Fikr Studio exactly.
/// Every note in the Flutter app is classified into ONE of these types
/// during AI analysis. Free-form AI-generated topic tags are NOT used.
enum NoteContentType {
  entity,
  claim,
  question,
  task,
  idea,
  reference,
  quote,
  definition,
  opinion,
  reflection,
  narrative,
  comparison,
  general;

  /// The human-readable label shown in the UI (matching Studio).
  String get label => switch (this) {
        entity => 'Entity',
        claim => 'Claim',
        question => 'Question',
        task => 'Task',
        idea => 'Idea',
        reference => 'Reference',
        quote => 'Quote',
        definition => 'Definition',
        opinion => 'Opinion',
        reflection => 'Reflection',
        narrative => 'Narrative',
        comparison => 'Comparison',
        general => 'Note',
      };

  /// Parse a raw string from the LLM / JSON into a [NoteContentType].
  /// Falls back to [general] for any unknown value.
  static NoteContentType fromString(String? raw) {
    if (raw == null || raw.isEmpty) return general;
    final lower = raw.trim().toLowerCase();
    return NoteContentType.values.firstWhere(
      (t) => t.name == lower,
      orElse: () => general,
    );
  }

  /// All valid string values the LLM may use — included in the prompt.
  static String get promptValues =>
      NoteContentType.values.map((t) => t.name).join(', ');
}
