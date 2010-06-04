#!/bin/sh

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

mk_mkdir "`dirname "$object"`"

{
    mk_quote "${_ALL_OBJECTS# }"
    echo "OBJECTS=$result"
    mk_quote "${_ALL_LIBDEPS# }"
    echo "LIBDEPS=$result"
    mk_quote "${_ALL_LIBDIRS# }"
    echo "LIBDIRS=$result"
    mk_quote "${_ALL_LDFLAGS# }"
    echo "LDFLAGS=$result"
} > ${object} || mk_fail "Could not write group: ${object}"
