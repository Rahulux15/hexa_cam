import java.util.Properties

plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("dev.flutter.flutter-gradle-plugin")
}

val localProps = Properties().apply {
    val localPropertiesFile = rootProject.file("local.properties")
    if (localPropertiesFile.exists()) {
        localPropertiesFile.inputStream().use { load(it) }
    }
}

val apiBaseUrl = (project.findProperty("API_BASE_URL") as String?)
    ?: localProps.getProperty("API_BASE_URL")
    ?: "https://api.quasmoindianmicroscope.com/api"

android {
    namespace = "com.hexa_cam"
    compileSdk = flutter.compileSdkVersion
    buildToolsVersion = "35.0.0"
    ndkVersion = "28.2.13676358"

    buildFeatures {
        buildConfig = true
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.hexa_cam"
        minSdk = 24
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        buildConfigField("String", "API_BASE_URL", "\"$apiBaseUrl\"")
    }

    buildTypes {
        debug {
            applicationIdSuffix = ".debug"
            versionNameSuffix = "-debug"
            isDebuggable = true
        }
        release {
            isMinifyEnabled = true
            isShrinkResources = true
            signingConfig = signingConfigs.getByName("debug")
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
    }

    // Keep default ABI behavior in Gradle config to avoid conflicts with
    // Flutter's debug abiFilters. For small release artifacts, build with:
    // flutter build apk --release --split-per-abi
}

flutter {
    source = "../.."
}
