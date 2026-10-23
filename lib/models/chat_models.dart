/// What the AI coach conversation is made of.
///
/// Mirrors `/ai-coach/*`: a session owns an ordered list of messages, and a
/// message was said either by the user or by the coach. The greeting the
/// screen opens with is **not** a message - it is UI, so it never reaches the
/// history or the model's context.

class ChatMessage {
  /// The server's id, or null for a message this device has only just typed
  /// and not yet had confirmed.
  final int? id;

  final String content;
  final bool isUser;
  final DateTime sentAt;

  /// The reply failed to arrive. Kept in the list rather than dropped: a
  /// question that vanishes leaves the user unsure whether it was sent.
  final bool failed;

  /// Cards the coach's answer carries besides its text - exercises it
  /// suggests, a schedule it proposes. Empty for every user message.
  final List<CoachAttachment> attachments;

  const ChatMessage({
    required this.content,
    required this.isUser,
    required this.sentAt,
    this.id,
    this.failed = false,
    this.attachments = const [],
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
        id: json['chat_message_id'] as int?,
        content: json['content'] as String? ?? '',
        // The API's vocabulary is a role, not a flag - 'user' or 'assistant'.
        isUser: (json['role'] as String? ?? 'assistant') == 'user',
        sentAt:
            DateTime.tryParse(json['created_at'] as String? ?? '')?.toLocal() ??
                DateTime.now(),
        attachments: (json['attachments'] as List<dynamic>? ?? const [])
            .map((e) => CoachAttachment.fromJson(e as Map<String, dynamic>))
            .whereType<CoachAttachment>()
            .toList(),
      );
}

/// Something an answer carries besides its text.
///
/// A sealed family rather than a map: the screen draws each kind differently,
/// and a switch over the kinds is checked by the compiler when a third one
/// arrives.
sealed class CoachAttachment {
  const CoachAttachment();

  /// Null for a kind this build does not know - an answer from a newer
  /// server still shows its text, just without the card.
  static CoachAttachment? fromJson(Map<String, dynamic> json) =>
      switch (json['type']) {
        'exercises' => ExerciseSuggestion.fromJson(json),
        'schedule' => ScheduleProposal.fromJson(json),
        _ => null,
      };
}

/// One catalog exercise as the chat draws it. Tapping opens its detail.
class CoachExercise {
  final int exerciseId;
  final String? name;
  final String trackingType;

  /// Non-null when the camera can count it - draws the AI tag.
  final String? aiAlgorithm;
  final String? iconUrl;
  final String? thumbnailUrl;

  const CoachExercise({
    required this.exerciseId,
    required this.trackingType,
    this.name,
    this.aiAlgorithm,
    this.iconUrl,
    this.thumbnailUrl,
  });

  factory CoachExercise.fromJson(Map<String, dynamic> json) => CoachExercise(
        exerciseId: json['exercise_id'] as int,
        name: json['name'] as String?,
        trackingType: json['tracking_type'] as String? ?? 'reps',
        aiAlgorithm: json['ai_algorithm'] as String?,
        iconUrl: json['icon_url'] as String?,
        thumbnailUrl: json['thumbnail_url'] as String?,
      );

  /// Same pair as the catalog models, so the chat reuses the files the
  /// explorer already cached.
  String? get listImageUrl => iconUrl ?? thumbnailUrl;
  String get listImageCacheKey =>
      iconUrl != null ? 'icon-$exerciseId' : 'thumb-$exerciseId';
}

class ExerciseSuggestion extends CoachAttachment {
  final String? reason;
  final List<CoachExercise> exercises;

  const ExerciseSuggestion({required this.exercises, this.reason});

