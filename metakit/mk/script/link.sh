#!/bin/sh

version_pre()
{
    case "$MODE" in
	library)
	    if [ -z "$VERSION" ]
	    then
		VERSION="0.0.0"
	    fi
	    ;;
	program)
	    return 0
	    ;;
    esac
    
    if [ "$VERSION" != "no" ]
    then
	_rest="${VERSION}."
	MAJOR="${_rest%%.*}"
	_rest="${_rest#*.}"
	MINOR="${_rest%%.*}"
	_rest="${_rest#*.}"
	MICRO="${_rest%%.*}"
    fi
    
    if [ -n "$MAJOR" ]
    then
	SONAME="${object##*/}.$MAJOR"
	LINK1="${object}"
	object="${object}.$MAJOR"
    fi
    
    if [ -n "$MINOR" ]
    then
	LINK2="${object}"
	object="${object}.$MINOR"
    fi
    
    if [ -n "$MICRO" ]
    then
	LINK3="${object}"
	object="${object}.$MICRO"
    fi
    
    if [ -n "$SONAME" ]
    then
	COMBINED_LDFLAGS="$COMBINED_LDFLAGS -Wl,-h,$SONAME"
    fi
}

version_post()
{
    _target="${object}"

    for _link in "$LINK3" "$LINK2" "$LINK1"
    do
	if [ -n "$_link" ]
	then
	    _mk_try ln -sf "${_target##*/}" "${_link}"
	    _target="$_link"
	fi
    done
}

object="$1"
shift 1


if [ "${MK_SYSTEM%/*}" = "build" ]
then
    LINK_LIBDIR="$MK_RUN_LIBDIR"
    RPATH_LIBDIR="$MK_ROOT_DIR/$MK_RUN_LIBDIR"
else
    mk_get_system_var MK_LIBDIR "$MK_SYSTEM"
    RPATH_LIBDIR="$result"
    mk_resolve_file "$result"
    LINK_LIBDIR="$result"
fi

COMBINED_LIBDEPS="$LIBDEPS"
COMBINED_LDFLAGS="$LDFLAGS -L${LINK_LIBDIR}"
COMBINED_LIBDIRS="$LIBDIRS"

case "${MK_OS}" in
    linux)
	COMBINED_LDFLAGS="$COMBINED_LDFLAGS -Wl,-rpath,${RPATH_LIBDIR} -Wl,-rpath-link,${LINK_LIBDIR}"
	;;
esac

for _group in ${GROUPS}
do
    unset OBJECTS LIBDEPS LIBDIRS LDFLAGS
    _dirname="`dirname "$_group"`"
    mk_safe_source "${MK_OBJECT_DIR}${MK_SUBDIR}/$_group" || mk_fail "Could not read group $_group"


    GROUP_OBJECTS="$GROUP_OBJECTS ${OBJECTS}"
    COMBINED_LIBDEPS="$COMBINED_LIBDEPS $LIBDEPS"
    COMBINED_LIBDIRS="$COMBINED_LIBDIRS $LIBDIRS"
    COMBINED_LDFLAGS="$COMBINED_LDFLAGS $LDFLAGS"
done

for lib in ${COMBINED_LIBDEPS}
do
    COMBINED_LDFLAGS="$COMBINED_LDFLAGS -l${lib}"
done

version_pre

MK_MSG_DOMAIN="link"


mk_msg "${object#${MK_STAGE_DIR}} ($MK_SYSTEM)"

mk_mkdir "`dirname "$object"`"

case "$MODE" in
    library)
	_mk_try ${MK_CC} -shared -o "$object" "$@" ${GROUP_OBJECTS} ${MK_LDFLAGS} ${COMBINED_LDFLAGS} -fPIC
	;;
    dso)
	_mk_try ${MK_CC} -shared -o "$object" "$@" ${GROUP_OBJECTS} ${MK_LDFLAGS} ${COMBINED_LDFLAGS} -fPIC
	;;
    program)
	_mk_try ${MK_CC} -o "$object" "$@" ${GROUP_OBJECTS} ${MK_LDFLAGS} ${COMBINED_LDFLAGS}
	;;
esac

version_post
