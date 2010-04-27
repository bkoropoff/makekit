configure()
{
    MK_PREFIX="`mk_option prefix '/usr/local'`"
    MK_EPREFIX="`mk_option exec-prefix "$MK_PREFIX"`"

    if [ "${MK_PREFIX}" = "/usr" ]
    then
	_default_sysconfdir="/etc"
	_default_localstatedir="/var"
    else
	_default_sysconfdir="$MK_PREFIX/etc"
	_default_localstatedir="$MK_PREFIX/var"
    fi
    
    MK_LIBDIR="`mk_option libdir "${MK_EPREFIX}/lib"`"
    MK_INCLUDEDIR="`mk_option includedir "${MK_PREFIX}/include"`"
    MK_BINDIR="`mk_option bindir "${MK_EPREFIX}/bin"`"
    MK_SBINDIR="`mk_option sbindir "${MK_EPREFIX}/sbin"`"
    MK_SYSCONFDIR="`mk_option sysconfdir "${_default_sysconfdir}"`"
    MK_LOCALSTATEDIR="`mk_option localstatedir "${_default_localstatedir}"`"
    MK_DATAROOTDIR="`mk_option datarootdir "${MK_PREFIX}/share"`"
    MK_DATADIR="`mk_option datadir "${MK_DATAROOTDIR}"`"

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
