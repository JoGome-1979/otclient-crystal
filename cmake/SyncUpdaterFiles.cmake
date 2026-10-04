# Creates a clean updater payload from the authoritative runtime sources.
# Resources are refreshed; unrelated platform binaries remain untouched.

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
if(DEFINED BINARY_PLATFORM AND BINARY_PLATFORM MATCHES "^(windows|linux)$" AND
   IS_PUBLISHABLE_BUILD AND NOT DEFINED BINARY_ARCH)
  message(FATAL_ERROR "BINARY_ARCH is required when publishing a desktop build")
endif()
if(DEFINED BINARY_ARCH AND NOT BINARY_ARCH MATCHES "^(x86|x64)$")
  message(FATAL_ERROR "Unsupported desktop architecture: ${BINARY_ARCH}")
endif()
if(DEFINED BINARY_PLATFORM AND BINARY_PLATFORM MATCHES "^(windows|linux)$" AND
   IS_PUBLISHABLE_BUILD AND (NOT DEFINED BINARY_FILE OR NOT EXISTS "${BINARY_FILE}"))
  message(FATAL_ERROR "Desktop publication requires an existing BINARY_FILE")
endif()
# Preserve the last successfully published release across platform/debug builds.
set(RELEASE_STAGING "${SOURCE_ROOT}/build/updater-releases")
file(MAKE_DIRECTORY "${RELEASE_STAGING}")
foreach(RELEASE_NAME IN ITEMS Crystal.exe Crystal)
  if(EXISTS "${OUTPUT_ROOT}/${RELEASE_NAME}" AND NOT EXISTS "${RELEASE_STAGING}/${RELEASE_NAME}")
    file(COPY_FILE "${OUTPUT_ROOT}/${RELEASE_NAME}" "${RELEASE_STAGING}/${RELEASE_NAME}")
  endif()
endforeach()
# Keep each release recoverable before recreating files/. Migrate old paths once.
foreach(WINDOWS_ARCH IN ITEMS x86 x64)
  set(SAVED_BINARY "${RELEASE_STAGING}/windows/${WINDOWS_ARCH}/Crystal${WINDOWS_ARCH}.exe")
  foreach(CANDIDATE IN ITEMS
      "${OUTPUT_ROOT}/Crystal${WINDOWS_ARCH}.exe"
      "${RELEASE_STAGING}/windows/${WINDOWS_ARCH}/Cliente${WINDOWS_ARCH}.exe"
      "${OUTPUT_ROOT}/binaries/windows/${WINDOWS_ARCH}/Cliente${WINDOWS_ARCH}.exe")
    if(NOT EXISTS "${SAVED_BINARY}" AND EXISTS "${CANDIDATE}")
      get_filename_component(SAVED_DIRECTORY "${SAVED_BINARY}" DIRECTORY)
      file(MAKE_DIRECTORY "${SAVED_DIRECTORY}")
      file(COPY_FILE "${CANDIDATE}" "${SAVED_BINARY}")
    endif()
  endforeach()
endforeach()
# Keep published packages in place, including their file identity and timestamps.
set(PRESERVED_PACKAGES
  Crystal Crystalx64 Crystalx86 Crystalx86.exe Crystalx64.exe Crystal.apk android-version.json
  Crystal-mac Crystal.ipa ios-version.json)
file(GLOB PREVIOUS_ENTRIES LIST_DIRECTORIES TRUE "${OUTPUT_ROOT}/*")
foreach(ENTRY IN LISTS PREVIOUS_ENTRIES)
  get_filename_component(ENTRY_NAME "${ENTRY}" NAME)
  if(NOT ENTRY_NAME IN_LIST PRESERVED_PACKAGES)
    file(REMOVE_RECURSE "${ENTRY}")
  endif()
endforeach()
file(MAKE_DIRECTORY "${OUTPUT_ROOT}")

file(COPY "${SOURCE_ROOT}/init.lua" DESTINATION "${OUTPUT_ROOT}")
foreach(SOURCE_DIRECTORY IN ITEMS data modules mods)
  file(COPY "${SOURCE_ROOT}/${SOURCE_DIRECTORY}" DESTINATION "${OUTPUT_ROOT}")
endforeach()

# Server-side paperdoll examples are documentation for integrating the game
# server and are never loaded by the client updater.
file(REMOVE_RECURSE "${OUTPUT_ROOT}/modules/game_paperdolls/server")

# Publish only the platform/architecture that successfully built Release.
# Debug and resource-only synchronization never replace native packages.
if(IS_PUBLISHABLE_BUILD AND DEFINED BINARY_PLATFORM AND
   BINARY_PLATFORM STREQUAL "windows")
  set(WINDOWS_EXECUTABLE "Crystal${BINARY_ARCH}.exe")
  set(SAVED_BINARY "${RELEASE_STAGING}/windows/${BINARY_ARCH}/${WINDOWS_EXECUTABLE}")
  get_filename_component(SAVED_DIRECTORY "${SAVED_BINARY}" DIRECTORY)
  file(MAKE_DIRECTORY "${SAVED_DIRECTORY}")
  file(COPY_FILE "${BINARY_FILE}" "${SAVED_BINARY}" ONLY_IF_DIFFERENT)
  file(COPY_FILE "${SAVED_BINARY}" "${OUTPUT_ROOT}/${WINDOWS_EXECUTABLE}" ONLY_IF_DIFFERENT)
elseif(IS_PUBLISHABLE_BUILD AND DEFINED BINARY_PLATFORM AND
       BINARY_PLATFORM STREQUAL "linux")
  if(NOT DEFINED BINARY_FILE OR NOT EXISTS "${BINARY_FILE}")
    message(FATAL_ERROR "Linux publication requires an existing BINARY_FILE")
  endif()
  if(BINARY_ARCH STREQUAL "x64")
    set(LINUX_EXECUTABLE "Crystalx64")
  else()
    set(LINUX_EXECUTABLE "Crystalx86")
  endif()
  set(SAVED_BINARY "${RELEASE_STAGING}/linux/${BINARY_ARCH}/${LINUX_EXECUTABLE}")
  get_filename_component(SAVED_DIRECTORY "${SAVED_BINARY}" DIRECTORY)
  file(MAKE_DIRECTORY "${SAVED_DIRECTORY}")
  file(COPY_FILE "${BINARY_FILE}" "${SAVED_BINARY}" ONLY_IF_DIFFERENT)
  file(COPY_FILE "${SAVED_BINARY}" "${OUTPUT_ROOT}/${LINUX_EXECUTABLE}" ONLY_IF_DIFFERENT)
  # The historical unqualified Linux executable was x64; its snapshot was saved above.
  if(BINARY_ARCH STREQUAL "x64")
    file(REMOVE "${OUTPUT_ROOT}/Crystal")
  endif()
endif()

# Android's Gradle release task already publishes Crystal.apk and its metadata
# directly into files/. Desktop/resource synchronization preserves them in place.

file(GLOB_RECURSE COPIED_FILES LIST_DIRECTORIES FALSE "${OUTPUT_ROOT}/*")
list(LENGTH COPIED_FILES COPIED_FILE_COUNT)
message(STATUS "Updater payload synchronized: ${OUTPUT_ROOT} (${COPIED_FILE_COUNT} files)")
