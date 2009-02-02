@mk_include lib/constants.sh@
@mk_include lib/paths.sh@
@mk_include lib/util.sh@

. "${MK_MANIFEST_FILE}" || mk_fail "could not read ${MK_MANIFEST_FILENAME}"
. "${MK_CONFIG_FILE}" || mk_fail "coould not read ${MK_CONFIG_FILENAME}"

if [ -n "${MK_EXPORT_LIST}" ]
then
    export ${MK_EXPORT_LIST}
fi

mk_set_comp_vars()
{
    MK_COMP="$1"
    MK_COMP_SOURCE_DIR="${MK_SOURCE_DIR}/$1"    
    MK_COMP_STAGE_DIR="${MK_STAGE_DIR}/$1"
    MK_COMP_BUILD_DIR="${MK_BUILD_DIR}/$1"
}

mk_prepare()
{
    mk_log "Preparing component: $1"
    mk_set_comp_vars "$1"

    mk_recreate_dir "$MK_COMP_BUILD_DIR"
    cd "$MK_COMP_BUILD_DIR"

    ${1}_prepare || mk_fail "Preparing component $1 failed"
}

mk_build()
{
    mk_log "Building component: $1"
    mk_set_comp_vars "$1"

    cd "$MK_COMP_BUILD_DIR" || exit 1

    ${1}_build || mk_fail "Building component $1 failed"
}

mk_stage()
{
    mk_log "Staging component: $1"
    mk_set_comp_vars "$1"

    cd "$MK_COMP_BUILD_DIR" || exit 1

    ${1}_stage || mk_fail "Staging component $1 failed"
}

mk_install()
{
    mk_log "Installing component: $1"
    mk_log "Destination: $2"
    mk_set_comp_vars "$1"

    MK_COMP_INSTALL_DIR="$2"

    mkdir -p "${MK_COMP_INSTALL_DIR}" || mk_fail "could not create install directory"

    cd "$MK_COMP_STAGE_DIR" || exit 1

    ${1}_install || mk_fail "Installing component $1 failed"
}

@mk_generate_action_rules@

while [ -n "$1" ]
do
    action="$1"
    shift
    case "$action" in
	--make)
	    MAKE="$1"
	    shift;
	    export MAKE
	    ;;
	prepare)
	    comp="$1"
	    shift
	    mk_prepare "${comp}"
	    ;;
	build)
	    comp="$1"
	    shift
	    mk_build "${comp}"
	    ;;
	stage)
	    comp="$1"
	    shift
	    mk_stage "${comp}"
	    ;;
	install)
	    comp="$1"
	    shift
	    dir="$1"
	    shift
	    if [ -z "$dir" ]
	    then
		dir="/"
	    fi
	    mk_install "${comp}" "${dir}"
	    ;;
	*)
	    mk_fail "Unrecognized parameter: $action"
	    ;;
    esac
done
