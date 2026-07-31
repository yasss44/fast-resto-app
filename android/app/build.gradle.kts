plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.fast.resto.fast_resto_bigbonney"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.fast.resto.fast_resto_bigbonney"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = 35
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // IMPORTANT: Configure a real release keystore before publishing!
            // 1. Generate: keytool -genkey -v -keystore release.keystore -keyalg RSA -keysize 2048
            // 2. Create android/key.properties with:
            //    storePassword=...
            //    keyPassword=...
            //    keyAlias=...
            //    storeFile=release.keystore
            // 3. Uncomment signing logic below, or set signingConfig manually.
            // Using debug keys for dev builds ONLY — never publish with this config.
            signingConfig = signingConfigs.getByName("debug")

            // Keep native shrinking off for APK releases; Flutter/Play Core optional
            // classes can otherwise fail R8 when deferred components are unused.
            // For Dart-level obfuscation, build with:
            //   flutter build apk --obfuscate --split-debug-info=debug-info/
            // This renames Dart symbols in the native binary (libapp.so)
            isMinifyEnabled = false
            isShrinkResources = false
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
}

flutter {
    source = "../.."
}
