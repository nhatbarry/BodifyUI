import 'package:flutter/material.dart';

/// The little bit of Markdown a chat model actually emits.
///
/// Bold and bullets, nothing else. A full Markdown package would pull in a
/// parser, its own theming and a table renderer to draw two things - and every
/// unsupported construct it *does* understand becomes a new way for a reply to
/// come out looking wrong. What is not handled here is shown as typed, which
/// is the honest failure mode.
class ChatMarkdown extends StatelessWidget {
  final String text;
  final Color color;
  final double fontSize;

  const ChatMarkdown({
    super.key,
    required this.text,
    required this.color,
    this.fontSize = 14,
  });

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        style: TextStyle(color: color, fontSize: fontSize, height: 1.45),
        children: _spans(),
      ),
    );
  }

  List<TextSpan> _spans() {
    final spans = <TextSpan>[];
    final lines = text.split('\n');

    for (var i = 0; i < lines.length; i++) {
      if (i > 0) spans.add(const TextSpan(text: '\n'));

      var line = lines[i];
      // Models write lists with either marker; both mean the same thing to a
      // reader, so both become the same bullet.
      if (line.startsWith('* ') || line.startsWith('- ')) {
        line = '•  ${line.substring(2)}';
      }

      // Odd-numbered pieces sit between a pair of **, so they are the bold
      // ones. An unclosed ** leaves its text unstyled rather than turning the
      // rest of the message bold.
      final parts = line.split('**');
      for (var p = 0; p < parts.length; p++) {
        if (parts[p].isEmpty) continue;
        final bolded = p.isOdd && parts.length.isOdd;
        spans.add(TextSpan(
          text: parts[p],
          style: bolded ? const TextStyle(fontWeight: FontWeight.w700) : null,
        ));
      }
    }

    return spans;
  }
}
