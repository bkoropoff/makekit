### section build

# Restores context of particular subdirectory
_mk_restore_context()
{
    # Set subdir
    MK_SUBDIR="$1"

    case "$MK_SUBDIR" in
	":")
	    MK_MSG_DOMAIN="metakit"
	    mk_source_or_fail "${MK_ROOT_DIR}/.MetaKitExports"
	    ;;
	"")
	    MK_MSG_DOMAIN="${MK_SOURCE_DIR##*/}"
	    mk_source_or_fail "${MK_OBJECT_DIR}/.MetaKitExports"
	    mk_source_or_fail "${MK_SOURCE_DIR}/MetaKitBuild"
	    ;;
	*)
	    MK_MSG_DOMAIN="${MK_SUBDIR#/}"
	    mk_source_or_fail "${MK_OBJECT_DIR}${MK_SUBDIR}/.MetaKitExports"
	    mk_source_or_fail "${MK_SOURCE_DIR}${MK_SUBDIR}/MetaKitBuild"
	    ;;
    esac

    unset -f configure make option
}

[ "$1" = "-c" ] || mk_fail "invalid invocation"

eval "$2"
