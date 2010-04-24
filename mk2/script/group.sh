#!/bin/sh

. "${MK_HOME}/mk.sh" || exit 1
. "${MK_ROOT_DIR}/.MetaKitExports" || mk_fail "Could not read .MetaKitExports"

mk_parse_params

object="$1"
shift 1

_ALL_OBJECTS="$*"
_ALL_LIBDEPS="$LIBDEPS"
_ALL_LIBDIRS="$LIBDIRS"
_ALL_LDFLAGS="$LDFLAGS"

MK_MSG_DOMAIN="group"

mk_msg "${object#${MK_OBJECT_DIR}/}"

for _group in ${GROUPDEPS}
do
    mk_safe_source "${MK_OBJECT_DIR}${MK_SUBDIR}/${_group}" || mk_fail "Could not read group: $_group"
    _ALL_OBJECTS="$_ALL_OBJECTS $OBJECTS"
    _ALL_LIBDEPS="$_ALL_LIBDEPS $LIBDEPS"
    _ALL_LIBDIRS="$_ALL_LIBDIRS $LIBDIRS"
    _ALL_LDFLAGS="$_ALL_LDFLAGS $LDFLAGS"
done

_mk_try mkdir -p "`dirname "$object"`"

{
    echo "OBJECTS=`mk_quote "${_ALL_OBJECTS# }"`"
    echo "LIBDEPS=`mk_quote "${_ALL_LIBDEPS# }"`"
    echo "LIBDIRS=`mk_quote "${_ALL_LIBDIRS# }"`"
    echo "LDFLAGS=`mk_quote "${_ALL_LDFLAGS# }"`"
} > ${object} || mk_fail "Could not write group: ${object}"
