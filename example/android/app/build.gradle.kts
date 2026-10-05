import java.util.Properties
import java.util.UUID

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val privacyTarget = providers.gradleProperty("target").orNull?.let { file(it) }
// `flutter test integration_test` builds a generated listener that imports the
// test file by URI, so match the privacy suite's path in the target or its text.
val privacySuite = Regex("""integration_test[\\/]android_privacy_test\.dart""")
val privacySession = if (privacyTarget?.isFile == true &&
    (privacySuite.containsMatchIn(privacyTarget.path) ||
        privacySuite.containsMatchIn(privacyTarget.readText())))
    UUID.randomUUID().toString() else ""

android {
    namespace = "com.cypherstack.mobile_app_privacy_example"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion
    buildFeatures { buildConfig = true }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
        applicationId = "com.cypherstack.mobile_app_privacy_example"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        debug {
            buildConfigField("String", "PRIVACY_TEST_SESSION", "\"$privacySession\"")
        }
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

val startPrivacyHost = tasks.register("startPrivacyTestHost") {
    onlyIf { privacySession.isNotEmpty() }
    doLast {
        val properties = Properties().apply {
            rootProject.file("local.properties").inputStream().use { load(it) }
        }
        val exe = if (System.getProperty("os.name").startsWith("Windows")) ".exe" else ""
        val log = layout.buildDirectory.file("privacy-host-$privacySession.log").get().asFile
        log.parentFile.mkdirs()
        ProcessBuilder(
            "${properties.getProperty("flutter.sdk")}/bin/cache/dart-sdk/bin/dart$exe",
            "run", "tool/integration_host.dart", privacySession,
            androidComponents.sdkComponents.adb.get().asFile.absolutePath
        ).directory(file("../..")).redirectErrorStream(true).redirectOutput(log).start()
    }
}
tasks.configureEach {
    if (name == "assembleDebug") finalizedBy(startPrivacyHost)
}

flutter {
    source = "../.."
}


dependencies {
    debugImplementation("androidx.test:runner:1.6.2")
    debugImplementation("androidx.test:core:1.6.1")
    debugImplementation("junit:junit:4.13.2")
    androidTestImplementation("androidx.test:runner:1.6.2")
    androidTestImplementation("androidx.test:core:1.6.1")
    androidTestImplementation("junit:junit:4.13.2")
}
