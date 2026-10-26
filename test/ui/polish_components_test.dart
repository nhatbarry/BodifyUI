import 'dart:ui' show SemanticsAction, Tristate;

import 'package:bodify/common/app_colors.dart';
import 'package:bodify/common_widget/pill_switcher.dart';
import 'package:bodify/common_widget/round_button.dart';
import 'package:bodify/common_widget/tab_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _screen = Size(360, 800);
const _longAction = 'Bắt đầu buổi tập luyện hôm nay';
const _plannerLabels = ['Lịch tập luyện', 'Kế hoạch dinh dưỡng'];
const _tabLabels = ['Trang chủ', 'Theo dõi', 'Huấn luyện viên', 'Hồ sơ'];

Future<void> _pumpNarrowLargeText(
  WidgetTester tester, {
  required Brightness brightness,
  required Widget child,
}) async {
  tester.view.physicalSize = _screen;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      theme: buildBodifyTheme(brightness),
      home: MediaQuery(
        data: const MediaQueryData(
          size: _screen,
          textScaler: TextScaler.linear(2),
        ),
        child: Scaffold(
          body: Align(
            alignment: Alignment.topCenter,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: child,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull,
      reason: 'Vietnamese labels must fit a 360px screen at 200% font size.');
}

void _expectAccessibleTapTarget(WidgetTester tester, String label) {
  final node = tester.getSemantics(find.bySemanticsLabel(label));
  expect(node.flagsCollection.isButton, isTrue);
  expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
  expect(node.rect.width, greaterThanOrEqualTo(48));
  expect(node.rect.height, greaterThanOrEqualTo(48));
}

void _expectSelection(WidgetTester tester, String label, bool selected) {
  final flags =
      tester.getSemantics(find.bySemanticsLabel(label)).flagsCollection;
  expect(flags.isSelected, selected ? Tristate.isTrue : Tristate.isFalse);
}

double _contrast(Color foreground, Color background) {
  final first = foreground.computeLuminance();
  final second = background.computeLuminance();
  final lighter = first > second ? first : second;
  final darker = first < second ? first : second;
  return (lighter + 0.05) / (darker + 0.05);
}

void main() {
  setUpAll(() async {
    final font = FontLoader('BeVietnamPro');
    for (final weight in ['Regular', 'Medium', 'Bold']) {
      font.addFont(rootBundle.load('assets/font/BeVietnamPro-$weight.ttf'));
    }
    await font.load();
  });
  for (final brightness in Brightness.values) {
    test('${brightness.name} gradient labels have readable contrast', () {
      final palette = brightness == Brightness.dark
          ? BodifyColors.dark
          : BodifyColors.light;
      for (final background in [
        ...palette.primaryGradient,
        ...palette.secondaryGradient,
      ]) {
        expect(
            _contrast(palette.onPrimary, background), greaterThanOrEqualTo(4.5),
            reason: 'Normal text must remain readable at every gradient end.');
      }
    });

    for (final type in RoundButtonType.values) {
      testWidgets(
          '${brightness.name} ${type.name} action fits large Vietnamese text and responds',
          (tester) async {
        var taps = 0;
        await _pumpNarrowLargeText(tester,
            brightness: brightness,
            child: RoundButton(
              title: _longAction,
              type: type,
              onPressed: () => taps++,
            ));

        expect(find.text(_longAction), findsOneWidget);
        _expectAccessibleTapTarget(tester, _longAction);
        await tester.tap(find.bySemanticsLabel(_longAction));
        await tester.pumpAndSettle();
        expect(taps, 1);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets(
        '${brightness.name} planner announces selection and accepts large-label taps',
        (tester) async {
      var selected = 0;
      final changes = <int>[];
      await _pumpNarrowLargeText(tester, brightness: brightness,
          child: StatefulBuilder(builder: (context, setState) {
        return PillSwitcher(
          labels: _plannerLabels,
          selected: selected,
          // Existing call sites may ask for a compact height. The public
          // control still needs an accessible hit area at large text size.
          height: 40,
          onChanged: (index) {
            changes.add(index);
            setState(() => selected = index);
          },
        );
      }));

      for (var index = 0; index < _plannerLabels.length; index++) {
        final label = _plannerLabels[index];
        expect(find.text(label), findsOneWidget);
        _expectAccessibleTapTarget(tester, label);
        _expectSelection(tester, label, index == selected);
      }
      await tester.tap(find.bySemanticsLabel(_plannerLabels[1]));
      await tester.pumpAndSettle();
      expect(changes, [1]);
      expect(selected, 1);
      _expectSelection(tester, _plannerLabels[1], true);
      _expectSelection(tester, _plannerLabels[0], false);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        '${brightness.name} tabs expose labels, selection and 48px tap targets',
        (tester) async {
      var selected = 0;
      final taps = <int>[];
      await _pumpNarrowLargeText(tester, brightness: brightness,
          child: StatefulBuilder(builder: (context, setState) {
        return IntrinsicHeight(
            child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var index = 0; index < _tabLabels.length; index++) ...[
              if (index == 2) const SizedBox(width: 64),
              Expanded(
                child: TabButton(
                  label: _tabLabels[index],
                  iconData: Icons.home_outlined,
                  isActive: selected == index,
                  onTap: () {
                    taps.add(index);
                    setState(() => selected = index);
                  },
                ),
              ),
            ],
          ],
        ));
      }));

      for (var index = 0; index < _tabLabels.length; index++) {
        final label = _tabLabels[index];
        expect(find.text(label), findsOneWidget);
        _expectAccessibleTapTarget(tester, label);
        _expectSelection(tester, label, index == selected);
      }
      await tester.tap(find.bySemanticsLabel(_tabLabels[2]));
      await tester.pumpAndSettle();
      expect(taps, [2]);
      expect(selected, 2);
      _expectSelection(tester, _tabLabels[2], true);
      _expectSelection(tester, _tabLabels[0], false);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Disabled action remains readable and has no tap semantics',
      (tester) async {
    await _pumpNarrowLargeText(tester,
        brightness: Brightness.light,
        child: const RoundButton(title: _longAction, onPressed: null));

    expect(find.text(_longAction), findsOneWidget);
    final node = tester.getSemantics(find.bySemanticsLabel(_longAction));
    expect(node.flagsCollection.isButton, isTrue);
    expect(node.flagsCollection.isEnabled, Tristate.isFalse);
    expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isFalse);
  });
}
