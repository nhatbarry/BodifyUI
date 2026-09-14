import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/api_config.dart';
import '../core/api_exception.dart';
import '../models/chat_models.dart';
import 'auth_service.dart';

/// The AI coach conversation, as the screen sees it.
///
/// An interface with one real implementation, kept because the screen should
/// not care whether an answer came from a server or a stub - and because a
/// test or a demo may want to swap [instance] for something that never leaves
/// the device.
abstract class AiCoachService {
  static AiCoachService instance = ApiAiCoachService();

  /// Sends one message and resolves with both halves of the exchange.
  ///
  /// `sessionId` null starts a new conversation - the server creates it and
  /// says which one it was, so opening the screen and typing is one round
  /// trip rather than two.
  Future<ChatExchange> send({int? sessionId, required String message});

  /// Past conversations, most recently used first.
  Future<List<ChatSession>> sessions();

  /// One conversation with its messages.
  Future<ChatSession> session(int sessionId);

  Future<void> delete(int sessionId);
}

/// What a send produced: where it landed, and both messages as the server
/// stored them.
class ChatExchange {
  final int sessionId;
  final String title;
  final ChatMessage question;
  final ChatMessage answer;

  const ChatExchange({
    required this.sessionId,
    required this.title,
    required this.question,
    required this.answer,
  });

  factory ChatExchange.fromJson(Map<String, dynamic> json) => ChatExchange(
        sessionId: json['chat_session_id'] as int,
        title: json['title'] as String? ?? '',
        question:
            ChatMessage.fromJson(json['user_message'] as Map<String, dynamic>),
        answer: ChatMessage.fromJson(
            json['assistant_message'] as Map<String, dynamic>),
      );
}

/// The real one: `/ai-coach/*` on the Bodify API.
///
/// The model is called on the server, so nothing here knows about Gemini and
/// no key ships in the app. The conversation history is not sent either - the
/// server reads it from the database, which is what stops a client putting
/// words in the coach's mouth.
class ApiAiCoachService implements AiCoachService {
  final http.Client _client = http.Client();

  /// Same retry-once-on-401 shape as the other services. Longer timeout than
  /// theirs: a model takes seconds to answer, where a database query does not.
  Future<http.Response> _send(
    Future<http.Response> Function(String token) request, {
    Duration timeout = const Duration(seconds: 60),
  }) async {
    final token = await AuthService.instance.validAccessToken();
    if (token == null) {
      throw const ApiException('Not signed in', statusCode: 401);
    }

    http.Response response;
    try {
      response = await request(token).timeout(timeout);
    } on TimeoutException {
      throw const ApiException('The coach took too long to answer.');
    } catch (_) {
      throw const ApiException('Cannot reach the server.');
    }

    if (response.statusCode == 401) {
      final session = await AuthService.instance.refreshSession();
      if (session == null) {
        throw const ApiException('Session expired', statusCode: 401);
      }
      try {
        response = await request(session.accessToken).timeout(timeout);
      } catch (_) {
        throw const ApiException('Cannot reach the server.');
      }
    }
    return response;
  }

  dynamic _decode(http.Response response) {
    // utf8.decode, not `response.body`: the default latin-1 reading turns
    // every Vietnamese answer into mojibake.
    final text = response.bodyBytes.isEmpty
        ? ''
        : utf8.decode(response.bodyBytes);
    final decoded = text.isEmpty ? null : jsonDecode(text);

    if (response.statusCode >= 200 && response.statusCode < 300) return decoded;
    throw ApiException(
      parseErrorMessage(decoded,
          fallback: 'Request failed (${response.statusCode})'),
      statusCode: response.statusCode,
    );
  }

  Map<String, String> _authJson(String token) => {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json; charset=utf-8',
      };

  @override
  Future<ChatExchange> send({int? sessionId, required String message}) async {
    final body = jsonEncode({'content': message});

    final response = await _send((token) => sessionId == null
        ? _client.post(
            ApiConfig.path('/ai-coach/sessions'),
            headers: _authJson(token),
            body: body,
          )
        : _client.post(
            ApiConfig.path('/ai-coach/sessions/$sessionId/messages'),
            headers: _authJson(token),
            body: body,
          ));

    return ChatExchange.fromJson(_decode(response) as Map<String, dynamic>);
  }

  @override
  Future<List<ChatSession>> sessions() async {
    final response = await _send(
      (token) => _client.get(
        ApiConfig.path('/ai-coach/sessions'),
        headers: {'Authorization': 'Bearer $token'},
      ),
      timeout: const Duration(seconds: 20),
    );
    return (_decode(response) as List<dynamic>)
        .map((e) => ChatSession.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<ChatSession> session(int sessionId) async {
    final response = await _send(
      (token) => _client.get(
        ApiConfig.path('/ai-coach/sessions/$sessionId'),
        headers: {'Authorization': 'Bearer $token'},
      ),
      timeout: const Duration(seconds: 20),
    );
    return ChatSession.fromJson(_decode(response) as Map<String, dynamic>);
  }

  @override
  Future<void> delete(int sessionId) async {
    final response = await _send(
      (token) => _client.delete(
        ApiConfig.path('/ai-coach/sessions/$sessionId'),
        headers: {'Authorization': 'Bearer $token'},
      ),
      timeout: const Duration(seconds: 20),
    );
    _decode(response);
  }
}
