
import 'package:bodify/common/app_colors.dart';
import 'package:flutter/material.dart';

class BlankView extends StatefulWidget {
  const BlankView({super.key});

  @override
  State<BlankView> createState() => _BlankViewState();
}

class _BlankViewState extends State<BlankView> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.surface,
    );
  }
}