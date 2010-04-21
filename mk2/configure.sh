#!/bin/sh

. "${MK_HOME}/mk.sh" || exit 1

_mk_emit()
{
    echo "$@" >&6
}

_mk_emitf()
{
    printf "$@" >&6
}

_mk_process_build_file()
{
    MK_BUILD_FILES="$MK_BUILD_FILES $1"

    unset configure make SUBDIRS

    . "$1" || mk_fail "Could not read $1"
    
    case "`type configure 2>&1`" in
	*"function"*)
	    configure
    esac

    case "`type make 2>&1`" in
	*"function"*)
	    make
    esac
}

_mk_process_build_recursive()
{
    MK_SUBDIR="$1"
    SOURCEDIR="${MK_SOURCE_DIR}${MK_SUBDIR}"
    OBJECTDIR="${MK_OBJECT_DIR}${MK_SUBDIR}"
    MK_LOG_DOMAIN="${MK_SUBDIR#/}"

    export MK_SUBDIR

    if [ -z "$MK_LOG_DOMAIN" ]
    then
	MK_LOG_DOMAIN="`(cd "${MK_SOURCE_DIR}" && basename "$(pwd)")`"
    fi

    mkdir -p "${OBJECTDIR}" || mk_fail "Could not create directory: ${OBJECTDIR}"

    # Begin exports file
    _mk_begin_exports "${MK_OBJECT_DIR}${MK_SUBDIR}/.MetaKitExports"

    # Process build file
    _mk_process_build_file "${MK_SOURCE_DIR}${MK_SUBDIR}/MetaKitBuild"

    # Finish exports files
    _mk_end_exports

    for _dir in ${SUBDIRS}
    do
	_mk_process_build_recursive "$1/${_dir}"

        # Restore exports
	_mk_restore_exports "${MK_OBJECT_DIR}${1}/.MetaKitExports"
    done
}

_mk_process_build()
{
    MK_SUBDIR=":"

    export MK_SUBDIR

    # Run build functions for all modules
    for _module in `_mk_modules`
    do
	MK_LOG_DOMAIN="$_module"
	_mk_process_build_file "${MK_HOME}/module/${_module}.sh"
    done

    # Run build functions for project
    _mk_process_build_recursive ''
}

mk_option()
{
    _name="$1"
    _default="$2"

    _IFS="$IFS"
    IFS='
'
    for _arg in ${MK_OPTIONS}
    do
	case "$_arg" in
	    "--${_name}="*)
		echo "$_arg" | sed 's/^[^=]*=//'
		IFS="$_IFS"
		return 0
		;;
	esac
    done

    IFS="$_IFS"

    if [ "$#" -eq '2' ]
    then
	echo "$_default"
    else
	mk_fail "Option not specified: $_name"
    fi

    set +x
}

_mk_begin_exports()
{
    MK_EXPORT_FILES="$MK_EXPORT_FILES '$1'"
    exec 3>"$1"

    for _export in ${MK_EXPORTS}
    do
	_val="`_mk_deref "$_export"`"
	echo "$_export=`_mk_quote_shell "$_val"`" >&3	
    done
}

_mk_end_exports()
{
    echo "MK_EXPORTS='$MK_EXPORTS'" >&3	
    exec 3>&-
}

_mk_restore_exports()
{
    unset ${MK_EXPORTS}

    . "$1"

    export ${MK_EXPORTS}
}

mk_export()
{
    for _export in "$@"
    do
	case "$_export" in
	    *"="*)
		_val="${1#*=}"
		_name="${1%%=*}"
		_mk_set "$_name" "$_val"
		export "$_name"
		MK_EXPORTS="$MK_EXPORTS $_name"
		echo "$_name=`_mk_quote_shell "$_val"`" >&3
		;;
	    *)
		_val="`_mk_deref $_export`"
		export "$_export"
		MK_EXPORTS="$MK_EXPORTS $_export"
		echo "$_export=`_mk_quote_shell "$_val"`" >&3
		;;
	esac
    done
}

mk_define()
{
    if [ -n "$MK_CONFIG_HEADER" ]
    then
	_name="$1"
	
	if [ "$#" -eq '2' ]
	then
	    _val="$2"
	else
	    _val="`_mk_deref "$_name"`"
	fi
	
	echo "#define $_name $_val" >&5
    fi
}

mk_config_header()
{
    unset HEADER

    _mk_args

    [ -z "$HEADER" ] && HEADER="$1"

    if [ -n "${MK_CONFIG_HEADER}" ]
    then
	exec 5>&-

	if [ -f "${MK_CONFIG_HEADER}" ] && diff "${MK_CONFIG_HEADER}" "${MK_CONFIG_HEADER}.new" >/dev/null 2>&1
	then
	    # The config header has not changed, so don't touch the timestamp on the file */
	    rm -f "${MK_CONFIG_HEADER}.new"
	else
	    mv "${MK_CONFIG_HEADER}.new" "${MK_CONFIG_HEADER}"
	fi
    fi

    MK_CONFIG_HEADER="${MK_OBJECT_DIR}${MK_SUBDIR}/${HEADER}"
    MK_CONFIG_HEADERS="$MK_CONFIG_HEADERS '$MK_CONFIG_HEADER'"

    mkdir -p "`dirname "${MK_CONFIG_HEADER}"`"

    mk_log "creating config header ${MK_CONFIG_HEADER#${MK_OBJECT_DIR}/}"

    exec 5>"${MK_CONFIG_HEADER}.new"
}

