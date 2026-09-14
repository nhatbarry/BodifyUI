import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../common/app_colors.dart';
import '../../core/api_exception.dart';
import '../../core/app_strings.dart';
import '../../models/chat_models.dart';
import '../../services/ai_coach_service.dart';
import 'chat_history_sheet.dart';
import 'chat_markdown.dart';

/// The AI coach conversation.
///
/// One screen, one conversation, with the others a tap away in the history
/// sheet - the shape every chat app has settled on, and the one the Kotlin
/// prototype in `D:\BodifyAIFitness` arrived at too.
///
/// The coach's answers come from [AiCoachService]. Today that is a local
/// stand-in that says so; Phase 6 replaces it with the backend, where the
/// user's training history is and where the model key can live safely.
class AiCoachView extends StatefulWidget {
  const AiCoachView({super.key});

  @override
  State<AiCoachView> createState() => _AiCoachViewState();
}

class _AiCoachViewState extends State<AiCoachView> {
  final TextEditingController _input = TextEditingController();
  final ScrollController _scroll = ScrollController();
  final FocusNode _inputFocus = FocusNode();

  /// The conversation on screen. The greeting is not in here: it is drawn by
  /// the empty state, so it never becomes something the model has to read back
  /// or the history has to store.
  List<ChatMessage> _messages = [];

