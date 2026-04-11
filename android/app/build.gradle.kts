import java.util.Properties
import org.gradle.api.GradleException

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

val keyProps = Properties().apply {
    val keyPropertiesFile = rootProject.file("key.properties")
    if (keyPropertiesFile.exists()) {
        keyPropertiesFile.inputStream().use { load(it) }
    }
}
val requestedTasks = gradle.startParameter.taskNames.map { it.lowercase() }
val requiresReleaseSigning = requestedTasks.any { task ->
    "release" in task || ("publish" in task && "debug" !in task)
}
val storeFilePath = keyProps.getProperty("storeFile")
val storePass = keyProps.getProperty("storePassword")
val keyAliasValue = keyProps.getProperty("keyAlias")
val keyPass = keyProps.getProperty("keyPassword")
val hasReleaseSigningConfig = !storeFilePath.isNullOrBlank() &&
    !storePass.isNullOrBlank() &&
    !keyAliasValue.isNullOrBlank() &&
    !keyPass.isNullOrBlank() &&
    rootProject.file(storeFilePath).exists()

if (requiresReleaseSigning && !hasReleaseSigningConfig) {
    throw GradleException(
        "Missing release signing config. Create android/key.properties with storeFile, storePassword, keyAlias, keyPassword, and ensure the keystore file exists.",
    )
}

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

    signingConfigs {
        create("release") {
            if (!hasReleaseSigningConfig) {
                return@create
            }
            val resolvedStoreFile = rootProject.file(storeFilePath!!)
            storeFile = resolvedStoreFile
            storePassword = storePass
            keyAlias = keyAliasValue
            keyPassword = keyPass
        }
    }

    buildTypes {
        debug {
            applicationIdSuffix = ".debug"
            versionNameSuffix = "-debug"
            isDebuggable = true
        }
        release {
            // Keep release startup stable across plugin-heavy builds.
            // R8/resource shrinking caused release-only crashes on some devices.
            isMinifyEnabled = false
            isShrinkResources = false
            signingConfig = if (hasReleaseSigningConfig) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
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
