cmake_minimum_required(VERSION 3.24)
project(dasNESWeb LANGUAGES C CXX)
if(NOT EMSCRIPTEN OR NOT EMSCRIPTEN_VERSION VERSION_EQUAL "5.0.3")
    message(FATAL_ERROR "Use Emscripten 5.0.3 via build-web.ps1")
endif()
set(CMAKE_CXX_STANDARD 17)
set(DASSDL3_ROOT "${CMAKE_CURRENT_SOURCE_DIR}/../../dasSDL3" CACHE PATH "dasSDL3 checkout")
get_filename_component(DASSDL3_ROOT "${DASSDL3_ROOT}" ABSOLUTE)
set(DASSDL3_BUILD "${DASSDL3_ROOT}/build/web" CACHE PATH "Built dasSDL3 wasm profile")
get_filename_component(APP "${CMAKE_CURRENT_SOURCE_DIR}/.." ABSOLUTE)
set(DAS "${DASSDL3_ROOT}/third_party/daScript")
file(STRINGS "${DASSDL3_BUILD}/CMakeCache.txt" sdl_line REGEX "^SDL3_SOURCE_DIR:STATIC=")
string(REGEX REPLACE "^[^=]*=" "" SDL "${sdl_line}")
add_library(runtime INTERFACE)
target_include_directories(runtime INTERFACE "${DAS}/include" "${DAS}/3rdparty/fmt/include"
    "${DAS}/3rdparty/uriparser/include" "${DASSDL3_BUILD}/dascript/include"
    "${DASSDL3_ROOT}/src" "${DASSDL3_ROOT}/web" "${SDL}/include"
    "${DASSDL3_BUILD}/_deps/sdl3-build/include-revision")
target_compile_definitions(runtime INTERFACE DAS_ENABLE_EXCEPTIONS=1 DAS_ENABLE_DYN_INCLUDES=1
    DAS_FUSION=2 DAS_NO_ASSERTIONS URIPARSER_BUILD_CHAR URI_STATIC_BUILD _EMSCRIPTEN_VER)
target_compile_options(runtime INTERFACE -msimd128 -mnontrapping-fptoint -fwasm-exceptions -sWASM_LEGACY_EXCEPTIONS=0 -fno-rtti)
target_link_options(runtime INTERFACE -fwasm-exceptions -sWASM_LEGACY_EXCEPTIONS=0 -sSTACK_SIZE=4MB
    -sALLOW_MEMORY_GROWTH=1 -sINITIAL_MEMORY=128MB -sMAXIMUM_MEMORY=2GB -sFORCE_FILESYSTEM=1
    -sFULL_ES3=1 -sMAX_WEBGL_VERSION=2 -sMIN_WEBGL_VERSION=1 -O1)
target_link_libraries(runtime INTERFACE "${DASSDL3_BUILD}/lib/liblibDaScript.a"
    "${DASSDL3_BUILD}/lib/liblibDaScript_runtime.a" "${DASSDL3_BUILD}/lib/liblibUriParser.a"
    "${DASSDL3_BUILD}/_deps/sdl3-build/libSDL3.a")
add_library(web_binding STATIC "${DASSDL3_ROOT}/web/module_web.cpp")
target_link_libraries(web_binding PUBLIC runtime)

set(core_scripts state mapper apu core cpu ppu pacing web_main)
file(MAKE_DIRECTORY "${CMAKE_BINARY_DIR}/app")
foreach(name IN LISTS core_scripts)
    configure_file("${APP}/${name}.das" "${CMAKE_BINARY_DIR}/app/${name}.das" COPYONLY)
endforeach()
set(preload
    "SHELL:--preload-file ${DAS}/daslib@/daslib"
    "SHELL:--exclude-file */_aot_generated/*"
    "SHELL:--exclude-file */.jitted_scripts/*"
    "SHELL:--exclude-file */_llvm_aot_generated/*"
    "SHELL:--preload-file ${DASSDL3_ROOT}/dassdl3@/dassdl3"
    "SHELL:--preload-file ${CMAKE_BINARY_DIR}/app@/app")
add_executable(generate_web_aot generate_aot.cpp)
target_link_libraries(generate_web_aot PRIVATE web_binding)
target_link_options(generate_web_aot PRIVATE ${preload} -lnodefs.js -sENVIRONMENT=node)
set_target_properties(generate_web_aot PROPERTIES SUFFIX ".js")
set(aot_outputs)
foreach(name IN LISTS core_scripts)
    list(APPEND aot_outputs "${CMAKE_BINARY_DIR}/aot/${name}.cpp")
endforeach()
foreach(i RANGE 0 4)
    list(APPEND aot_outputs "${CMAKE_BINARY_DIR}/aot/shared${i}.cpp")
endforeach()
file(MAKE_DIRECTORY "${CMAKE_BINARY_DIR}/aot")
file(GLOB_RECURSE boost_scripts "${DASSDL3_ROOT}/dassdl3/*.das" "${DAS}/daslib/*.das")
file(GLOB app_scripts "${APP}/*.das")
set_property(TARGET generate_web_aot APPEND PROPERTY LINK_DEPENDS ${app_scripts} ${boost_scripts})
add_custom_command(OUTPUT ${aot_outputs}
    COMMAND "${NODE_EXECUTABLE}" "$<TARGET_FILE:generate_web_aot>" "${APP}" "${CMAKE_BINARY_DIR}/aot"
    DEPENDS generate_web_aot ${app_scripts} ${boost_scripts} VERBATIM)
add_executable(dasnes_web runner.cpp ${aot_outputs})
target_link_libraries(dasnes_web PRIVATE web_binding)
target_link_options(dasnes_web PRIVATE ${preload}
    "SHELL:--preload-file ${APP}/demo.nes@/demo.nes"
    -sMODULARIZE=1 -sEXPORT_NAME=createDasNES -sINVOKE_RUN=0 -sEXIT_RUNTIME=0
    "-sEXPORTED_FUNCTIONS=['_main','_web_stop','_web_pause']"
    "-sEXPORTED_RUNTIME_METHODS=['callMain','FS','ENV']")
set_target_properties(dasnes_web PROPERTIES SUFFIX ".js" RUNTIME_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/site")
if(CMAKE_HOST_WIN32)
    foreach(target generate_web_aot dasnes_web)
        add_custom_command(TARGET ${target} POST_BUILD COMMAND icacls "$<TARGET_FILE:${target}>" /reset VERBATIM)
    endforeach()
endif()
foreach(page index.html app.js style.css)
    configure_file("${CMAKE_CURRENT_SOURCE_DIR}/${page}" "${CMAKE_BINARY_DIR}/site/${page}" COPYONLY)
endforeach()
