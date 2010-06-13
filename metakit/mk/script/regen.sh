#!/bin/sh

MK_MSG_DOMAIN="regen"

mk_msg "reconfiguring"

export MK_HOME MK_SOURCE_DIR MK_SHELL

mk_unquote_list "${MK_OPTIONS}"

_mk_try ${MK_SHELL} "${MK_HOME}/configure.sh" "$@"
