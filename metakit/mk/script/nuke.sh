#!/bin/sh

MK_MSG_DOMAIN="nuke"

for _target in "${MK_STAGE_DIR}" "${MK_OBJECT_DIR}" "Makefile" "config.log" ".MetaKitDeps" ".MetaKitExports"
do
    if [ -e "$_target" ]
    then
	mk_msg "${_target}"
    	mk_run_or_fail rm -rf "$_target"
    fi
done
