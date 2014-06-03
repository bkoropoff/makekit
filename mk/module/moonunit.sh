#
# Copyright (c) Brian Koropoff
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#     * Redistributions of source code must retain the above copyright
#       notice, this list of conditions and the following disclaimer.
#     * Redistributions in binary form must reproduce the above copyright
#       notice, this list of conditions and the following disclaimer in the
#       documentation and/or other materials provided with the distribution.
#     * Neither the name of the MakeKit project nor the names of its
#       contributors may be used to endorse or promote products derived
#       from this software without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS ``AS IS''
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDERS OR CONTRIBUTORS
# BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
# CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
# SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
# INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
# CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
# ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF
# THE POSSIBILITY OF SUCH DAMAGE.
#

#<
# @module moonunit
# @brief Build MoonUnit tests
#
# Allows building tests using the MoonUnit test framework.
#
# To check for the availability of MoonUnit, use <funcref>mk_check_moonunit</funcref>.
# To build a test library, use <funcref>mk_moonunit</funcref>.
# When this module is included in a project, a <lit>test</lit> target is generated which
# runs all MoonUnit test libraries within the project.  Other targets which run particular
# test libraries can be manually defined with <funcref>mk_moonunit_test</funcref>.
#
# All targets which run tests accept the following parameters to <lit>make</lit>:
#
# <deflist>
#   <defentry>
#     <term><lit>TEST=</lit><param>pattern</param></term>
#     <item>
#       Passes <param>pattern</param> as the <lit>-t</lit> option of MoonUnit,
#       selecting a subset of tests to run.
#     </item>
#   </defentry>
#   <defentry>
#     <term><lit>DEBUG=</lit><param>pattern</param></term>
#     <item>
#       Similar to <lit>TEST=</lit>, but also runs the unit tests in debug mode
#       within a debugger.
#     </item>
#   </defentry>
#   <defentry>
#     <term><lit>DEBUGGER=</lit><param>command</param></term>
#     <item>
#       Use <param>command</param> as the debugger in which MoonUnit is run when
#       using the <lit>DEBUG=</lit> option.  Defaults to <lit>gdb --args</lit>.
#     </item>
#   </defentry>
#   <defentry>
#     <term><lit>LOGLEVEL=</lit><param>level</param></term>
#     <item>
#       Use <param>level</param> as the log level when running tests.
#     </item>
#   </defentry>
#   <defentry>
#     <term><lit>XML=</lit><param>file</param></term>
#     <item>
#       Outputs XML test results to <param>file</param> in addition to
#       the human-readable output written to the console.
#     </item>
#   </defentry>
#   <defentry>
#     <term><lit>HTML=</lit><param>dir</param></term>
#     <item>
#       Outputs XHTML test results to <param>dir</param> in addition to
#       the human-readable output written to the console.
#     </item>
#   </defentry>
#   <defentry>
#     <term><lit>TITLE=</lit><param>title</param></term>
#     <term><lit>RUN=</lit><param>run</param></term>
#     <item>
#       Sets the title and test run identifiers which appear in XML and HTML output.
#     </item>
#   </defentry>
# </deflist>
#>

#<
# @var MK_MOONUNIT_DIR
# @brief Unit test output directory
# @value mu The default directory name.
#
# The subdirectory of the build directory where MoonUnit unit test
# libraries are placed.
#>

DEPENDS="path compiler program"

### section build

_mk_invoke_moonunit_stub()
{
    mk_push_vars CPPFLAGS
    mk_parse_params

    MK_MSG_DOMAIN="moonunit-stub"
    __output="$1"
    shift

    mk_msg "${__output#${MK_OBJECT_DIR}/}"

    if ! ${MOONUNIT_STUB} \
        CPP="$MK_CC -E" \
        CXXCPP="$MK_CXX -E" \
        CPPFLAGS="$MK_CPPFLAGS $MK_ISA_CPPFLAGS $CPPFLAGS -I${MK_STAGE_DIR}${MK_INCLUDEDIR}" \
        -o "$__output" \
        "$@"
    then
        rm -f "$__output"
        mk_fail "moonunit-stub failed"
    fi

    mk_pop_vars
}

### section configure

