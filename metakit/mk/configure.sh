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
    if mk_function_exists configure
    then
	_mk_configure_prehooks
	configure
	_mk_configure_posthooks
    fi
}

_mk_process_build_configure()
{
    unset -f option configure make
    unset SUBDIRS

    MK_CURRENT_FILE="${MK_SOURCE_DIR}$1/MetaKitBuild"
    MK_BUILD_FILES="$MK_BUILD_FILES $MK_CURRENT_FILE"

    mk_safe_source "$MK_CURRENT_FILE" || mk_fail "Could not read MetaKitBuild in ${1#/}"
    
    mk_function_exists option && option

    MK_SUBDIR="$1"
    mk_msg_verbose "configuring"
    _mk_configure_prehooks
    mk_function_exists configure && configure
    _mk_configure_posthooks
}

_mk_process_build_make()
{
    unset -f option configure make
    unset SUBDIRS

    MK_CURRENT_FILE="${MK_SOURCE_DIR}$1/MetaKitBuild"
    mk_safe_source "$MK_CURRENT_FILE" || mk_fail "Could not read MetaKitBuild in ${1#/}"
    
    MK_SUBDIR="$1"
    mk_msg_verbose "emitting make rules"
    _mk_make_prehooks
    mk_function_exists make && make
    _mk_make_posthooks
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

    _mk_end_exports

    # Run build functions for project
    _mk_process_build_recursive ''

    MK_SUBDIR=":"

    # Export summary variables
    exec 3>>".MetaKitExports"
    mk_quote "$MK_PRECIOUS_FILES"
    echo "MK_PRECIOUS_FILES=$result" >&3
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

    if [ "$VAR" = "MK_HELP" -a "$MK_HELP" != "yes" ]
    then
	_skip_help="yes"
    else
	_skip_help=""
    fi

    mk_unquote_list "$MK_OPTIONS"
    for _arg in "$@"
    do
	case "$_arg" in
	    "--$OPTION="*|"--with-$OPTION="*|"$VAR="*)
		mk_set "$VAR" "${_arg#*=}"
		break
		;;
	    "--$OPTION"|"--enable-$OPTION")
		mk_set "$VAR" "yes"
		break
		;;
	    "--no-$OPTION"|"--disable-$OPTION")
		mk_set "$VAR" "yes"
		break
		;;
	esac
    done

    if ! mk_is_set "$VAR"
    then
	if [ -n "$REQUIRED" ]
	then
	    mk_fail "Option not specified: $OPTION"
	else
	    mk_set "$VAR" "$DEFAULT"
	fi
    fi

    if [ "$MK_HELP" = "yes" -a -z "$_skip_help" ]
    then
	_mk_print_option
    fi

    mk_pop_vars
}

_mk_print_option()
{
    [ -z "$PARAM" ] && PARAM="value"
    [ -z "$HELP" ] && HELP="No help available"

    if [ -n "$OPTION" ]
    then
	_form="  --${OPTION}=${PARAM}"
    else
	_form="  ${VAR}=${PARAM}"
    fi
    _doc="$HELP"
    
    if mk_is_set "$VAR"
    then
	mk_get "$VAR"
	_doc="$_doc [$result]"
    elif [ -n "$DEFAULT" ]
    then
	_doc="$_doc [$DEFAULT]"
    fi
    
    if [ "${#_form}" -gt 40 ]
    then
	printf "%s\n%-40s%s\n" "$_form" "" "$_doc"
    else
	printf "%-40s%s\n" "$_form" "$_doc"
    fi
}

_mk_begin_exports()
{
    MK_EXPORT_FILES="$MK_EXPORT_FILES '$1'"
    MK_PRECIOUS_FILES="$MK_PRECIOUS_FILES $1"
    exec 3>"$1"
}

_mk_end_exports()
{
    for _export in ${MK_EXPORTS}
    do
	mk_get "$_export"
	mk_quote "$result"
	echo "$_export=$result" >&3
    done

    echo "MK_EXPORTS='$MK_EXPORTS'" >&3	
    exec 3>&-
}

_mk_restore_exports()
{
    unset ${MK_EXPORTS}

    . "$1"
}

mk_export()
{
    for _export in "$@"
    do
	case "$_export" in
	    *"="*)
		_val="${_export#*=}"
		_name="${_export%%=*}"
		mk_set "$_name" "$_val"
		_mk_contains "$_name" ${MK_EXPORTS} || MK_EXPORTS="$MK_EXPORTS $_name"
		;;
	    *)
		_mk_contains "$_export" ${MK_EXPORTS} || MK_EXPORTS="$MK_EXPORTS $_export"
		;;
	esac
    done
}

mk_add_configure_prehook()
{
    if ! _mk_contains "$1" "$_MK_CONFIGURE_PREHOOKS"
    then
	_MK_CONFIGURE_PREHOOKS="$_MK_CONFIGURE_PREHOOKS $1"
    fi
}

