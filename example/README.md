# mobile_app_privacy_example

Run `flutter run` to open the example app. Its home page shows the platform
version and demonstrates privacy overlays when the app leaves the foreground.
Choose **Accessibility protection** to open a separate page with sample content
and native filtering controls. Android instrumentation tests navigate to this
same page to check filtering in both Flutter activity embeddings, rather than
building a separate accessibility app.

`lib/accessibility_sensitive.dart` is an optional example-only widget. It queries
the Android SDK version through an example-only platform channel once per mount.
Below Android 14 (SDK 34), it excludes the wrapped subtree's semantics, including
screen-reader access. On Android 14+, it leaves semantics available regardless of
the native filtering toggle. It does nothing on other platforms. While the SDK
lookup is pending or fails, it keeps semantics excluded on Android.

Use it by wrapping sensitive content; no synchronized host state is needed:

```dart
AccessibilitySensitive(child: Text('example secret'))
```

This is an application policy choice, not a requirement for using the plugin.
Applications copying the widget must also provide its SDK lookup channel (see
`android/app/src/main/kotlin/com/cypherstack/mobile_app_privacy_example/ExamplePlatform.kt`)
or use their existing device-information API.

## Testing

The plugin targets Android and iOS. Linux, macOS and Windows hosts can run the
Android tests against an emulator; the iOS tests need macOS.

### Unit and widget tests

From the repository root:

```sh
flutter analyze
flutter test
(cd example && flutter test test)
```

### Android

Start a disposable API 33 or 34 emulator. Let a freshly created one settle for a
few minutes after it boots. Then run the Flutter integration suite from `example/`:

```sh
flutter test integration_test -d <emulator-serial>
```

Building `integration_test/android_privacy_test.dart` makes the Gradle task
`startPrivacyTestHost` launch `tool/integration_host.dart`, an ADB helper the
suite uses to enable the probe accessibility services, send the app to the
background and bring it back. The helper waits up to two minutes for the suite,
exits when the app exits or after 20 minutes, and restores the emulator's
original accessibility settings on the way out. Its log is written to
`build/app/privacy-host-<session>.log`. The helper refuses physical devices.

The native instrumentation tests cover the plugin in both Flutter activity
embeddings. Use `android-x64` or `android-arm64` to match the emulator:

```sh
flutter build apk --debug --target-platform android-x64 --android-skip-build-dependency-validation
(cd android && ./gradlew :app:connectedDebugAndroidTest -Ptarget-platform=android-x64 -PskipDependencyChecks=true)
```

On API 33 the native run reports `OK (14 tests)` with ten API-34-only cases
skipped by assumption. If Gradle cannot find a JDK, set `JAVA_HOME` to the one
listed by `flutter doctor -v`.

The plugin's Kotlin unit tests run without a device:

```sh
(cd android && ./gradlew :mobile_app_privacy:testDebugUnitTest)
```

### iOS

Name the repository directory `mobile_app_privacy` to match the example's SwiftPM
package identity. Boot a simulator, then run the smoke test. The Android suite
skips itself on other platforms:

```sh
xcrun simctl list devices available
xcrun simctl bootstatus <simulator-udid> -b
flutter test integration_test -d <simulator-udid>
```

For the XCTest cases, regenerate Flutter's iOS configuration first:

```sh
flutter build ios --simulator --debug --config-only
xcodebuild test -workspace ios/Runner.xcworkspace -scheme Runner -configuration Debug \
  -destination "platform=iOS Simulator,id=<simulator-udid>" CODE_SIGNING_ALLOWED=NO
```

If Xcode reports an iOS 13/15 deployment mismatch, repeat the `--config-only`
command rather than editing the generated package.
