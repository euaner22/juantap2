plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")   // ✅ only one Kotlin plugin — modern syntax
    id("dev.flutter.flutter-gradle-plugin") // ✅ required for Flutter builds
    id("com.google.gms.google-services") // ✅ Firebase integration
}

android {
    namespace = "com.example.juantap"
    compileSdk = 35

    defaultConfig {
        applicationId = "com.example.juantap"
        minSdk = 26
        targetSdk = 35
        versionCode = 1
        versionName = "1.0"
        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
    }

    buildTypes {
        getByName("release") {
            isMinifyEnabled = false
            isShrinkResources = false
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = "17"
    }
}

flutter {
    source = "../.."
}

dependencies {
    // ✅ Firebase BOM keeps versions consistent
    implementation(platform("com.google.firebase:firebase-bom:33.2.0"))

    // ✅ Firebase libraries you’re using
    implementation("com.google.firebase:firebase-analytics-ktx")
    implementation("com.google.firebase:firebase-database-ktx")
}
