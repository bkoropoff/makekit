mk_declare_system_var()
{
    mk_push_vars EXPORT
    mk_parse_params

    for __var in "$@"
    do
	if ! _mk_contains "$__var" ${MK_SYSTEM_VARS}
	then
	    MK_SYSTEM_VARS="$MK_SYSTEM_VARS $__var"
	    if [ "$EXPORT" != "no" ]
	    then
		for __isa in ${MK_HOST_ISAS}
		do
		    _mk_define_name "host/${__isa}"
		    mk_export "${__var}_$result"
		done
		
		for __isa in ${MK_BUILD_ISAS}
		do
		    _mk_define_name "build/${__isa}"
		    mk_export "${__var}_$result"
		done
	    fi
	fi
    done

    mk_pop_vars
}

mk_get_system_var()
{
    mk_push_vars SYSTEM
    mk_parse_params
    
    [ -z "$SYSTEM" ] && SYSTEM="$2"

    if [ "$MK_SYSTEM" = "$SYSTEM" ]
    then
	mk_get "$1"
    else
	_mk_define_name "${1}_$SYSTEM"
	mk_get "$result"
    fi

    mk_pop_vars
}

mk_set_system_var()
{
    mk_push_vars SYSTEM
    mk_parse_params

    if [ "$MK_SYSTEM" = "$SYSTEM" ]
    then
	mk_set "$1" "$2"
    else
        _mk_define_name "${1}_$SYSTEM"
	mk_set "$result" "$2"
    fi

    

    mk_pop_vars
}

mk_system()
{
    mk_push_vars suffix var

    # If we are changing the current system
    if [ "$MK_SYSTEM" != "$1" ]
    then
	if [ -n "$MK_SYSTEM" ]
	then
	# Save all current variable values
	    _mk_define_name "$MK_SYSTEM"
	    suffix="$result"
	    for var in ${MK_SYSTEM_VARS}
	    do
		eval "${var}_${suffix}=\"\$$var\""
	    done
	fi

	# Switch to the new system
	mk_canonical_system "$1"
	MK_SYSTEM="$result"

	# Restore variable values
	_mk_define_name "$MK_SYSTEM"
	suffix="$result"
	for var in ${MK_SYSTEM_VARS}
	do
	    eval "${var}=\"\$${var}_${suffix}\""
	done
    fi

    mk_pop_vars
}

mk_canonical_system()
{
    case "$1" in
	""|host)
	    result="host/${MK_HOST_PRIMARY_ISA}"
	    ;;
	build)
	    result="build/${MK_BUILD_PRIMARY_ISA}"
	    ;;
	*)
	    result="$1"
    esac
}

mk_run_with_extended_library_path()
{
    unset __env
    
    case "$MK_BUILD_OS" in
	linux|*)
	    __env="LD_LIBRARY_PATH=$LD_LIBRARY_PATH:$1"
	    ;;
    esac
    
    shift
    env "$__env" "$@"
}

