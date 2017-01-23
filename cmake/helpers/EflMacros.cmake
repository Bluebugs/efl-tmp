# NOTE:
#
# - Use function() whenever possible, macro() doesn't start a new
#   variable scope and needs careful handling to avoid left overs.
#
# - To 'export' values or lists, use the macros SET_GLOBAL() and
#   LIST_APPEND_GLOBAL().
#

# LIST_APPEND_GLOBAL(Var Element)
#
# Append to a list in the global variable scope (cache internal)
function(LIST_APPEND_GLOBAL _var _element)
  set(_local ${${_var}})
  list(APPEND _local ${_element})
  set(${_var} ${_local} CACHE INTERNAL "")
endfunction()

# SET_GLOBAL(Var Value [Help])
#
# Set a variable in the global variable scope (cache internal)
function(SET_GLOBAL _var _value)
  set(${_var} "${_value}" CACHE INTERNAL "${ARGN}")
endfunction()

unset(EFL_ALL_OPTIONS CACHE)
unset(EFL_ALL_LIBS CACHE)
unset(EFL_ALL_TESTS CACHE)
unset(EFL_PKG_CONFIG_MISSING_OPTIONAL CACHE)

# EFL_OPTION(Name Help Default)
#
# Declare an option() that will be automatically printed by
# EFL_OPTIONS_SUMMARY()
#
# To extend the EFL_OPTIONS_SUMMARY() message, use
# EFL_OPTION_SET_MESSAGE(Name Message)
function(EFL_OPTION _name _help _defval)
  set(_type)
  set(_vartype)
  set(_choices)
  list(LENGTH ARGN _argc)
  if(_argc LESS 1)
    set(_type BOOL)
    set(_vartype BOOL)
  else()
    list(GET ARGN 0 _type)
    set(_vartype ${_type})
    list(REMOVE_AT ARGN 0)
  endif()
  if(${_vartype} STREQUAL "CHOICE")
    set(_type STRING)
    SET_GLOBAL(EFL_OPTION_CHOICES_${_name} "${ARGN}" "Possible values for ${_name}")
    set(_choices " (Choices: ${ARGN})")
  endif()

  LIST_APPEND_GLOBAL(EFL_ALL_OPTIONS ${_name})

  SET_GLOBAL(EFL_OPTION_DEFAULT_${_name} "${_defval}" "Default value for ${_name}")
  SET_GLOBAL(EFL_OPTION_TYPE_${_name} "${_vartype}" "Type of ${_name}")
  set(${_name} ${_defval} CACHE ${_type} "${_help}${_choices}")
  option(${_name} "${_help}${_choices}" ${_defval})

  if(_choices)
    list(FIND ARGN "${${_name}}" _ret)
    if(${_ret} EQUAL -1)
      message(FATAL_ERROR "Invalid choice ${_name}=${${_name}}${_choices}")
    endif()
  endif()
endfunction()

# EFL_OPTION_SET_MESSAGE(Name Message)
#
# Extends the summary line output by EFL_OPTIONS_SUMMARY()
# with more details.
function(EFL_OPTION_SET_MESSAGE _name _message)
  SET_GLOBAL(EFL_OPTION_MESSAGE_${_name} "${_message}")
endfunction()

# EFL_OPTIONS_SUMMARY()
# Shows the summary of options, their values and related messages.
function(EFL_OPTIONS_SUMMARY)
  message(STATUS "EFL Options Summary:")
  message(STATUS "  CMAKE_INSTALL_PREFIX=${CMAKE_INSTALL_PREFIX}")
  message(STATUS "  CMAKE_BUILD_TYPE=${CMAKE_BUILD_TYPE}")
  foreach(_o ${EFL_ALL_OPTIONS})
    set(_v ${${_o}})
    set(_d ${EFL_OPTION_DEFAULT_${_o}})
    if("${_v}" STREQUAL "${_d}")
      set(_i "default")
    else()
      set(_i "default: ${_d}")
    endif()
    if(EFL_OPTION_MESSAGE_${_o})
      set(_m " [${EFL_OPTION_MESSAGE_${_o}}]")
    else()
      set(_m)
    endif()
    message(STATUS "  ${_o}=${_v} (${_i})${_m}")
  endforeach()
  message(STATUS "EFL Libraries:")
  foreach(_o ${EFL_ALL_LIBS})
    message(STATUS "  ${_o}${_mods}")
    foreach(_m ${${_o}_MODULES})
      string(REGEX REPLACE "^${_o}-module-" "" _m ${_m})
      message(STATUS "    dynamic: ${_m}")
    endforeach()
    foreach(_m ${${_o}_STATIC_MODULES})
      string(REGEX REPLACE "^${_o}-module-" "" _m ${_m})
      message(STATUS "    static.: ${_m}")
    endforeach()
    unset(_m)
  endforeach()

  if(EFL_PKG_CONFIG_MISSING_OPTIONAL)
    message(STATUS "The following pkg-config optional modules are missing:")
    foreach(_m ${EFL_PKG_CONFIG_MISSING_OPTIONAL})
      message(STATUS "  ${_m}")
    endforeach()
    unset(_m)
  endif()
endfunction()

set(EFL_ALL_LIBS)
set(EFL_ALL_TESTS)

# EFL_FINALIZE()
#
# Finalize EFL processing, adding extra targets.
function(EFL_FINALIZE)
  add_custom_target(all-libs DEPENDS ${EFL_ALL_LIBS})
  add_custom_target(all-tests DEPENDS ${EFL_ALL_TESTS})
endfunction()

unset(HEADER_FILE_CONTENT CACHE)

# HEADER_CHECK(header [NAME variable] [INCLUDE_FILES extra1.h .. extraN.h])
#
# Check if the header file exists, in such case define variable
# in configuration file.
#
# Variable defaults to HAVE_${HEADER}, where HEADER is the uppercase
# representation of the first parameter. It can be overridden using
# NAME keyword.
#
# To include extra files, then use INCLUDE_FILES keyword.
function(HEADER_CHECK header)
  string(TOUPPER HAVE_${header} var)
  string(REGEX REPLACE "[^a-zA-Z0-9]" "_" var "${var}")
  string(REGEX REPLACE "_{2,}" "_" var "${var}")

  cmake_parse_arguments(PARAMS "" "NAME" "INCLUDE_FILES" ${ARGN})

  if(PARAMS_NAME)
    set(var ${PARAMS_NAME})
  endif()

  set(CMAKE_EXTRA_INCLUDE_FILES "${PARAMS_INCLUDE_FILES}")

  CHECK_INCLUDE_FILE(${header} ${var})

  if(${${var}})
    SET_GLOBAL(HEADER_FILE_CONTENT "${HEADER_FILE_CONTENT}#define ${var} 1\n")
  else()
    SET_GLOBAL(HEADER_FILE_CONTENT "${HEADER_FILE_CONTENT}#undef ${var}\n")
  endif()
