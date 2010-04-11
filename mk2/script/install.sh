#!/bin/sh

. "${MK_HOME}/mk.sh" || exit 1
. "./.MetaKitExports" || mk_fail "Could not read .MetaKitExports"

_mk_args

target="$1"
source="$2"

MK_LOG_DOMAIN="install"

mk_log "${target#${MK_STAGE_DIR}}"
_mk_try mkdir -p "`dirname "$target"`"
_mk_try cp "$source" "$target"
