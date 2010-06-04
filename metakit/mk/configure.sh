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

_mk_process_build_module()
{
    _mk_find_resource "module/$1.sh"

    MK_CURRENT_FILE="$result"
    MK_BUILD_FILES="$MK_BUILD_FILES $MK_CURRENT_FILE"

    unset -f option configure make
    unset SUBDIRS

    _mk_source_module "$1"
    
    mk_function_exists option && option
    mk_function_exists configure && configure
    mk_function_exists make && make
}

_mk_process_build_configure()
{
    unset -f option configure make
    unset SUBDIRS

    MK_CURRENT_FILE="${MK_SOURCE_DIR}$1/MetaKitBuild"
    MK_BUILD_FILES="$MK_BUILD_FILES $MK_CURRENT_FILE"

    mk_safe_source "$MK_CURRENT_FILE" || mk_fail "Could not read MetaKitBuild in ${1#/}"
    
    mk_function_exists option && option

    if mk_function_exists configure
    then
	MK_SUBDIR="$1"
	mk_msg_verbose "configuring"
	configure
    fi
}

_mk_process_build_make()
{
    unset -f option configure make
    unset SUBDIRS

    MK_CURRENT_FILE="${MK_SOURCE_DIR}$1/MetaKitBuild"
    mk_safe_source "$MK_CURRENT_FILE" || mk_fail "Could not read MetaKitBuild in ${1#/}"
    
    if mk_function_exists make
    then
	MK_SUBDIR="$1"
	
	mk_msg_verbose "emitting make rules"
	make
    fi
}

_mk_process_build_recursive()
{
    mk_push_vars MK_MSG_DOMAIN MK_CURRENT_FILE _preorder_make

    MK_MSG_DOMAIN="${1#/}"

    if [ -z "$MK_MSG_DOMAIN" ]
    then
	MK_MSG_DOMAIN="$(cd "${MK_SOURCE_DIR}" && basename "$(pwd)")"
    fi

    mk_mkdir "${MK_OBJECT_DIR}$1"

    # Begin exports file
    _mk_begin_exports "${MK_OBJECT_DIR}$1/.MetaKitExports"

    # Process configure stage
    _mk_process_build_configure "$1"

    # Finish exports files
    _mk_end_exports

    for _dir in ${SUBDIRS}
    do
	if [ "$_dir" = "." ]
	then
	    # Process make stage before children
	    _preorder_make=yes
	    _mk_process_build_make "$1"
	else
	    _mk_process_build_recursive "$1/${_dir}"
	    _mk_restore_exports "${MK_OBJECT_DIR}${1}/.MetaKitExports"
	fi
    done

    # Process make stage if we didn't do it before child directories
    if [ -z "$_preorder_make" ]
    then
	_mk_process_build_make "$1"
    fi

    mk_pop_vars
}

_mk_process_build()
{
    MK_SUBDIR=":"

    # Run build functions for all modules
    _mk_module_list
    for _module in ${result}
    do
	MK_MSG_DOMAIN="$_module"
	_mk_process_build_module "${_module}"
    done

    # Run build functions for project
    _mk_process_build_recursive ''

    # Export summary variables
    exec 3>>".MetaKitExports"
    mk_export MK_PRECIOUS_FILES
    exec 3>&-;
}

mk_option()
{
    unset _found
    mk_push_vars TYPE OPTION DEFAULT VAR PARAM HELP REQUIRED
    mk_parse_params
    
    [ -z "$VAR" ] && VAR="$1"
    [ -z "$OPTION" ] && OPTION="$2"
    [ -z "$DEFAULT" ] && DEFAULT="$3"

    _IFS="$IFS"
    IFS='
'

    mk_unquote_list "$MK_OPTIONS"
    for _arg in "$@"
    do
	case "$_arg" in
	    "--$OPTION="*|"--with-$OPTION="*)
		mk_set "$VAR" "${_arg#*=}"
		_found=yes
		break
		;;
	    "--$OPTION"|"--enable-$OPTION")
		mk_set "$VAR" "yes"
		_found=yes
		break
		;;
	    "--no-$OPTION"|"--disable-$OPTION")
		mk_set "$VAR" "yes"
		_found=yes
		break
		;;
	esac
    done

    IFS="$_IFS"

    if [ -z "$_found" ]
    then
	if [ -n "$REQUIRED" ]
	then
	    mk_fail "Option not specified: $OPTION"
	else
	    mk_set "$VAR" "$DEFAULT"
	fi
    fi

    if [ "$VAR" != "MK_HELP" -a "$MK_HELP" = "yes" ]
    then
	_mk_print_option
    fi

    mk_pop_vars
}

