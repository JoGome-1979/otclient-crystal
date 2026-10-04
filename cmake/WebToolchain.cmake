# vcpkg invokes Emscripten for targets and keeps native tools on x64-linux.
include("${CMAKE_CURRENT_LIST_DIR}/WebEnvironment.cmake")
include("${CRYSTAL_WEB_VCPKG_ROOT}/scripts/buildsystems/vcpkg.cmake")
