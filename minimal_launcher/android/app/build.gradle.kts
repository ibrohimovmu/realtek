plugins {
    id("com.android.application")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.minimal.minimal_launcher"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // Fresh clean applicationId so it installs cleanly even if an older
        // com.minimal.minimal_launcher build with a different key is on the phone
        applicationId = "com.minimal.nordic_launcher"
        minSdk = 23
        targetSdk = 34
        versionCode = 5
        versionName = "4.1.0"
    }

    signingConfigs {
        create("release") {
            val keystoreFile = file("nova-release.jks")
            if (keystoreFile.exists()) {
                storeFile = keystoreFile
                storePassword = "nova2026"
                keyAlias = "nova_key"
                keyPassword = "nova2026"
                enableV1Signing = true
                enableV2Signing = true
            }
        }
    }

    buildTypes {
        release {
            val keystoreFile = file("nova-release.jks")
            signingConfig = if (keystoreFile.exists()) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }

    packaging {
        jniLibs {
            useLegacyPackaging = true
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