#<
# @brief Build a MoonUnit test library
# @usage DLO=dlo SOURCES=sources options...
# @option DLO=dlo The name of the library
# @option SOURCES=sources The test sources
# @option ... All options applicable to <funcref>mk_dlo</funcref>.
#
# Defines a target to build a MoonUnit test library.  This function
# behaves nearly identically to <funcref>mk_dlo</funcref>, except that
# <lit>moonunit-stub</lit> is automatically invoked on the source files to
# generate a stub for the MoonUnit test loader, and <param>INSTALLDIR</param>
# defaults to <lit>@$MK_MOONUNIT_DIR</lit>.
#
# To use this function, you must use first perform a configuration check
# with <funcref>mk_check_moonunit</funcref>.  If you do not, or MoonUnit
# is not found, this function will fail.
#
# Sets <var>result</var> to the generated library file target.
#>
mk_moonunit()
{
    mk_have_moonunit || mk_fail "mk_moonunit: moonunit unavailable"

    mk_push_vars DLO SOURCES CPPFLAGS CFLAGS LDFLAGS HEADERS LIBDIRS INCLUDEDIRS LIBDEPS HEADERDEPS GROUPS DEPS
    mk_parse_params

    unset _CPPFLAGS _rsources _deps

    case "$DLO" in
        *)
            _stub="${DLO}-stub.c"
            ;;
    esac

    for _dir in ${INCLUDEDIRS}
    do
        _CPPFLAGS="$_CPPFLAGS -I${MK_SOURCE_DIR}${MK_SUBDIR}/${_dir} -I${MK_OBJECT_DIR}${MK_SUBDIR}/${_dir}"
    done

    for _header in ${HEADERDEPS}
    do
        if mk_have_internal_header "$_header"
        then
            mk_resolve_header "$_header"
            mk_append_list _deps "$result"
        fi
    done

    mk_target \
        TARGET="$_stub" \
        DEPS="$SOURCES $_deps" \
        _mk_invoke_moonunit_stub CPPFLAGS="$_CPPFLAGS $CPPFLAGS" '$@' "&$SOURCES"
    
    SOURCES="$SOURCES $_stub"

    mk_dlo \
        INSTALLDIR="@$MK_MOONUNIT_DIR" \
        DLO="$DLO" \
        SOURCES="$SOURCES" \
        HEADERS="$HEADERS" \
        CPPFLAGS="$CPPFLAGS" \
        CFLAGS="$CFLAGS" \
        LDFLAGS="$LDFLAGS" \
        LIBDIRS="$LIBDIRS" \
        INCLUDEDIRS="$INCLUDEDIRS" \
        LIBDEPS="$LIBDEPS moonunit" \
        HEADERDEPS="$HEADERDEPS" \
        GROUPS="$GROUPS" \
        DEPS="$DEPS"

    MK_MOONUNIT_TESTS="$MK_MOONUNIT_TESTS $result"

    mk_pop_vars
}

#<
# @brief Define a MoonUnit test target
# @usage NAME=name libraries...
# @option NAME=name The name of the test target
# @option HELP=help Message to display for the target when running <lit>make help</lit>
# @option libraries A list of libraries (as separate parameters) to run in target notation.
# @option LIBRARIES=libraries An alternate way to specify the libraries using an
#                             internally-quoted list.
#
# Defines a phony target with the given literal name which runs MoonUnit tests
# in the specified libraries.
#
# To use this function, you must use first perform a configuration check
# with <funcref>mk_check_moonunit</funcref>.  If you do not, or MoonUnit
# is not found, this function will fail.
#
# This function is a no-op when cross-compiling, or when the build system
# has the MoonUnit libraries, headers, and stub generator, but lacks the
# <lit>moonunit</lit> binary, as tests cannot be run in these cases.
#
# Sets <var>result</var> to the generated phony target.
#>
mk_moonunit_test()
{
    mk_push_vars LIBRARIES NAME HELP
    mk_parse_params
    mk_require_params mk_moonunit_test NAME

    mk_quote_list "$@"
    LIBRARIES="$LIBRARIES $result"

    if [ -z "$HELP" ]
    then
        HELP="Run unit tests in"
        mk_unquote_list "$LIBRARIES"
        for result
        do
            mk_basename "$result"
            result="${result%.la}"
            HELP="$HELP $result"
        done
    fi

    if [ -n "$MOONUNIT" -a "$MK_CROSS_COMPILING" = no ]
    then
        mk_phony_target \
            NAME="$NAME" \
            HELP="$HELP" \
            DEPS="$LIBRARIES" -- \
            _mk_moonunit_test \
            DEBUG='$(DEBUG)' \
            DEBUGGER='$(DEBUGGER)' \
            TEST='$(TEST)' \
            LOGLEVEL='$(LOGLEVEL)' \
            XML='$(XML)' \
            HTML='$(HTML)' \
            TITLE='$(TITLE)' \
            RUN='$(RUN)' \
            PARAMS='$(PARAMS)' \
            "*$LIBRARIES"
    else
        result=""
    fi

    mk_pop_vars
}

