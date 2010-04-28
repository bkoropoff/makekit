#!/bin/sh

MK_MSG_DOMAIN="regen"

mk_msg "mkconfigure"

IFS='
'

_mk_try "${MK_HOME}/mkconfigure" ${MK_OPTIONS}
