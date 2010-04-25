#!/bin/sh

. "${MK_HOME}/mk.sh" || exit 1
. "./.MetaKitExports" || mk_fail "Could not read .MetaKitExports"

mk_parse_params

target="$1"
source="$2"

MK_MSG_DOMAIN="install"

mk_msg "${target#${MK_STAGE_DIR}}"
mk_mkdir "`dirname "$target"`"
_mk_try cp "$source" "$target"
