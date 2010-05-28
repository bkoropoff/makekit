#!/bin/sh

MK_MSG_DOMAIN="build"

__msg="${MK_SUBDIR}/$SOURCEDIR"
mk_msg "${__msg#/}"

mk_mkdir "${MK_STAGE_DIR}"
_stage_dir="`cd "${MK_STAGE_DIR}" && pwd`"
cd "${MK_OBJECT_DIR}${MK_SUBDIR}/${SOURCEDIR}"
_mk_try ${MAKE} ${MFLAGS}
if [ "$INSTALL" != "no" ]
then
    _mk_try ${MAKE} ${MFLAGS} DESTDIR="${_stage_dir}" install
fi
cd "${MK_ROOT_DIR}"
_mk_try touch "$1"
