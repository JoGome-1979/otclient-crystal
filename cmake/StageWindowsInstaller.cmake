# Preserve the Windows installer entry point while sharing its bootstrap modules.
set(PLATFORM windows)
include("${CMAKE_CURRENT_LIST_DIR}/StageClientBootstrap.cmake")
