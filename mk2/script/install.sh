#!/bin/sh

target="$1"
source="$2"

MK_MSG_DOMAIN="install"

mk_msg "${target#${MK_STAGE_DIR}}"
mk_mkdir "`dirname "$target"`"
_mk_try cp "$source" "$target"
