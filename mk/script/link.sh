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

combine_libtool_flags()
{
    for _lib in ${COMBINED_LIBDEPS}
    do
        for _path in ${COMBINED_LDFLAGS} ${MK_LDFLAGS} -L/usr/lib -L/lib
        do
            case "$_path" in
                "-L"*)
                    if [ -e "${_path#-L}/lib${_lib}.la" ]
                    then
                        unset dependency_libs
                        mk_safe_source "${_path#-L}/lib${_lib}.la" || mk_fail "could not read libtool archive"
                        for _dep in ${dependency_libs}
                        do
                            case "$_dep" in
                                "${MK_LIBDIR}"/*.la)
                                    _dep="${_dep##*/}"
                                    _dep="${_dep#lib}"
                                    _mk_contains "${_dep%.la}" ${COMBINED_LIBDEPS} ||
                                    COMBINED_LIBDEPS="${COMBINED_LIBDEPS} ${_dep%.la}" 
                                    ;;
                                "-l"*)
                                    _mk_contains "${_dep#-l}" ${COMBINED_LIBDEPS} ||
                                    COMBINED_LIBDEPS="${COMBINED_LIBDEPS} ${_dep#-l}"
                                    ;;
                                "-L${MK_LIBDIR}")
                                    continue
                                    ;;
                                "-L"*)
                                    _mk_contains "${_dep}" ${COMBINED_LDFLAGS} ||
                                    COMBINED_LDFLAGS="$COMBINED_LDFLAGS $_dep"
                                    ;;
                            esac
                        done
                        break
                    fi
                    ;;
            esac
        done
    done
}

create_libtool_archive()
{
    # Create a fake .la file that can be used by combine_libtool_flags
    # This should be expanded upon for full compatibility with libtool
    {
        mk_quote "-L${RPATH_LIBDIR} $_LIBS"
        echo "# Created by MakeKit"
        echo "dependency_libs=$result"
    } > "$object" || mk_fail "could not write $object"
}

object="$1"
shift 1

IS_CXX=false

[ "$COMPILER" = "c++" ] && IS_CXX=true

if [ "${MK_SYSTEM%/*}" = "build" ]
then
    LINK_LIBDIR="$MK_RUN_LIBDIR"
    RPATH_LIBDIR="$MK_ROOT_DIR/$MK_RUN_LIBDIR"
else
    RPATH_LIBDIR="$MK_LIBDIR"
    mk_resolve_file "$MK_LIBDIR"
    LINK_LIBDIR="$result"
fi

COMBINED_LIBDEPS="$LIBDEPS"
COMBINED_LDFLAGS="$LDFLAGS"
COMBINED_LIBDIRS="$LIBDIRS"

[ -d "$LINK_LIBDIR" ] && COMBINED_LDFLAGS="$COMBINED_LDFLAGS -L${LINK_LIBDIR}"

# SONAME
if [ -n "$SONAME" ]
then
    case "$MK_OS" in
        darwin)
            COMBINED_LDFLAGS="$COMBINED_LDFLAGS -install_name ${MK_LIBDIR}/${SONAME}"
            ;;
        *)
            COMBINED_LDFLAGS="$COMBINED_LDFLAGS -Wl,-h,$SONAME"
            ;;
    esac
fi

# Group suffix
_gsuffix=".${MK_CANONICAL_SYSTEM%/*}.${MK_CANONICAL_SYSTEM#*/}.og"

for _group in ${GROUPS}
do
    unset OBJECTS LIBDEPS LIBDIRS LDFLAGS
    mk_safe_source "${MK_OBJECT_DIR}${MK_SUBDIR}/$_group${_gsuffix}" || mk_fail "Could not read group $_group"

    GROUP_OBJECTS="$GROUP_OBJECTS ${OBJECTS}"
    COMBINED_LIBDEPS="$COMBINED_LIBDEPS $LIBDEPS"
    COMBINED_LIBDIRS="$COMBINED_LIBDIRS $LIBDIRS"
    COMBINED_LDFLAGS="$COMBINED_LDFLAGS $LDFLAGS"
    [ "$COMPILER" = "c++" ] && IS_CXX=true
done

${IS_CXX} && COMPILER="c++"

case "$COMPILER" in
    c)
        CPROG="$MK_CC"
        LD_STYLE="$MK_CC_LD_STYLE"
        ;;
    c++)
        CPROG="$MK_CXX"
        LD_STYLE="$MK_CXX_LD_STYLE"
        ;;
esac

case "${MK_OS}:${LD_STYLE}" in
    *:gnu)
        DLO_LINK="-shared"
        LIB_LINK="-shared"
        COMBINED_LDFLAGS="$COMBINED_LDFLAGS -Wl,-rpath,${RPATH_LIBDIR} -Wl,-rpath-link,${LINK_LIBDIR}"
        ;;
    solaris:native)
        DLO_LINK="-shared"
        LIB_LINK="-shared"
        COMBINED_LDFLAGS="$COMBINED_LDFLAGS -R${RPATH_LIBDIR}"
        
        if [ "$MODE" = "library" ]
        then
            COMBINED_LDFLAGS="$COMBINED_LDFLAGS -Wl,-z,defs -Wl,-z,text"
            COMBINED_LIBDEPS="$COMBINED_LIBDEPS c"
        fi

        # The solaris linker is anal retentive about implicit shared library dependencies,
        # so use available libtool .la files to add implicit dependencies to the link command
        combine_libtool_flags
        ;;
    darwin:native)
        DLO_LINK="-bundle"
        LIB_LINK="-dynamiclib"
        COMBINED_LDFLAGS="$COMBINED_LDFLAGS -Wl,-undefined -Wl,dynamic_lookup -Wl,-single_module -Wl,-arch_errors_fatal"
        ;;
esac

for lib in ${COMBINED_LIBDEPS}
do
    _LIBS="$_LIBS -l${lib}"
done

[ "${object%/*}" != "${object}" ] && mk_mkdir "${object%/*}"

case "$MODE" in
    library)
        mk_msg_domain "link"
        mk_msg "${object#${MK_STAGE_DIR}} ($MK_CANONICAL_SYSTEM)"
        mk_run_or_fail ${CPROG} ${LIB_LINK} -o "$object" "$@" ${GROUP_OBJECTS} ${COMBINED_LDFLAGS} ${MK_LDFLAGS} -fPIC ${_LIBS}
        ;;
    dlo)
        mk_msg_domain "link"
        mk_msg "${object#${MK_STAGE_DIR}} ($MK_CANONICAL_SYSTEM)"
        mk_run_or_fail ${CPROG} ${DLO_LINK} -o "$object" "$@" ${GROUP_OBJECTS} ${COMBINED_LDFLAGS} ${MK_LDFLAGS} -fPIC ${_LIBS}
        ;;
    program)
        mk_msg_domain "link"
        mk_msg "${object#${MK_STAGE_DIR}} ($MK_CANONICAL_SYSTEM)"
        mk_run_or_fail ${CPROG} -o "$object" "$@" ${GROUP_OBJECTS} ${COMBINED_LDFLAGS} ${MK_LDFLAGS} ${_LIBS}
        ;;
    la)
        mk_msg_domain "la"
        mk_msg "${object#${MK_STAGE_DIR}} ($MK_SYSTEM)"
        create_libtool_archive
        ;;
esac
