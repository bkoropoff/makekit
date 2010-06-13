DEPENDS="platform"

option()
{
    mk_option \
	OPTION=prefix \
	VAR=MK_PREFIX \
	PARAM="path" \
	DEFAULT='/usr/local' \
	HELP="Architecture-independent installation prefix"

    mk_option \
	OPTION=exec-prefix \
	VAR=MK_EPREFIX \
	PARAM="path" \
	DEFAULT="$MK_PREFIX" \
	HELP="Architecture-dependent installation prefix"
    
    if [ "${MK_PREFIX}" = "/usr" ]
    then
	_default_sysconfdir="/etc"
	_default_localstatedir="/var"
    else
	_default_sysconfdir="$MK_PREFIX/etc"
	_default_localstatedir="$MK_PREFIX/var"
    fi

    for _isa in ${MK_HOST_ISAS}
    do
	_mk_define_name "host/$_isa"
	_var="MK_LIBDIR_$result"
	
	case "${MK_HOST_OS}-${MK_HOST_DISTRO}-${MK_HOST_ARCH}-${_isa}" in
	    linux-*-x86_64-x86_32)
		_default_libdir="${MK_EPREFIX}/lib32"
		;;
	    *)
		_default_libdir="${MK_EPREFIX}/lib"
		;;
	esac

	mk_option \
	    OPTION="libdir-$_isa" \
	    VAR="$_var"  \
	    PARAM="path" \
	    DEFAULT="$_default_libdir" \
	    HELP="Library directory ($_isa)"
    done

    mk_option MK_INCLUDEDIR includedir "${MK_PREFIX}/include"
    mk_option MK_BINDIR bindir "${MK_EPREFIX}/bin"
    mk_option MK_SBINDIR sbindir "${MK_EPREFIX}/sbin"
    mk_option MK_SYSCONFDIR sysconfdir "${_default_sysconfdir}"
    mk_option MK_LOCALSTATEDIR localstatedir "${_default_localstatedir}"
    mk_option MK_DATAROOTDIR datarootdir "${MK_PREFIX}/share"
    mk_option MK_DATADIR datadir "${MK_DATAROOTDIR}"
}

configure()
{
    mk_declare_system_var MK_LIBDIR

    mk_msg "prefix: $MK_PREFIX"
    mk_msg "exec prefix: $MK_EPREFIX"

    for _isa in ${MK_HOST_ISAS}
    do
	_mk_define_name "host/$_isa"
	_var="MK_LIBDIR_$result"
	_vars="$_vars $_var"
	mk_get "$_var"
	mk_msg "library dir ($_isa): $result"
	mk_set_system_var SYSTEM="host/$_isa" MK_LIBDIR "$result"
    done
    
    mk_msg "include dir: $MK_INCLUDEDIR"
    mk_msg "binary dir: $MK_BINDIR"
    mk_msg "system binary dir: $MK_SBINDIR"
    mk_msg "system config dir: $MK_SYSCONFDIR"
    mk_msg "local state dir: $MK_LOCALSTATEDIR"
    mk_msg "data root dir: $MK_DATAROOTDIR"
    mk_msg "data dir: $MK_DATADIR"

    mk_export \
	MK_PREFIX MK_LIBDIR MK_INCLUDEDIR MK_BINDIR \
	MK_SBINDIR MK_SYSCONFDIR MK_LOCALSTATEDIR \
	MK_DATAROOTDIR MK_DATADIR

    # Set up paths where programs compiled for the build system should go
    mk_export MK_RUN_PREFIX="${MK_RUN_DIR}"
    mk_export MK_RUN_EPREFIX="${MK_RUN_DIR}"
    mk_export MK_RUN_LIBDIR="${MK_RUN_DIR}/lib"
    mk_export MK_RUN_BINDIR="${MK_RUN_DIR}/bin"
    mk_export MK_RUN_SBINDIR="${MK_RUN_DIR}/sbin"
    mk_export MK_RUN_SYSCONFDIR="${MK_RUN_DIR}/etc"
    mk_export MK_RUN_LOCALSTATEDIR="${MK_RUN_DIR}/var"
    mk_export MK_RUN_DATAROOTDIR="${MK_RUN_DIR}/share"
    mk_export MK_RUN_DATADIR="${MK_RUN_DIR}/share"
}
