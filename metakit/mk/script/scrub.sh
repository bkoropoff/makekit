#!/bin/sh

MK_MSG_DOMAIN="scrub"

for _target in "${MK_STAGE_DIR}"
do
    if [ -e "$_target" ]
    then
	mk_msg "${_target}"
    	mk_run_or_fail rm -rf "$_target"
    fi
done