endfunction()

# FUNC_CHECK(func [NAME variable]
#            [INCLUDE_FILES header1.h .. headerN.h]
#            [LIBRARIES lib1 ... libN]
#            [DEFINITIONS -DA=1 .. -DN=123]
#            [FLAGS -cmdlineparam1 .. -cmdlineparamN]
#            [CXX])
#
# Check if the function exists, in such case define variable in
# configuration file.
#
# Variable defaults to HAVE_${FUNC}, where FUNC is the uppercase
# representation of the first parameter. It can be overridden using
# NAME keyword.
#
# To define include files use INCLUDE_FILES keyword.
#
# To use C++ compiler, use CXX keyword
function(FUNC_CHECK func)
  string(TOUPPER HAVE_${func} var)
  string(REGEX REPLACE "_{2,}" "_" var "${var}")

  cmake_parse_arguments(PARAMS "CXX" "NAME" "INCLUDE_FILES;LIBRARIES;DEFINITIONS;FLAGS" ${ARGN})

  set(CMAKE_REQUIRED_LIBRARIES "${PARAMS_LIBRARIES}")
  set(CMAKE_REQUIRED_DEFINITIONS "${PARAMS_DEFINITIONS}")
  set(CMAKE_REQUIRED_FLAGS "${PARAMS_FLAGS}")

  if(PARAMS_CXX)
    check_cxx_symbol_exists(${func} "${PARAMS_INCLUDE_FILES}" ${var})
  else()
    check_symbol_exists(${func} "${PARAMS_INCLUDE_FILES}" ${var})
  endif()

  if(${${var}} )
    SET_GLOBAL(HEADER_FILE_CONTENT "${HEADER_FILE_CONTENT}#define ${var} 1\n")
  else()
    SET_GLOBAL(HEADER_FILE_CONTENT "${HEADER_FILE_CONTENT}#undef ${var}\n")
  endif()
endfunction()

# TYPE_CHECK(type [NAME variable]
#           [INCLUDE_FILES file1.h ... fileN.h]
#           [LIBRARIES lib1 ... libN]
#           [DEFINITIONS -DA=1 .. -DN=123]
#           [FLAGS -cmdlineparam1 .. -cmdlineparamN]
#           [CXX])
#
# Check if the type exists and its size, in such case define variable
# in configuration file.
#
# Variable defaults to HAVE_${TYPE}, where TYPE is the uppercase
# representation of the first parameter. It can be overridden using
# NAME keyword.
#
# To define include files use INCLUDE_FILES keyword.
#
# To use C++ compiler, use CXX keyword
function(TYPE_CHECK type)
  string(TOUPPER HAVE_${type} var)
  string(REGEX REPLACE "_{2,}" "_" var "${var}")

  cmake_parse_arguments(PARAMS "CXX" "NAME" "INCLUDE_FILES;LIBRARIES;DEFINITIONS;FLAGS" ${ARGN})

  set(CMAKE_REQUIRED_LIBRARIES "${PARAMS_LIBRARIES}")
  set(CMAKE_REQUIRED_DEFINITIONS "${PARAMS_DEFINITIONS}")
  set(CMAKE_REQUIRED_FLAGS "${PARAMS_FLAGS}")
  set(CMAKE_EXTRA_INCLUDE_FILES "${PARAMS_INCLUDE_FILES}")

  if(PARAMS_CXX)
    set(lang CXX)
  else()
    set(lang C)
  endif()

  CHECK_TYPE_SIZE(${type} ${var} LANGUAGE ${lang})

  if(HAVE_${var})
    SET_GLOBAL(HEADER_FILE_CONTENT "${HEADER_FILE_CONTENT}#define ${var} 1\n")
  else()
    SET_GLOBAL(HEADER_FILE_CONTENT "${HEADER_FILE_CONTENT}#undef ${var}\n")
  endif()
endfunction()

# EFL_HEADER_CHECKS_FINALIZE(file)
#
# Write the configuration gathered with HEADER_CHECK(), TYPE_CHECK()
# and FUNC_CHECK() to the given file.
function(EFL_HEADER_CHECKS_FINALIZE file)
  file(WRITE ${file}.new ${HEADER_FILE_CONTENT})
  if (NOT EXISTS ${file})
    file(RENAME ${file}.new ${file})
    message(STATUS "${file} was generated.")
  else()
    file(MD5 ${file}.new _new_md5)
    file(MD5 ${file} _old_md5)
    if(_new_md5 STREQUAL _old_md5)
      message(STATUS "${file} is unchanged.")
    else()
      file(REMOVE ${file})
      file(RENAME ${file}.new ${file})
      message(STATUS "${file} was updated.")
    endif()
  endif()
  unset(HEADER_FILE_CONTENT CACHE) # allow to reuse with an empty contents
endfunction()

# EFL_FILES_TO_ABSOLUTE(Var Source_Dir Binary_Dir [file1 ... fileN])
#
# Convert list of files to absolute path. If not absolute, then
# check inside Source_Dir and if it fails assumes it's inside Binary_Dir
function(EFL_FILES_TO_ABSOLUTE _var _srcdir _bindir)
  set(_lst "")
  foreach(f ${ARGN})
    if(EXISTS "${f}")
      list(APPEND _lst "${f}")
    elseif(EXISTS "${_srcdir}/${f}")
      list(APPEND _lst "${_srcdir}/${f}")
    else()
      list(APPEND _lst "${_bindir}/${f}")
    endif()
  endforeach()
  set(${_var} "${_lst}" PARENT_SCOPE)
endfunction()

# EFL_PKG_CONFIG_EVAL_TO(Var Name [module1 ... moduleN])
#
# Evaluate the list of of pkg-config modules and assign to variable
# Var. If it's missing, abort with a message saying ${Name} is missing
# the list of modules.
#
# OPTIONAL keyword may be used to convert the remaining elements in optional
# packages.
function(EFL_PKG_CONFIG_EVAL_TO _var _name)
  set(_found "")
  set(_missing "")
  set(_missing_optional "")
  set(_optional OFF)
  foreach(f ${ARGN})
    if(${f} STREQUAL "OPTIONAL")
      set(_optional ON)
    else()
      pkg_check_modules(PKG_CONFIG_DEP_${f} ${f})
      if(PKG_CONFIG_DEP_${f}_FOUND)
        list(APPEND _found ${f})
      elseif(_optional)
        list(APPEND _missing_optional ${f})
        LIST_APPEND_GLOBAL(EFL_PKG_CONFIG_MISSING_OPTIONAL ${f})
      else()
        list(APPEND _missing ${f})
      else()
      endif()
    endif()
  endforeach()
  if(NOT _missing)
    SET_GLOBAL(${_var} "${_found}")
    SET_GLOBAL(${_var}_MISSING "${_missing_optional}")
  else()
    message(FATAL_ERROR "${_name} missing required pkg-config modules: ${_missing}")
  endif()
