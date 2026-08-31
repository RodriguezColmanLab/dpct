# Fetches and builds LEMON and jsoncpp from source, installing them into a
# local vendor prefix, and prepends that prefix to CMAKE_PREFIX_PATH so the
# find_package(LEMON) / find_package(jsoncpp) calls in the main
# CMakeLists.txt discover them exactly as they would a system/conda install.
#
# This is meant for environments (e.g. `pip install git+...`) where LEMON and
# jsoncpp are not available as pre-built system or conda packages, and
# building from source is preferred. Both dependencies ship their own CMake
# build system that exports the same config files a system/conda install
# would (LEMONConfig.cmake with LEMON_INCLUDE_DIR/LEMON_LIBRARIES, and
# JsonCppConfig.cmake with the JsonCpp::JsonCpp target), so no custom
# Find-modules are needed here.

include(FetchContent)

set(DPCT_VENDOR_PREFIX "${CMAKE_BINARY_DIR}/_vendor" CACHE PATH
    "Install prefix used for vendored dependencies (LEMON, jsoncpp)")

set(_dpct_vendor_common_args
    -DCMAKE_BUILD_TYPE=Release
    -DCMAKE_POSITION_INDEPENDENT_CODE=ON
    -DBUILD_SHARED_LIBS=OFF
    -DCMAKE_INSTALL_PREFIX=${DPCT_VENDOR_PREFIX}
    -DCMAKE_PREFIX_PATH=${DPCT_VENDOR_PREFIX}
)
if(CMAKE_TOOLCHAIN_FILE)
    list(APPEND _dpct_vendor_common_args -DCMAKE_TOOLCHAIN_FILE=${CMAKE_TOOLCHAIN_FILE})
endif()

# Configures, builds and installs a FetchContent-declared dependency using
# its own CMake build system (a small manual "superbuild" step). This runs
# synchronously during *our* configure step, so by the time we reach
# find_package(LEMON)/find_package(jsoncpp) further down, both are already
# installed into DPCT_VENDOR_PREFIX.
function(dpct_build_vendored_dep name)
    set(_stamp "${DPCT_VENDOR_PREFIX}/.dpct-vendor-${name}-installed")
    if(EXISTS "${_stamp}")
        message(STATUS "dpct: vendored dependency '${name}' already installed, skipping rebuild")
        return()
    endif()

    FetchContent_GetProperties(${name})
    if(NOT ${name}_POPULATED)
        FetchContent_Populate(${name})
    endif()

    set(_src "${${name}_SOURCE_DIR}")
    set(_bin "${${name}_BINARY_DIR}")

    message(STATUS "dpct: configuring vendored dependency '${name}'")
    execute_process(
        COMMAND ${CMAKE_COMMAND} -S "${_src}" -B "${_bin}"
                ${_dpct_vendor_common_args}
                ${ARGN}
        RESULT_VARIABLE _result
    )
    if(NOT _result EQUAL 0)
        message(FATAL_ERROR "dpct: failed to configure vendored dependency '${name}'")
    endif()

    message(STATUS "dpct: building + installing vendored dependency '${name}'")
    execute_process(
        COMMAND ${CMAKE_COMMAND} --build "${_bin}" --target install --parallel
        RESULT_VARIABLE _result
    )
    if(NOT _result EQUAL 0)
        message(FATAL_ERROR "dpct: failed to build/install vendored dependency '${name}'")
    endif()

    file(TOUCH "${_stamp}")
endfunction()

# --- LEMON --------------------------------------------------------------
# NOTE: no URL_HASH is pinned here because we could not verify one in this
# environment. Consider pinning a SHA256 (URL_HASH SHA256=...) once you've
# downloaded and checked the tarball once, for reproducibility/integrity.
FetchContent_Declare(
    lemon
    URL https://lemon.cs.elte.hu/pub/sources/lemon-1.3.1.tar.gz
)
dpct_build_vendored_dep(lemon)

# --- jsoncpp -------------------------------------------------------------
FetchContent_Declare(
    jsoncpp
    GIT_REPOSITORY https://github.com/open-source-parsers/jsoncpp.git
    GIT_TAG 1.9.6
)
dpct_build_vendored_dep(jsoncpp
    -DJSONCPP_WITH_TESTS=OFF
    -DJSONCPP_WITH_POST_BUILD_UNITTEST=OFF
    -DJSONCPP_WITH_EXAMPLE=OFF
)

list(PREPEND CMAKE_PREFIX_PATH "${DPCT_VENDOR_PREFIX}")
