#!/bin/sh

_object="$1"
_source="$2"

EXTRA_CPPFLAGS="-I${MK_STAGE_DIR}${MK_INCLUDEDIR} -DHAVE_CONFIG_H"
INCLUDE_CPPFLAGS=""

for _dir in ${INCLUDEDIRS}
do
    INCLUDE_CPPFLAGS="$INCLUDE_CPPFLAGS -I${MK_SOURCE_DIR}${MK_SUBDIR}/$_dir -I${MK_OBJECT_DIR}${MK_SUBDIR}/$_dir"
done

MK_MSG_DOMAIN="compile"

if [ -z "$DISABLE_DEPGEN" ]
then
    mk_mkdir ".MetaKitDeps"
    _mk_slashless_name "${_object%.o}"
    DEP_FLAGS="-MMD -MP -MF .MetaKitDeps/${result}.dep"
fi

if [ "$PIC" = "yes" ]
then
    EXTRA_CFLAGS="$EXTRA_CFLAGS -fPIC"
fi

mk_msg "${_source#${MK_SOURCE_DIR}/}"
mk_mkdir "`dirname "$_object"`"
_mk_try ${MK_CC} \
    ${INCLUDE_CPPFLAGS} ${MK_CPPFLAGS} ${CPPFLAGS} ${EXTRA_CPPFLAGS} \
    ${MK_CFLAGS} ${CFLAGS} ${EXTRA_CFLAGS} \
    ${DEP_FLAGS} \
    -o "$_object" \
    -c "$_source"
