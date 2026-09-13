import 'package:flutter/material.dart';

import '../../common/app_colors.dart';
import '../../core/app_strings.dart';
import '../../models/chat_models.dart';
import '../../services/ai_coach_service.dart';

/// Past conversations, as a sheet over the one in progress.
///
/// A sheet rather than a screen: picking an old conversation is a detour from
/// the chat, not a place to be, and the message you were half way through
/// typing stays visible behind it.
///
/// Resolves with the conversation to open, or null if the user just closed it.
Future<ChatSession?> showChatHistorySheet(
  BuildContext context, {
  required String currentSessionId,
  required VoidCallback onNewChat,
}) {
  return showModalBottomSheet<ChatSession>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => _ChatHistorySheet(
      currentSessionId: currentSessionId,
      onNewChat: onNewChat,
    ),
  );
}

class _ChatHistorySheet extends StatefulWidget {
  final String currentSessionId;
  final VoidCallback onNewChat;

  const _ChatHistorySheet({
    required this.currentSessionId,
    required this.onNewChat,
  });

  @override
  State<_ChatHistorySheet> createState() => _ChatHistorySheetState();
}

class _ChatHistorySheetState extends State<_ChatHistorySheet> {
  List<ChatSession>? _sessions;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final sessions = await AiCoachService.instance.sessions();
    if (mounted) setState(() => _sessions = sessions);
  }

  Future<void> _delete(ChatSession session) async {
    await AiCoachService.instance.delete(session.id);
    if (!mounted) return;
    setState(() => _sessions =
        _sessions?.where((s) => s.id != session.id).toList() ?? []);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final sessions = _sessions;

    return Container(
      // Never more than most of the screen: the conversation underneath is
      // what the user is coming back to.
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.75,
      ),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: colors.surfaceVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 12, 10),
              child: Row(
                children: [
                  Icon(Icons.history, size: 19, color: colors.primary1),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      tr('title_chat_history'),
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      widget.onNewChat();
                    },
                    icon: Icon(Icons.add, size: 17, color: colors.primary1),
                    label: Text(
                      tr('btn_new_chat'),
                      style: TextStyle(color: colors.primary1, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: colors.surfaceVariant),
            Flexible(
              child: sessions == null
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 46),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  : sessions.isEmpty
                      ? _buildEmpty(colors)
                      : ListView.builder(
                          shrinkWrap: true,
                          padding: const EdgeInsets.fromLTRB(14, 12, 14, 16),
                          itemCount: sessions.length,
                          itemBuilder: (context, i) => _SessionRow(
                            session: sessions[i],
                            isCurrent:
                                sessions[i].id == widget.currentSessionId,
                            colors: colors,
                            onTap: () =>
                                Navigator.pop(context, sessions[i]),
                            onDelete: () => _delete(sessions[i]),
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty(BodifyColors colors) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 42, horizontal: 30),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.forum_outlined, size: 34, color: colors.textSecondary),
          const SizedBox(height: 12),
          Text(
            tr('msg_no_chat_history'),
            textAlign: TextAlign.center,
            style: TextStyle(color: colors.textSecondary, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _SessionRow extends StatelessWidget {
  final ChatSession session;
  final bool isCurrent;
  final BodifyColors colors;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _SessionRow({
    required this.session,
    required this.isCurrent,
    required this.colors,
    required this.onTap,
    required this.onDelete,
  });

  /// "Vừa xong" reads better than a timestamp for something from two minutes
  /// ago; a date reads better than "9 ngày trước". The switch happens at a
  /// week, which is roughly where people stop counting in days.
  String _when() {
    final diff = DateTime.now().difference(session.updatedAt);
    if (diff.inMinutes < 1) return tr('label_just_now');
    if (diff.inHours < 1) {
      return tr('label_minutes_ago').replaceFirst('{n}', '${diff.inMinutes}');
    }
    if (diff.inDays < 1) {
      return tr('label_hours_ago').replaceFirst('{n}', '${diff.inHours}');
    }
    if (diff.inDays < 7) {
      return tr('label_days_ago').replaceFirst('{n}', '${diff.inDays}');
    }
    final d = session.updatedAt;
    return '${d.day.toString().padLeft(2, '0')}/'
        '${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
          decoration: BoxDecoration(
            color: colors.surfaceVariant,
            borderRadius: BorderRadius.circular(14),
            // The conversation you are already in is marked, so reopening it
            // is not mistaken for starting somewhere new.
            border: isCurrent
                ? Border.all(color: colors.primary1.withValues(alpha: 0.6))
                : null,
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: colors.primary1.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.auto_awesome,
                    size: 17, color: colors.primary1),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      session.titleOr(tr('label_untitled_chat')),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${_when()} · ${tr('label_message_count').replaceFirst('{n}', '${session.messages.length}')}',
                      style: TextStyle(
                          color: colors.textSecondary, fontSize: 11),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: onDelete,
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.delete_outline,
                    size: 18, color: Color(0xFFE74C3C)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
