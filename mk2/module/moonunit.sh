DEPENDS="path compiler"

load()
{
    mk_moonunit()
    {
	if [ "$HAVE_MOONUNIT" = no ]
	then
	    return 0
	fi

	mk_push_vars LIBRARY SOURCES CPPFLAGS CFLAGS LDFLAGS HEADERS LIBDIRS INCLUDEDIRS
	mk_parse_params

	unset _rsources

	case "$LIBRARY" in
	    *)
		_stub="${LIBRARY}-stub.c"
		;;
	esac

	for _source in ${SOURCES}
	do
	    mk_resolve_input "$_source"
	    _rsources="$_rsources $RET"
	done

	for _dir in ${INCLUDEDIRS}
	do
	    CPPFLAGS="$CPPFLAGS -I${MK_SOURCE_DIR}${MK_SUBDIR}/${_dir} -I${MK_OBJECT_DIR}${MK_SUBDIR}/${_dir}"
	done

	mk_object \
	    OUTPUT="$_stub" \
	    COMMAND="echo [moonunit] ${MK_SUBDIR#/}/${_stub}; moonunit-stub CPPFLAGS='$MK_CPPFLAGS $CPPFLAGS -I${MK_STAGE_DIR}${MK_INCLUDEDIR}' -o \$@${_rsources}" \
	    ${SOURCES}
	
	SOURCES="$SOURCES $_stub"

	mk_library \
	    INSTALL="no" \
	    LIBRARY="$LIBRARY" \
	    SOURCES="$SOURCES" \
	    HEADERS="$HEADERS" \
	    CPPFLAGS="$CPPFLAGS" \
	    CFLAGS="$CFLAGS" \
	    LDFLAGS="$LDFLAGS" \
	    LIBDIRS="$LIBDIRS" \
	    INCLUDEDIRS="$INCLUDEDIRS"

	MK_MOONUNIT_TESTS="$MK_MOONUNIT_TESTS ${MK_OBJECT_DIR}${MK_SUBDIR}/${OUTPUT}"

	mk_pop_vars
    }
}

configure()
{
    if type moonunit 2>&1 >/dev/null
    then
	HAVE_MOONUNIT_PROGRAM=yes
    else
	HAVE_MOONUNIT_PROGRAM=no
    fi
    mk_msg "program moonunit: $HAVE_MOONUNIT_PROGRAM"
    
    mk_check_headers HEADERS="moonunit/moonunit.h"

    if [ "$HAVE_MOONUNIT_PROGRAM" = yes -a "$HAVE_MOONUNIT_MOONUNIT_H" != no ]
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
	_mk_emitf "\t@echo [test] running moonunit tests; env LD_LIBRARY_PATH='%s' moonunit%s\n\n" \
	    "${MK_STAGE_DIR}${MK_LIBDIR}" \
	    "${MK_MOONUNIT_TESTS}"
    fi
}