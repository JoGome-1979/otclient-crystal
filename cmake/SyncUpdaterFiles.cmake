# Creates a clean updater payload from the authoritative runtime sources.
# The destination is removed first so deleted or renamed source files cannot
# remain published accidentally after a later compilation.

if(NOT DEFINED SOURCE_ROOT OR SOURCE_ROOT STREQUAL "")
  message(FATAL_ERROR "SOURCE_ROOT was not provided to SyncUpdaterFiles.cmake")
endif()

if(NOT DEFINED OUTPUT_ROOT OR OUTPUT_ROOT STREQUAL "")
  message(FATAL_ERROR "OUTPUT_ROOT was not provided to SyncUpdaterFiles.cmake")
endif()

file(REAL_PATH "${SOURCE_ROOT}" SOURCE_ROOT)
cmake_path(ABSOLUTE_PATH OUTPUT_ROOT NORMALIZE)

if(OUTPUT_ROOT STREQUAL SOURCE_ROOT)
  message(FATAL_ERROR "Updater output cannot be the repository root")
endif()

foreach(REQUIRED_PATH IN ITEMS init.lua data modules mods)
  if(NOT EXISTS "${SOURCE_ROOT}/${REQUIRED_PATH}")
    message(FATAL_ERROR "Required updater source is missing: ${SOURCE_ROOT}/${REQUIRED_PATH}")
  endif()
endforeach()

set(EXPECTED_OUTPUT "${SOURCE_ROOT}/files")
cmake_path(NORMAL_PATH EXPECTED_OUTPUT)
if(NOT OUTPUT_ROOT STREQUAL EXPECTED_OUTPUT)
  message(FATAL_ERROR "Updater output must be the generated files/ directory")
endif()
# Reject incomplete Windows publication requests before changing files/.
set(IS_PUBLISHABLE_BUILD FALSE)
if(DEFINED BUILD_CONFIG AND BUILD_CONFIG MATCHES "^(Release|RelWithDebInfo|MinSizeRel)$")
  set(IS_PUBLISHABLE_BUILD TRUE)
endif()
if(DEFINED BINARY_PLATFORM AND BINARY_PLATFORM STREQUAL "windows" AND
   IS_PUBLISHABLE_BUILD AND NOT DEFINED BINARY_ARCH)
  message(FATAL_ERROR "BINARY_ARCH is required when publishing a Windows build")
endif()
if(DEFINED BINARY_ARCH AND NOT BINARY_ARCH MATCHES "^(x86|x64)$")
  message(FATAL_ERROR "Unsupported Windows architecture: ${BINARY_ARCH}")
endif()
if(DEFINED BINARY_PLATFORM AND BINARY_PLATFORM STREQUAL "windows" AND
   IS_PUBLISHABLE_BUILD AND (NOT DEFINED BINARY_FILE OR NOT EXISTS "${BINARY_FILE}"))
  message(FATAL_ERROR "Windows publication requires an existing BINARY_FILE")
endif()
# Preserve the last successfully published release across platform/debug builds.
set(RELEASE_STAGING "${SOURCE_ROOT}/build/updater-releases")
file(MAKE_DIRECTORY "${RELEASE_STAGING}")
foreach(RELEASE_NAME IN ITEMS Crystal.exe Crystal)
  if(EXISTS "${OUTPUT_ROOT}/${RELEASE_NAME}" AND NOT EXISTS "${RELEASE_STAGING}/${RELEASE_NAME}")
    file(COPY_FILE "${OUTPUT_ROOT}/${RELEASE_NAME}" "${RELEASE_STAGING}/${RELEASE_NAME}")
  endif()
