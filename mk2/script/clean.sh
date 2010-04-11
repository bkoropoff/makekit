#!/bin/sh

. "${MK_HOME}/mk.sh" || exit 1

_mk_args

for _target in "$@"
do
    if [ -d "$_target" ]
    then
	echo "[clean] $_target"
    	_mk_try rm -rf "$_target"
    elif [ -f "$_target" ]
    then
	echo "[clean] $_target"
	_mk_try rm -f "$_target"
    fi
done