option()
{
    case `uname` in
	Linux)
	    _default_MK_BUILD_OS='linux'
	    ;;
	*)
	    mk_fail "unknown OS: `uname`"
    esac

    case `uname -m` in
	i?86)
	    _default_MK_BUILD_ARCH="x86"
	    ;;
	x86_64)
	    _default_MK_BUILD_ARCH="x86_64"
	    ;;
	*)
	    mk_fail "unknown architecture: `uname -m`"
	    ;;
    esac

    case "${_default_MK_BUILD_OS}-${_default_MK_BUILD_ARCH}" in
	*"-x86")
	    _default_MK_BUILD_ISAS="x86_32"
	    ;;
	"linux-x86_64")
	    _default_MK_BUILD_ISAS="x86_64 x86_32"
	    ;;
	*)
	    _default_MK_BUILD_ISAS="$_default_MK_BUILD_ARCH"
	    ;;
    esac

    case "$_default_MK_BUILD_OS" in
	linux)
	    if mk_safe_source "/etc/lsb-release"
	    then
		case "$DISTRIB_ID" in
		    *)
			_default_MK_BUILD_DISTRO="`echo "$DISTRIB_ID" | tr 'A-Z' 'a-z'`"
			_default_MK_BUILD_DISTRO_VERSION="$DISTRIB_RELEASE"
			;;
		esac
	    else
		_default_MK_BUILD_DISTRO="unknown"
		_default_MK_BUILD_DISTRO_VERSION="unknown"
	    fi		
	    ;;
	*)
	    _default_MK_BUILD_DISTRO="unknown"
	    _default_MK_BUILD_DISTRO_VERSION="unknown"
	    ;;
    esac

    mk_option \
	OPTION=build-os \
	VAR=MK_BUILD_OS \
	DEFAULT="$_default_MK_BUILD_OS" \
	HELP="Build operating system"

    mk_option \
	OPTION=build-arch \
	VAR=MK_BUILD_ARCH \
	DEFAULT="$_default_MK_BUILD_ARCH" \
	HELP="Build CPU architecture"

    mk_option \
	OPTION=build-isas \
	VAR=MK_BUILD_ISAS \
	DEFAULT="$_default_MK_BUILD_ISAS" \
	HELP="Build instruction set architectures"

    mk_option \
	OPTION=build-distro \
	VAR=MK_BUILD_DISTRO \
	DEFAULT="$_default_MK_BUILD_DISTRO" \
	HELP="Build operating system distribution"

    mk_option \
	OPTION=build-distro-version \
	VAR=MK_BUILD_DISTRO_VERSION \
	DEFAULT="$_default_MK_BUILD_DISTRO_VERSION" \
	HELP="Build operating system distribution version"

    mk_option \
	OPTION=host-os \
	VAR=MK_HOST_OS \
	DEFAULT="$MK_BUILD_OS" \
	HELP="Host operating system"

    mk_option \
	OPTION=host-arch \
	VAR=MK_HOST_ARCH \
	DEFAULT="$MK_BUILD_ARCH" \
	HELP="Host CPU architecture"

    mk_option \
	OPTION=host-isas \
	VAR=MK_HOST_ISAS \
	DEFAULT="$MK_BUILD_ISAS" \
	HELP="Host instruction set architectures"

    mk_option \
	OPTION=host-distro \
	VAR=MK_HOST_DISTRO \
	DEFAULT="$MK_BUILD_DISTRO" \
	HELP="Host operating system distribution"

    mk_option \
	OPTION=host-distro-version \
	VAR=MK_HOST_DISTRO_VERSION \
	DEFAULT="$MK_BUILD_DISTRO_VERSION" \
	HELP="Host operating system distribution version"

    MK_BUILD_PRIMARY_ISA="${MK_BUILD_ISAS%% *}"
    MK_HOST_PRIMARY_ISA="${MK_HOST_ISAS%% *}"
}

configure()
{
    mk_export MK_SYSTEM_VARS

    case "$MK_HOST_OS" in
	linux)
	    MK_LIB_EXT=".so"
	    MK_DSO_EXT=".so"
	    ;;
    esac

    mk_msg "build operating system: $MK_BUILD_OS"
    mk_msg "build distribution: $MK_BUILD_DISTRO"
    mk_msg "build distribution version: $MK_BUILD_DISTRO_VERSION"
    mk_msg "build processor architecture: $MK_BUILD_ARCH"
    mk_msg "build instruction set architectures: $MK_BUILD_ISAS"

    mk_msg "host operating system: $MK_HOST_OS"
    mk_msg "host distribution: $MK_HOST_DISTRO"
    mk_msg "host distribution version: $MK_HOST_DISTRO_VERSION"
    mk_msg "host processor architecture: $MK_HOST_ARCH"
    mk_msg "host instruction set architectures: $MK_HOST_ISAS"

    mk_export MK_BUILD_OS MK_BUILD_DISTRO MK_BUILD_DISTRO_VERSION MK_BUILD_ARCH MK_BUILD_ISAS MK_BUILD_PRIMARY_ISA
    mk_export MK_HOST_OS MK_HOST_DISTRO MK_HOST_DISTRO_VERSION MK_HOST_ARCH MK_HOST_ISAS MK_HOST_PRIMARY_ISA
    mk_export MK_LIB_EXT MK_DSO_EXT

    mk_export MK_OS="$MK_HOST_OS" MK_ARCH="$MK_HOST_ARCH"

    # Register hooks that set the target system to the default
    # or restore any modified system variables at the start of
    # all configure() and make() functions
    mk_add_configure_prehook _mk_platform_restore_system_vars
    mk_add_make_prehook _mk_platform_restore_system_vars

    # Register hooks that commit all system variables
    # at the end of all configure() and make() functions so that they
    # get written out as exports and restored correctly
    mk_add_configure_posthook _mk_platform_commit_system_vars
    mk_add_make_posthook _mk_platform_commit_system_vars

    # Set the default system now
    mk_system "host/${MK_HOST_PRIMARY_ISA}"
}

_mk_platform_restore_system_vars()
{
    # Switch system back to default
    MK_SYSTEM="host/${MK_HOST_PRIMARY_ISA}"
    # Restore all variables
    _mk_define_name "$MK_SYSTEM"
    for ___var in ${MK_SYSTEM_VARS}
    do
	eval "${___var}=\"\$${___var}_${result}\""
    done
}

_mk_platform_commit_system_vars()
{
    if [ -n "$MK_SYSTEM" ]
    then
	_mk_define_name "$MK_SYSTEM"
	for ___var in ${MK_SYSTEM_VARS}
	do
	    eval "${___var}_${result}=\"\$$___var\""
	done
    fi
}
