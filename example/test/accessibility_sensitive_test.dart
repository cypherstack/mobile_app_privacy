import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app_privacy_example/accessibility_sensitive.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('mobile_app_privacy_example/platform');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final android = TargetPlatformVariant.only(TargetPlatform.android);

  void mockVersion(Future<int?> Function() version) {
    messenger.setMockMethodCallHandler(channel, (call) {
      expect(call.method, 'getAndroidSdkInt');
      return version();
    });
  }

  String semantics(WidgetTester tester) => tester
      .binding
      .renderViews
      .single
      .owner!
      .semanticsOwner!
      .rootSemanticsNode!
      .toStringDeep();

  Future<void> pump(WidgetTester tester, Widget child) async {
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: child)));
    await tester.pumpAndSettle();
  }

  setUp(() => mockVersion(() async => 33));
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  testWidgets('Android 13 hides only the wrapped content from semantics', (
    tester,
  ) async {
    await pump(
      tester,
      const Column(
        children: [
          Text('Wallet backup'),
          AccessibilitySensitive(child: SelectableText('test-secret-key')),
          Text('public-address'),
        ],
      ),
    );
    expect(semantics(tester), isNot(contains('test-secret-key')));
    expect(semantics(tester), contains('Hidden from accessibility services'));
    expect(semantics(tester), contains('Wallet backup'));
    expect(semantics(tester), contains('public-address'));
    expect(find.text('test-secret-key'), findsOneWidget);
  }, variant: android);

  testWidgets('Android 13 also excludes edited input values', (tester) async {
    await pump(tester, const AccessibilitySensitive(child: TextField()));
    await tester.enterText(find.byType(TextField), 'edited-secret');
    await tester.pump();
    expect(semantics(tester), isNot(contains('edited-secret')));
    expect(find.text('edited-secret'), findsOneWidget);
  }, variant: android);

  for (final sdkInt in [34, 35]) {
    testWidgets('SDK $sdkInt preserves semantics without host state', (
      tester,
    ) async {
      mockVersion(() async => sdkInt);
      await pump(
        tester,
        const AccessibilitySensitive(child: Text('test-secret')),
      );
      expect(semantics(tester), contains('test-secret'));
      expect(semantics(tester), isNot(contains('Hidden from accessibility')));
    }, variant: android);
  }

  testWidgets(
    'iOS preserves semantics without querying Android',
    (tester) async {
      mockVersion(() async => throw StateError('Unexpected Android query'));
      await pump(
        tester,
        const AccessibilitySensitive(child: Text('test-secret')),
      );
      expect(semantics(tester), contains('test-secret'));
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  testWidgets(
    'version lookup preserves input state and runs once per mount',
    (tester) async {
      final version = Completer<int?>();
      var calls = 0;
      mockVersion(() {
        calls++;
        return version.future;
      });
      Widget build(String hint) => MaterialApp(
        home: Scaffold(
          body: AccessibilitySensitive(
            hiddenLabel: 'Protected value',
            child: TextField(decoration: InputDecoration(hintText: hint)),
          ),
        ),
      );
      await tester.pumpWidget(build('Before'));
      await tester.enterText(find.byType(TextField), 'edited-secret');
      final state = tester.state(find.byType(EditableText));
      await tester.pump();
      expect(semantics(tester), contains('Protected value'));
      expect(semantics(tester), isNot(contains('edited-secret')));
      version.complete(34);
      await tester.pumpAndSettle();
      expect(tester.state(find.byType(EditableText)), same(state));
      expect(semantics(tester), contains('edited-secret'));
      await tester.pumpWidget(build('After'));
      expect(tester.state(find.byType(EditableText)), same(state));
      expect(calls, 1);
    },
    variant: android,
  );

  testWidgets('lookup errors keep sensitive semantics excluded', (
    tester,
  ) async {
    mockVersion(() async => throw PlatformException(code: 'unavailable'));
    await pump(
      tester,
      const AccessibilitySensitive(child: Text('test-secret')),
    );
    expect(semantics(tester), isNot(contains('test-secret')));
    expect(tester.takeException(), isNull);
  }, variant: android);
}
