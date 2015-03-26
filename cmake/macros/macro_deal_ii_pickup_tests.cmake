## ---------------------------------------------------------------------
##
## Copyright (C) 2013 by the deal.II authors
##
## This file is part of the deal.II library.
##
## The deal.II library is free software; you can use it, redistribute
## it, and/or modify it under the terms of the GNU Lesser General
## Public License as published by the Free Software Foundation; either
## version 2.1 of the License, or (at your option) any later version.
## The full text of the license can be found in the file LICENSE at
## the top level of the deal.II distribution.
##
## ---------------------------------------------------------------------

#
# A macro to set up testing and pick up all tests in the current
# subdirectory.
#
# If TEST_PICKUP_REGEX is set, only tests matching the regex will be
# processed.
#
# Furthermore, the macro sets up (if necessary) deal.II, perl, a diff tool
# and the following variables, that can be overwritten by environment or
# command line:
#
#     TEST_DIFF
#       - specifying the executable and command line of the diff command to
#         use
#
#     TEST_LIBRARIES
#     TEST_LIBRARIES_DEBUG
#     TEST_LIBRARIES_RELEASE
#       - specifying additional libraries (and targets) to link against.
#
#     TEST_TIME_LIMIT
#       - specifying the maximal wall clock time in seconds a test is
#         allowed to run
#
# Usage:
#     DEAL_II_PICKUP_TESTS()
#


#
# Two very small macros that are used below:
#

MACRO(SET_IF_EMPTY _variable)
  IF("${${_variable}}" STREQUAL "")
    SET(${_variable} ${ARGN})
  ENDIF()
ENDMACRO()

MACRO(ITEM_MATCHES _var _regex)
  SET(${_var})
  FOREACH (_item ${ARGN})
    IF("${_item}" MATCHES ${_regex})
      SET(${_var} TRUE)
      BREAK()
    ENDIF()
  ENDFOREACH()
ENDMACRO()


