import 'dart:async';
import 'dart:math';

import '../core/app_strings.dart';
import '../models/chat_models.dart';

/// The AI coach conversation, as the screen sees it.
///
/// An interface rather than a concrete client, because the thing behind it is
/// not built yet: Phase 6 puts the model call on the backend, where the user's
/// training data lives and the API key is not shipped inside the app. Until
/// then [LocalAiCoachService] stands in, and swapping it is one line in
/// [AiCoachService.instance].
abstract class AiCoachService {
  /// Swapped for the HTTP-backed implementation when Phase 6 lands.
  static AiCoachService instance = LocalAiCoachService();

  /// Sends one message in [sessionId] and resolves with the coach's reply.
  Future<ChatMessage> send({
    required String sessionId,
    required String message,
    required List<ChatMessage> history,
  });

  /// Past conversations, most recently used first.
  Future<List<ChatSession>> sessions();

  /// One conversation with its messages.
  Future<ChatSession?> session(String sessionId);

  /// Records what a conversation now contains, creating it if it is new.
  Future<void> save(ChatSession session);

  Future<void> delete(String sessionId);
}

/// A stand-in that answers on-device so the screen is usable before the
/// backend exists.
///
/// It is deliberately obvious about what it is: the replies say so. A
/// placeholder that imitates a real coach would let a half-built feature look
/// finished, and the first person fooled by it would be us.
///
/// Sessions live in memory only. They survive moving between tabs, which is
/// what the history sheet needs to be worth showing, and not an app restart -
/// storing them locally would build a second home for data the backend is
/// about to own.
class LocalAiCoachService implements AiCoachService {
  final Map<String, ChatSession> _sessions = {};
  final Random _random = Random();

  @override
  Future<ChatMessage> send({
    required String sessionId,
    required String message,
    required List<ChatMessage> history,
  }) async {
    // A pause in roughly the range a real model call takes, so the typing
    // indicator and the scroll behaviour are exercised rather than skipped.
    await Future<void>.delayed(
      Duration(milliseconds: 700 + _random.nextInt(700)),
    );

    return ChatMessage(
      content: tr('msg_ai_coach_placeholder_reply'),
      isUser: false,
      sentAt: DateTime.now(),
    );
  }

  @override
  Future<List<ChatSession>> sessions() async {
    final all = _sessions.values.toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return all;
  }

  @override
  Future<ChatSession?> session(String sessionId) async => _sessions[sessionId];

  @override
  Future<void> save(ChatSession session) async {
    if (session.messages.isEmpty) return;
    _sessions[session.id] = session;
  }

  @override
  Future<void> delete(String sessionId) async {
    _sessions.remove(sessionId);
  }
}
