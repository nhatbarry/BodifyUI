/// What the AI coach conversation is made of.
///
/// Shaped after the backend that will serve it (Phase 6): a session owns an
/// ordered list of messages, and a message is only ever "the user said this"
/// or "the coach said this". The greeting the screen opens with is **not** a
/// message - it is UI, so it never reaches the history or the model's context.

class ChatMessage {
  final String content;
  final bool isUser;
  final DateTime sentAt;

  /// The reply failed to arrive. Kept in the list rather than dropped: a
  /// question that vanishes leaves the user unsure whether it was sent.
  final bool failed;

  const ChatMessage({
    required this.content,
    required this.isUser,
    required this.sentAt,
    this.failed = false,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
        content: json['content'] as String? ?? '',
        isUser: json['is_user'] as bool? ?? false,
        sentAt: DateTime.tryParse(json['sent_at'] as String? ?? '')?.toLocal() ??
            DateTime.now(),
      );

  Map<String, dynamic> toJson() => {
        'content': content,
        'is_user': isUser,
        'sent_at': sentAt.toUtc().toIso8601String(),
      };
}

/// One conversation. `title` is derived from the first thing the user asked,
/// which is what makes a history list readable without opening every row.
class ChatSession {
  final String id;
  final String title;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<ChatMessage> messages;

  const ChatSession({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    this.messages = const [],
  });

  ChatSession copyWith({
    String? title,
    DateTime? updatedAt,
    List<ChatMessage>? messages,
  }) =>
      ChatSession(
        id: id,
        title: title ?? this.title,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        messages: messages ?? this.messages,
      );

  factory ChatSession.fromJson(Map<String, dynamic> json) => ChatSession(
        id: '${json['session_id'] ?? json['id']}',
        title: json['title'] as String? ?? '',
        createdAt:
            DateTime.tryParse(json['created_at'] as String? ?? '')?.toLocal() ??
                DateTime.now(),
        updatedAt:
            DateTime.tryParse(json['updated_at'] as String? ?? '')?.toLocal() ??
                DateTime.now(),
        messages: (json['messages'] as List<dynamic>? ?? const [])
            .map((e) => ChatMessage.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  /// The first line of a session row. Falls back rather than showing an empty
  /// row: a conversation always has *something* the user typed.
  String titleOr(String fallback) => title.trim().isEmpty ? fallback : title;
}
