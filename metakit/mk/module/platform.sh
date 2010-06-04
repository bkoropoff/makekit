load()
{
    mk_run_with_extended_library_path()
    {
	unset __env

	case "$MK_OS" in
	    linux|*)
		__env="LD_LIBRARY_PATH=$LD_LIBRARY_PATH:$1"
		;;
	esac

	shift
	env "$__env" "$@"
    }
}

configure()
{
    case `uname` in
	Linux)
	    MK_OS='linux'
	    MK_LIB_EXT=".so"
	    MK_DSO_EXT=".so"
	    ;;
	*)
	    mk_fail "unknown OS: `uname`"
    esac

    case `uname -m` in
	i?86)
	    MK_ARCH="x86"
	    ;;
	x86_64)
	    MK_ARCH="x86_64"
	    ;;
	*)
	    mk_fail "unknown architecture: `uname -m`"
	    ;;
    esac

    mk_msg "detected OS: $MK_OS"
    mk_msg "detected architecture: $MK_ARCH"

    mk_export MK_OS MK_ARCH MK_LIB_EXT MK_DSO_EXT
}