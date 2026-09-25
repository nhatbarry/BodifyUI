import 'package:flutter/material.dart';

/// An [IndexedStack] that fades the newly shown child in, with a slight rise.
///
/// Every child stays mounted, exactly as with a plain IndexedStack, so state
/// and already-fetched data survive switching away and back (the reason the
/// main tabs use one - see MainTabView). Only the transition is new: a
/// switch that snapped from one screen to the next read as a jump rather than
/// a move.
///
/// Honours the platform's "reduce motion" setting by not animating at all.
class FadeIndexedStack extends StatefulWidget {
  final int index;
  final List<Widget> children;
  final Duration duration;

  const FadeIndexedStack({
    super.key,
    required this.index,
    required this.children,
    this.duration = const Duration(milliseconds: 220),
  });

  @override
  State<FadeIndexedStack> createState() => _FadeIndexedStackState();
}

class _FadeIndexedStackState extends State<FadeIndexedStack>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: widget.duration, value: 1);
  late final Animation<double> _curve =
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);

  @override
  void didUpdateWidget(FadeIndexedStack oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.index != widget.index) {
      if (MediaQuery.of(context).disableAnimations) {
        _controller.value = 1;
      } else {
        _controller.forward(from: 0);
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _curve,
      child: SlideTransition(
        position: Tween(begin: const Offset(0, 0.015), end: Offset.zero)
            .animate(_curve),
        child: IndexedStack(index: widget.index, children: widget.children),
      ),
    );
  }
}
