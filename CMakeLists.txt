cmake_minimum_required(VERSION 3.24)
project(dasNES LANGUAGES CXX)
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_MSVC_RUNTIME_LIBRARY MultiThreadedDLL)
if(NOT MSVC OR NOT CMAKE_SIZEOF_VOID_P EQUAL 8 OR NOT CMAKE_BUILD_TYPE STREQUAL "Release")
    message(FATAL_ERROR "Use MSVC x64, single-config Release and the matching dasSDL3 build")
endif()
set(DASSDL3_ROOT "${CMAKE_CURRENT_SOURCE_DIR}/../dasSDL3" CACHE PATH "dasSDL3 source checkout")
set(DASSDL3_BUILD "${DASSDL3_ROOT}/build/ninja" CACHE PATH "Existing Release dasSDL3 build")
get_filename_component(DASSDL3_ROOT "${DASSDL3_ROOT}" ABSOLUTE)
set(DAS_ROOT "${DASSDL3_ROOT}/third_party/daScript")
file(STRINGS "${DASSDL3_BUILD}/CMakeCache.txt" sdl_source_line REGEX "^SDL3_SOURCE_DIR:STATIC=")
string(REGEX REPLACE "^[^=]*=" "" SDL_SOURCE "${sdl_source_line}")
if(NOT EXISTS "${SDL_SOURCE}/include/SDL3/SDL.h")
    message(FATAL_ERROR "SDL headers missing; build dasSDL3 first")
endif()
add_library(runtime INTERFACE)
target_include_directories(runtime INTERFACE
    "${DASSDL3_ROOT}/src" "${DAS_ROOT}/include" "${DAS_ROOT}/3rdparty/fmt/include"
    "${DAS_ROOT}/3rdparty/uriparser/include" "${DASSDL3_BUILD}/third_party/daScript/include"
    "${SDL_SOURCE}/include" "${DASSDL3_BUILD}/_deps/sdl3-build/include-revision")
target_compile_definitions(runtime INTERFACE DAS_ENABLE_EXCEPTIONS=1 DAS_ENABLE_DYN_INCLUDES=1
    DAS_FUSION=2 DAS_NO_ASSERTIONS URIPARSER_BUILD_CHAR URI_STATIC_BUILD
    DASNES_SDL_ROOT="${DASSDL3_ROOT}")
target_compile_options(runtime INTERFACE /bigobj)
target_link_libraries(runtime INTERFACE
    "${DAS_ROOT}/lib/libDaScript_runtime.lib"
    "${DAS_ROOT}/lib/libUriParser.lib" "${DASSDL3_BUILD}/_deps/sdl3-build/SDL3-static.lib"
    dbghelp ws2_32 mswsock rpcrt4 kernel32 user32 gdi32 winmm imm32 ole32 oleaut32
    version uuid advapi32 setupapi shell32 dinput8 winspool comdlg32)
# Build the binding registration with AOT headers enabled; leave dasSDL3's own build untouched.
add_library(sdl_binding STATIC "${DASSDL3_ROOT}/src/module_sdl3.cpp")
target_link_libraries(sdl_binding PUBLIC "${DAS_ROOT}/lib/libDaScript.lib" runtime)
target_compile_definitions(sdl_binding PRIVATE DASSDL3_AOT_HEADER="sdl3_aot.h"
    DASSDL3_TYPES_INCLUDE="generated/clangbind/sdl3_types.inc"
    DASSDL3_REGISTRATION_INCLUDE="generated/clangbind/sdl3_functions.inc")