endforeach()
# Rescue both architecture-specific payloads before rebuilding files/.
foreach(WINDOWS_ARCH IN ITEMS x86 x64)
  set(WINDOWS_EXECUTABLE "Cliente${WINDOWS_ARCH}.exe")
  set(SAVED_BINARY "${RELEASE_STAGING}/windows/${WINDOWS_ARCH}/${WINDOWS_EXECUTABLE}")
  set(PUBLISHED_BINARY "${OUTPUT_ROOT}/binaries/windows/${WINDOWS_ARCH}/${WINDOWS_EXECUTABLE}")
  if(EXISTS "${PUBLISHED_BINARY}" AND NOT EXISTS "${SAVED_BINARY}")
    get_filename_component(SAVED_DIRECTORY "${SAVED_BINARY}" DIRECTORY)
    file(MAKE_DIRECTORY "${SAVED_DIRECTORY}")
    file(COPY_FILE "${PUBLISHED_BINARY}" "${SAVED_BINARY}")
  endif()
endforeach()
file(REMOVE_RECURSE "${OUTPUT_ROOT}")
file(MAKE_DIRECTORY "${OUTPUT_ROOT}")

file(COPY "${SOURCE_ROOT}/init.lua" DESTINATION "${OUTPUT_ROOT}")
foreach(SOURCE_DIRECTORY IN ITEMS data modules mods)
  file(COPY "${SOURCE_ROOT}/${SOURCE_DIRECTORY}" DESTINATION "${OUTPUT_ROOT}")
endforeach()

# Server-side paperdoll examples are documentation for integrating the game
# server and are never loaded by the client updater.
file(REMOVE_RECURSE "${OUTPUT_ROOT}/modules/game_paperdolls/server")

# Publish each Windows architecture separately. The root Crystal.exe remains
# an x64 compatibility alias for installed clients that do not report their arch.
foreach(WINDOWS_ARCH IN ITEMS x86 x64)
  set(WINDOWS_EXECUTABLE "Cliente${WINDOWS_ARCH}.exe")
  set(SAVED_BINARY "${RELEASE_STAGING}/windows/${WINDOWS_ARCH}/${WINDOWS_EXECUTABLE}")
  set(DIST_BINARY "${SOURCE_ROOT}/dist/windows-${WINDOWS_ARCH}-release/Cliente${WINDOWS_ARCH}.exe")
  if(NOT EXISTS "${DIST_BINARY}")
  if(WINDOWS_ARCH STREQUAL "x86")
    set(DIST_BINARY "${SOURCE_ROOT}/dist/dist-windows/Clientex86.exe")
  else()
    set(DIST_BINARY "${SOURCE_ROOT}/dist/dist-windows/Clientex64.exe")
    if(NOT EXISTS "${DIST_BINARY}")
      set(DIST_BINARY "${SOURCE_ROOT}/dist/dist-windows/Crystal.exe")
    endif()
    if(NOT EXISTS "${DIST_BINARY}")
      set(DIST_BINARY "${SOURCE_ROOT}/dist/CrystalClient/Crystal.exe")
    endif()
  endif()
  endif()
  set(WINDOWS_UPDATER_BINARY "")
  if(DEFINED BINARY_FILE AND DEFINED BINARY_PLATFORM AND
     BINARY_PLATFORM STREQUAL "windows" AND IS_PUBLISHABLE_BUILD AND
     BINARY_ARCH STREQUAL WINDOWS_ARCH)
    set(WINDOWS_UPDATER_BINARY "${BINARY_FILE}")
  elseif(EXISTS "${SAVED_BINARY}")
    set(WINDOWS_UPDATER_BINARY "${SAVED_BINARY}")
  elseif(WINDOWS_ARCH STREQUAL "x64" AND EXISTS "${RELEASE_STAGING}/Crystal.exe")
    set(WINDOWS_UPDATER_BINARY "${RELEASE_STAGING}/Crystal.exe")
  elseif(EXISTS "${DIST_BINARY}")
    set(WINDOWS_UPDATER_BINARY "${DIST_BINARY}")
  endif()
  if(WINDOWS_UPDATER_BINARY STREQUAL "")
    continue()
  endif()
  if(NOT EXISTS "${WINDOWS_UPDATER_BINARY}")
    message(FATAL_ERROR "Windows ${WINDOWS_ARCH} updater binary is missing: ${WINDOWS_UPDATER_BINARY}")
  endif()
  get_filename_component(SAVED_DIRECTORY "${SAVED_BINARY}" DIRECTORY)
  file(MAKE_DIRECTORY "${SAVED_DIRECTORY}")
  if(NOT WINDOWS_UPDATER_BINARY STREQUAL SAVED_BINARY)
    file(COPY_FILE "${WINDOWS_UPDATER_BINARY}" "${SAVED_BINARY}" ONLY_IF_DIFFERENT)
  endif()
  set(PUBLISH_DIRECTORY "${OUTPUT_ROOT}/binaries/windows/${WINDOWS_ARCH}")
  file(MAKE_DIRECTORY "${PUBLISH_DIRECTORY}")
  file(COPY_FILE "${SAVED_BINARY}" "${PUBLISH_DIRECTORY}/${WINDOWS_EXECUTABLE}")
  if(WINDOWS_ARCH STREQUAL "x64")
    file(COPY_FILE "${SAVED_BINARY}" "${RELEASE_STAGING}/Crystal.exe" ONLY_IF_DIFFERENT)
    file(COPY_FILE "${SAVED_BINARY}" "${OUTPUT_ROOT}/Crystal.exe")
  endif()
