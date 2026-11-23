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
    if (project.name == "agora_rtc_engine" || project.name == "iris_method_channel") {
        afterEvaluate {
            val android = project.extensions.findByName("android") ?: return@afterEvaluate
            val method = android.javaClass.methods.firstOrNull {
                (it.name == "setCompileSdk" || it.name == "compileSdkVersion") && it.parameterCount == 1
            }
            method?.let { m ->
                val paramType = m.parameterTypes[0]
                if (paramType == Int::class.javaPrimitiveType || paramType == java.lang.Integer::class.java) {
                    m.invoke(android, 35)
                } else if (paramType == String::class.java) {
                    m.invoke(android, "android-35")
                }
            }
        }
    }
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
