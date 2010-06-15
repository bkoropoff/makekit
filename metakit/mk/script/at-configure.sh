#!/bin/sh

_stamp="$1"
shift

MK_MSG_DOMAIN="configure"
__msg="${MK_SUBDIR}/$SOURCEDIR ($MK_SYSTEM)"

mk_msg "begin ${__msg#/}"

mk_mkdir "${MK_OBJECT_DIR}${MK_SUBDIR}/$DIR"
mk_mkdir "${MK_STAGE_DIR}"

if [ "${MK_SYSTEM%/*}" = "build" ]
then
    _prefix="$MK_ROOT_DIR/$MK_RUN_PREFIX"
    _includedir="$MK_ROOT_DIR/$MK_RUN_INCLUDEDIR"
    _libdir="$MK_ROOT_DIR/$MK_RUN_LIBDIR"
    _bindir="$MK_ROOT_DIR/$MK_RUN_BINDIR"
    _sbindir="$MK_ROOT_DIR/$MK_RUN_SBINDIR"
    _sysconfdir="$MK_ROOT_DIR/$MK_RUN_SYSCONFDIR"
    _localstatedir="$MK_ROOT_DIR/$MK_RUN_LOCALSTATEDIR"
else
    _prefix="$MK_PREFIX"
    _includedir="$MK_INCLUDEDIR"
    _libdir="$MK_LIBDIR"
    _bindir="$MK_BINDIR"
    _sbindir="$MK_SBINDIR"
    _sysconfdir="$MK_SYSCONFDIR"
    _localstatedir="$MK_LOCALSTATEDIR"
fi

_src_dir="`cd ${MK_SOURCE_DIR}${MK_SUBDIR}/${SOURCEDIR} && pwd`"
_stage_dir="`cd ${MK_STAGE_DIR} && pwd`"
_include_dir="${_stage_dir}${_includedir}"
_lib_dir="${_stage_dir}${_libdir}"

cd "${MK_OBJECT_DIR}${MK_SUBDIR}/$DIR" && \
mk_run_or_fail "${_src_dir}/configure" \
    CC="$_cc" \
    CPPFLAGS="-I${_include_dir} $_cppflags $CPPFLAGS" \
    CFLAGS="$MK_CFLAGS $CFLAGS" \
    LDFLAGS="-L${_lib_dir} $MK_LDFLAGS $LDFLAGS" \
    --build="${MK_AT_BUILD_STRING}" \
    --host="${MK_AT_HOST_STRING}" \
    --prefix="${_prefix}" \
    --libdir="${_libdir}" \
    --bindir="${_bindir}" \
    --sbindir="${_sbindir}" \
    --sysconfdir="${_sysconfdir}" \
    --localstatedir="${_localstatedir}" \
    "$@"
cd "${MK_ROOT_DIR}" && mk_run_or_fail touch "$_stamp"
mk_msg "end ${__msg#/}"