_mk_print_option()
{
    [ -z "$PARAM" ] && PARAM="$VAR"
    [ -z "$HELP" ] && HELP="No help available"

    _form="  --${OPTION}=${PARAM}"
    _doc="$HELP"
    
    if [ -n "$_found" ]
    then
	mk_get "$VAR"
	_doc="$_doc [$result]"
    elif [ -n "$DEFAULT" ]
    then
	_doc="$_doc [$DEFAULT]"
    fi
    
    if [ "${#_form}" -gt 40 ]
    then
	printf "%s\n%-40s%s\bn" "$_form" "" "$_doc"
    else
	printf "%-40s%s\n" "  --${OPTION}=${PARAM}" "$_doc"
    fi
}

_mk_begin_exports()
{
    MK_EXPORT_FILES="$MK_EXPORT_FILES '$1'"
    MK_PRECIOUS_FILES="$MK_PRECIOUS_FILES $1"
    exec 3>"$1"

    for _export in ${MK_EXPORTS}
    do
	mk_get "$_export"
	mk_quote "$result"
	echo "$_export=$result" >&3
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
		mk_set "$_name" "$_val"
		MK_EXPORTS="$MK_EXPORTS $_name"
		mk_quote "$_val"
		echo "$_name=$result" >&3
		;;
	    *)
		mk_get "$_export"
		MK_EXPORTS="$MK_EXPORTS $_export"
		mk_quote "$result"
		echo "$_export=$result" >&3
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
	    result="$2"
	else
	    mk_get "$_name"
	fi
	
	echo "#define $_name $result" >&5
    fi
}

_mk_close_config_header()
{
    if [ -n "${MK_CONFIG_HEADER}" ]
    then
	cat >&5 <<EOF

#endif
EOF
	exec 5>&-

	if [ -f "${MK_CONFIG_HEADER}" ] && diff "${MK_CONFIG_HEADER}" "${MK_CONFIG_HEADER}.new" >/dev/null 2>&1
	then
	    # The config header has not changed, so don't touch the timestamp on the file */
	    rm -f "${MK_CONFIG_HEADER}.new"
	else
	    mv "${MK_CONFIG_HEADER}.new" "${MK_CONFIG_HEADER}"
	fi

	MK_CONFIG_HEADER=""
    fi
}

mk_config_header()
{
    mk_push_vars HEADER
    mk_parse_params

    _mk_close_config_header

    [ -z "$HEADER" ] && HEADER="$1"

    MK_CONFIG_HEADER="${MK_OBJECT_DIR}${MK_SUBDIR}/${HEADER}"
    MK_CONFIG_HEADERS="$MK_CONFIG_HEADERS '$MK_CONFIG_HEADER'"

    mkdir -p "${MK_CONFIG_HEADER}%/*"

    mk_msg "config header ${MK_CONFIG_HEADER#${MK_OBJECT_DIR}/}"

    exec 5>"${MK_CONFIG_HEADER}.new"

    cat >&5 <<EOF
/* Generated by MetaKit */

#ifndef __MK_CONFIG_H__
#define __MK_CONFIG_H__

EOF

    mk_add_configure_output "$MK_CONFIG_HEADER"

    mk_pop_vars
}

_mk_emit_make_header()
{
    _mk_emit "SHELL=${MK_SHELL}"
    _mk_emit "MK_HOME=${MK_HOME}"
    _mk_emit "MK_ROOT_DIR=${MK_ROOT_DIR}"
    _mk_emit "PREAMBLE=MK_HOME='\$(MK_HOME)'; MK_ROOT_DIR='\$(MK_ROOT_DIR)'; MK_VERBOSE='\$(V)'; . '\$(MK_HOME)/env.sh'"
    _mk_emit ""
    _mk_emit "default: all"
    _mk_emit ""
}

