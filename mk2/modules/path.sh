configure()
{
    MK_PREFIX_DIR="`mk_option prefix '/usr/local'`"
    MK_LIB_DIR="`mk_option libdir "${MK_PREFIX_DIR}/lib"`"
    MK_INCLUDE_DIR="`mk_option includedir "${MK_PREFIX_DIR}/include"`"
    MK_BIN_DIR="`mk_option bindir "${MK_PREFIX_DIR}/bin"`"

    mk_log "prefix: $MK_PREFIX_DIR"
    mk_log "library dir: $MK_LIB_DIR"
    mk_log "include dir: $MK_INCLUDE_DIR"
    mk_log "binary dir: $MK_BIN_DIR"

    mk_export MK_PREFIX_DIR MK_LIB_DIR MK_INCLUDE_DIR MK_BIN_DIR
}
