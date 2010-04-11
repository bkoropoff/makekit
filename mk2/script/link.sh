#!/bin/sh

. "${MK_HOME}/mk.sh" || exit 1
. "${MK_ROOT_DIR}/.MetaKitExports" || mk_fail "Could not read .MetaKitExports"

_mk_args

object="$1"
shift 1

STAGE_LIB_DIR="${MK_STAGE_DIR}${MK_LIB_DIR}"
EXTRA_LDFLAGS="-fPIC -L${STAGE_LIB_DIR}"

case "${MK_OS}" in
    linux)
	EXTRA_LDFLAGS="$EXTRA_LDFLAGS -Wl,-rpath,${MK_LIB_DIR} -Wl,-rpath-link,${STAGE_LIB_DIR}"
	;;
esac

for lib in ${LIBS}
do
    LIB_LDFLAGS="$LIB_LDFLAGS -l${lib}"
done

MK_LOG_DOMAIN="link"

mk_log "${object#${MK_STAGE_DIR}}"
_mk_try mkdir -p "`dirname "$object"`"
case "$MODE" in
    library)
	_mk_try ${MK_CC} -shared -o "$object" "$@" ${MK_LDFLAGS} ${LDFLAGS} ${LIB_LDFLAGS} ${EXTRA_LDFLAGS}
	;;
    program)
	_mk_try ${MK_CC} -o "$object" "$@" ${MK_LDFLAGS} ${LDFLAGS} ${LIB_LDFLAGS} ${EXTRA_LDFLAGS}
	;;
esac
