configure()
{
    MK_PREFIX_DIR="`mk_option prefix '/usr/local'`"
    MK_LIB_DIR="`mk_option libdir "${MK_PREFIX_DIR}/lib"`"
    MK_INCLUDE_DIR="`mk_option includedir "${MK_PREFIX_DIR}/include"`"
    MK_BIN_DIR="`mk_option bindir "${MK_PREFIX_DIR}/bin"`"
    MK_SBIN_DIR="`mk_option sbindir "${MK_PREFIX_DIR}/sbin"`"

    mk_msg "prefix: $MK_PREFIX_DIR"
    mk_msg "library dir: $MK_LIB_DIR"
    mk_msg "include dir: $MK_INCLUDE_DIR"
    mk_msg "binary dir: $MK_BIN_DIR"
    mk_msg "system binary dir: $MK_SBIN_DIR"

    mk_export MK_PREFIX_DIR MK_LIB_DIR MK_INCLUDE_DIR MK_BIN_DIR MK_SBIN_DIR
}