mk_add_configure_posthook()
{
    if ! _mk_contains "$1" "$_MK_CONFIGURE_POSTHOOKS"
    then
	_MK_CONFIGURE_POSTHOOKS="$_MK_CONFIGURE_POSTHOOKS $1"
    fi
}

mk_add_make_prehook()
{
    if ! _mk_contains "$1" "$_MK_MAKE_PREHOOKS"
    then
	_MK_MAKE_PREHOOKS="$_MK_MAKE_PREHOOKS $1"
    fi
}

mk_add_make_posthook()
{
    if ! _mk_contains "$1" "$_MK_MAKE_POSTHOOKS"
    then
	_MK_MAKE_POSTHOOKS="$_MK_MAKE_POSTHOOKS $1"
    fi
}

_mk_configure_prehooks()
{
    for _hook in ${_MK_CONFIGURE_PREHOOKS}
    do
	"$_hook"
    done
}

_mk_configure_posthooks()
{
    for _hook in ${_MK_CONFIGURE_POSTHOOKS}
    do
	"$_hook"
    done
}

_mk_make_prehooks()
{
    for _hook in ${_MK_MAKE_PREHOOKS}
    do
	"$_hook"
    done
}

_mk_make_posthooks()
{
    for _hook in ${_MK_MAKE_POSTHOOKS}
    do
	"$_hook"
    done
}

_mk_emit_make_header()
{
    _mk_emit "SHELL=${MK_SHELL}"
    _mk_emit "MK_HOME=${MK_HOME}"
    _mk_emit "MK_ROOT_DIR=${MK_ROOT_DIR}"
    _mk_emit "PREAMBLE=MK_HOME='\$(MK_HOME)'; MK_ROOT_DIR='\$(MK_ROOT_DIR)'; MK_VERBOSE='\$(V)'; . '\$(MK_HOME)/env.sh'"
}

_mk_emit_make_footer()
{
    # Run make functions for all modules in reverse order
    _mk_module_list
    _mk_reverse ${result}
    for _module in ${result}
    do
	MK_MSG_DOMAIN="$_module"
	unset -f make
	
	_mk_source_module "${_module}"
	
	if mk_function_exists make
	then
	    _mk_make_prehooks
	    make
	    _mk_make_posthooks
	fi
    done

    _mk_emit ""
    _mk_emit "Makefile:${MK_BUILD_FILES}${MK_CONFIGURE_INPUTS}"
    _mk_emitf "\t@\$(PREAMBLE); MK_SOURCE_DIR='%s'; MK_MSG_DOMAIN='metakit'; mk_msg 'regenerating Makefile'; set -- %s; . '\$(MK_HOME)/configure.sh'\n\n" "$MK_SOURCE_DIR" "$MK_OPTIONS"

    for _target in ${MK_CONFIGURE_OUTPUTS}
    do
	_mk_emit "${_target}: Makefile"
	_mk_emit ""
    done

    _mk_emit "sinclude .MetaKitDeps/*.dep"
    _mk_emit ""
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
	if [ -z "$1" ]
	then
	    echo "Options (${MK_SOURCE_DIR#*/}):"
	else
	    echo "Options (${1#/}):"
	fi
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
    _basic_options
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

_basic_options()
{
    mk_option \
	VAR=MK_SOURCE_DIR \
	OPTION=sourcedir \
	PARAM=path \
	DEFAULT='.' \
	HELP="Source directory"
   
    mk_option \
	VAR=MK_OBJECT_DIR \
	OPTION=objectdir \
	PARAM=path \
	DEFAULT='object' \
	HELP="Intermediate file directory"
    
    mk_option \
	VAR=MK_STAGE_DIR \
	OPTION=stagedir \
	PARAM=path \
	DEFAULT='stage' \
	HELP="Staging directory"
    
    mk_option \
	VAR=MK_RUN_DIR \
	OPTION=rundir \
	PARAM=path \
	DEFAULT='run' \
	HELP="Build tool install directory"
	
    mk_option \
	VAR=MK_HELP \
	OPTION=help \
	PARAM='yes|no' \
	DEFAULT='no' \
	HELP="Show this help"
}

# Save our parameters for later use
mk_quote_list "$@"
MK_OPTIONS="$result"

# Set up basic variables
MK_ROOT_DIR="$PWD"
_basic_options

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
exec 6>.Makefile.new
MK_MAKEFILE_FD=6

# Export basic variables
mk_export MK_HOME MK_SHELL MK_ROOT_DIR MK_SOURCE_DIR MK_OBJECT_DIR MK_STAGE_DIR MK_RUN_DIR MK_OPTIONS MK_SEARCH_DIRS

# Emit Makefile header
_mk_emit_make_header

# Process build files
_mk_process_build

# Emit Makefile footer
_mk_emit_make_footer

# Close and atomically replace Makefile
exec 6>&-
mv ".Makefile.new" "Makefile" || mk_fail "could not replace Makefile"

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
