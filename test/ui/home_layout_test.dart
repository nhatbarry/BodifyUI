import 'dart:ui' show SemanticsAction;

import 'package:bodify/common/app_colors.dart';
import 'package:bodify/core/app_locale.dart';
import 'package:bodify/core/app_strings.dart';
import 'package:bodify/view/home/home_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _secureStorage =
    MethodChannel('plugins.it_nomads.com/flutter_secure_storage');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  var tokenReads = 0;

  setUpAll(() async {
    final font = FontLoader('BeVietnamPro');
    for (final weight in ['Regular', 'Medium', 'Bold']) {
      font.addFont(rootBundle.load('assets/font/BeVietnamPro-$weight.ttf'));
    }
    await font.load();
  });

  setUp(() async {
    tokenReads = 0;
    SharedPreferences.setMockInitialValues({});
    await LocaleController.instance.setLanguage(AppLanguage.vietnamese);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_secureStorage, (call) async {
      if (call.method == 'read') {
        tokenReads++;
        // An absent local session is enough to exercise actual service errors.
        // Never mint a token or persist a fake session for layout verification.
        return null;
      }
      throw StateError('Unexpected secure-storage operation: ${call.method}');
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_secureStorage, null);
  });

  for (final brightness in Brightness.values) {
    for (final size in [const Size(360, 800), const Size(640, 360)]) {
      for (final scale in [1.0, 2.0]) {
        testWidgets(
            'Home ${brightness.name} ${size.width.toInt()}x${size.height.toInt()} '
            '${(scale * 100).toInt()}% text handles absent session and retry',
            (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);

          await tester.pumpWidget(MaterialApp(
            theme: buildBodifyTheme(brightness),
            home: MediaQuery(
              data: MediaQueryData(
                size: size,
                textScaler: TextScaler.linear(scale),
                // Status and gesture bars should not hide content or targets.
                padding: const EdgeInsets.only(top: 24, bottom: 24),
              ),
              child: const HomeView(),
            ),
          ));
          await tester.pumpAndSettle();

          expect(tester.takeException(), isNull,
              reason: 'Home must lay out and settle real asynchronous errors.');
          expect(tokenReads, greaterThanOrEqualTo(3));
          expect(find.byType(CircularProgressIndicator), findsNothing);
          expect(find.text(tr('label_bodify_user')), findsOneWidget);
          expect(find.text(tr('title_bmi')), findsOneWidget);
          expect(find.text(tr('msg_bmi_load_failed')), findsOneWidget);
          expect(find.text(tr('msg_activity_load_failed')), findsOneWidget);
          expect(find.text(tr('msg_health_unavailable')), findsOneWidget);
          expect(find.text(tr('btn_retry')), findsNWidgets(2));
          expect(find.text('–'), findsWidgets,
              reason: 'Unknown measurements use a missing-value marker.');
          expect(
            find.byWidgetPredicate((widget) =>
                widget is Text &&
                RegExp(r'^\d+(?:[.,]\d+)?$').hasMatch(widget.data ?? '')),
            findsNothing,
            reason:
                'An absent session must not fabricate BMI or health values.',
          );

          // Reach and use both real error actions, including the activity card
          // below the fold on a small phone or in landscape.
          for (var index = 0; index < 2; index++) {
            final retry = find.text(tr('btn_retry')).at(index);
            final button = find
                .ancestor(
                    of: retry,
                    matching: find.byWidgetPredicate(
                        (widget) => widget is ButtonStyleButton))
                .first;
            await tester.ensureVisible(button);
            await tester.pumpAndSettle();
            final node = tester.getSemantics(button);
            expect(node.flagsCollection.isButton, isTrue);
            expect(
                node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
            expect(node.rect.width, greaterThanOrEqualTo(48));
            expect(node.rect.height, greaterThanOrEqualTo(48));
            final previousReads = tokenReads;
            await tester.tap(retry);
            await tester.pumpAndSettle();
            expect(tokenReads, greaterThan(previousReads),
                reason: 'Retry must call the actual service again.');
            expect(find.text(tr('msg_bmi_load_failed')), findsOneWidget);
            expect(find.text(tr('msg_activity_load_failed')), findsOneWidget);
            expect(tester.takeException(), isNull,
                reason: 'Retry must preserve a stable, readable error layout.');
          }
        });
      }
    }
  }
}
