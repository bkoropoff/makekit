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

##
#
# doxygen.sh -- support for building doxygen documentation
#
##

DEPENDS="core"

### section configure

mk_have_doxygen()
{
    [ -n "$DOXYGEN" ]
}

mk_doxygen_html()
{
    mk_push_vars \
        INSTALLDIR="${MK_HTMLDIR}/doxygen" \
        DOXYFILE="Doxyfile" \
        HEADERDIRS \
        EXAMPLES \
        HEADERS \
        INPUT
    mk_parse_params
    
    mk_have_doxygen || mk_fail "mk_doxygen_html: doxygen is unavailable"

    mk_unquote_list "$HEADERDIRS"
    mk_get_stage_targets SELECT="*.h *.hpp" "$@"
    HEADERS="$result"

    mk_resolve_files "$EXAMPLES"
    EXAMPLES="$result"

    mk_resolve_targets "$INPUT"
    INPUT="$result"

    mk_target \
        TARGET="${INSTALLDIR}" \
        DEPS="$HEADERS $DOXYFILE" \
        _mk_doxygen_html %EXAMPLES '$@' "&$DOXYFILE" "*$HEADERS" "*$INPUT"
    
    mk_pop_vars
}

mk_check_doxygen()
{
    mk_check_program doxygen
}

### section build

_mk_doxygen_html()
{
    # $1 = installdir
    # $2 = Doxyfile
    # ... = sources
    mk_push_vars EXAMPLES
    mk_parse_params

    mk_msg_domain doxygen

    mk_msg "${1#$MK_STAGE_DIR}"

    mk_mkdir "$1"
    
    {
        cat "$2"
        echo "GENERATE_HTML = yes"
        echo "OUTPUT_DIRECTORY ="
        echo "HTML_OUTPUT = $1"
        echo "FULL_PATH_NAMES = yes"
        echo "STRIP_FROM_PATH = ${MK_STAGE_DIR}${MK_INCLUDEDIR}"
        echo "STRIP_FROM_INC_PATH = ${MK_STAGE_DIR}${MK_INCLUDEDIR}"
        echo "INPUT = "
        echo "EXAMPLE_PATH = "
        shift 2
        for header
        do
            echo "INPUT += ${header#@}"
        done

        mk_unquote_list "$EXAMPLES"
        for example
        do
            echo "EXAMPLE_PATH += $example"
        done
    } | mk_run_or_fail doxygen -

    mk_pop_vars
}
