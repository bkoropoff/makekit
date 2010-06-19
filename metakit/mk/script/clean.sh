#!/bin/sh

MK_MSG_DOMAIN="clean"

__IFS="$IFS"

do_clean()
{
    IFS="$__IFS"
    
    for _target in "$@"
    do
	if _mk_contains "$_target" ${MK_PRECIOUS_FILES} || [ -d "$_target" ]
	then
	    continue;
	fi
	
	mk_msg "${_target#${MK_OBJECT_DIR}/}"
    	mk_safe_rm "$_target"
    done
}

for __dir in "$MK_OBJECT_DIR" "$MK_RUN_DIR" ".MetaKitDeps"
do
    if [ -d "$__dir" ]
    then
	IFS='
'
	do_clean `find "$__dir"`
    fi
done
