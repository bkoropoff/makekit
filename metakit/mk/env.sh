#!/bin/sh

. "${MK_HOME}/mk.sh" || exit 1

mk_import
_mk_load_modules

if [ "$MK_SUBDIR" != ":" ]
then
    mk_safe_source "${MK_SOURCE_DIR}${MK_SUBDIR}/MetaKitBuild"
    unset -f make configure option
fi