endforeach()

# Publish the extensionless Linux ELF as Crystal. Keeping a distinct filename
# allows one files/ payload to serve Windows and Linux without collisions.
set(LINUX_RELEASE_BINARY "${SOURCE_ROOT}/dist/dist-linux/Crystal")
set(LINUX_UPDATER_BINARY "")
if(DEFINED BINARY_FILE AND DEFINED BINARY_PLATFORM AND
   BINARY_PLATFORM STREQUAL "linux" AND IS_PUBLISHABLE_BUILD)
  set(LINUX_UPDATER_BINARY "${BINARY_FILE}")
elseif(EXISTS "${RELEASE_STAGING}/Crystal")
  set(LINUX_UPDATER_BINARY "${RELEASE_STAGING}/Crystal")
elseif(EXISTS "${LINUX_RELEASE_BINARY}")
  set(LINUX_UPDATER_BINARY "${LINUX_RELEASE_BINARY}")
endif()

if(NOT LINUX_UPDATER_BINARY STREQUAL "" AND NOT LINUX_UPDATER_BINARY STREQUAL "${RELEASE_STAGING}/Crystal")
  file(COPY_FILE "${LINUX_UPDATER_BINARY}" "${RELEASE_STAGING}/Crystal" ONLY_IF_DIFFERENT)
endif()
if(NOT LINUX_UPDATER_BINARY STREQUAL "")
  if(NOT EXISTS "${LINUX_UPDATER_BINARY}")
    message(FATAL_ERROR "Linux Release updater binary is missing: ${LINUX_UPDATER_BINARY}")
  endif()

  execute_process(
    COMMAND "${CMAKE_COMMAND}" -E copy_if_different
      "${LINUX_UPDATER_BINARY}"
      "${OUTPUT_ROOT}/Crystal"
    RESULT_VARIABLE LINUX_BINARY_COPY_RESULT
  )
  if(NOT LINUX_BINARY_COPY_RESULT EQUAL 0)
    message(FATAL_ERROR "Unable to publish the Linux Crystal binary to the updater payload")
  endif()
endif()

# Preserve the last successfully assembled Android release in the common VPS
# payload. The Gradle release build refreshes this staging directory.
set(ANDROID_UPDATER_STAGING "${SOURCE_ROOT}/android-output/updater")
if(EXISTS "${ANDROID_UPDATER_STAGING}/Crystal.apk" AND
   EXISTS "${ANDROID_UPDATER_STAGING}/android-version.json")
  file(COPY
    "${ANDROID_UPDATER_STAGING}/Crystal.apk"
    "${ANDROID_UPDATER_STAGING}/android-version.json"
    DESTINATION "${OUTPUT_ROOT}")
endif()

file(GLOB_RECURSE COPIED_FILES LIST_DIRECTORIES FALSE "${OUTPUT_ROOT}/*")
list(LENGTH COPIED_FILES COPIED_FILE_COUNT)
message(STATUS "Updater payload synchronized: ${OUTPUT_ROOT} (${COPIED_FILE_COUNT} files)")
