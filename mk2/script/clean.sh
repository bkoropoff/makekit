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
    	_mk_try rm -f "$_target"
    done
}

IFS='
'

do_clean `find "$MK_OBJECT_DIR" ".MetaKitDeps"`