add_executable(dasnes_aot_generator native/aot.cpp)
target_link_libraries(dasnes_aot_generator PRIVATE sdl_binding)
add_executable(dasNES native/host.cpp "${DAS_ROOT}/modules/dasLLVM/src/dasLLVM.cpp")
target_compile_definitions(dasNES PRIVATE DASNES_JIT_ROOT="${CMAKE_CURRENT_SOURCE_DIR}/build/jit")
target_link_libraries(dasNES PRIVATE sdl_binding)
file(GLOB local_scripts CONFIGURE_DEPENDS "${CMAKE_CURRENT_SOURCE_DIR}/*.das")
file(GLOB_RECURSE library_scripts CONFIGURE_DEPENDS "${DASSDL3_ROOT}/dassdl3/*.das" "${DAS_ROOT}/daslib/*.das")
set(aot_inputs pacing.das pacing_tests.das state.das mapper.das apu.das hardware_tests.das apu_event_tests.das rom_replay.das main.das core.das cpu.das ppu.das tests.das demo_test.das trace.das benchmark.das timing_tests.das scroll_tests.das smb_scroll_test.das profile.das renderer_tests.das
    "${DASSDL3_ROOT}/dassdl3/sdl3_result.das"
    "${DASSDL3_ROOT}/dassdl3/sdl3_boost.das"
    "${DASSDL3_ROOT}/dassdl3/sdl3_pixels_boost.das"
    "${DASSDL3_ROOT}/dassdl3/sdl3_audio_boost.das"
    "${DAS_ROOT}/daslib/fio.das")
foreach(input IN LISTS aot_inputs)
    get_filename_component(input "${input}" ABSOLUTE BASE_DIR "${CMAKE_CURRENT_SOURCE_DIR}")
    string(SHA256 key "${input}")
    set(output "${CMAKE_CURRENT_BINARY_DIR}/${key}.aot.cpp")
    if(input MATCHES "/cpu\\.das$")
        # Avoid pathological MSVC inlining time for the large instruction decoder.
        set_source_files_properties("${output}" PROPERTIES COMPILE_OPTIONS /Ob0)
    endif()
    add_custom_command(OUTPUT "${output}"
        COMMAND dasnes_aot_generator "${input}" "${output}" "${DASSDL3_ROOT}"
        DEPENDS dasnes_aot_generator "${input}" ${local_scripts} ${library_scripts} VERBATIM)
    target_sources(dasNES PRIVATE "${output}")
endforeach()

# Distribution build: compiler and binding registrations exist only in the generator.
add_executable(dasnes_standalone_generator EXCLUDE_FROM_ALL native/standalone_generate.cpp)
target_link_libraries(dasnes_standalone_generator PRIVATE sdl_binding)
target_compile_options(dasnes_standalone_generator PRIVATE /EHsc)
set(standalone_dir "${CMAKE_CURRENT_BINARY_DIR}/standalone")
file(MAKE_DIRECTORY "${standalone_dir}")
add_custom_command(OUTPUT "${standalone_dir}/nes.das.cpp" "${standalone_dir}/nes.das.h"
    COMMAND dasnes_standalone_generator "${CMAKE_CURRENT_SOURCE_DIR}/main.das"
        "${standalone_dir}" "${CMAKE_CURRENT_SOURCE_DIR}/native/standalone.das"
    DEPENDS dasnes_standalone_generator native/standalone.das ${local_scripts} ${library_scripts} VERBATIM)
add_executable(dasNES_standalone EXCLUDE_FROM_ALL native/standalone_host.cpp "${standalone_dir}/nes.das.cpp")
target_include_directories(dasNES_standalone PRIVATE "${standalone_dir}")
target_link_libraries(dasNES_standalone PRIVATE runtime)
# The generator limits optimization only for the CPU decoder on MSVC.
# The generated Nes initializer needs >1 MB of native stack.
target_compile_options(dasNES_standalone PRIVATE /EHsc /Gy /Gw)
target_link_options(dasNES_standalone PRIVATE /OPT:REF /OPT:ICF /STACK:16777216
    "/MAP:${standalone_dir}/dasNES_standalone.map")
set_property(TARGET dasNES_standalone APPEND PROPERTY LINK_DEPENDS
    "${CMAKE_CURRENT_SOURCE_DIR}/native/check_standalone.cmake" "${CMAKE_CURRENT_SOURCE_DIR}/demo.nes")
add_custom_command(TARGET dasNES_standalone POST_BUILD
    COMMAND "${CMAKE_COMMAND}" "-DMAP_FILE=${standalone_dir}/dasNES_standalone.map"
        -P "${CMAKE_CURRENT_SOURCE_DIR}/native/check_standalone.cmake"
    COMMAND "${CMAKE_COMMAND}" -E copy_if_different "${CMAKE_CURRENT_SOURCE_DIR}/demo.nes" "$<TARGET_FILE_DIR:dasNES_standalone>/demo.nes"
    VERBATIM)