_mk_emit_make_footer()
{
    # Run postmake functions for all modules
    _mk_module_list
    for _module in ${result}
    do
	MK_MSG_DOMAIN="$_module"
	unset -f postmake

	_mk_source_module "${_module}"

	mk_function_exists postmake && postmake
    done

    _mk_emit "all:${MK_ALL_TARGETS}"
    _mk_emit ""

    _mk_emit "clean:"
    _mk_emitf "\t@\$(PREAMBLE); mk_run_script clean\n\n"

    _mk_emit "scrub: clean"
    _mk_emitf "\t@\$(PREAMBLE); mk_run_script scrub\n\n"

    _mk_emit "nuke:"
    _mk_emitf "\t@\$(PREAMBLE); mk_run_script nuke\n\n"

    _mk_emit "regen:"
    _mk_emitf "\t@\$(PREAMBLE); mk_run_script regen\n\n"

    _mk_emit "Makefile:${MK_BUILD_FILES}${MK_CONFIGURE_INPUTS}"
    _mk_emitf "\t@\$(PREAMBLE); mk_run_script regen\n\n"

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
    MK_ALL_TARGETS="$MK_ALL_TARGETS ${1#@}"
}

mk_add_configure_output()
{
    MK_CONFIGURE_OUTPUTS="$MK_CONFIGURE_OUTPUTS $1"
    MK_PRECIOUS_FILES="$MK_PRECIOUS_FILES $1"
}

mk_add_configure_input()
{
    MK_CONFIGURE_INPUTS="$MK_CONFIGURE_INPUTS $1"
}

mk_help_recursive()
{
    unset -f option
    unset SUBDIRS
    
    mk_safe_source "${MK_SOURCE_DIR}${1}/MetaKitBuild" || mk_fail "Could not read MetaKitBuild in ${1#/}"

    if mk_function_exists option
    then
	echo "Options (${1#/}):"
	option
	echo ""
    fi
    
    for _dir in ${SUBDIRS}
    do
	if [ "$_dir" != "." ]
	then
	    mk_help_recursive "$1/${_dir}"
	fi
    done
}

mk_help()
{
    echo "Usage: mkconfigure [ options ... ]"
    echo "Options:"
    printf "%-40s%s\n" "  --help"                    "Show this help"
    printf "%-40s%s\n" "  --sourcedir=MK_SOURCE_DIR" "Source directory [$MK_SOURCE_DIR]"
    printf "%-40s%s\n" "  --objectdir=MK_OBJECT_DIR" "Object directory [$MK_OBJECT_DIR]"
    printf "%-40s%s\n" "  --stagedir=MK_STAGE_DIR"   "Staging directory [$MK_STAGE_DIR]"
    echo ""

    _mk_module_list
    for _module in ${result}
    do
	unset -f option

	_mk_source_module "${_module}"

	if mk_function_exists "option"
	then
	    echo "Options ($_module):"
	    option
	    echo ""
	fi
    done

    if [ -f "${MK_SOURCE_DIR}/MetaKitBuild" ]
    then
	mk_help_recursive ""
    fi
}

# Save our parameters for later use
mk_quote_list "$@"
MK_OPTIONS="$result"

# Set up basic variables
MK_ROOT_DIR="$PWD"
mk_option MK_SOURCE_DIR sourcedir '.'
mk_option MK_OBJECT_DIR objectdir 'object'
mk_option MK_STAGE_DIR stagedir 'stage'
mk_option MK_HELP help 'no'

MK_SEARCH_DIRS="${MK_HOME}"

# Look for local modules and scripts in source directory
if [ -d "${MK_SOURCE_DIR}/mklocal" ]
then
    MK_SEARCH_DIRS="${MK_SEARCH_DIRS} ${MK_SOURCE_DIR}/mklocal"
fi

MK_MSG_DOMAIN="metakit"

if [ "$MK_HELP" = "yes" ]
then
    mk_help
    exit 0
fi

# Open log file
exec 4>config.log
MK_LOG_FD=4

mk_msg "initializing"

# Load all modules
_mk_load_modules

MK_MSG_DOMAIN="metakit"

# Begin saving exports
_mk_begin_exports ".MetaKitExports"

# Open Makefile for writing
exec 6>Makefile
MK_MAKEFILE_FD=6

# Export basic variables
export MK_HOME MK_SHELL MK_ROOT_DIR
mk_export MK_HOME MK_SHELL MK_ROOT_DIR MK_SOURCE_DIR MK_OBJECT_DIR MK_STAGE_DIR MK_OPTIONS MK_SEARCH_DIRS

# Emit Makefile header
_mk_emit_make_header

# Process build files
_mk_process_build

# Emit Makefile footer
_mk_emit_make_footer

# Close Makefile
exec 6>&-

# Close config header file if one was open
_mk_close_config_header

# Close log file
exec 4>&-

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