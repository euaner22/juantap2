// Root-level Gradle configuration
plugins {
    id("com.android.application") apply false
    id("com.android.library") apply false
    id("org.jetbrains.kotlin.android") version "2.0.21" apply false
    id("com.google.gms.google-services") apply false
}

tasks.register<Delete>("clean") {
    delete(rootProject.buildDir)
}
