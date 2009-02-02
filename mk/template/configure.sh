#!/bin/sh

@mk_include lib/constants.sh@
@mk_include lib/util.sh@

DIRNAME="`dirname "$0"`"
MK_ROOT_DIR="`mk_canonical_path "$DIRNAME"`"
MK_WORK_DIR="`pwd`"
MK_PREFIX="/usr/local"
MK_DEFINE_LIST=""
MK_EXPORT_LIST=""

@mk_include lib/paths.sh@

mk_define()
{
    for __var in "$@"
    do
	if echo "${MK_DEFINE_LIST}" | grep " $__var " >/dev/null
	then
	    :
	else
	    MK_DEFINE_LIST="${MK_DEFINE_LIST} $__var "
	fi
    done
}

mk_export()
{
    for __var in "$@"
    do
	if echo "${MK_DEFINE_LIST}" | grep " $__var " >/dev/null
	then
	    :
	else
	    MK_DEFINE_LIST="${MK_DEFINE_LIST} $__var "
	fi
	
	if echo "${MK_EXPORT_LIST}" | grep " $__var " >/dev/null
	then
	    :
	else
	    MK_EXPORT_LIST="${MK_EXPORT_LIST} $__var "
	fi
    done
}

mk_make_define()
{
    printf "$1=$2\n" >&4
}

mk_check_program()
{
    __var="$1"
    shift
    __desc="$1"
    shift
    __val="`mk_deref "$__var"`"

    mk_log_start "$__desc: "
    if type "${__val}" >/dev/null 2>&1
    then
	mk_log_end "$__val"
	return 0
    else
	for __prog in "$@"
	do
	    if type "${__prog}" >/dev/null 2>&1
	    then
		mk_log_end "${__prog}"
		mk_assign "${__var}" "${__prog}"
		return 0
	    fi
	done
    fi

    mk_log_end "not found"
    return 1
}

mk_check_program_path()
{
    __var="$1"
    shift
    __desc="$1"
    shift
    __val="`mk_deref "$__var"`"

    mk_log_start "$__desc: "
    if __path="`mk_resolve_program_path "${__val}"`"
    then
	mk_log_end "$__path"
	mk_assign "${__var}" "${__path}"
	return 0
    else
	for __prog in "$@"
	do
	    if __path="`mk_resolve_program_path "${__prog}"`"
	    then
		mk_log_end "${__path}"
		mk_assign "${__var}" "${__path}"
		return 0
	    fi
	done
    fi

    mk_log_end "not found"
    return 1
}

mk_configure_help()
{
    @mk_generate_configure_help@
}

# Load manifest
. "${MK_MANIFEST_FILE}" || mk_fail "could not read ${MK_MANIFEST_FILENAME}"

# Save our arguments to write to the makefile
MK_CONFIGURE_ARGS=""
for __arg in "$@"
do
    MK_CONFIGURE_ARGS="$MK_CONFIGURE_ARGS `mk_quote "$__arg"`"
done

while [ -n "$1" ]
do
    _param="$1"
    shift
    
    case "${_param}" in
	--help)
	    mk_configure_help
	    exit 0
	    ;;
@mk_generate_configure_parse@
        *)
	    mk_fail "unrecognized option: $_param"
	    exit 1
	    ;;
    esac
done

mk_log "Configuring ${PROJECT_NAME}"
@mk_generate_configure_body@

mk_log "Creating ${MK_CONFIG_FILENAME}"
# Open config file
exec 4>${MK_CONFIG_FILE}

for __var in ${MK_DEFINE_LIST}
do
    __stmt="echo \"\$${__var}\""
    __val="`eval "$__stmt"`"
    echo "$__var=`mk_quote "$__val"`" >&4
done

echo "MK_EXPORT_LIST='`echo "${MK_EXPORT_LIST}" | sed -e 's/  *//' -e 's/^ //' -e 's/ $//'`'" >&4

# Close config file
exec 4>&-

mk_log "Creating ${MK_MAKEFILE_FILENAME}"
# Open up Makefile
exec 4>"${MK_MAKEFILE_FILE}"

# Write basic Makefile variables
mk_make_define MK_ROOT_DIR "${MK_ROOT_DIR}"
mk_make_define MK_WORK_DIR "${MK_WORK_DIR}"
mk_make_define ACTION      "\$(MK_WORK_DIR)/${MK_ACTION_FILENAME} --make \"\$(MAKE)\""
mk_make_define MK_CONFIGURE_ARGS "${MK_CONFIGURE_ARGS}"

# Decide if resources are present
if [ -d "${MK_RESOURCE_DIR}" ]
then
    MK_RESOURCE_YES=""
    MK_RESOURCE_NO="#"
else
    MK_RESOURCE_YES="#"
    MK_RESOURCE_NO=""
fi

echo "" >&4
sed \
    -e "s:@MK_WORK_DIR@:${MK_WORK_DIR}:g" \
    -e "s:@MK_RESOURCE_YES@:${MK_RESOURCE_YES}:g" \
    -e "s:@MK_RESOURCE_NO@:${MK_RESOURCE_NO}:g" \
    < "${MK_ROOT_DIR}/${MK_MAKEFILE_FILENAME}.in" >&4

# Close Makefile
exec 4>&-

mk_log "Creating ${MK_ACTION_FILENAME}"
# Open up action file
exec 4>"${MK_ACTION_FILE}"

echo "#!${MK_SHELL}" >&4
echo "MK_ROOT_DIR='${MK_ROOT_DIR}'" >&4
echo "MK_WORK_DIR='${MK_WORK_DIR}'" >&4

cat "${MK_ROOT_DIR}/${MK_ACTION_FILENAME}.in" >&4

# Close action file
exec 4>&-

# Set action file executable
chmod +x "${MK_ACTION_FILE}"

# Set up basic directory structure
for dir in ${MK_TARGET_DIRNAME} ${MK_BUILD_DIRNAME} ${MK_STAGE_DIRNAME} ${MK_DIST_DIRNAME}
do
    mk_log "Creating directory ${dir}"
    mkdir -p "${MK_WORK_DIR}/${dir}"
done
