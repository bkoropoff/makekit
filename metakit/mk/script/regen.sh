#!/bin/sh

MK_MSG_DOMAIN="regen"

mk_msg "mkconfigure"

export MK_HOME MK_SOURCE_DIR

mk_unquote_list "${MK_OPTIONS}"

_mk_try ${MK_SHELL} "${MK_HOME}/configure.sh" "$@"
