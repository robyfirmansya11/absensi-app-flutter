allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// Override compileSdk — DIDAFTARKAN PALING AWAL,
// supaya sempat "nempel" sebelum evaluationDependsOn memaksa evaluasi dini.
subprojects {
    afterEvaluate {
        plugins.withId("com.android.library") {
            extensions.configure<com.android.build.gradle.LibraryExtension> {
                if ((compileSdk ?: 0) < 36) {
                    compileSdk = 36
                }
            }
        }
        plugins.withId("com.android.application") {
            extensions.configure<com.android.build.gradle.AppExtension> {
                if (compileSdkVersion == null ||
                    (compileSdkVersion!!.removePrefix("android-").toIntOrNull() ?: 0) < 36
                ) {
                    compileSdkVersion(36)
                }
            }
        }
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

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}