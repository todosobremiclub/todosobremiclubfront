 import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")

    // ✅ Firebase (lee android/app/google-services.json)
    id("com.google.gms.google-services")

    // ✅ Plugin oficial de Flutter (maneja Kotlin internamente)
    id("dev.flutter.flutter-gradle-plugin")
}

// Cargamos las propiedades del keystore desde app/key.properties
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("app/key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.example.todosobremiclub_app"
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17

kotlinOptions {
    jvmTarget = "17"
}

        // ✅ Necesario para APIs Java 8+ (notificaciones, etc)
        isCoreLibraryDesugaringEnabled = true
    }

    // ✅ YA NO usamos kotlinOptions manual
    // Flutter gestiona Kotlin internamente

    defaultConfig {
    applicationId = "com.todosobremiclub.app"

    minSdk = flutter.minSdkVersion
    targetSdk = 35

    versionCode = flutter.versionCode
    versionName = flutter.versionName
}


    // 🔐 Firma release con key.properties
    signingConfigs {
        create("release") {
            if (keystoreProperties.isNotEmpty()) {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        getByName("release") {
            signingConfig = signingConfigs.getByName("release")
            isMinifyEnabled = false
            isShrinkResources = false
        }
        getByName("debug") {
            // sin cambios
        }
    }
}

// ✅ Necesario para desugaring
dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

flutter {
    source = "../.."
}
