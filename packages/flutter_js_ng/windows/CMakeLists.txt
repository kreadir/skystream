cmake_minimum_required(VERSION 3.15)

set(PROJECT_NAME "flutter_js")
project(${PROJECT_NAME} LANGUAGES CXX)
add_compile_options("$<$<CXX_COMPILER_ID:MSVC>:/utf-8>")

# This value is used when generating builds using this plugin, so it must
# not be changed
set(PLUGIN_NAME "flutter_js_plugin")

add_library(${PLUGIN_NAME} SHARED
  "flutter_js_plugin.cpp"
)
apply_standard_settings(${PLUGIN_NAME})
set_target_properties(${PLUGIN_NAME} PROPERTIES
  CXX_VISIBILITY_PRESET hidden)
target_compile_definitions(${PLUGIN_NAME} PRIVATE FLUTTER_PLUGIN_IMPL)
target_include_directories(${PLUGIN_NAME} INTERFACE
  "${CMAKE_CURRENT_SOURCE_DIR}/include")
target_link_libraries(${PLUGIN_NAME} PRIVATE flutter flutter_wrapper_plugin)

# List of absolute paths to libraries that should be bundled with the plugin
set(flutter_js_bundled_libraries
  ""
  PARENT_SCOPE
)


set(BUILD_BUNDLE_DIR "$<TARGET_FILE_DIR:${BINARY_NAME}>")
# Make the "install" step default, as it's required to run.
set(CMAKE_VS_INCLUDE_INSTALL_TO_DEFAULT_BUILD 1)
if(CMAKE_INSTALL_PREFIX_INITIALIZED_TO_DEFAULT)
  set(CMAKE_INSTALL_PREFIX "${BUILD_BUNDLE_DIR}" CACHE PATH "..." FORCE)
endif()

set(INSTALL_BUNDLE_LIB_DIR "${CMAKE_INSTALL_PREFIX}")
# ---- Build QuickJS from Source ----
set(QUICKJS_SRC_DIR "${CMAKE_CURRENT_SOURCE_DIR}/../android/src/main/c")
add_definitions(-DCONFIG_VERSION="2024-01-01" -DQUICKJS -DCONFIG_BIGNUM -D_GNU_SOURCE)

add_library(quickjs_c_bridge SHARED
    "${QUICKJS_SRC_DIR}/quickjs/cutils.c"
    "${QUICKJS_SRC_DIR}/quickjs/libregexp.c"
    "${QUICKJS_SRC_DIR}/quickjs/libunicode.c"
    "${QUICKJS_SRC_DIR}/quickjs/libbf.c"
    "${QUICKJS_SRC_DIR}/quickjs/quickjs.c"
    "${QUICKJS_SRC_DIR}/libfastdev_quickjs_runtime.cpp"
)

if(MSVC)
    target_compile_options(quickjs_c_bridge PRIVATE /experimental:c11atomics)
endif()

target_include_directories(quickjs_c_bridge PRIVATE "${QUICKJS_SRC_DIR}/quickjs")

set(flutter_js_bundled_libraries
  "$<TARGET_FILE:quickjs_c_bridge>"
  PARENT_SCOPE
)

add_dependencies(${PLUGIN_NAME} quickjs_c_bridge)