cmake_minimum_required(VERSION 3.27)
message( "\nConfiguring python wrapper:" )

find_package(Python REQUIRED Interpreter Development)
find_package(pybind11 CONFIG)

# include external headers as system includes so we do not have to cope with their warnings
include_directories(SYSTEM ${PYTHON_INCLUDE_DIRS})

set(PYDPCT_SRCS pydpct.cpp pythongraphreader.cpp)
pybind11_add_module(dpct_python ${PYDPCT_SRCS})
set_target_properties(dpct_python PROPERTIES OUTPUT_NAME dpct)
target_link_libraries(dpct_python PRIVATE dpct::dpct)

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
