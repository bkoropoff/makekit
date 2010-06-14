DEPENDS="path compiler program"

load()
{
    _mk_invoke_moonunit_stub()
    {
	mk_push_vars CPPFLAGS
	mk_parse_params

	MK_MSG_DOMAIN="moonunit-stub"
	__output="$1"
	shift

	mk_msg "${__output#${MK_OBJECT_DIR}/}"

	if ! mk_run_program \
	    ${MOONUNIT_STUB} \
	    CPPFLAGS="$MK_CPPFLAGS $CPPFLAGS -I${MK_STAGE_DIR}${MK_INCLUDEDIR}" \
	    -o "$__output" \
	    "$@"
	then
	    rm -f "$__output"
	    mk_fail "moonunit-stub failed"
	fi

	mk_pop_vars
    }

    mk_moonunit()
    {
	if [ "$HAVE_MOONUNIT" = no ]
	then
	    return 0
	fi

	mk_push_vars DSO SOURCES CPPFLAGS CFLAGS LDFLAGS HEADERS LIBDIRS INCLUDEDIRS LIBDEPS HEADERDEPS GROUPS DEPS
	mk_parse_params

	unset _CPPFLAGS _rsources

	case "$DSO" in
	    *)
		_stub="${DSO}-stub.c"
		;;
	esac

	for _source in ${SOURCES}
	do
	    mk_resolve_target "$_source"
	    _rsources="$_rsources '$result'"
	done

	for _dir in ${INCLUDEDIRS}
	do
	    CPPFLAGS="$CPPFLAGS -I${MK_SOURCE_DIR}${MK_SUBDIR}/${_dir} -I${MK_OBJECT_DIR}${MK_SUBDIR}/${_dir}"
	done

	mk_target \
	    TARGET="$_stub" \
	    DEPS="$_rsources" \
	    _mk_invoke_moonunit_stub %CPPFLAGS '$@' "*${_rsources}"
	
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
	    HEADERDEPS="$HEADERDEPS" \
	    GROUPS="$GROUPS" \
	    DEPS="$DEPS"

	MK_MOONUNIT_TESTS="$MK_MOONUNIT_TESTS $result"

	mk_pop_vars
    }
}

configure()
{
    if [ "${MK_BUILD_OS}-${MK_BUILD_ARCH}" != "${MK_HOST_OS}-${MK_HOST_ARCH}" ]
    then
	mk_msg "moonunit unavailable when cross-compiling"
	HAVE_MOONUNIT=no
    else
	mk_check_program moonunit
	mk_check_program moonunit-stub
	
	mk_check_headers HEADERS="moonunit/moonunit.h"
	
	if [ -n "$MOONUNIT" -a -n "$MOONUNIT_STUB" -a "$HAVE_MOONUNIT_MOONUNIT_H" != no ]
	then
	    HAVE_MOONUNIT=yes
	else
	    HAVE_MOONUNIT=no
	fi
    fi
    
    mk_msg "moonunit available: $HAVE_MOONUNIT"

    mk_export HAVE_MOONUNIT
}

make()
{
    if [ "$HAVE_MOONUNIT" = yes ]
    then
	mk_target \
	    TARGET="@test" \
	    DEPS="${MK_MOONUNIT_TESTS}" \
	    mk_run_script moonunit "*${MK_MOONUNIT_TESTS}"

	mk_add_phony_target "$result"
    fi
}