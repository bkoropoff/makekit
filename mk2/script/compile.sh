#!/bin/sh

. "${MK_HOME}/mk.sh" || exit 1
mk_import

mk_parse_params

_object="$1"
_source="$2"

EXTRA_CPPFLAGS="-I${MK_STAGE_DIR}${MK_INCLUDE_DIR} -DHAVE_CONFIG_H"

for _dir in ${INCLUDEDIRS}
do
    EXTRA_CPPFLAGS="$EXTRA_CPPFLAGS -I${MK_SOURCE_DIR}${MK_SUBDIR}/$_dir -I${MK_OBJECT_DIR}${MK_SUBDIR}/$_dir"
done

MK_MSG_DOMAIN="compile"

if [ -z "$DISABLE_DEPGEN" ]
then
    DEP_FLAGS="-MMD -MP -MF ${MK_ROOT_DIR}/.MetaKitDeps/`echo ${_object%.o} | tr / _`.dep"
fi

if [ "$PIC" = "yes" ]
then
    EXTRA_CFLAGS="$EXTRA_CFLAGS -fPIC"
fi

mk_msg "${_source#${MK_SOURCE_DIR}/}"
_mk_try mkdir -p "`dirname "$_object"`" "${MK_ROOT_DIR}/.MetaKitDeps"
_mk_try ${MK_CC} \
    ${MK_CPPFLAGS} ${CPPFLAGS} ${EXTRA_CPPFLAGS} \
    ${MK_CFLAGS} ${CFLAGS} ${EXTRA_CFLAGS} \
    ${DEP_FLAGS} \
    -o "$_object" \
    -c "$_source"
