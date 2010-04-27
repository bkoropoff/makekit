#!/bin/sh

. "${MK_HOME}/mk.sh" || exit 1
mk_import

mk_parse_params

_stamp="$1"
shift

MK_MSG_DOMAIN="configure"

mk_msg "$SOURCEDIR"

mk_mkdir "${MK_OBJECT_DIR}${MK_SUBDIR}/${SOURCEDIR}"
mk_mkdir "${MK_STAGE_DIR}"

_src_dir="`cd ${MK_SOURCE_DIR}${MK_SUBDIR}/${SOURCEDIR} && pwd`"
_stage_dir="`cd ${MK_STAGE_DIR} && pwd`"
_include_dir="${_stage_dir}${MK_INCLUDE_DIR}"
_lib_dir="${_stage_dir}${MK_LIBDIR}"

cd "${MK_OBJECT_DIR}${MK_SUBDIR}/${SOURCEDIR}" && \
_mk_try "${_src_dir}/configure" \
    CPPFLAGS="-I${_include_dir} $CPPFLAGS" \
    CFLAGS="$CFLAGS" \
    LDFLAGS="-L${_lib_dir} $LDFLAGS" \
    --prefix="${MK_PREFIX}" \
    --libdir="${MK_LIBDIR}" \
    --bindir="${MK_BINDIR}" \
    --sbindir="${MK_SBINDIR}" \
    --sysconfdir="${MK_SYSCONFDIR}" \
    --localstatedir="${MK_LOCALSTATEDIR}" \
    "$@"
cd "${MK_ROOT_DIR}" && _mk_try touch "$_stamp"