  factory ExerciseSuggestion.fromJson(Map<String, dynamic> json) =>
      ExerciseSuggestion(
        reason: json['reason'] as String?,
        exercises: (json['exercises'] as List<dynamic>? ?? const [])
            .map((e) => CoachExercise.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

/// An exercise on a proposed date: [sets] identical target sets.
class ProposedExercise extends CoachExercise {
  final int sets;
  final int? targetReps;
  final double? targetWeightKg;
  final int? targetDurationSeconds;
  final double? targetDistanceM;

  const ProposedExercise({
    required super.exerciseId,
    required super.trackingType,
    required this.sets,
    super.name,
    super.aiAlgorithm,
    super.iconUrl,
    super.thumbnailUrl,
    this.targetReps,
    this.targetWeightKg,
    this.targetDurationSeconds,
    this.targetDistanceM,
  });

  factory ProposedExercise.fromJson(Map<String, dynamic> json) {
    final card = CoachExercise.fromJson(json);
    return ProposedExercise(
      exerciseId: card.exerciseId,
      name: card.name,
      trackingType: card.trackingType,
      aiAlgorithm: card.aiAlgorithm,
      iconUrl: card.iconUrl,
      thumbnailUrl: card.thumbnailUrl,
      sets: json['sets'] as int? ?? 1,
      targetReps: json['target_reps'] as int?,
      targetWeightKg: (json['target_weight_kg'] as num?)?.toDouble(),
      targetDurationSeconds: json['target_duration_seconds'] as int?,
      targetDistanceM: (json['target_distance_m'] as num?)?.toDouble(),
    );
  }
}

class ProposedDay {
  final DateTime date;
  final bool restDay;
  final List<ProposedExercise> exercises;

  /// The date already holds something in the plan, and applying replaces it.
  final bool replacesExisting;

  const ProposedDay({
    required this.date,
    required this.restDay,
    required this.exercises,
    required this.replacesExisting,
  });

  factory ProposedDay.fromJson(Map<String, dynamic> json) => ProposedDay(
        // A calendar date, not an instant: parsed as local midnight so it is
        // never shifted a day by the time zone.
        date: DateTime.parse(json['date'] as String),
        restDay: json['rest_day'] as bool? ?? false,
        exercises: (json['exercises'] as List<dynamic>? ?? const [])
            .map((e) => ProposedExercise.fromJson(e as Map<String, dynamic>))
            .toList(),
        replacesExisting: json['replaces_existing'] as bool? ?? false,
      );
}

enum ProposalStatus { pending, applied, dismissed }

/// A schedule the coach drafted. Nothing in the plan changes until the user
/// taps Apply - the coach drafts, the user writes.
class ScheduleProposal extends CoachAttachment {
  final ProposalStatus status;
  final String? summary;
  final int? planId;
  final String? planName;

  /// Applying creates [planName] as a new plan and makes it the active one.
  final bool createsPlan;
  final List<ProposedDay> days;

  /// Dates that had already passed when Apply was tapped, so were not written.
  final List<DateTime> skippedDates;

  const ScheduleProposal({
    required this.status,
    required this.days,
    required this.createsPlan,
    this.summary,
    this.planId,
    this.planName,
    this.skippedDates = const [],
  });

  int get replacedCount => days.where((d) => d.replacesExisting).length;

  factory ScheduleProposal.fromJson(Map<String, dynamic> json) =>
      ScheduleProposal(
        status: switch (json['status']) {
          'applied' => ProposalStatus.applied,
          'dismissed' => ProposalStatus.dismissed,
          _ => ProposalStatus.pending,
        },
        summary: json['summary'] as String?,
        planId: json['plan_id'] as int?,
        planName: json['plan_name'] as String?,
        createsPlan: json['creates_plan'] as bool? ?? false,
        days: (json['days'] as List<dynamic>? ?? const [])
            .map((e) => ProposedDay.fromJson(e as Map<String, dynamic>))
            .toList(),
        skippedDates: (json['skipped_dates'] as List<dynamic>? ?? const [])
            .map((e) => DateTime.parse(e as String))
            .toList(),
      );
}

/// One conversation. `title` comes from the server, derived from the first
/// thing the user asked, so every device names it the same way.
class ChatSession {
  final int id;
  final String title;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Empty in the list response, which carries counts rather than threads -
  /// the history screen shows "4 messages", not the messages.
  final List<ChatMessage> messages;

  /// What the list row shows. Server-counted, so it is right even though
  /// [messages] is empty here.
  final int messageCount;

  const ChatSession({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    this.messages = const [],
    this.messageCount = 0,
  });

  factory ChatSession.fromJson(Map<String, dynamic> json) {
    final messages = (json['messages'] as List<dynamic>? ?? const [])
        .map((e) => ChatMessage.fromJson(e as Map<String, dynamic>))
        .toList();

    return ChatSession(
      id: json['chat_session_id'] as int,
      title: json['title'] as String? ?? '',
      createdAt:
          DateTime.tryParse(json['created_at'] as String? ?? '')?.toLocal() ??
              DateTime.now(),
      updatedAt:
          DateTime.tryParse(json['updated_at'] as String? ?? '')?.toLocal() ??
              DateTime.now(),
      messages: messages,
      // The detail response has no count of its own; the thread it carries is
      // the count.
      messageCount: json['message_count'] as int? ?? messages.length,
    );
  }

  /// The first line of a session row. Falls back rather than showing an empty
  /// row: a conversation always has *something* the user typed.
  String titleOr(String fallback) => title.trim().isEmpty ? fallback : title;
}
