#!/bin/sh

MK_MSG_DOMAIN="nuke"

for _target in "${MK_STAGE_DIR}" "${MK_OBJECT_DIR}" "Makefile" "config.log" ".MetaKitDeps" ".MetaKitExports"
do
    if [ -e "$_target" ]
    then
	mk_msg "${_target}"
    	_mk_try rm -rf "$_target"
    fi
done