endfunction()

# EFL_PKG_CONFIG_EVAL(Name Private_List Public_List)
#
# Evaluates both lists and creates ${Name}_PKG_CONFIG_REQUIRES as well as
# ${Name}_PKG_CONFIG_REQUIRES_PRIVATE with found elements.
#
# OPTIONAL keyword may be used to convert the remaining elements in optional
# packages.
function(EFL_PKG_CONFIG_EVAL _target _private _public)
  EFL_PKG_CONFIG_EVAL_TO(${_target}_PKG_CONFIG_REQUIRES ${_target} ${_public})
  EFL_PKG_CONFIG_EVAL_TO(${_target}_PKG_CONFIG_REQUIRES_PRIVATE ${_target} ${_private})

  set(_lst ${${_target}_PKG_CONFIG_REQUIRES_MISSING})
  foreach(_e ${${_target}_PKG_CONFIG_REQUIRES_PRIVATE_MISSING})
    list(APPEND _lst ${_e})
  endforeach()
  if(_lst)
    message(STATUS "${_target} missing optional pkg-config: ${_lst}")
  endif()
endfunction()

function(EFL_PKG_CONFIG_LIB_WRITE)
  set(_pkg_config_requires)
  set(_pkg_config_requires_private)
  set(_libraries)
  set(_public_libraries)

  foreach(_e ${${EFL_LIB_CURRENT}_PKG_CONFIG_REQUIRES})
    set(_pkg_config_requires "${_pkg_config_requires} ${_e}")
  endforeach()

  foreach(_e ${${EFL_LIB_CURRENT}_PKG_CONFIG_REQUIRES_PRIVATE})
    set(_pkg_config_requires_private "${_pkg_config_requires_private} ${_e}")
  endforeach()

  foreach(_e ${LIBRARIES})
    set(_libraries "${_libraries} -l${_e}")
  endforeach()

  foreach(_e ${PUBLIC_LIBRARIES})
    set(_public_libraries "${_public_libraries} -l${_e}")
  endforeach()

  if(NOT ${EFL_LIB_CURRENT} STREQUAL "efl")
    set(_cflags " -I\${includedir}/${EFL_LIB_CURRENT}-${PROJECT_VERSION_MAJOR}")
  endif()

  # TODO: handle eolian needs

  set(_contents
"prefix=${CMAKE_INSTALL_PREFIX}
exec_prefix=\${prefix}
libdir=\${exec_prefix}/lib
includedir=\${prefix}/include
datarootdir=\${prefix}/share
datadir=\${datarootdir}
pkgdatadir=\${datadir}/${EFL_LIB_CURRENT}
modules=\${libdir}/${EFL_LIB_CURRENT}/modules

Name: ${EFL_LIB_CURRENT}
Description: ${DESCRIPTION}
Version: ${VERSION}
Requires:${_pkg_config_requires}
Requires.private:${_pkg_config_requires_private}
Libs: -L\${libdir} -l${EFL_LIB_CURRENT}${_public_libraries}
Libs.private:${_libraries}
Cflags: -I\${includedir}/efl-${PROJECT_VERSION_MAJOR}${_cflags}
")
  file(WRITE "${CMAKE_BINARY_DIR}/lib/pkgconfig/${EFL_LIB_CURRENT}.pc" "${_contents}")
  install(FILES "${CMAKE_BINARY_DIR}/lib/pkgconfig/${EFL_LIB_CURRENT}.pc"
    DESTINATION "lib/pkgconfig")
endfunction()

# _EFL_INCLUDE_OR_DETECT(Name Source_Dir)
#
# Internal macro that will include(${Source_Dir}/CMakeLists.txt) if
# that exists, otherwise will check if there is a single source file,
# in that case it will automatically define SOURCES to that (including
# extras such as headers and .eo)
#
# Name is only used to print out messages when it's auto-detected.
macro(_EFL_INCLUDE_OR_DETECT _name _srcdir)
  if(EXISTS ${_srcdir}/CMakeLists.txt)
    include(${_srcdir}/CMakeLists.txt)
  else()
    # doc says it's not recommended because it can't know if more files
    # were added, but we're doing this explicitly to handle one file.
    file(GLOB _autodetect_files RELATIVE ${_srcdir}
        ${_srcdir}/*.c
        ${_srcdir}/*.h
        ${_srcdir}/*.hh
        ${_srcdir}/*.cxx
        ${_srcdir}/*.cpp
        ${_srcdir}/*.eo
        )
    list(LENGTH _autodetect_files _autodetect_files_count)
    if(_autodetect_files_count GREATER 1)
      message(WARNING "${_name}: ${_srcdir} contains no CMakeLists.txt and contains more than one source file. Don't know what to do, then ignored.")
    elseif(_autodetect_files_count EQUAL 1)
      file(GLOB SOURCES RELATIVE ${_srcdir}
        ${_srcdir}/*.c
        ${_srcdir}/*.h
        ${_srcdir}/*.hh
        ${_srcdir}/*.cxx
        ${_srcdir}/*.cpp
        ${_srcdir}/*.eo
        )
      message(STATUS "${_name} auto-detected as: ${SOURCES}")
    else()
      message(STATUS "${_name} contains no auto-detectable sources.")
    endif()
    unset(_autodetect_files_count)
    unset(_autodetect_files)
  endif()
endmacro()

# _EFL_LIB_PROCESS_MODULES_INTERNAL()
#
# Internal function to process modules of current EFL_LIB()
function(_EFL_LIB_PROCESS_MODULES_INTERNAL)
  unset(${EFL_LIB_CURRENT}_MODULES CACHE)
  unset(${EFL_LIB_CURRENT}_STATIC_MODULES CACHE)

  if(EXISTS ${EFL_MODULES_SOURCE_DIR}/CMakeLists.txt)
    message(FATAL_ERROR "${EFL_MODULES_SOURCE_DIR}/CMakeLists.txt shouldn't exist. Modules are expected to be defined in their own directory.")
  else()
    file(GLOB modules RELATIVE ${EFL_MODULES_SOURCE_DIR} ${EFL_MODULES_SOURCE_DIR}/*)
    foreach(module ${modules})
      if(IS_DIRECTORY ${EFL_MODULES_SOURCE_DIR}/${module})
        set(EFL_MODULE_SCOPE ${module})

        file(GLOB submodules RELATIVE ${EFL_MODULES_SOURCE_DIR}/${EFL_MODULE_SCOPE} ${EFL_MODULES_SOURCE_DIR}/${EFL_MODULE_SCOPE}/*)
        foreach(submodule ${submodules})
          if(IS_DIRECTORY ${EFL_MODULES_SOURCE_DIR}/${EFL_MODULE_SCOPE}/${submodule})
            EFL_MODULE(${submodule})
          endif()
          unset(submodule)
          unset(submodules)
        endforeach()
      else()
        set(EFL_MODULE_SCOPE)
        EFL_MODULE(${module})
      endif()
      unset(EFL_MODULE_SCOPE)
    endforeach()
  endif()

  if(${EFL_LIB_CURRENT}_MODULES)
    add_custom_target(${EFL_LIB_CURRENT}-modules DEPENDS ${${EFL_LIB_CURRENT}_MODULES})
  endif()
endfunction()

# _EFL_LIB_PROCESS_BINS_INTERNAL()
#
# Internal function to process bins of current EFL_LIB()
function(_EFL_LIB_PROCESS_BINS_INTERNAL)
  if(EXISTS ${EFL_BIN_SOURCE_DIR}/CMakeLists.txt)
    EFL_BIN(${EFL_LIB_CURRENT})
  else()
    file(GLOB bins RELATIVE ${EFL_BIN_SOURCE_DIR} ${EFL_BIN_SOURCE_DIR}/*)
    foreach(bin ${bins})
      if(IS_DIRECTORY ${EFL_BIN_SOURCE_DIR}/${bin})
        EFL_BIN(${bin})
      endif()
    endforeach()
  endif()

  if(${EFL_LIB_CURRENT}_BINS)
    add_custom_target(${EFL_LIB_CURRENT}-bins DEPENDS ${${EFL_LIB_CURRENT}_BINS})
  endif()
endfunction()

# _EFL_LIB_PROCESS_TESTS_INTERNAL()
#
# Internal function to process tests of current EFL_LIB()
function(_EFL_LIB_PROCESS_TESTS_INTERNAL)
  unset(${EFL_LIB_CURRENT}_TESTS CACHE)

  if(EXISTS ${EFL_TESTS_SOURCE_DIR}/CMakeLists.txt)
    EFL_TEST(${EFL_LIB_CURRENT})
  else()
    file(GLOB tests RELATIVE ${EFL_TESTS_SOURCE_DIR} ${EFL_TESTS_SOURCE_DIR}/*)
    foreach(test ${tests})
      if(IS_DIRECTORY ${EFL_TESTS_SOURCE_DIR}/${test})
        EFL_TEST(${test})
      endif()
    endforeach()
  endif()

  if(${EFL_LIB_CURRENT}_TESTS)
    add_custom_target(${EFL_LIB_CURRENT}-tests DEPENDS ${${EFL_LIB_CURRENT}_TESTS})
    LIST_APPEND_GLOBAL(EFL_ALL_TESTS ${EFL_LIB_CURRENT}-tests)
  endif()
endfunction()

# EFL_LIB(Name)
#
# adds a library ${Name} automatically setting object/target
# properties based on script-modifiable variables:
#  - DESCRIPTION: results in ${Name}_DESCRIPTION and fills pkg-config files.
#  - PKG_CONFIG_REQUIRES: results in ${Name}_PKG_CONFIG_REQUIRES and
#    fills pkg-config files. Elements after 'OPTIONAL' keyword are
#    optional.
#  - PKG_CONFIG_REQUIRES_PRIVATE: results in
#    ${Name}_PKG_CONFIG_REQUIRES_PRIVATE and fills pkg-config
#    files. Elements after 'OPTIONAL' keyword are optional.
#  - INCLUDE_DIRECTORIES: results in target_include_directories
#  - SYSTEM_INCLUDE_DIRECTORIES: results in target_include_directories(SYSTEM)
#  - OUTPUT_NAME
#  - SOURCES source files that are needed, eo files can also be added here to be build
#  - PUBLIC_HEADERS
#  - VERSION (defaults to project version)
#  - SOVERSION (defaults to project major version)
#  - LIBRARY_TYPE: SHARED or STATIC, defaults to SHARED
#  - OBJECT_DEPENDS: say this object depends on other files (ie: includes)
#  - DEPENDENCIES: results in add_dependencies()
#  - LIBRARIES: results in target_link_libraries(LINK_PRIVATE)
#  - PUBLIC_LIBRARIES: results in target_link_libraries(LINK_PUBLIC)
#  - DEFINITIONS: target_compile_definitions()
#  - PUBLIC_EO_FILES: the eo files will be used to build that lib, and will be installed to the filesystem
#
# Defines the following variables that can be used within the included files:
#  - EFL_LIB_CURRENT to ${Name}
#  - EFL_LIB_SOURCE_DIR to source dir of ${Name} libraries
#  - EFL_LIB_BINARY_DIR to binary dir of ${Name} libraries
#  - EFL_BIN_SOURCE_DIR to source dir of ${Name} executables
#  - EFL_BIN_BINARY_DIR to binary dir of ${Name} executables
#  - EFL_MODULES_SOURCE_DIR to source dir of ${Name} modules
#  - EFL_MODULES_BINARY_DIR to binary dir of ${Name} modules
#  - EFL_TESTS_SOURCE_DIR to source dir of ${Name} tests
#  - EFL_TESTS_BINARY_DIR to binary dir of ${Name} tests
#
# Modules are processed like:
#   - loop for directories in src/modules/${EFL_LIB_CURRENT}:
#      - if a src/modules/${EFL_LIB_CURRENT}/${Module}/CMakeLists.txt
#        use variables as documented in EFL_MODULE()
#      - otherwise loop for scoped-modules in
#        src/modules/${EFL_LIB_CURRENT}/${EFL_MODULE_SCOPE}/CMakeLists.txt
#        and use variables as documented in EFL_MODULE()
#
# EFL_MODULE() will handle MODULE_TYPE=ON;OFF;STATIC, handling
# dependencies and installation in the proper path, considering
# ${EFL_MODULE_SCOPE} whenever it's set.
#
# Binaries and tests are processed similarly:
#   - if src/bin/${EFL_LIB_CURRENT}/CMakeLists.txt exist, then use
#     variables as documented in EFL_BIN() or EFL_TEST().  The target
#     will be called ${EFL_LIB_CURRENT}-bin or ${EFL_LIB_CURRENT}-test
#     and the test OUTPUT_NAME defaults to ${EFL_LIB_CURRENT}_suite.
#   - otherwise loop for directories in src/bin/${EFL_LIB_CURRENT} and
#     for each src/bin/${EFL_LIB_CURRENT}/${Entry}/CMakeLists.txt use
#     variables as documented in EFL_BIN() or EFL_TEST().  Binaries
#     must provide an unique name that will be used as both target and
#     OUTPUT_NAME. Tests will generate targets
#     ${EFL_LIB_CURRENT}-test-${Entry}, while OUTPUT_NAME is ${Entry}.
#
# NOTE: src/modules/${EFL_LIB_CURRENT}/CMakeLists.txt is not
#       allowed as it makes no sense to have a single module named
#       after the library.
#
function(EFL_LIB _target)
  set(EFL_LIB_CURRENT ${_target})
  set(EFL_LIB_SOURCE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/src/lib/${_target})
  set(EFL_LIB_BINARY_DIR ${CMAKE_CURRENT_BINARY_DIR}/src/lib/${_target})
  set(EFL_BIN_SOURCE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/src/bin/${_target})
  set(EFL_BIN_BINARY_DIR ${CMAKE_CURRENT_BINARY_DIR}/src/bin/${_target})
  set(EFL_MODULES_SOURCE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/src/modules/${_target})
  set(EFL_MODULES_BINARY_DIR ${CMAKE_CURRENT_BINARY_DIR}/src/modules/${_target})
  set(EFL_TESTS_SOURCE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/src/tests/${_target})
  set(EFL_TESTS_BINARY_DIR ${CMAKE_CURRENT_BINARY_DIR}/src/tests/${_target})

  set(DESCRIPTION)
  set(PKG_CONFIG_REQUIRES)
  set(PKG_CONFIG_REQUIRES_PRIVATE)
  set(INCLUDE_DIRECTORIES)
  set(SYSTEM_INCLUDE_DIRECTORIES)
  set(OUTPUT_NAME)
  set(SOURCES)
  set(PUBLIC_HEADERS)
  set(VERSION ${PROJECT_VERSION_MAJOR}.${PROJECT_VERSION_MINOR}.${PROJECT_VERSION_PATCH})
  set(SOVERSION ${PROJECT_VERSION_MAJOR})
  set(LIBRARY_TYPE SHARED)
  set(OBJECT_DEPENDS)
  set(DEPENDENCIES)
  set(LIBRARIES)
  set(PUBLIC_LIBRARIES)
  set(DEFINITIONS)

  include(${CMAKE_CURRENT_SOURCE_DIR}/cmake/config/${_target}.cmake OPTIONAL)
  include(${EFL_LIB_SOURCE_DIR}/CMakeLists.txt OPTIONAL)
  if(LIBRARY_TYPE STREQUAL SHARED AND NOT PUBLIC_HEADERS)
    message(FATAL_ERROR "Shared libraries must install public headers!")
  endif()

  #merge public eo files into sources
  set(SOURCES ${SOURCES} ${PUBLIC_EO_FILES})

  EFL_FILES_TO_ABSOLUTE(_headers ${EFL_LIB_SOURCE_DIR} ${EFL_LIB_BINARY_DIR}
    ${PUBLIC_HEADERS})
  EFL_FILES_TO_ABSOLUTE(_sources ${EFL_LIB_SOURCE_DIR} ${EFL_LIB_BINARY_DIR}
    ${SOURCES})
  EFL_FILES_TO_ABSOLUTE(_obj_deps ${EFL_LIB_SOURCE_DIR} ${EFL_LIB_BINARY_DIR}
    ${OBJECT_DEPENDS})
  EFL_FILES_TO_ABSOLUTE(_public_eo_files ${EFL_LIB_SOURCE_DIR} ${EFL_LIB_BINARY_DIR}
    ${PUBLIC_EO_FILES})

  foreach(public_eo_file ${_public_eo_files})
    get_filename_component(filename ${public_eo_file} NAME)
    list(APPEND _headers ${EFL_LIB_BINARY_DIR}/${filename}.h)
  endforeach()

  EFL_PKG_CONFIG_EVAL(${_target} "${PKG_CONFIG_REQUIRES_PRIVATE}" "${PKG_CONFIG_REQUIRES}")


  add_library(${_target} ${LIBRARY_TYPE} ${_sources} ${_headers})
  set_target_properties(${_target} PROPERTIES
    FRAMEWORK TRUE
    PUBLIC_HEADER "${_headers}"
    OBJECT_DEPENDS "${_obj_deps}"
    COMPILE_FLAGS -DPACKAGE_DATA_DIR=\\"${CMAKE_INSTALL_FULL_DATADIR}/${_target}/\\")

  if(DEPENDENCIES)
    add_dependencies(${_target} ${DEPENDENCIES})
  endif()

  if(LIBRARIES)
    target_link_libraries(${_target} LINK_PRIVATE ${LIBRARIES})
  endif()
  if(PUBLIC_LIBRARIES)
    target_link_libraries(${_target} PUBLIC ${PUBLIC_LIBRARIES})
  endif()

  target_include_directories(${_target} PUBLIC
    ${INCLUDE_DIRECTORIES}
    ${EFL_LIB_SOURCE_DIR}
    ${EFL_LIB_BINARY_DIR}
    )
  if(SYSTEM_INCLUDE_DIRECTORIES)
    target_include_directories(${_target} SYSTEM PUBLIC ${SYSTEM_INCLUDE_DIRECTORIES})
  endif()

  if(DEFINITIONS)
    target_compile_definitions(${_target} PRIVATE ${DEFINITIONS})
  endif()

  if(OUTPUT_NAME)
    set_target_properties(${_target} PROPERTIES OUTPUT_NAME ${OUTPUT_NAME})
  endif()

  if(VERSION AND SOVERSION)
    set_target_properties(${_target} PROPERTIES
      VERSION ${VERSION}
      SOVERSION ${SOVERSION})
  endif()

  EFL_CREATE_EO_RULES(${_target} ${EFL_LIB_BINARY_DIR})

  EFL_PKG_CONFIG_LIB_WRITE()

  install(TARGETS ${_target}
    PUBLIC_HEADER DESTINATION include/${_target}-${PROJECT_VERSION_MAJOR}
    RUNTIME DESTINATION bin
    ARCHIVE DESTINATION lib
    LIBRARY DESTINATION lib)
  install(FILES
    ${_public_eo_files} DESTINATION share/eolian/include/${_target}-${PROJECT_VERSION_MAJOR}
    )
  # do not leak those into binaries, modules or tests
  unset(_sources)
  unset(_headers)
  unset(_obj_deps)
  unset(INCLUDE_DIRECTORIES)
  unset(SYSTEM_INCLUDE_DIRECTORIES)
  unset(OUTPUT_NAME)
  unset(SOURCES)
  unset(PUBLIC_HEADERS)
  unset(VERSION)
  unset(SOVERSION)
  unset(LIBRARY_TYPE)
  unset(OBJECT_DEPENDS)
  unset(DEPENDENCIES)
  unset(LIBRARIES)
  unset(PUBLIC_LIBRARIES)
  unset(DEFINITIONS)
  unset(DESCRIPTION)
  unset(PKG_CONFIG_REQUIRES)
  unset(PKG_CONFIG_REQUIRES_PRIVATE)

  _EFL_LIB_PROCESS_BINS_INTERNAL()
  _EFL_LIB_PROCESS_MODULES_INTERNAL()
  _EFL_LIB_PROCESS_TESTS_INTERNAL()

  LIST_APPEND_GLOBAL(EFL_ALL_LIBS ${_target})
endfunction()

# EFL_BIN(Name)
#
# Adds a binary (executable) for ${EFL_LIB_CURRENT} using
# ${EFL_BIN_SOURCE_DIR} and ${EFL_BIN_BINARY_DIR}
#
# Settings:
#  - INCLUDE_DIRECTORIES: results in target_include_directories
#  - SYSTEM_INCLUDE_DIRECTORIES: results in target_include_directories(SYSTEM)
#  - OUTPUT_NAME
#  - SOURCES
#  - OBJECT_DEPENDS: say this object depends on other files (ie: includes)
#  - DEPENDENCIES: results in add_dependencies(), defaults to
#    ${EFL_LIB_CURRENT}-modules
#  - LIBRARIES: results in target_link_libraries()
#  - DEFINITIONS: target_compile_definitions()
#  - INSTALL_DIR: defaults to bin. If empty, won't install.
#
# NOTE: it's meant to be called by files included by EFL_LIB() or similar,
# otherwise you need to prepare the environment yourself.
function(EFL_BIN _binname)
  set(INCLUDE_DIRECTORIES)
  set(SYSTEM_INCLUDE_DIRECTORIES)
  set(OUTPUT_NAME ${_binname})
  set(SOURCES)
  set(OBJECT_DEPENDS)
  if(TARGET ${EFL_LIB_CURRENT}-modules)
    set(DEPENDENCIES ${EFL_LIB_CURRENT}-modules)
  else()
    set(DEPENDENCIES)
  endif()
  set(LIBRARIES)
  set(DEFINITIONS)
  set(INSTALL ON)
  set(INSTALL_DIR bin)

  if(_binname STREQUAL ${EFL_LIB_CURRENT})
    set(_binsrcdir "${EFL_BIN_SOURCE_DIR}")
    set(_binbindir "${EFL_BIN_BINARY_DIR}")
    set(_bintarget "${EFL_LIB_CURRENT}-bin") # otherwise target would exist
  else()
    set(_binsrcdir "${EFL_BIN_SOURCE_DIR}/${_binname}")
    set(_binbindir "${EFL_BIN_BINARY_DIR}/${_binname}")
    set(_bintarget "${_binname}")
  endif()

  _EFL_INCLUDE_OR_DETECT("Binary ${_bintarget}" ${_binsrcdir})

  if(NOT SOURCES)
    message(WARNING "${_binsrcdir}/CMakeLists.txt defines no SOURCES")
    return()
  endif()
  if(PUBLIC_HEADERS)
    message(WARNING "${_binsrcdir}/CMakeLists.txt should not define PUBLIC_HEADERS, it's not to be installed.")
  endif()

  EFL_FILES_TO_ABSOLUTE(_sources ${_binsrcdir} ${_binbindir} ${SOURCES})
  EFL_FILES_TO_ABSOLUTE(_obj_deps ${_binsrcdir} ${_binbindir} ${OBJECT_DEPENDS})

  add_executable(${_bintarget} ${_sources})

  if(_obj_deps)
    set_target_properties(${_bintarget} PROPERTIES
      OBJECT_DEPENDS "${_obj_deps}")
  endif()

  if(DEPENDENCIES)
    add_dependencies(${_bintarget} ${DEPENDENCIES})
  endif()

  target_include_directories(${_bintarget} PRIVATE
    ${_binrcdir}
    ${_binbindir}
    ${INCLUDE_DIRECTORIES})
  if(SYSTEM_INCLUDE_DIRECTORIES)
    target_include_directories(${_bintarget} SYSTEM PRIVATE
      ${SYSTEM_INCLUDE_DIRECTORIES})
  endif()
  target_link_libraries(${_bintarget} LINK_PRIVATE
    ${EFL_LIB_CURRENT}
    ${LIBRARIES})

  if(DEFINITIONS)
    target_compile_definitions(${_bintarget} PRIVATE ${DEFINITIONS})
  endif()

  if(OUTPUT_NAME)
    set_target_properties(${_bintarget} PROPERTIES OUTPUT_NAME ${OUTPUT_NAME})
  endif()

  if(INSTALL_DIR)
    install(TARGETS ${_bintarget} RUNTIME DESTINATION ${INSTALL_DIR})
  endif()
endfunction()

# EFL_TEST(Name)
#
# Adds a test for ${EFL_LIB_CURRENT} using
# ${EFL_TESTS_SOURCE_DIR} and ${EFL_TESTS_BINARY_DIR}
#
# Settings:
#  - INCLUDE_DIRECTORIES: results in target_include_directories
#  - SYSTEM_INCLUDE_DIRECTORIES: results in target_include_directories(SYSTEM)
#  - OUTPUT_NAME
#  - SOURCES
#  - OBJECT_DEPENDS: say this object depends on other files (ie: includes)
#  - DEPENDENCIES: results in add_dependencies(), defaults to
#    ${EFL_LIB_CURRENT}-modules
#  - LIBRARIES: results in target_link_libraries()
#  - DEFINITIONS: target_compile_definitions()
#
# NOTE: it's meant to be called by files included by EFL_LIB() or similar,
# otherwise you need to prepare the environment yourself.
function(EFL_TEST _testname)
  if(NOT CHECK_FOUND)
    message(STATUS "${EFL_LIB_CURRENT} test ${_testname} ignored since no 'check' library was found.")
    return()
  endif()

  set(INCLUDE_DIRECTORIES)
  set(SYSTEM_INCLUDE_DIRECTORIES)
  set(OUTPUT_NAME ${_testname})
  set(SOURCES)
  set(OBJECT_DEPENDS)
  if(TARGET ${EFL_LIB_CURRENT}-modules)
    set(DEPENDENCIES ${EFL_LIB_CURRENT}-modules)
  else()
    set(DEPENDENCIES)
  endif()
  set(LIBRARIES)
  set(DEFINITIONS)

  if(_testname STREQUAL ${EFL_LIB_CURRENT})
    set(_testsrcdir "${EFL_TESTS_SOURCE_DIR}")
    set(_testbindir "${EFL_TESTS_BINARY_DIR}")
    set(_testtarget "${EFL_LIB_CURRENT}-test") # otherwise target would exist
    set(OUTPUT_NAME "${EFL_LIB_CURRENT}_suite") # backward compatible
  else()
    set(_testsrcdir "${EFL_TESTS_SOURCE_DIR}/${_testname}")
    set(_testbindir "${EFL_TESTS_BINARY_DIR}/${_testname}")
    set(_testtarget "${EFL_LIB_CURRENT}-test-${_testname}")
  endif()

  _EFL_INCLUDE_OR_DETECT("Test ${_testtarget}" ${_testsrcdir})

  if(NOT SOURCES)
    message(WARNING "${_testsrcdir}/CMakeLists.txt defines no SOURCES")
    return()
  endif()
  if(PUBLIC_HEADERS)
    message(WARNING "${_testsrcdir}/CMakeLists.txt should not define PUBLIC_HEADERS, it's not to be installed.")
  endif()

  EFL_FILES_TO_ABSOLUTE(_sources ${_testsrcdir} ${_testbindir} ${SOURCES})
  EFL_FILES_TO_ABSOLUTE(_obj_deps ${_testsrcdir} ${_testbindir} ${OBJECT_DEPENDS})

  add_executable(${_testtarget} EXCLUDE_FROM_ALL ${_sources})

  if(_obj_deps)
    set_target_properties(${_testtarget} PROPERTIES
      OBJECT_DEPENDS "${_obj_deps}")
  endif()

  if(DEPENDENCIES)
    add_dependencies(${_testtarget} ${DEPENDENCIES})
  endif()

  target_include_directories(${_testtarget} PRIVATE
    ${_testrcdir}
    ${_testbindir}
    ${INCLUDE_DIRECTORIES})
  target_include_directories(${_testtarget} SYSTEM PRIVATE
    ${SYSTEM_INCLUDE_DIRECTORIES}
    ${CHECK_INCLUDE_DIRS})
  target_link_libraries(${_testtarget} LINK_PRIVATE
    ${EFL_LIB_CURRENT}
    ${LIBRARIES}
    ${CHECK_LIBRARIES})

  target_compile_definitions(${_testtarget} PRIVATE
    "-DPACKAGE_DATA_DIR=\"${EFL_TESTS_SOURCE_DIR}\""
    "-DTESTS_SRC_DIR=\"${_testrcdir}\""
    "-DTESTS_BUILD_DIR=\"${_testbindir}\""
    "-DTESTS_WD=\"${PROJECT_BINARY_DIR}\""
    ${DEFINITIONS}
    )

  if(OUTPUT_NAME)
    set_target_properties(${_testtarget} PROPERTIES OUTPUT_NAME ${OUTPUT_NAME})
  endif()

  set_target_properties(${_testtarget} PROPERTIES
    LIBRARY_OUTPUT_DIRECTORY "${_testbindir}"
    RUNTIME_OUTPUT_DIRECTORY "${_testbindir}")

  add_test(NAME ${_testname} COMMAND ${_testtarget})
  LIST_APPEND_GLOBAL(${EFL_LIB_CURRENT}_TESTS ${_testtarget})

  add_test(${_testname}-build "${CMAKE_COMMAND}" --build ${CMAKE_BINARY_DIR} --target ${_testtarget})
  set_tests_properties(${_testname} PROPERTIES DEPENDS ${_testname}-build)
endfunction()

# EFL_MODULE(Name)
#
# Adds a module for ${EFL_LIB_CURRENT} using
# ${EFL_MODULES_SOURCE_DIR} and ${EFL_MODULES_BINARY_DIR}
# as well as ${EFL_MODULE_SCOPE} if it's contained into
# a subdir, such as eina's "mp" or evas "engines".
#
# To keep it simple to use, user is only expected to define variables:
#  - SOURCES
#  - OBJECT_DEPENDS
#  - LIBRARIES
#  - INCLUDE_DIRECTORIES
#  - SYSTEM_INCLUDE_DIRECTORIES
#  - DEFINITIONS
#  - MODULE_TYPE: one of ON;OFF;STATIC, defaults to ON
#  - INSTALL_DIR: defaults to
#    lib/${EFL_LIB_CURRENT}/modules/${EFL_MODULE_SCOPE}/${Name}/v-${PROJECT_VERSION_MAJOR}.${PROJECT_VERSION_MINOR}/.
#    If empty, won't install.
#
# NOTE: since the file will be included it shouldn't mess with global variables!
function(EFL_MODULE _modname)
  if(EFL_MODULE_SCOPE)
    set(_modsrcdir ${EFL_MODULES_SOURCE_DIR}/${EFL_MODULE_SCOPE}/${_modname})
    set(_modoutdir lib/${EFL_LIB_CURRENT}/modules/${EFL_MODULE_SCOPE}/${_modname}/v-${PROJECT_VERSION_MAJOR}.${PROJECT_VERSION_MINOR})
    set(_modbindir ${EFL_MODULES_BINARY_DIR}/${EFL_MODULE_SCOPE}/${_modname})
    set(_modtarget ${EFL_LIB_CURRENT}-module-${EFL_MODULE_SCOPE}-${_modname})
    string(TOUPPER "${EFL_LIB_CURRENT}_MODULE_TYPE_${EFL_MODULE_SCOPE}_${_modname}" _modoptionname)
    if(NOT ${_modoptionname}_DEFAULT)
      set(${_modoptionname}_DEFAULT "ON")
    endif()
    EFL_OPTION(${_modoptionname} "Build ${EFL_LIB_CURRENT} module ${EFL_MODULE_SCOPE}/${_modname}" ${${_modoptionname}_DEFAULT} CHOICE ON;OFF;STATIC)
  else()
    set(_modsrcdir ${EFL_MODULES_SOURCE_DIR}/${_modname})
    set(_modoutdir lib/${EFL_LIB_CURRENT}/modules/${_modname}/v-${PROJECT_VERSION_MAJOR}.${PROJECT_VERSION_MINOR})
    set(_modbindir ${EFL_MODULES_BINARY_DIR}/${_modname})
    set(_modtarget ${EFL_LIB_CURRENT}-module-${_modname})
    string(TOUPPER "${EFL_LIB_CURRENT}_MODULE_TYPE_${_modname}" _modoptionname)
    if(NOT ${_modoptionname}_DEFAULT)
      set(${_modoptionname}_DEFAULT "ON")
    endif()
    EFL_OPTION(${_modoptionname} "Build ${EFL_LIB_CURRENT} module ${_modname}" ${${_modoptionname}_DEFAULT} CHOICE ON;OFF;STATIC)
  endif()

  set(SOURCES)
  set(OBJECT_DEPENDS)
  set(LIBRARIES)
  set(INCLUDE_DIRECTORIES)
  set(SYSTEM_INCLUDE_DIRECTORIES)
  set(DEFINITIONS)
  set(MODULE_TYPE "${${_modoptionname}}")
  set(INSTALL_DIR ${_modoutdir})

  _EFL_INCLUDE_OR_DETECT("Module ${_modtarget}" ${_modsrcdir})

  if(NOT SOURCES)
    message(WARNING "${_modsrcdir}/CMakeLists.txt defines no SOURCES")
    return()
  endif()
  if(PUBLIC_HEADERS)
    message(WARNING "${_modsrcdir}/CMakeLists.txt should not define PUBLIC_HEADERS, it's not to be installed.")
  endif()

  if("${MODULE_TYPE}" STREQUAL "OFF")
    return()
  elseif("${MODULE_TYPE}" STREQUAL "STATIC")
    set(_modtype STATIC)
  else()
    set(_modtype MODULE)
  endif()

  EFL_FILES_TO_ABSOLUTE(_sources ${_modsrcdir} ${_modbindir} ${SOURCES})
  EFL_FILES_TO_ABSOLUTE(_obj_deps ${_modsrcdir} ${_modbindir} ${OBJECT_DEPENDS})

  add_library(${_modtarget} ${_modtype} ${_sources})
  set_target_properties(${_modtarget} PROPERTIES
    OBJECT_DEPENDS "${_obj_deps}"
    PREFIX ""
    OUTPUT_NAME "module")

  target_include_directories(${_modtarget} PRIVATE
    ${_modsrcdir}
    ${_modbindir}
    ${INCLUDE_DIRECTORIES})
  target_include_directories(${_modtarget} SYSTEM PUBLIC
    ${SYSTEM_INCLUDE_DIRECTORIES})
  target_link_libraries(${_modtarget} LINK_PRIVATE ${LIBRARIES})

  target_compile_definitions(${_modtarget} PRIVATE ${DEFINITIONS})

  set_target_properties(${_modtarget} PROPERTIES
    LIBRARY_OUTPUT_DIRECTORY "${_modoutdir}"
    ARCHIVE_OUTPUT_DIRECTORY "${_modoutdir}"
    RUNTIME_OUTPUT_DIRECTORY "${_modoutdir}")

  if("${MODULE_TYPE}" STREQUAL "STATIC")
    target_link_libraries(${EFL_LIB_CURRENT} LINK_PRIVATE ${_modtarget})
    target_compile_definitions(${EFL_LIB_CURRENT} PRIVATE "-D${_modoptionname}_STATIC=1")
    target_include_directories(${_modtarget} PRIVATE
      ${EFL_LIB_SOURCE_DIR}
      ${EFL_LIB_BINARY_DIR})
    set_target_properties(${_modtarget} PROPERTIES
      POSITION_INDEPENDENT_CODE TRUE)

    LIST_APPEND_GLOBAL(${EFL_LIB_CURRENT}_STATIC_MODULES ${_modtarget})
  else()
    target_link_libraries(${_modtarget} LINK_PRIVATE ${EFL_LIB_CURRENT})
    target_compile_definitions(${EFL_LIB_CURRENT} PRIVATE "-D${_modoptionname}_DYNAMIC=1")
    LIST_APPEND_GLOBAL(${EFL_LIB_CURRENT}_MODULES ${_modtarget})
    if(INSTALL_DIR)
      install(TARGETS ${_modtarget} LIBRARY DESTINATION "${INSTALL_DIR}")
    endif()
  endif()
endfunction()

macro(EFL_PROJECT version)
  if ("${CMAKE_BUILD_TYPE}" STREQUAL "Release")
      project(efl VERSION ${version})
  else ("${CMAKE_BUILD_TYPE}" STREQUAL "Release")
    execute_process(
      COMMAND git rev-list --count HEAD
      WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}
      OUTPUT_VARIABLE GIT_VERSION
      OUTPUT_STRIP_TRAILING_WHITESPACE
    )
    project(efl VERSION ${version}.${GIT_VERSION})
  endif ("${CMAKE_BUILD_TYPE}" STREQUAL "Release")
  message("VERSION ${PROJECT_VERSION}")
endmacro()

# Will use the source of the given target to create rules for creating
# the .eo.c and .eo.h files. The INCLUDE_DIRECTORIES of the target will be used
function(EFL_CREATE_EO_RULES target generation_dir)
   get_target_property(build_files ${target} SOURCES)
   get_target_property(_link_libraries ${target} LINK_LIBRARIES)
   #build a list of targets we use to scan for all files
   list(APPEND _include_targets ${target})
   foreach(lib ${_link_libraries})
     if (TARGET ${lib})
        list(APPEND _include_targets ${lib})
     endif()
   endforeach()

   #build a list of include directories
   foreach(link_target ${_include_targets})
     list(APPEND include_cmd -I${CMAKE_SOURCE_DIR}/src/lib/${link_target})
   endforeach()

   foreach(file ${build_files})
      get_filename_component(ext ${file} EXT)
      get_filename_component(filename ${file} NAME)

      if (${ext} MATCHES "^\\.eo$")
         set(build_files ${EFL_LIB_BINARY_DIR}/${filename}.c ${EFL_LIB_BINARY_DIR}/${filename}.h)
         set(create_rule ON)
      elseif (${ext} MATCHES "^\\.eot$")
         set(build_files ${EFL_LIB_BINARY_DIR}/${filename}.h)
         set(create_rule ON)
      endif()

      #add the custom rule
      if (create_rule)
        add_custom_command(
           OUTPUT ${build_files}
           COMMAND ${CMAKE_COMMAND} -E env "EFL_RUN_IN_TREE=1" ${EOLIAN_BIN} ${include_cmd} -o c:${EFL_LIB_BINARY_DIR}/${filename}.c -o h:${EFL_LIB_BINARY_DIR}/${filename}.h ${file}
           DEPENDS ${file}
        )
        unset(create_rule)
        list(APPEND eo_gen_files ${build_files})
      endif()
    endforeach()
    if(eo_gen_files)
      file(MAKE_DIRECTORY ${EFL_LIB_BINARY_DIR})
      add_custom_target(${target}-eo
        DEPENDS ${eo_gen_files}
      )
      add_dependencies(${target} ${target}-eo)
      add_dependencies(${target}-eo eolian-bin)
    endif()
endfunction()
