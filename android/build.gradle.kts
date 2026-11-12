import com.android.build.gradle.LibraryExtension

// agora_rtc_engine / iris_method_channel read these via safeExtGet(..., 31).
extra.apply {
    set("compileSdkVersion", 37)
    set("minSdkVersion", 23)
    set("targetSdkVersion", 35)
}

allprojects {
    repositories {
        google()
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
    pluginManager.withPlugin("com.android.library") {
        extensions.configure<LibraryExtension>("android") {
            compileSdk = 37
        }
    }
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
