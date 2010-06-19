#!/bin/sh

MK_MSG_DOMAIN="nuke"

for _target in "${MK_STAGE_DIR}" "${MK_OBJECT_DIR}" "Makefile" "config.log" ".MetaKit"*
do
    if [ -e "$_target" ]
    then
	mk_msg "${_target}"
    	mk_safe_rm "$_target"
    fi
done
