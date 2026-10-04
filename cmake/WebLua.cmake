# Rebuild Lua with the active WebAssembly toolchain instead of shipping an
# untracked precompiled .a tied to a particular LLVM/Emscripten installation.
include(FetchContent)
FetchContent_Declare(crystal_lua51
  URL "https://www.lua.org/ftp/lua-5.1.5.tar.gz"
  URL_HASH SHA256=2640fc56a795f29d28ef15e13c34a47e223960b0240e8cb0a82d9b0738695333
  DOWNLOAD_EXTRACT_TIMESTAMP TRUE)
FetchContent_MakeAvailable(crystal_lua51)
file(GLOB lua51_sources "${crystal_lua51_SOURCE_DIR}/src/*.c")
list(REMOVE_ITEM lua51_sources "${crystal_lua51_SOURCE_DIR}/src/lua.c" "${crystal_lua51_SOURCE_DIR}/src/luac.c" "${crystal_lua51_SOURCE_DIR}/src/print.c")
add_library(crystal_web_lua STATIC ${lua51_sources})
set(lua51_headers "${CMAKE_BINARY_DIR}/web-include/lua51")
file(MAKE_DIRECTORY "${lua51_headers}")
foreach(header IN ITEMS lua.h luaconf.h lauxlib.h lualib.h)
  configure_file("${crystal_lua51_SOURCE_DIR}/src/${header}" "${lua51_headers}/${header}" COPYONLY)
endforeach()
target_include_directories(crystal_web_lua PUBLIC "${CMAKE_BINARY_DIR}/web-include")
target_compile_options(crystal_web_lua PRIVATE -pthread -matomics -mbulk-memory)
if(WASM_USE_WASM_EXCEPTIONS)
  target_compile_options(crystal_web_lua PRIVATE -fwasm-exceptions)
endif()
