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

  const ChatMessage({
    required this.content,
    required this.isUser,
    required this.sentAt,
    this.id,
    this.failed = false,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
        id: json['chat_message_id'] as int?,
        content: json['content'] as String? ?? '',
        // The API's vocabulary is a role, not a flag - 'user' or 'assistant'.
        isUser: (json['role'] as String? ?? 'assistant') == 'user',
        sentAt:
            DateTime.tryParse(json['created_at'] as String? ?? '')?.toLocal() ??
                DateTime.now(),
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
