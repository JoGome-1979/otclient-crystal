if(NOT CMAKE_HOST_SYSTEM_NAME STREQUAL "Linux")
  message(FATAL_ERROR "Use Ubuntu WSL for the Android APK presets.")
endif()
if(NOT CMAKE_BUILD_TYPE MATCHES "^(Release|Debug)$")
  message(FATAL_ERROR "Android packaging supports Release and Debug.")
endif()
if(NOT "$ENV{ANDROID_HOME}" STREQUAL "")
  set(default_sdk "$ENV{ANDROID_HOME}")
else()
  set(default_sdk "$ENV{HOME}/Android/Sdk")
endif()
if(NOT "$ENV{VCPKG_ROOT}" STREQUAL "")
  set(default_vcpkg "$ENV{VCPKG_ROOT}")
else()
  set(default_vcpkg "$ENV{HOME}/vcpkg")
endif()
set(CRYSTAL_ANDROID_SDK "${default_sdk}" CACHE PATH "Linux Android SDK")
set(CRYSTAL_ANDROID_VCPKG "${default_vcpkg}" CACHE PATH "Linux vcpkg")
set(CRYSTAL_ANDROID_ABIS "arm64-v8a" CACHE STRING "Comma-separated Android ABIs")
set(CRYSTAL_ANDROID_JOBS "10" CACHE STRING "Gradle, vcpkg and native parallel limit")
if(NOT CRYSTAL_ANDROID_JOBS MATCHES "^[1-9][0-9]*$")
  message(FATAL_ERROR "CRYSTAL_ANDROID_JOBS must be positive.")
endif()
add_custom_target(apk ALL
  COMMAND "${CMAKE_COMMAND}"
    "-DSOURCE_ROOT:PATH=${CMAKE_SOURCE_DIR}" "-DBINARY_ROOT:PATH=${CMAKE_BINARY_DIR}"
    "-DSDK_ROOT:PATH=${CRYSTAL_ANDROID_SDK}" "-DVCPKG_ROOT:PATH=${CRYSTAL_ANDROID_VCPKG}"
    "-DABIS:STRING=${CRYSTAL_ANDROID_ABIS}" "-DJOBS:STRING=${CRYSTAL_ANDROID_JOBS}"
    "-DVARIANT:STRING=${CMAKE_BUILD_TYPE}" -P "${CMAKE_SOURCE_DIR}/AndroidPackage.cmake"
  USES_TERMINAL VERBATIM)
message(STATUS "Android ${CMAKE_BUILD_TYPE}: SDK=${CRYSTAL_ANDROID_SDK}; ABIs=${CRYSTAL_ANDROID_ABIS}")
message(STATUS "APK output: ${CMAKE_BINARY_DIR}/Crystal.apk")