MACRO(DEAL_II_PICKUP_TESTS)

  IF(NOT DEAL_II_PROJECT_CONFIG_INCLUDED)
    MESSAGE(FATAL_ERROR
      "\nDEAL_II_PICKUP_TESTS can only be called in external (test sub-) "
      "projects after the inclusion of deal.IIConfig.cmake. It is not "
      "intended for internal use.\n\n"
      )
  ENDIF()

  #
  # We need perl:
  #

  FIND_PACKAGE(Perl REQUIRED)

  #
  # We need a diff tool, preferably numdiff:
  #

  FIND_PROGRAM(DIFF_EXECUTABLE
    NAMES diff
    HINTS ${DIFF_DIR}
    PATH_SUFFIXES bin
    )

  FIND_PROGRAM(NUMDIFF_EXECUTABLE
    NAMES numdiff
    HINTS ${NUMDIFF_DIR}
    PATH_SUFFIXES bin
    )

  MARK_AS_ADVANCED(DIFF_EXECUTABLE NUMDIFF_EXECUTABLE)

  SET_IF_EMPTY(TEST_DIFF "$ENV{TEST_DIFF}")
  IF("${TEST_DIFF}" STREQUAL "")
    #
    # No TEST_DIFF is set, specify one:
    #

    IF(NOT NUMDIFF_EXECUTABLE MATCHES "-NOTFOUND")
      SET(TEST_DIFF ${NUMDIFF_EXECUTABLE} -a 1e-6 -r 1e-8 -s ' \\t\\n:<>=,;')
      IF(DIFF_EXECUTABLE MATCHES "-NOTFOUND")
        SET(DIFF_EXECUTABLE ${NUMDIFF_EXECUTABLE})
      ENDIF()
    ELSEIF(NOT DIFF_EXECUTABLE MATCHES "-NOTFOUND")
      SET(TEST_DIFF ${DIFF_EXECUTABLE})
    ELSE()
      MESSAGE(FATAL_ERROR
        "Could not find diff or numdiff. One of those are required for running the testsuite.\n"
        "Please specify TEST_DIFF by hand."
        )
    ENDIF()
  ENDIF()

  SET_IF_EMPTY(TEST_TIME_LIMIT "$ENV{TEST_TIME_LIMIT}")
  SET_IF_EMPTY(TEST_TIME_LIMIT 600)

  #
  # Enable testing...
  #

  ENABLE_TESTING()

  #
  # ... and finally pick up tests:
  #

  SET_IF_EMPTY(TEST_PICKUP_REGEX "$ENV{TEST_PICKUP_REGEX}")


  GET_FILENAME_COMPONENT(_category ${CMAKE_CURRENT_SOURCE_DIR} NAME)

  SET(DEAL_II_SOURCE_DIR) # avoid a bogus warning

  FILE(GLOB _tests "*.output")
  FOREACH(_test ${_tests})
    SET(_comparison ${_test})
    GET_FILENAME_COMPONENT(_test ${_test} NAME)

    #
    # Respect TEST_PICKUP_REGEX:
    #

    IF( "${TEST_PICKUP_REGEX}" STREQUAL "" OR
        "${_category}/${_test}" MATCHES "${TEST_PICKUP_REGEX}" )
      SET(_define_test TRUE)
    ELSE()
      SET(_define_test FALSE)
    ENDIF()

    #
    # Respect compiler constraint:
    #

    STRING(REGEX MATCHALL
      "compiler=[^=]*=(on|off|yes|no|true|false)" _matches ${_test}
      )
    FOREACH(_match ${_matches})
      STRING(REGEX REPLACE
        "^compiler=([^=]*)=(on|off|yes|no|true|false)$" "\\1"
        _compiler ${_match}
        )
      STRING(REGEX MATCH "(on|off|yes|no|true|false)$" _boolean ${_match})

      IF( ( "${CMAKE_CXX_COMPILER_ID}-${CMAKE_CXX_COMPILER_VERSION}"
              MATCHES "^${_compiler}"
            AND NOT ${_boolean} )
          OR ( NOT "${CMAKE_CXX_COMPILER_ID}-${CMAKE_CXX_COMPILER_VERSION}"
                   MATCHES "^${_compiler}"
               AND ${_boolean} ) )
        SET(_define_test FALSE)
      ENDIF()
    ENDFOREACH()

    #
    # Query configuration and check whether we support it. Otherwise
    # set _define_test to FALSE:
    #

    STRING(REGEX MATCHALL
      "with_([0-9]|[a-z]|_)*=(on|off|yes|no|true|false|[0-9]+(\\.[0-9]+)*)"
      _matches ${_test}
      )

    FOREACH(_match ${_matches})
      STRING(REGEX REPLACE "^with_(([0-9]|[a-z]|_)*)=.*" "\\1" _feature ${_match})
      STRING(TOUPPER ${_feature} _feature)

      IF(NOT DEFINED DEAL_II_WITH_${_feature})
        MESSAGE(FATAL_ERROR "
Invalid feature constraint \"${_match}\" in file
\"${_comparison}\":
The feature \"DEAL_II_${_feature}\" does not exist.\n"
          )
      ENDIF()

      #
      # First process simple yes/no feature constraints:
      #
      STRING(REGEX MATCH "(on|off|yes|no|true|false)$" _boolean ${_match})
      IF(NOT "${_boolean}" STREQUAL "")
        IF( (DEAL_II_WITH_${_feature} AND NOT ${_boolean}) OR
            (NOT DEAL_II_WITH_${_feature} AND ${_boolean}) )
          SET(_define_test FALSE)
        ENDIF()
      ENDIF()

      #
      # Process version constraints:
      #
      STRING(REGEX MATCH "([0-9]+(\\.[0-9]+)*)$" _version ${_match})
      IF(NOT "${_version}" STREQUAL "")

        IF(NOT ${DEAL_II_WITH_${_feature}})
          SET(_define_test FALSE)
        ENDIF()

        IF("${DEAL_II_${_feature}_VERSION}" VERSION_LESS "${_version}")
          SET(_define_test FALSE)
        ENDIF()
      ENDIF()

    ENDFOREACH()

    IF(_define_test)
      STRING(REGEX REPLACE "\\..*" "" _test ${_test})
      DEAL_II_ADD_TEST(${_category} ${_test} ${_comparison} ${_add_output})
    ENDIF()

  ENDFOREACH()
ENDMACRO()
