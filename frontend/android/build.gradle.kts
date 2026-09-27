allprojects {
    repositories {
        // 国内镜像优先，官方源兜底。AGP / AndroidX / Kotlin 等依赖全部走这里，
        // 直连 google() / mavenCentral() 在国内常常要几十秒甚至超时。
        maven { url = uri("https://maven.aliyun.com/repository/google") }
        maven { url = uri("https://maven.aliyun.com/repository/public") }
        google()
        mavenCentral()
        // Flutter 引擎 artifacts 官方源（国内用户通过 FLUTTER_STORAGE_BASE_URL 镜像加速）
        maven { url = uri("https://storage.googleapis.com/download.flutter.io") }
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