option()
{
    mk_option \
        OPTION="moonunit-dir" \
        VAR="MK_MOONUNIT_DIR" \
        PARAM="dir" \
        DEFAULT="mu" \
        HELP="Directory where MoonUnit tests are placed"
}

#<
# @brief Check for MoonUnit
# @usage
#
# Checks for all prerequisites necessary to build MoonUnit tests.
# You can test for the result with <funcref>mk_have_moonunit</funcref>.
#>
mk_check_moonunit()
{
    mk_check_program moonunit-stub
    mk_check_headers moonunit/moonunit.h
    mk_check_libraries moonunit
    
    if [ -n "$MOONUNIT_STUB" -a "$HAVE_MOONUNIT_MOONUNIT_H" != no -a "$HAVE_LIB_MOONUNIT" != no ]
    then
        HAVE_MOONUNIT=yes
    else
        HAVE_MOONUNIT=no
    fi
    
    mk_msg "moonunit available: $HAVE_MOONUNIT"

    mk_declare -i HAVE_MOONUNIT
}

#<
# @brief Test if MoonUnit was found
# @usage
#
# Returns <lit>0</lit> (logical true) if MoonUnit was found successfully by
# <funcref>mk_check_moonunit</funcref>, and <lit>1</lit> (logical false)
# otherwise.
#>
mk_have_moonunit()
{
    [ "$HAVE_MOONUNIT" = "yes" ]
}

configure()
{
    if [ "$MK_CROSS_COMPILING" = yes ]
    then
        mk_msg "cross compiling -- tests cannot be run"
    else
        mk_check_program moonunit
        mk_check_program moonunit-xml
    fi
}

make()
{
    if [ -n "$MK_MOONUNIT_TESTS" ]
    then
        mk_moonunit_test \
            NAME="test" \
            HELP="Run all unit tests" \
            LIBRARIES="$MK_MOONUNIT_TESTS"
        mk_add_clean_target "@${MK_MOONUNIT_DIR}"
    fi
}

### section build

_mk_moonunit_test()
{
    mk_push_vars DEBUG DEBUGGER TEST XML HTML TITLE RUN PARAMS LOGLEVEL params msg la ret
    mk_parse_params
    
    mk_msg_domain moonunit

    for la
    do
        mk_quote "${la%.la}${MK_DLO_EXT}"
        params="$params $result"
        mk_basename "$la"
        msg="$msg ${result%.la}"
    done

    if [ -n "$DEBUG" ]
    then
        [ -z "$DEBUGGER" ] && DEBUGGER="gdb --args"
        mk_quote -t "$DEBUG" -d
        params="$params $result"
    else
        DEBUGGER=""
    fi

    if [ -n "$TEST" ]
    then
        mk_quote -t "$TEST"
        params="$params $result"
    fi

    if [ -n "$HTML" ]
    then
        mk_tempfile output.xml
        XML="$result"
    fi

    [ -z "$LOGLEVEL" ] && LOGLEVEL=info

    mk_quote_list -l console:loglevel="$LOGLEVEL"
    params="$params $result"

    if [ -n "$XML" ]
    then
        [ -n "$RUN" ] && RUN=",name=$RUN"
        [ -n "$TITLE" ] && TITLE=",title=$TITLE"
        mk_quote -l xml:file="$XML$RUN$TITLE",loglevel="$LOGLEVEL"
        params="$params $result"
    fi

    if [ -n "$PARAMS" ]
    then
        params="$params $PARAMS"
    fi

    mk_msg "${msg# }"

    mk_unquote_list "$params"
    
    (
        mk_run_or_fail \
            env "$MK_LIBPATH_VAR"="${MK_STAGE_DIR}${MK_LIBDIR}" \
            ${DEBUGGER} ${MOONUNIT} "$@"
    )

    ret=$?

    if [ -n "$HTML" -a -f "$XML" ]
    then
        mk_run_or_fail ${MOONUNIT_XML} -m html -o "$HTML" "$XML"
    fi

    [ "$ret" -ne 0 ] && exit "$ret"

    mk_pop_vars
}
