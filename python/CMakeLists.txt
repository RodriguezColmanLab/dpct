cmake_minimum_required(VERSION 3.27)
message( "\nConfiguring python wrapper:" )

find_package(Python REQUIRED Interpreter)
find_package(pybind11 CONFIG)

# include external headers as system includes so we do not have to cope with their warnings
# Obtain the Python include directory from the configured Python interpreter.
# This works even if CMake's FindPython 'Development' component didn't provide
# Python_INCLUDE_DIRS inside the manylinux/cibuildwheel container.
execute_process(
  COMMAND ${Python_EXECUTABLE} -c "import sysconfig; print(sysconfig.get_paths()['include'])"
  OUTPUT_VARIABLE PYTHON_SYSCONFIG_INCLUDE
  OUTPUT_STRIP_TRAILING_WHITESPACE
)
include_directories(SYSTEM ${PYTHON_SYSCONFIG_INCLUDE})

set(PYDPCT_SRCS pydpct.cpp pythongraphreader.cpp)
add_library(dpct_python MODULE ${PYDPCT_SRCS})
# Remove default 'lib' prefix on some platforms and ensure output name 'dpct'
set_target_properties(dpct_python PROPERTIES PREFIX "" OUTPUT_NAME dpct)
# Make sure pybind11 headers are used; if pybind11 exports a target, link it
# (pybind11 is header-only for the usual case)
target_include_directories(dpct_python PRIVATE ${pybind11_INCLUDE_DIRS})
target_link_libraries(dpct_python PRIVATE dpct::dpct pybind11::pybind11)

# scikit-build-core (used for `pip install`) stages the wheel's
# platform-lib directory in SKBUILD_PLATLIB_DIR; a conda build has no such
# variable and installs straight to the environment's site-packages.
if(DEFINED SKBUILD_PLATLIB_DIR)
    set(DPCT_PYTHON_INSTALL_DIR ${SKBUILD_PLATLIB_DIR})
else()
    set(DPCT_PYTHON_INSTALL_DIR ${Python_SITELIB})
endif()

install(TARGETS dpct_python
          LIBRARY DESTINATION ${DPCT_PYTHON_INSTALL_DIR}
          RUNTIME DESTINATION ${DPCT_PYTHON_INSTALL_DIR})
