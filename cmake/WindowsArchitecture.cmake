# Detect the compiler target, rather than the architecture of the build machine.
if(CMAKE_SIZEOF_VOID_P EQUAL 4)
  set(CRYSTAL_WINDOWS_ARCH x86)
elseif(CMAKE_SIZEOF_VOID_P EQUAL 8)
  set(CRYSTAL_WINDOWS_ARCH x64)
else()
  message(FATAL_ERROR "Unsupported Windows pointer size: ${CMAKE_SIZEOF_VOID_P}")
endif()
if(DEFINED CRYSTAL_WINDOWS_TARGET_ARCH AND
   NOT CRYSTAL_WINDOWS_TARGET_ARCH STREQUAL CRYSTAL_WINDOWS_ARCH)
  message(FATAL_ERROR "The preset requires ${CRYSTAL_WINDOWS_TARGET_ARCH}, but the compiler targets ${CRYSTAL_WINDOWS_ARCH}. Open the matching Visual Studio Native Tools Command Prompt and configure a separate build directory.")
endif()
if(DEFINED CMAKE_CXX_COMPILER_ARCHITECTURE_ID AND
   NOT CMAKE_CXX_COMPILER_ARCHITECTURE_ID STREQUAL "" AND
   NOT CMAKE_CXX_COMPILER_ARCHITECTURE_ID MATCHES "^(X86|x86|x64|X64|AMD64)$")
  message(FATAL_ERROR "Unsupported Windows compiler architecture: ${CMAKE_CXX_COMPILER_ARCHITECTURE_ID}")
endif()
if(DEFINED VCPKG_TARGET_TRIPLET AND
   NOT VCPKG_TARGET_TRIPLET MATCHES "^${CRYSTAL_WINDOWS_ARCH}-windows")
  message(FATAL_ERROR "The vcpkg triplet ${VCPKG_TARGET_TRIPLET} does not match the ${CRYSTAL_WINDOWS_ARCH} compiler.")
endif()
# Keep linker products and symbols inside the selected build tree.
if(NOT DEFINED CRYSTAL_DISTRIBUTION_PRESET)
  get_filename_component(CRYSTAL_DISTRIBUTION_PRESET "${CMAKE_BINARY_DIR}" NAME)
endif()
if(NOT CRYSTAL_DISTRIBUTION_PRESET MATCHES "^[A-Za-z0-9_-]+$")
  message(FATAL_ERROR "Invalid distribution preset: ${CRYSTAL_DISTRIBUTION_PRESET}")
endif()
set(CRYSTAL_WINDOWS_DIST_DIRECTORY "${CMAKE_SOURCE_DIR}/dist/${CRYSTAL_DISTRIBUTION_PRESET}")
set(CRYSTAL_WINDOWS_OUTPUT_NAME "Cliente${CRYSTAL_WINDOWS_ARCH}")
