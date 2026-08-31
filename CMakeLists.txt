cmake_minimum_required(VERSION 3.27)
project(dpct)

include(CMakePackageConfigHelpers)
set(CMAKE_MODULE_PATH ${PROJECT_SOURCE_DIR}/cmake_extensions/)
# ------------------------------------------
# user defined configuration
option(WITH_TESTS "Build tests." OFF)
option(WITH_LOG "Enable logs." OFF)
option(WITH_PYTHON "Build python wrapper." ON)
option(WITH_BIN "Build track executable." ON)
option(MULTI_STAGE_BUILD "Enable conda build of the Python packages with multiple outputs" OFF)
option(DPCT_VENDOR_DEPS "Fetch and build LEMON/jsoncpp from source instead of requiring them preinstalled (useful for `pip install`)" OFF)
option(DPCT_STATIC_LIB "Build libdpct as a static, position-independent library so it can be baked into the Python extension module without needing to ship/locate a separate shared library at runtime" OFF)

if(DPCT_VENDOR_DEPS)
    include(${CMAKE_CURRENT_SOURCE_DIR}/cmake/VendorDeps.cmake)
endif()


if(WITH_LOG)
    add_definitions(-DDEBUG_LOG)
endif()

if (NOT WIN32)
    set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -Wall -Wno-unused-local-typedefs")
endif()

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# C++ STL debug symbols
if("${CMAKE_CXX_COMPILER_ID}" STREQUAL "GNU")
  set(WITH_DEBUG_STL "False" CACHE BOOL "Build with C++ stl debug symbols?")
  if(WITH_DEBUG_STL)
    add_definitions(-D_GLIBCXX_DEBUG)
  endif()
endif()


if (MULTI_STAGE_BUILD)
    find_package(dpct REQUIRED)
else()
    find_package(LEMON REQUIRED)
    find_package(jsoncpp REQUIRED)
    file(GLOB_RECURSE SOURCES src/*.cpp)
    file(GLOB_RECURSE HEADERS include/*.h)
    include_directories(${LEMON_INCLUDE_DIR})
    include_directories(${CMAKE_CURRENT_SOURCE_DIR}/include/)

    if(DPCT_STATIC_LIB)
        set(_dpct_lib_type STATIC)
        set(CMAKE_POSITION_INDEPENDENT_CODE ON)
    else()
        set(_dpct_lib_type SHARED)
    endif()

    add_library(dpct ${_dpct_lib_type} ${SOURCES} ${HEADERS})
    target_link_libraries(dpct ${LEMON_LIBRARIES} JsonCpp::JsonCpp)

    target_include_directories(dpct
        PUBLIC
            $<INSTALL_INTERFACE:${CMAKE_INSTALL_INCLUDEDIR}>
    )

    add_library(dpct::dpct ALIAS dpct)
    set_target_properties(dpct PROPERTIES
        EXPORT_NAME dpct
    )

    # Consumers (src/*.cpp, python/*.cpp) include headers as <dpct/foo.h>.
    # After `make install`, that layout exists because headers are copied to
    # ${prefix}/include/dpct/*.h. But target_include_directories'
    # BUILD_INTERFACE above pointed straight at the flat source include/
    # directory (no dpct/ subfolder), so an in-tree/single-stage build (as
    # opposed to conda's two-stage build, which always builds against an
    # *installed* dpct) failed to resolve <dpct/foo.h>. Mirror the installed
    # layout in the build tree via a symlinked include/dpct/ so both build
    # and install interfaces agree.
    set(DPCT_BUILD_INCLUDE_DIR "${CMAKE_CURRENT_BINARY_DIR}/build_include")
    file(MAKE_DIRECTORY "${DPCT_BUILD_INCLUDE_DIR}")
    if(NOT EXISTS "${DPCT_BUILD_INCLUDE_DIR}/dpct")
        file(CREATE_LINK "${CMAKE_CURRENT_SOURCE_DIR}/include" "${DPCT_BUILD_INCLUDE_DIR}/dpct"
             SYMBOLIC RESULT _dpct_link_result)
        if(NOT _dpct_link_result EQUAL 0)
            message(STATUS "dpct: symlinking include/ as dpct/ failed (${_dpct_link_result}), copying headers instead")
            file(REMOVE_RECURSE "${DPCT_BUILD_INCLUDE_DIR}/dpct")
            file(COPY "${CMAKE_CURRENT_SOURCE_DIR}/include/" DESTINATION "${DPCT_BUILD_INCLUDE_DIR}/dpct")
        endif()
    endif()
    target_include_directories(dpct
        PUBLIC
            $<BUILD_INTERFACE:${DPCT_BUILD_INCLUDE_DIR}>
    )

    # installation
    install(TARGETS dpct
        EXPORT dpctTargets
        ARCHIVE DESTINATION lib
        LIBRARY DESTINATION lib
        RUNTIME DESTINATION bin
        INCLUDES DESTINATION include
    )
    install(DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}/include/"
        DESTINATION include/dpct
        FILES_MATCHING PATTERN "*.h"
    )

    install(EXPORT dpctTargets
        FILE dpctTargets.cmake
        DESTINATION lib/cmake/dpct
        NAMESPACE dpct::
    )

    write_basic_package_version_file(
        "${CMAKE_CURRENT_BINARY_DIR}/dpctConfigVersion.cmake"
        VERSION 1.5.0
        COMPATIBILITY SameMajorVersion
    )
    configure_package_config_file(
        "${CMAKE_CURRENT_SOURCE_DIR}/cmake/dpctConfig.cmake.in"
        "${CMAKE_CURRENT_BINARY_DIR}/dpctConfig.cmake"
        INSTALL_DESTINATION lib/cmake/dpct
    )

    install(FILES
        "${CMAKE_CURRENT_BINARY_DIR}/dpctConfig.cmake"
        "${CMAKE_CURRENT_BINARY_DIR}/dpctConfigVersion.cmake"
        DESTINATION lib/cmake/dpct
    )


endif()

# ------------------------------------------
# add subdirectories
if(WITH_TESTS)
    enable_testing()
    add_subdirectory(test)
    list(APPEND CMAKE_CTEST_ARGUMENTS "--output-on-failure")
endif()

if(WITH_PYTHON)
  add_subdirectory(python)
endif()

if(WITH_BIN)
    add_subdirectory(bin)
endif()