  /// Null until the server has created the conversation - which it does on the
  /// first message, so a user who opens the tab and leaves does not litter
  /// their history with an empty thread.
  int? _sessionId;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    // Redraws the send button as the field fills and empties.
    _input.addListener(_onInputChanged);
  }

  @override
  void dispose() {
    _input.removeListener(_onInputChanged);
    _input.dispose();
    _scroll.dispose();
    _inputFocus.dispose();
    super.dispose();
  }

  void _onInputChanged() => setState(() {});

  bool get _canSend => _input.text.trim().isNotEmpty && !_sending;

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty || _sending) return;

    final question = ChatMessage(
      content: text,
      isUser: true,
      sentAt: DateTime.now(),
    );

    setState(() {
      _messages = [..._messages, question];
      _input.clear();
      _sending = true;
    });
    _scrollToEnd();

    try {
      // The history is not sent: the server reads it from the database, which
      // is what stops a client putting words in the coach's mouth.
      final exchange = await AiCoachService.instance.send(
        sessionId: _sessionId,
        message: text,
      );
      if (!mounted) return;
      setState(() {
        _sessionId = exchange.sessionId;
        // The optimistic copy of the question is replaced by the server's, so
        // the list holds one version of each sentence with a real id and the
        // server's clock.
        _messages = [
          ..._messages.sublist(0, _messages.length - 1),
          exchange.question,
          exchange.answer,
        ];
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _messages = [
          ..._messages,
          ChatMessage(
            content: tr('error_ai_coach_failed'),
            isUser: false,
            sentAt: DateTime.now(),
            failed: true,
          ),
        ];
      });
    } finally {
      if (mounted) {
        setState(() => _sending = false);
        _scrollToEnd();
      }
    }
  }

  void _scrollToEnd() {
    // After the frame the new bubble is laid out in - before it, the extent to
    // scroll to is the old one and the last message stays half off-screen.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  void _startNewChat() {
    if (_messages.isEmpty) return; // already on a blank conversation
    setState(() {
      // Nothing is created server-side until the first message: an empty
      // thread in the history is clutter nobody asked for.
      _sessionId = null;
      _messages = [];
      _sending = false;
    });
  }

  Future<void> _openHistory() async {
    _inputFocus.unfocus();
    final chosen = await showChatHistorySheet(
      context,
      currentSessionId: _sessionId,
      onNewChat: _startNewChat,
    );
    if (chosen == null || !mounted) return;

    // The list rows carry no messages - the thread is fetched when one is
    // actually opened, so the history screen costs one small response.
    setState(() {
      _sessionId = chosen.id;
      _messages = [];
      _sending = true;
    });

    try {
      final full = await AiCoachService.instance.session(chosen.id);
      if (!mounted) return;
      setState(() => _messages = full.messages);
    } catch (e) {
      _showError(e);
    } finally {
      if (mounted) setState(() => _sending = false);
      _scrollToEnd();
    }
  }

  void _showError(Object e) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(e is ApiException ? e.message : '$e')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Scaffold(
      backgroundColor: colors.surface,
      // The input has to ride above the keyboard, and this screen is the whole
      // tab - so the scaffold resizes rather than the list being padded by hand.
      resizeToAvoidBottomInset: true,
      appBar: _buildAppBar(colors),
      body: Column(
        children: [
          Expanded(
            child: _messages.isEmpty
                ? _buildGreeting(colors)
                : _buildConversation(colors),
          ),
          _buildComposer(colors),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BodifyColors colors) {
    return AppBar(
      backgroundColor: colors.surface,
      elevation: 0,
      automaticallyImplyLeading: false,
      titleSpacing: 16,
      title: Row(
        children: [
          _CoachAvatar(size: 36, iconSize: 19, colors: colors),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  tr('nav_ai_coach'),
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  tr('subtitle_ai_coach'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: colors.textSecondary, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          onPressed: _messages.isEmpty ? null : _startNewChat,
          tooltip: tr('btn_new_chat'),
          icon: Icon(
            Icons.add_comment_outlined,
            size: 20,
            color: _messages.isEmpty ? colors.textSecondary : colors.textPrimary,
          ),
        ),
        IconButton(
          onPressed: _openHistory,
          tooltip: tr('title_chat_history'),
          icon: Icon(Icons.history, size: 22, color: colors.primary1),
        ),
        const SizedBox(width: 4),
      ],
    );
  }

  /// What the screen says before anything has been asked.
  ///
  /// Drawn rather than seeded as a first message: a greeting in the message
  /// list would be sent to the model as context and stored in the history as
  /// if the coach had said something.
  Widget _buildGreeting(BodifyColors colors) {
    final prompts = [
      tr('prompt_ai_plan'),
      tr('prompt_ai_form'),
      tr('prompt_ai_nutrition'),
    ];

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 16),
      children: [
        Center(child: _CoachAvatar(size: 72, iconSize: 34, colors: colors)),
        const SizedBox(height: 18),
        Text(
          tr('title_ai_greeting'),
          textAlign: TextAlign.center,
          style: TextStyle(
            color: colors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          tr('msg_ai_greeting'),
          textAlign: TextAlign.center,
          style: TextStyle(
            color: colors.textSecondary,
            fontSize: 13,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 26),
        // Starter questions, because a blank chat box is the hardest thing to
        // answer: they show what this thing is for in the shape of a tap.
        for (final prompt in prompts)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _SuggestionChip(
              text: prompt,
              colors: colors,
              onTap: () {
                _input.text = prompt;
                _send();
              },
            ),
          ),
      ],
    );
  }

  Widget _buildConversation(BodifyColors colors) {
    return ListView.builder(
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
      // One extra row for the typing indicator while a reply is in flight.
      itemCount: _messages.length + (_sending ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _messages.length) {
          return _TypingIndicator(colors: colors);
        }
        return _MessageBubble(message: _messages[index], colors: colors);
      },
    );
  }

  /// How far the tab bar's floating search button reaches up into this screen.
  ///
  /// It is 70px tall and `centerDocked`, so half of it sits above the nav bar -
  /// directly over the middle of a full-width input. Without this clearance a
  /// tap in the centre of the text field opens the exercise search instead.
  static const double _fabOverhang = 36;

  Widget _buildComposer(BodifyColors colors) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8 + _fabOverhang),
        decoration: BoxDecoration(
          color: colors.surface,
          border: Border(
            top: BorderSide(color: colors.surfaceVariant, width: 1),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: ConstrainedBox(
                // Grows with a long question, then scrolls - so the message
                // list never loses more than a third of the screen to it.
                constraints: const BoxConstraints(maxHeight: 120),
                child: TextField(
                  controller: _input,
                  focusNode: _inputFocus,
                  minLines: 1,
                  maxLines: null,
                  textCapitalization: TextCapitalization.sentences,
                  textInputAction: TextInputAction.newline,
                  style: TextStyle(color: colors.textPrimary, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: tr('hint_ask_ai_coach'),
                    hintStyle:
                        TextStyle(color: colors.textSecondary, fontSize: 14),
                    filled: true,
                    fillColor: colors.surfaceVariant,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(22),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            _SendButton(
              enabled: _canSend,
              colors: colors,
              onTap: () {
                HapticFeedback.selectionClick();
                _send();
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// Pieces
// ============================================================

class _CoachAvatar extends StatelessWidget {
  final double size;
  final double iconSize;
  final BodifyColors colors;

  const _CoachAvatar({
    required this.size,
    required this.iconSize,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: colors.primaryGradient),
        shape: BoxShape.circle,
      ),
      child: Icon(Icons.auto_awesome, color: colors.onPrimary, size: iconSize),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final BodifyColors colors;

  const _MessageBubble({required this.message, required this.colors});

  static String _time(DateTime at) =>
      '${at.hour.toString().padLeft(2, '0')}:${at.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;
    final width = MediaQuery.of(context).size.width;

    final bubble = Container(
      constraints: BoxConstraints(maxWidth: width * 0.78),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isUser
            ? colors.primary1
            : (message.failed
                ? const Color(0xFFE74C3C).withValues(alpha: 0.12)
                : colors.surfaceVariant),
        // The square corner points at whoever is speaking - the cheapest way
        // to tell the two sides apart without a label.
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(16),
          topRight: const Radius.circular(16),
          bottomLeft: Radius.circular(isUser ? 16 : 4),
          bottomRight: Radius.circular(isUser ? 4 : 16),
        ),
      ),
      child: ChatMarkdown(
        text: message.content,
        color: isUser
            ? colors.onPrimary
            : (message.failed ? const Color(0xFFE74C3C) : colors.textPrimary),
      ),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment:
            isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment:
                isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (!isUser) ...[
                _CoachAvatar(size: 28, iconSize: 15, colors: colors),
                const SizedBox(width: 8),
              ],
              Flexible(child: bubble),
            ],
          ),
          Padding(
            padding: EdgeInsets.only(
              top: 4,
              left: isUser ? 0 : 36,
              right: isUser ? 2 : 0,
            ),
            child: Text(
              _time(message.sentAt),
              style: TextStyle(color: colors.textSecondary, fontSize: 10),
            ),
          ),
        ],
      ),
    );
  }
}