_mk_emit_make_header()
{
    _mk_emit "MK_HOME='${MK_HOME}'"
    _mk_emit "MK_SCRIPT_DIR='${MK_SCRIPT_DIR}'"
    _mk_emit "MK_ROOT_DIR='${MK_ROOT_DIR}'"
    _mk_emit "MK_SHELL=/bin/sh"
    _mk_emit "SCRIPT=exec env MK_HOME='\$(MK_HOME)' MK_ROOT_DIR='\$(MK_ROOT_DIR)' MK_SUBDIR=\$\${MK_SUBDIR} \$(MK_SHELL) \$(MK_SCRIPT_DIR)"
    _mk_emit ""
    _mk_emit "default: all"
    _mk_emit ""
}

_mk_emit_make_footer()
{
    # Run postmake functions for all modules
    for _module in `_mk_modules`
    do
	MK_LOG_DOMAIN="$_module"
	unset postmake

	. "${MK_HOME}/module/${_module}.sh"

	case "`type postmake 2>&1`" in
	    *"function"*)
		postmake
	esac
    done

    _mk_emit "all:${MK_ALL_TARGETS}"
    _mk_emit ""
    _mk_emit "clean:"
    _mk_emitf "\t@\$(SCRIPT)/clean.sh %s\n\n" "'.MetaKitDeps'${MK_CLEAN_TARGETS} "

    _mk_emit "scrub: clean"
    _mk_emitf "\t@\$(SCRIPT)/clean.sh%s\n\n" "${MK_SCRUB_TARGETS}"

    _mk_emit "nuke: scrub"
    _mk_emitf "\t@\$(SCRIPT)/clean.sh 'Makefile'%s\n\n" "${MK_EXPORT_FILES}${MK_CONFIG_HEADERS}${MK_CONFIGURE_OUTPUTS}"

    _mk_emit "regen:"
    _mk_emitf "\t@\$(SCRIPT)/regen.sh\n\n"

    _mk_emit "Makefile:${MK_BUILD_FILES}${MK_CONFIGURE_INPUTS}" "${MK_HOME}/module/"*.sh
    _mk_emitf "\t@\$(SCRIPT)/regen.sh\n\n"

    for _target in ${MK_CONFIGURE_OUTPUTS}
    do
	_mk_emit "${_target}: Makefile"
	_mk_emit ""
    done

    _mk_emit "sinclude .MetaKitDeps/*.dep"
    _mk_emit ""

    _mk_emit ".PHONY: default all clean scrub regen"
}

mk_add_all_target()
{
    MK_ALL_TARGETS="$MK_ALL_TARGETS ${MK_STAGE_DIR}$1"
}

mk_add_clean_target()
{
    MK_CLEAN_TARGETS="$MK_CLEAN_TARGETS '${MK_OBJECT_DIR}${MK_SUBDIR}/$1'"
}

mk_add_scrub_target()
{
    MK_SCRUB_TARGETS="$MK_SCRUB_TARGETS '${MK_STAGE_DIR}$1'"
}

mk_add_configure_output()
{
    MK_CONFIGURE_OUTPUTS="$MK_CONFIGURE_OUTPUTS $1"
}

mk_add_configure_input()
{
    MK_CONFIGURE_INPUTS="$MK_CONFIGURE_INPUTS $1"
}

# Save our parameters for later use
MK_OPTIONS="`( for i in "$@"; do echo "$i"; done )`"

MK_LOG_DOMAIN="metakit"

mk_log "initializing"

# Load all modules
_mk_load_modules

# Set up basic variables
MK_ROOT_DIR="`pwd`"
MK_SOURCE_DIR="`mk_option sourcedir 'source'`"
MK_OBJECT_DIR="`mk_option objectdir 'object'`"
MK_STAGE_DIR="`mk_option stagedir 'stage'`"

# Begin saving exports
_mk_begin_exports ".MetaKitExports"

# Open verbose log file
exec 4>config.log

# Open Makefile for writing
exec 6>Makefile

# Export basic variables
mk_export MK_HOME MK_ROOT_DIR MK_SOURCE_DIR MK_OBJECT_DIR MK_STAGE_DIR MK_OPTIONS

# Emit Makefile header
_mk_emit_make_header

# Process build files
_mk_process_build

# Emit Makefile footer
_mk_emit_make_footer

# Close Makefile
exec 6>&-

# Close config header file if one was open
if [ -n "$MK_CONFIG_HEADER" ]
then
    exec 5>&-
fi

# Dispense wisdom
_fortunes="${MK_HOME}/fortunes"
if [ -f "$_fortunes" ]
then
    _line="`tail -n $(_mk_random 1 $(wc -l "$_fortunes")) "$_fortunes" | head -n 1`"
    _line="`eval echo "\"$_line\""`"
    echo ""
    echo "---"
    echo "$_line"
    echo "---"
fi
