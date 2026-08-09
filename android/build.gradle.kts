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
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}

// AGP 8+ Uyumlu Optimize Edilmiş Override Bloğu
subprojects {
    // com.android.library plugini projeye dahil edildiği an (evaluation öncesi/sırası) tetiklenir.
    plugins.withId("com.android.library") {
        project.extensions.configure<com.android.build.gradle.LibraryExtension>("android") {
            compileSdk = 36
            
            if (namespace == null) {
                namespace = "dev.isar.${project.name.replace('-', '_')}"
            }
        }
    }
}