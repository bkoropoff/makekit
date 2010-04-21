#!/bin/sh

. "${MK_HOME}/mk.sh" || exit 1
. "${MK_ROOT_DIR}/.MetaKitExports" || mk_fail "Could not read .MetaKitExports"

_mk_args

IFS='
'

MK_LOG_DOMAIN="regen"

mk_log "mkconfigure"

_mk_try "${MK_HOME}/mkconfigure" ${MK_OPTIONS}
