#!/bin/sh

MK_MSG_DOMAIN="scrub"

for _target in "${MK_STAGE_DIR}"
do
    if [ -e "$_target" ]
    then
	mk_msg "${_target}"
    	_mk_try rm -rf "$_target"
    fi
done
