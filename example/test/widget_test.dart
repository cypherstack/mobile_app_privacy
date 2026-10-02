// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mobile_app_privacy_example/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const pluginChannel = MethodChannel('mobile_app_privacy');
  const platformChannel = MethodChannel('mobile_app_privacy_example/platform');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  setUp(() {
    var filtered = true;
    messenger.setMockMethodCallHandler(pluginChannel, (call) async {
      switch (call.method) {
        case 'getPlatformVersion':
          return 'Android 14';
        case 'setAccessibilityDataSensitive':
          filtered = call.arguments['enable'] as bool;
          return filtered;
        case 'isAccessibilityDataSensitive':
          return filtered;
        default:
          return null;
      }
    });
    messenger.setMockMethodCallHandler(platformChannel, (_) async => 34);
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(pluginChannel, null);
    messenger.setMockMethodCallHandler(platformChannel, null);
  });

  testWidgets('Verify Platform version', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp());

    // Verify that platform version is retrieved.
    expect(
      find.byWidgetPredicate(
        (Widget widget) =>
            widget is Text && widget.data!.startsWith('Running on:'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('accessibility page opens from the demo and returns home', (
    tester,
  ) async {
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Accessibility protection'));
    await tester.pumpAndSettle();
    expect(find.text('public-probe'), findsOneWidget);
    expect(find.text('fallback-probe'), findsOneWidget);
    expect(find.text('Disable protection'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('public-probe'), findsNothing);
    expect(find.text('Running on: Android 14\n'), findsOneWidget);
    // The page's periodic input updates must stop after navigation away.
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
  });
}
