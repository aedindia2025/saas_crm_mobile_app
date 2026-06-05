allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

layout.buildDirectory.set(file("../build"))

subprojects {
    layout.buildDirectory.set(file("${rootProject.layout.buildDirectory.get()}/${project.name}"))
}

tasks.register<Delete>("clean") {
    delete(layout.buildDirectory)
}