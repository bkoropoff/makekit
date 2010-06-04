option()
{
    mk_option \
	OPTION=prefix \
	VAR=MK_PREFIX \
	DEFAULT='/usr/local' \
	HELP="Architecture-independent installation prefix"

    mk_option \
	OPTION=exec-prefix \
	VAR=MK_EPREFIX \
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

    mk_option MK_LIBDIR libdir "${MK_EPREFIX}/lib"
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
    mk_msg "prefix: $MK_PREFIX"
    mk_msg "exec prefix: $MK_EPREFIX"
    mk_msg "library dir: $MK_LIBDIR"
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
}
