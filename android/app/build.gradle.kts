plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
}

val ciAbiFilters = providers.gradleProperty("otclient.android.abis")
    .orElse(providers.environmentVariable("OTCLIENT_ANDROID_ABIS"))
    .orNull
    ?.split(",")
    ?.map { it.trim() }
    ?.filter { it.isNotEmpty() }
    ?: listOf("arm64-v8a", "armeabi-v7a", "x86_64", "x86")

android {
    namespace = "com.github.otclient"
    compileSdk = 36

    defaultConfig {
        applicationId = "com.github.otclient"
        minSdk = 21
        targetSdk = 36
        // Always increment versionCode before publishing a new APK update.
        versionCode = 6
        versionName = "1.4.5"
        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"

        ndk {
            abiFilters += ciAbiFilters
        }

        externalNativeBuild {
            cmake {
                cppFlags += listOf("-std=c++20")

                arguments += listOf(
                    "-DVCPKG_TARGET_ANDROID=ON",
                    "-DANDROID_STL=c++_shared",
                    "-DVCPKG_MANIFEST_INSTALL=ON",
                    "-DVCPKG_INSTALL_OPTIONS=--allow-unsupported",
                    // Unity translation units exceed the available WSL memory;
                    // regular per-file compilation is slower but deterministic.
                    "-DSPEED_UP_BUILD_UNITY=OFF",
                    // Android's external native build does not inject the CMake
                    // PCH reliably; disable it so every source includes its own
                    // standard-library declarations, including std::shared_ptr.
                    "-DTOGGLE_PRE_COMPILED_HEADER=OFF"
                )
            }
        }
    }

    signingConfigs {
        create("release") {
            // Use env vars for CI/production, fallback to debug keystore for local dev
            storeFile = file(System.getenv("RELEASE_KEYSTORE")
                ?: System.getProperty("user.home") + "/.android/debug.keystore")
            storePassword = System.getenv("RELEASE_KEYSTORE_PASSWORD") ?: "android"
            keyAlias = System.getenv("RELEASE_KEY_ALIAS") ?: "androiddebugkey"
            keyPassword = System.getenv("RELEASE_KEY_PASSWORD") ?: "android"
        }
    }

    externalNativeBuild {
        cmake {
            path = file("../../CMakeLists.txt")
            version = "3.22.1"
        }
    }

    buildTypes {
        getByName("release") {
            isMinifyEnabled = false
            isShrinkResources = false
            signingConfig = signingConfigs.getByName("release")
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                file("proguard-rules.pro")
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

    buildFeatures {
        viewBinding = true
        prefab = true
    }

    ndkVersion = "29.0.13599879"
}

dependencies {
    implementation("androidx.core:core-ktx:1.17.0")
    implementation("androidx.appcompat:appcompat:1.7.1")
    implementation("androidx.games:games-activity:1.2.1")
    implementation("com.google.android.material:material:1.13.0")
}

// Give every locally generated variant a predictable, user-facing file name.
android.applicationVariants.all {
    outputs.all {
        (this as com.android.build.gradle.internal.api.BaseVariantOutputImpl).outputFileName = "Crystal.apk"
    }
}


// Publishes the release APK and its authoritative version metadata. Keeping a
// staging copy under android-output lets desktop CMake synchronization retain
// the latest APK while rebuilding the Lua/data updater payload.
val publishReleaseApkForUpdater = tasks.register("publishReleaseApkForUpdater") {
    onlyIf {
        val assemble = tasks.named("assembleRelease").get()
        assemble.state.executed && assemble.state.failure == null
    }
    doLast {
        val apk = layout.buildDirectory.file("outputs/apk/release/Crystal.apk").get().asFile
        require(apk.isFile) { "Release APK not found: ${apk.absolutePath}" }

        val stagingDirectory = rootProject.projectDir.parentFile.resolve("android-output/updater")
        val updaterDirectory = rootProject.projectDir.parentFile.resolve("files")
        stagingDirectory.mkdirs()
        updaterDirectory.mkdirs()

        val metadata = """{
  "versionCode": ${android.defaultConfig.versionCode},
  "versionName": "${android.defaultConfig.versionName}"
}
"""
        apk.copyTo(stagingDirectory.resolve("Crystal.apk"), overwrite = true)
        stagingDirectory.resolve("android-version.json").writeText(metadata)
        apk.copyTo(updaterDirectory.resolve("Crystal.apk"), overwrite = true)
        updaterDirectory.resolve("android-version.json").writeText(metadata)
        println("Android updater package published to: ${updaterDirectory.absolutePath}")
    }
}

tasks.matching { it.name == "assembleRelease" }.configureEach {
    finalizedBy(publishReleaseApkForUpdater)
}
