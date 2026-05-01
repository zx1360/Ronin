allprojects {
    repositories {
        google()
        mavenCentral()
        // Official Flutter engine artifacts repository (fallback when mirror misses a revision)
        maven { url = uri("https://storage.googleapis.com/download.flutter.io") }
        // 清华镜像（可选，增强稳定性）
        maven { url = uri("https://mirrors.tuna.tsinghua.edu.cn/flutter") }
    }
}

val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
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
