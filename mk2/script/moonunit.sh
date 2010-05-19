#!/bin/sh

case "${MK_OS}" in
    linux)
	_libpath_var="LD_LIBRARY_PATH"
	;;
    *)
	_libpath_var="LD_LIBRARY_PATH"
	;;
esac

set -x
_mk_set "$_libpath_var" "${MK_STAGE_DIR}${MK_LIBDIR}"
export "$_libpath_var"
set +x

MK_MSG_DOMAIN="test"

mk_msg "moonunit"
moonunit "$@" || mk_fail "unit tests failed"
