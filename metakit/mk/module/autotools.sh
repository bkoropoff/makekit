DEPENDS="core path compiler platform"

_mk_at_system_string()
{
    mk_get "MK_${1}_OS"

    case "${result}" in
	linux)
	    __os="linux-gnu"
	    ;;
	*)
	    __os="unknown"
	    ;;
    esac

    mk_get "MK_${1}_ARCH"

    case "${result}" in
	x86)
	    __arch="i686-pc"
	    ;;
	x86_64)
	    __arch="x86_64-unknown"
	    ;;
	*)
	    __arch="unknown-unknown"
	    ;;
    esac

    result="${__arch}-${__os}"
}

load()
{
    mk_autotools()
    {
	mk_push_vars \
	    SOURCEDIR HEADERS LIBS PROGRAMS LIBDEPS HEADERDEPS \
	    CPPFLAGS CFLAGS LDFLAGS INSTALL TARGETS SELECT \
	    dir prefix
	mk_parse_params

	unset _stage_deps

	_mk_slashless_name "${SOURCEDIR}/${MK_SYSTEM}"
	dir="$result"

	_mk_emit ""
	_mk_emit "#"
	_mk_emit "# autotools source component $SOURCEDIR ($MK_SYSTEM)"
	_mk_emit "#"
	_mk_emit ""

	for _lib in ${LIBDEPS}
	do
	    _stage_deps="$_stage_deps '${MK_LIBDIR}/lib${_lib}${MK_LIB_EXT}'"
	done
	
	for _header in ${HEADERDEPS}
	do
	    _stage_deps="$_stage_deps '${MK_INCLUDEDIR}/${_header}'"
	done

	mk_target \
	    TARGET=".${dir}_configure" \
	    DEPS="${_stage_deps}" \
	    mk_run_script \
	    at-configure \
	    %SOURCEDIR %CPPFLAGS %CFLAGS %LDFLAGS \
	    DIR="$dir" '$@' "$@"

	__configure_stamp="$result"

	mk_target \
	    TARGET=".${dir}_build" \
	    DEPS="'$__configure_stamp'" \
	    mk_run_script \
	    at-build \
	    %SYSTEM %SOURCEDIR %INSTALL %SELECT \
	    DIR="$dir" MAKE='$(MAKE)' MFLAGS='$(MFLAGS)' '$@'

	__build_stamp="$result"

	# Add dummy rules for target built by this component
	for _header in ${HEADERS}
	do
	    mk_target \
		TARGET="${MK_INCLUDEDIR}/${_header}" \
		DEPS="'$__build_stamp'"

	    mk_add_all_target "$result"

	    MK_INTERNAL_HEADERS="$MK_INTERNAL_HEADERS $_header"
	done

	for _lib in ${LIBS}
	do
	    mk_target \
		TARGET="${MK_LIBDIR}/lib${_lib}${MK_LIB_EXT}" \
		DEPS="'$__build_stamp'"

	    mk_add_all_target "$result"

	    MK_INTERNAL_LIBS="$MK_INTERNAL_LIBS $_lib"
	done

	for _program in ${PROGRAMS}
	do
	    mk_target \
		TARGET="@${MK_OBJECT_DIR}/build-run/bin/${_program}" \
		DEPS="'$__build_stamp'"

	    MK_INTERNAL_PROGRAMS="$MK_INTERNAL_PROGRAMS $_program"
	done

	for _target in ${TARGETS}
	do
	    mk_target \
		TARGET="$_target" \
		DEPS="'$__build_stamp'"
	done

	if ! [ -f "${MK_SOURCE_DIR}${MK_SUBDIR}/${SOURCEDIR}/configure" ]
	then
	    if [ -f "${MK_SOURCE_DIR}${MK_SUBDIR}/${SOURCEDIR}/autogen.sh" ]
	    then
		mk_msg "running autogen.sh for ${SOURCEDIR}"
		cd "${MK_SOURCE_DIR}${MK_SUBDIR}/${SOURCEDIR}" && mk_run_or_fail "./autogen.sh"
		cd "${MK_ROOT_DIR}"
	    else
		mk_msg "running autoreconf for ${SOURCEDIR}"
		cd "${MK_SOURCE_DIR}${MK_SUBDIR}/${SOURCEDIR}" && mk_run_or_fail autoreconf -fi
		cd "${MK_ROOT_DIR}"
	    fi
	fi

	mk_pop_vars
    }
}

option()
{
    _mk_at_system_string BUILD

    mk_option \
	OPTION="at-build-string" \
	VAR=MK_AT_BUILD_STRING \
	DEFAULT="$result" \
	HELP="Build system string"

    _mk_at_system_string HOST

    mk_option \
	OPTION="at-host-string" \
	VAR=MK_AT_HOST_STRING \
	DEFAULT="$result" \
	HELP="Host system string"
}

configure()
{
    mk_msg "build system string: $MK_AT_BUILD_STRING"
    mk_msg "host system string: $MK_AT_HOST_STRING"

    mk_export MK_AT_BUILD_STRING MK_AT_HOST_STRING
}