#!/bin/sh

MK_MSG_DOMAIN="regen"

mk_msg "mkconfigure"

mk_unquote_list "${MK_OPTIONS}"

_mk_try "${MK_HOME}/mkconfigure" "$@"
