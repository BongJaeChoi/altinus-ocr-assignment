import java.util.Base64
import java.util.Properties

plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
if (keystorePropertiesFile.isFile) {
    keystorePropertiesFile.inputStream().use(keystoreProperties::load)
}

val releaseSigningPropertyNames =
    listOf("storeFile", "storePassword", "keyAlias", "keyPassword")
val releaseSigningConfigured =
    keystorePropertiesFile.isFile &&
        releaseSigningPropertyNames.all { propertyName ->
            !keystoreProperties.getProperty(propertyName).isNullOrBlank()
        }

val dartDefines = providers.gradleProperty("dart-defines").orNull
    ?.split(',')
    ?.filter(String::isNotBlank)
    ?.map { encodedDefine ->
        String(Base64.getDecoder().decode(encodedDefine), Charsets.UTF_8)
    }
    .orEmpty()
val cloudEvidenceEnabled = dartDefines.contains("ARTINUS_CLOUD_EVIDENCE=true")
if (cloudEvidenceEnabled && !releaseSigningConfigured) {
    throw GradleException(
        "ARTINUS cloud evidence requires the registered release signing identity",
    )
}

android {
    namespace = "dev.bongjae.artinusocr"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "dev.bongjae.artinusocr"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = 24
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (releaseSigningConfigured) {
            create("registeredRelease") {
                storeFile = file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig =
                if (releaseSigningConfigured) {
                    signingConfigs.getByName("registeredRelease")
                } else {
                    signingConfigs.getByName("debug")
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

dependencies {
    implementation("com.google.mlkit:text-recognition-korean:16.0.1")
    // Flutter's built-in Kotlin integration adds this module during assemble.
    // Declaring it here lets Gradle persist the runtime classpaths in the lockfile.
    runtimeOnly("org.jetbrains.kotlin:kotlin-stdlib-common:2.4.0")
    testImplementation("junit:junit:4.13.2")
}

dependencyLocking {
    lockAllConfigurations()
}
