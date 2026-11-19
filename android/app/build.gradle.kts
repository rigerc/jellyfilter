plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val releaseSigning = listOf(
    "ANDROID_KEYSTORE_PATH",
    "ANDROID_KEYSTORE_PASSWORD",
    "ANDROID_KEY_ALIAS",
    "ANDROID_KEY_PASSWORD",
).associateWith { System.getenv(it)?.takeIf(String::isNotBlank) }
val hasReleaseSigning = releaseSigning.values.all { it != null }
require(hasReleaseSigning || releaseSigning.values.all { it == null }) {
    "Set all four ANDROID signing environment variables, or none."
}

android {
    namespace = "com.jellyfinpicker.jellyfin_picker"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.jellyfinpicker.jellyfin_picker"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = 26
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseSigning) {
            create("release") {
                storeFile = file(requireNotNull(releaseSigning["ANDROID_KEYSTORE_PATH"]))
                storePassword = releaseSigning["ANDROID_KEYSTORE_PASSWORD"]
                keyAlias = releaseSigning["ANDROID_KEY_ALIAS"]
                keyPassword = releaseSigning["ANDROID_KEY_PASSWORD"]
            }
        }
    }

    buildTypes {
        release {
            // Without credentials, local release builds are unsigned.
            if (hasReleaseSigning) {
                signingConfig = signingConfigs.getByName("release")
            }
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
