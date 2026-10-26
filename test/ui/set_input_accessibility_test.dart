import 'dart:ui' show SemanticsAction;

import 'package:bodify/common/app_colors.dart';
import 'package:bodify/common_widget/set_input_fields.dart';
import 'package:bodify/core/app_locale.dart';
import 'package:bodify/core/app_strings.dart';
import 'package:bodify/models/progress_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

String _label(String key) => switch (key) {
      'duration' => tr('label_duration_seconds'),
      'distance' => tr('label_distance_m'),
      'weight' => tr('label_target_weight_kg'),
      _ => tr('label_reps'),
    };

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await LocaleController.instance.setLanguage(AppLanguage.vietnamese);
    final font = FontLoader('BeVietnamPro');
    for (final weight in ['Regular', 'Medium', 'Bold']) {
      font.addFont(rootBundle.load('assets/font/BeVietnamPro-$weight.ttf'));
    }
    await font.load();
  });

  for (final type in TrackingType.values) {
    testWidgets('${type.name} set form has accessible controls at 200% text',
        (tester) async {
      final reps = TextEditingController(text: '12');
      final weight = TextEditingController(text: '42.5');
      final duration = TextEditingController(text: '60');
      final distance = TextEditingController(text: '20');
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      try {
        await tester.pumpWidget(MaterialApp(
          theme: buildBodifyTheme(
              type == TrackingType.duration || type == TrackingType.distance
                  ? Brightness.dark
                  : Brightness.light),
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(360, 800),
              textScaler: TextScaler.linear(2),
            ),
            child: Scaffold(
              body: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: SetInputFields(
                    trackingType: type,
                    reps: reps,
                    weight: weight,
                    duration: duration,
                    distance: distance,
                    label: _label,
                  ),
                ),
              ),
            ),
          ),
        ));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.text(_label('weight')), findsOneWidget);
        expect(find.text('42.5'), findsOneWidget,
            reason: 'Every tracking type must keep its real weight editable.');

        Future<void> verifyStepper(
            String axis, TextEditingController controller, int step) async {
          final original = int.parse(controller.text);
          final increase =
              tr('btn_increase_value').replaceAll('{label}', _label(axis));
          final decrease =
              tr('btn_decrease_value').replaceAll('{label}', _label(axis));
          for (final label in [increase, decrease]) {
            final control = find.bySemanticsLabel(label);
            expect(control, findsOneWidget);
            await tester.ensureVisible(control);
            await tester.pumpAndSettle();
            final node = tester.getSemantics(control);
            expect(node.flagsCollection.isButton, isTrue);
            expect(
                node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
            expect(node.rect.width, greaterThanOrEqualTo(48));
            expect(node.rect.height, greaterThanOrEqualTo(48));
          }
          await tester.tap(find.bySemanticsLabel(increase));
          await tester.pumpAndSettle();
          expect(controller.text, '${original + step}');
          expect(weight.text, '42.5');
          await tester.tap(find.bySemanticsLabel(decrease));
          await tester.pumpAndSettle();
          expect(controller.text, '$original');
          expect(weight.text, '42.5');
          expect(tester.takeException(), isNull);
        }

        if (type == TrackingType.reps || type == TrackingType.repsDuration) {
          await verifyStepper('reps', reps, 1);
        }
        if (type == TrackingType.duration ||
            type == TrackingType.repsDuration) {
          await verifyStepper('duration', duration, 5);
        }
        if (type == TrackingType.distance) {
          expect(find.text(_label('distance')), findsOneWidget);
          expect(find.text('20'), findsOneWidget);
          expect(find.bySemanticsLabel(RegExp(r'^(Tăng|Giảm) ')), findsNothing,
              reason: 'A distance set retains its decimal input.');
        }
        expect(weight.text, '42.5');
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        reps.dispose();
        weight.dispose();
        duration.dispose();
        distance.dispose();
      }
    });
  }
}
