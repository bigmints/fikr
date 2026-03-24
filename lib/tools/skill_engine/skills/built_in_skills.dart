/// Built-in skill definitions.
///
/// These are the pre-built skills that ship with the app.
/// Each returns a [Skill] instance that the [SkillExecutor] can run.
library;

import '../../tool_interface.dart';
import '../skill.dart';

// ───────────────────────────────────────────────────────────────────────────
//  voice_note_capture
// ───────────────────────────────────────────────────────────────────────────

/// Full voice note pipeline:
/// audio → transcribe → analyze → create note → extract tasks → upload audio
Skill voiceNoteCaptureSkill() => Skill(
      name: 'voice_note_capture',
      description:
          'Record audio, transcribe, analyze, save as a note, and extract tasks.',
      triggers: [
        'voice_command:take a note',
        'ui_action:record_button_tap',
      ],
      steps: [
        // Step 0: Transcribe audio file (audioPath must be in initialVars)
        const SkillStep(
          toolName: 'ai.transcribe',
          input: {'audioPath': r'$audioPath'},
          outputKey: 'transcription',
        ),
        // Step 1: Analyze transcript
        const SkillStep(
          toolName: 'ai.analyze',
          input: {
            'transcript': r'$transcription.transcript',
            'buckets': r'$buckets',
          },
          outputKey: 'analysis',
        ),
        // Step 2: Create the note
        const SkillStep(
          toolName: 'notes.create',
          input: {
            'title': r'$analysis.intent',
            'text': r'$analysis.cleanedText',
            'transcript': r'$transcription.transcript',
            'bucket': r'$analysis.bucket',
            'topics': r'$analysis.topics',
          },
          outputKey: 'note',
        ),
        // Step 3 (parallel): Upload audio if user can sync
        const SkillStep(
          toolName: 'audio.upload',
          input: {
            'noteId': r'$note.id',
            'localPath': r'$audioPath',
          },
          condition: r'$canSync',
          parallel: true,
          onError: StepErrorPolicy.skip,
        ),
        // Step 4 (parallel): Show success notification
        const SkillStep(
          toolName: 'notify.in_app',
          input: {
            'title': 'Note saved',
            'description': 'Your voice note has been transcribed and saved.',
            'type': 'success',
          },
          parallel: true,
          onError: StepErrorPolicy.skip,
        ),
      ],
    );

// ───────────────────────────────────────────────────────────────────────────
//  generate_insights
// ───────────────────────────────────────────────────────────────────────────

/// Weekly insights generation:
/// list notes → generate insights → create tasks → create reminders
Skill generateInsightsSkill() => Skill(
      name: 'generate_insights',
      description:
          'Generate insights from recent notes — highlights, tasks, reminders.',
      triggers: [
        'ui_action:generate_insights',
        'schedule:weekly',
      ],
      steps: [
        // Step 0: List recent notes (passed via initialVars)
        const SkillStep(
          toolName: 'notes.list',
          input: {'sort': 'newest', 'limit': 50},
          outputKey: 'notesList',
        ),
        // Step 1: Generate insights from notes
        const SkillStep(
          toolName: 'ai.insights',
          input: {
            'notes': r'$notesList',
            'buckets': r'$buckets',
            'existingTaskTitles': r'$existingTaskTitles',
          },
          outputKey: 'insights',
        ),
      ],
    );

// ───────────────────────────────────────────────────────────────────────────
//  smart_task_from_note
// ───────────────────────────────────────────────────────────────────────────

/// Extract tasks from a note and link them.
Skill smartTaskFromNoteSkill() => Skill(
      name: 'smart_task_from_note',
      description: 'Extract actionable tasks from a note and link them back.',
      triggers: ['ui_action:extract_tasks'],
      steps: [
        const SkillStep(
          toolName: 'notes.get',
          input: {'id': r'$noteId'},
          outputKey: 'note',
        ),
        const SkillStep(
          toolName: 'ai.extract_actions',
          input: {'text': r'$note.text'},
          outputKey: 'extractedActions',
        ),
        const SkillStep(
          toolName: 'tasks.create',
          input: {
            'title': r'$item.title',
            'description': r'$item.description',
            'sourceNoteId': r'$noteId',
          },
          forEach: r'$extractedActions.actions',
          outputKey: 'createdTasks',
        ),
      ],
    );

// ───────────────────────────────────────────────────────────────────────────
//  morning_briefing
// ───────────────────────────────────────────────────────────────────────────

/// Daily briefing: pending tasks + active reminders + recent notes summary.
Skill morningBriefingSkill() => Skill(
      name: 'morning_briefing',
      description:
          'Generate a daily briefing from tasks, reminders, and recent notes.',
      triggers: ['schedule:daily_morning'],
      steps: [
        const SkillStep(
          toolName: 'tasks.list',
          input: {'status': 'todo', 'limit': 10},
          outputKey: 'pendingTasks',
        ),
        const SkillStep(
          toolName: 'reminders.list',
          input: {'includeDissmissed': false},
          outputKey: 'activeReminders',
        ),
        const SkillStep(
          toolName: 'notes.list',
          input: {'sort': 'newest', 'limit': 5},
          outputKey: 'recentNotes',
        ),
      ],
    );

// ───────────────────────────────────────────────────────────────────────────
//  sync_all
// ───────────────────────────────────────────────────────────────────────────

/// Full bidirectional sync.
Skill syncAllSkill() => Skill(
      name: 'sync_all',
      description: 'Push local data, then pull cloud data.',
      requiredTier: ToolTier.plus,
      triggers: ['ui_action:sync_now'],
      steps: [
        const SkillStep(
          toolName: 'sync.push',
          input: {},
          outputKey: 'pushResult',
        ),
        const SkillStep(
          toolName: 'sync.pull',
          input: {},
          outputKey: 'pullResult',
        ),
        const SkillStep(
          toolName: 'notify.in_app',
          input: {
            'title': 'Sync complete',
            'type': 'success',
          },
          onError: StepErrorPolicy.skip,
        ),
      ],
    );

// ───────────────────────────────────────────────────────────────────────────
//  Convenience: all built-in skills
// ───────────────────────────────────────────────────────────────────────────

List<Skill> allBuiltInSkills() => [
      voiceNoteCaptureSkill(),
      generateInsightsSkill(),
      smartTaskFromNoteSkill(),
      morningBriefingSkill(),
      syncAllSkill(),
    ];
