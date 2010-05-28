DEPENDS="path compiler program"

load()
{
    mk_moonunit()
    {
	if [ "$HAVE_MOONUNIT" = no ]
	then
	    return 0
	fi

	mk_push_vars DSO SOURCES CPPFLAGS CFLAGS LDFLAGS HEADERS LIBDIRS INCLUDEDIRS LIBDEPS HEADERDEPS
	mk_parse_params

	unset _CPPFLAGS _rsources

	case "$DSO" in
	    *)
		_stub="${DSO}-stub.c"
		;;
	esac

	for _source in ${SOURCES}
	do
	    mk_resolve_input "$_source"
	    _rsources="$_rsources $result"
	done

	for _dir in ${INCLUDEDIRS}
	do
	    _CPPFLAGS="$_CPPFLAGS -I${MK_SOURCE_DIR}${MK_SUBDIR}/${_dir} -I${MK_OBJECT_DIR}${MK_SUBDIR}/${_dir}"
	done

	mk_object \
	    OUTPUT="$_stub" \
	    COMMAND="echo [moonunit] ${MK_SUBDIR#/}/${_stub}; moonunit-stub CPPFLAGS='$MK_CPPFLAGS $_CPPFLAGS -I${MK_STAGE_DIR}${MK_INCLUDEDIR}' -o \$@${_rsources}" \
	    ${SOURCES}
	
	SOURCES="$SOURCES $_stub"

	mk_dso \
	    INSTALL="no" \
	    DSO="$DSO" \
	    SOURCES="$SOURCES" \
	    HEADERS="$HEADERS" \
	    CPPFLAGS="$CPPFLAGS" \
	    CFLAGS="$CFLAGS" \
	    LDFLAGS="$LDFLAGS" \
	    LIBDIRS="$LIBDIRS" \
	    INCLUDEDIRS="$INCLUDEDIRS" \
	    LIBDEPS="$LIBDEPS" \
	    HEADERDEPS="$HEADERDEPS"

	MK_MOONUNIT_TESTS="$MK_MOONUNIT_TESTS ${MK_OBJECT_DIR}${MK_SUBDIR}/${OUTPUT}"

	mk_pop_vars
    }
}

configure()
{
    mk_check_program moonunit
    
    mk_check_headers HEADERS="moonunit/moonunit.h"

    if [ -n "$MOONUNIT" -a "$HAVE_MOONUNIT_MOONUNIT_H" != no ]
    then
	HAVE_MOONUNIT=yes
    else
	HAVE_MOONUNIT=no
    fi
    
    mk_msg "moonunit available: $HAVE_MOONUNIT"

    mk_export HAVE_MOONUNIT
}

postmake()
{
    if [ "$HAVE_MOONUNIT" = yes ]
    then
	_mk_emitf "test: ${MK_MOONUNIT_TESTS}\n"
	_mk_emitf "\t@\$(SCRIPT) moonunit ${MK_MOONUNIT_TESTS}\n\n"
    fi
}