#!/bin/sh

MK_MSG_DOMAIN="build"

mk_msg "$SOURCEDIR"

mk_mkdir "${MK_STAGE_DIR}"
_stage_dir="`cd "${MK_STAGE_DIR}" && pwd`"
cd "${MK_OBJECT_DIR}${MK_SUBDIR}/${SOURCEDIR}"
_mk_try ${MAKE} ${MFLAGS}
_mk_try ${MAKE} ${MFLAGS} DESTDIR="${_stage_dir}" install
cd "${MK_ROOT_DIR}"
_mk_try touch "$1"