/// Three dots while the coach is thinking.
///
/// An animation rather than a spinner: a spinner reads as "loading a screen",
/// and this is somebody about to answer you.
class _TypingIndicator extends StatefulWidget {
  final BodifyColors colors;

  const _TypingIndicator({required this.colors});

  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = widget.colors;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _CoachAvatar(size: 28, iconSize: 15, colors: colors),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: colors.surfaceVariant,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
                bottomLeft: Radius.circular(4),
                bottomRight: Radius.circular(16),
              ),
            ),
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(3, (i) {
                    // Each dot peaks a third of a cycle after the one before.
                    final t = (_controller.value - i * 0.2) % 1.0;
                    final lift = t < 0.5 ? t * 2 : (1 - t) * 2;
                    return Padding(
                      padding: EdgeInsets.only(right: i == 2 ? 0 : 5),
                      child: Opacity(
                        opacity: 0.35 + lift * 0.65,
                        child: Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: colors.textSecondary,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    );
                  }),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SendButton extends StatelessWidget {
  final bool enabled;
  final BodifyColors colors;
  final VoidCallback onTap;

  const _SendButton({
    required this.enabled,
    required this.colors,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 44,
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: enabled
              ? LinearGradient(colors: colors.primaryGradient)
              : null,
          color: enabled ? null : colors.surfaceVariant,
          shape: BoxShape.circle,
        ),
        child: Icon(
          Icons.arrow_upward_rounded,
          size: 20,
          color: enabled ? colors.onPrimary : colors.textSecondary,
        ),
      ),
    );
  }
}

class _SuggestionChip extends StatelessWidget {
  final String text;
  final BodifyColors colors;
  final VoidCallback onTap;

  const _SuggestionChip({
    required this.text,
    required this.colors,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: colors.surfaceVariant,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: colors.primary1.withValues(alpha: 0.25)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                text,
                style: TextStyle(color: colors.textPrimary, fontSize: 13),
              ),
            ),
            Icon(Icons.north_east, size: 15, color: colors.primary1),
          ],
        ),
      ),
    );
  }
}
