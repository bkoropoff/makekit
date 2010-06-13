#!/bin/sh

MK_MSG_DOMAIN="build"

__msg="${MK_SUBDIR}/$SOURCEDIR ($MK_SYSTEM)"
mk_msg "begin ${__msg#/}"

_stamp="$1"
mk_mkdir "${MK_STAGE_DIR}"
_stage_dir="`cd "${MK_STAGE_DIR}" && pwd`"
cd "${MK_OBJECT_DIR}${MK_SUBDIR}/$DIR" || mk_fail "could not change directory"
_mk_try ${MAKE} ${MFLAGS}
if [ "$INSTALL" != "no" ]
then
    if [ "${MK_SYSTEM%/*}" = "build" ]
    then
	_mk_try ${MAKE} ${MFLAGS} install
    elif [ -n "$SELECT" ]
    then
	# We have to install to a temporary location, then copy selected files
	rm -rf ".install"
	_mk_try ${MAKE} ${MFLAGS} DESTDIR="${PWD}/.install" install
	mk_expand_absolute_pathnames "$SELECT" ".install"
	mk_unquote_list "$result"
	for _file in "$@"
	do
	    if [ -e ".install${_file}" ]
	    then
		_dest="${_stage_dir}${_file}"
		mk_mkdir "${_dest%/*}"
		cp -pr ".install${_file}" "$_dest" || mk_fail "failed to copy file: $_file"
	    else
		mk_fail "could not select file: $_file"
	    fi
	done
	rm -rf ".install"
    else
	_mk_try ${MAKE} ${MFLAGS} DESTDIR="${_stage_dir}" install
    fi
fi
cd "${MK_ROOT_DIR}"
_mk_try touch "$_stamp"
mk_msg "end ${__msg#/}"