allprojects {
    repositories {
        google()
        // Google-hosted Maven Central mirror, tried before mavenCentral()
        // itself: this environment's outbound connections to
        // repo.maven.apache.org fail their TLS handshake unpredictably
        // (works fine via curl, fails via Gradle/Java's HTTP client) --
        // this mirror sits on the same infrastructure as google() below,
        // which has been reliable.
        maven { url = uri("https://maven-central.storage-download.googleapis.com/maven2/") }
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

// Some plugin subprojects (e.g. file_picker) ship with a lower compileSdk
// than the flutter_plugin_android_lifecycle version they depend on
// transitively. Force every Android library module to compileSdk 36 to
// match the app module above. Must run after the subproject's own
// build.gradle has set its compileSdk, or our override gets clobbered back
// to 34 -- but evaluationDependsOn(":app") above already evaluates some
// subprojects eagerly, so afterEvaluate() throws on those; fall back to
// applying immediately when that's the case.
subprojects {
    val applyCompileSdkFix: () -> Unit = {
        extensions.findByType(com.android.build.gradle.LibraryExtension::class.java)?.let {
            it.compileSdk = 36
        }
    }
    if (state.executed) applyCompileSdkFix() else afterEvaluate { applyCompileSdkFix() }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
