#!/bin/sh

. "${MK_HOME}/mk.sh" || exit 1
. "${MK_ROOT_DIR}/.MetaKitExports" || mk_fail "Could not read .MetaKitExports"

mk_parse_params

object="$1"
shift 1

STAGE_LIB_DIR="${MK_STAGE_DIR}${MK_LIB_DIR}"

COMBINED_LIBDEPS="$LIBDEPS"
COMBINED_LDFLAGS="$LDFLAGS -L${STAGE_LIB_DIR}"
COMBINED_LIBDIRS="$LIBDIRS"

case "${MK_OS}" in
    linux)
	COMBINED_LDFLAGS="$COMBINED_LDFLAGS -Wl,-rpath,${MK_LIB_DIR} -Wl,-rpath-link,${STAGE_LIB_DIR}"
	;;
esac

for _group in ${GROUPS}
do
    unset OBJECTS LIBDEPS LIBDIRS LDFLAGS
    _dirname="`dirname "$_group"`"
    mk_safe_source "${MK_OBJECT_DIR}${MK_SUBDIR}/$_group" || mk_fail "Could not read group $_group"


    GROUP_OBJECTS="$GROUP_OBJECTS ${OBJECTS}"
    COMBINED_LIBDEPS="$COMBINED_LIBDEPS $LIBDEPS"
    COMBINED_LIBDIRS="$COMBINED_LIBDIRS $LIBDIRS"
    COMBINED_LDFLAGS="$COMBINED_LDFLAGS $LDFLAGS"
done

for lib in ${COMBINED_LIBDEPS}
do
    COMBINED_LDFLAGS="$COMBINED_LDFLAGS -l${lib}"
done

MK_MSG_DOMAIN="link"

mk_msg "${object#${MK_STAGE_DIR}}"
mk_mkdir "`dirname "$object"`"
case "$MODE" in
    library)
	_mk_try ${MK_CC} -shared -o "$object" "$@" ${GROUP_OBJECTS} ${MK_LDFLAGS} ${COMBINED_LDFLAGS} -fPIC
	;;
    dso)
	_mk_try ${MK_CC} -shared -o "$object" "$@" ${GROUP_OBJECTS} ${MK_LDFLAGS} ${COMBINED_LDFLAGS} -fPIC
	;;
    program)
	_mk_try ${MK_CC} -o "$object" "$@" ${GROUP_OBJECTS} ${MK_LDFLAGS} ${COMBINED_LDFLAGS}
	;;
esac
