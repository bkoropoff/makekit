DEPENDS="platform"

load()
{
    mk_resolve_target()
    {
	case "$1" in
	    "@"*)
		# Already an absolute target, leave as is
		result="$1"
		;;
	    *)
		# Resolve to absolute target
		case "$1" in
		    "/"*)
                        # Input is a product in the staging area
			result="@${MK_STAGE_DIR}$1"
			;;
		    *)
			__source_file="${MK_SOURCE_DIR}${MK_SUBDIR}/${1}"
			
			if [ -e "${__source_file}" ]
			then
                            # Input is a source file
			    result="@${__source_file}"
			else
                            # Input is an object file
			    # Makefile targets are matched verbatim, so
			    # we need to normalize the file path so that paths
			    # with '.' or '..' are reduced to the canonical form
			    # that appears on the left hand side of make rules.
			    mk_normalize_path "${MK_OBJECT_DIR}${MK_SUBDIR}/${1}"
			    result="@$result"
			fi
			;;
		esac
		;;
	esac
    }

    __mk_resolve()
    {
	# Accumulator variable
	__resolve_result=""
	# Save the resolve function and quote function
	__resolve_func="$2"
	__resolve_quote="$3"
	# Save the current directory
	__resolve_PWD="$PWD"
	if [ "$MK_SUBDIR" != ":" ]
	then
	# Change to the source subdirectory so that pathname expansion picks up source files.
	    cd "${MK_SOURCE_DIR}${MK_SUBDIR}" || mk_fail "could not change to directory ${MK_SOURCE_DIR}${MK_SUBDIR}"
	fi
	# Unquote the list into the positional parameters.  This will perform pathname expansion.
	mk_unquote_list "$1"
	# Restore the current directory
	cd "$__resolve_PWD"

	# For each expanded item
	for __resolve_item in "$@"
	do
	    # Resolve the item to a fully-qualified target/file using the resolve function
	    "$__resolve_func" "$__resolve_item"
	    # Quote the result using the quote function
	    "$__resolve_quote" "$result"
	    # Accumulate
	    __resolve_result="$__resolve_result $result"
	done

	# Strip off the leading space
	result="${__resolve_result# }"
    }

    mk_resolve_file()
    {
	mk_resolve_target "$@"
	result="${result#@}"
    }

    mk_resolve_targets()
    {
	__mk_resolve "$1" mk_resolve_target mk_quote
    }

    mk_resolve_files_space()
    {
	__mk_resolve "$1" mk_resolve_file mk_quote_space
    }

    mk_resolve_files()
    {
	__mk_resolve "$1" mk_resolve_file mk_quote
    }

    _mk_rule()
    {
	__lhs="$1"
	shift
	__command="$1"
	shift

	if [ -n "$__command" ]
	then
	    _mk_emitf '\n%s: %s\n\t@MK_SUBDIR='%s'; $(PREAMBLE); mk_system "%s"; \\\n\t%s\n' "$__lhs" "${*# }" "${MK_SUBDIR}" "$MK_SYSTEM" "${__command# }"
	else
	    _mk_emitf '\n%s: %s\n' "$__lhs" "${*# }"
	fi
    }
    
    _mk_build_command()
    {
	for __param in "$@"
	do
	    case "$__param" in
		"%<"|"%>"|"%<<"|"%>>"|"%;")
		    __command="$__command ${__param#%}"
		    ;;
		"@"*)
		    mk_quote "${__param#@}"
		    __command="$__command $result"
		    ;;
		"&"*)
		    mk_resolve_files "${__param#&}"
		    __command="$__command $result"
		    ;;
		"%"*)
		    mk_get "${__param#%}"

		    if [ -n "$result" ]
		    then
			mk_quote "${__param#%}=$result"
			__command="$__command $result"
		    fi
		    ;;
		"*"*)
		    _mk_build_command_expand "${__param#?}"
		    ;;
		*)
		    mk_quote "$__param"
		    __command="$__command $result"
		    ;;
	    esac
	done
    }

    _mk_build_command_expand()
    {
	
	mk_unquote_list "$1"
	_mk_build_command "$@"
    }

    mk_target()
    {
	mk_push_vars TARGET DEPS
	mk_parse_params

	__resolved=""
	__command=""

	_mk_build_command "$@"

	mk_resolve_files_space "$DEPS"
	__resolved="$result"

	mk_resolve_target "$TARGET"
	__target="$result"
	mk_quote_space "${result#@}"

	_mk_rule "$result" "${__command}" "${__resolved}"

	case "$__target" in
	    "@${MK_STAGE_DIR}"/*)
		mk_quote "${__target}"
		MK_SUBDIR_TARGETS="$MK_SUBDIR_TARGETS $result"
		;;
	esac

	mk_pop_vars

	result="$__target"
    }

    mk_install_file()
    {
	mk_push_vars FILE INSTALLFILE INSTALLDIR MODE
	mk_parse_params

	if [ -z "$INSTALLFILE" ]
	then
	    INSTALLFILE="$INSTALLDIR/$FILE"
	fi

	mk_resolve_target "$FILE"
	_resolved="$result"

	mk_target \
	    TARGET="$INSTALLFILE" \
	    DEPS="'$_resolved' $*" \
	    mk_run_script install %MODE '$@' "$_resolved"

	mk_add_all_target "$result"

	mk_pop_vars
    }

    mk_install_files()
    {
	mk_push_vars INSTALLDIR FILES MODE
	mk_parse_params

	unset _inputs

	for _file in ${FILES} "$@"
	do
	    mk_install_file \
		INSTALLDIR="$INSTALLDIR" \
		FILE="$_file" \
		MODE="$MODE"
	done

	mk_pop_vars
    }

    mk_output_file()
    {
	mk_push_vars INPUT OUTPUT
	mk_parse_params

	[ -z "$OUTPUT" ] && OUTPUT="$1"
	[ -z "$INPUT" ] && INPUT="${OUTPUT}.in"

	# Emit an awk script that will perform replacements
	{
	    echo "{"
	    
	    for _export in ${MK_EXPORTS}
	    do
		mk_get "$_export"
		mk_quote_c_string "$result"

		echo "    gsub(\"@${_export}@\", $result);"
	    done

	    echo "    print \$0;"
	    echo "}"
	} > ".awk.$$"

	mk_resolve_file "${INPUT}"
	_input="$result"
	mk_resolve_file "${OUTPUT}"
	_output="$result"

	mk_mkdir "${_output%/*}"
	awk -f ".awk.$$" < "$_input" > "${_output}.new" || mk_fail "awk error"
	mk_run_or_fail rm -f ".awk.$$"

	if [ -f "${_output}" ] && diff "${_output}" "${_output}.new" >/dev/null 2>&1
	then
	    mk_run_or_fail rm -f "${_output}.new"
	else
	    mk_run_or_fail mv "${_output}.new" "${_output}"
	fi

	mk_add_configure_output "${_output}"
	mk_add_configure_input "${_input}"

	mk_pop_vars
    }

    mk_run_script()
    {
	if _mk_find_resource "script/${1}.sh"
	then
	    shift
	    mk_parse_params
	    . "$result"
	    return "$?"
	else
	    mk_fail "could not find script: $1"
	fi
    }

    mk_add_all_target()
    {
	mk_quote "$1"
	MK_ALL_TARGETS="$MK_ALL_TARGETS $result"
    }

    mk_add_phony_target()
    {
	mk_quote "$1"
	MK_PHONY_TARGETS="$MK_PHONY_TARGETS $result"
    }

    
    mk_check_cache()
    {
	_mk_define_name "CACHED_$MK_SYSTEM"
	if mk_is_set "${1}__${result}"
	then
	    mk_get "${1}__${result}"
	    __value="${result}"
	    mk_declare_system_var "$1"
	    mk_set "$1" "$__value"
	    result="$__value"
	    return 0
	else
	    return 1
	fi
    }

    mk_cache()
    {
	_mk_define_name "CACHED_$MK_SYSTEM"
	MK_CACHE_VARS="$MK_CACHE_VARS ${1}__${result}"
	mk_set "${1}__${result}" "$2"
	mk_set "$1" "$2"
	mk_declare_system_var "$1"
    }

    _mk_save_cache()
    {
	{
	    for __var in ${MK_CACHE_VARS}
	    do
		mk_get "$__var"
		mk_quote "$result"
		echo "$__var=$result"
	    done
	    echo "MK_CACHE_VARS='${MK_CACHE_VARS# }'"
	} > .MetaKitCache
    }

    _mk_load_cache()
    {
	mk_safe_source "./.MetaKitCache"
    }

    mk_run_or_fail()
    {
	mk_msg_verbose "+ $*"
	
	___output=`"$@" 2>&1`
	___ret=$?
	
	if [ $___ret -ne 0 ]
	then
	    mk_msg "FAILED: $*"
	    echo "$___output"
	    exit 1
	fi
    }
}

configure()
{
    # Add a post-make() hook to write out a rule
    # to build all staging targets in that subdirectory
    mk_add_make_posthook _mk_core_write_subdir_rule
   
    # Emit the default target
    mk_target \
	TARGET="@default" \
	DEPS="@all"
    
    mk_add_phony_target "$result"

    # Load configure check cache if there is one
    _mk_load_cache
}

make()
{
    mk_target \
	TARGET="@all" \
	DEPS="$MK_ALL_TARGETS"

    mk_add_phony_target "$result"

    mk_target \
	TARGET="@clean" \
	mk_run_script clean

    mk_add_phony_target "$result"

    mk_target \
	TARGET="@scrub" \
	DEPS="@clean" \
	mk_run_script scrub

    mk_add_phony_target "$result"

    mk_target \
	TARGET="@nuke" \
	mk_run_script nuke

    mk_add_phony_target "$result"

    mk_target \
	TARGET="@.PHONY" \
	DEPS="$MK_PHONY_TARGETS"

    # Save configure check cache
    _mk_save_cache
}

_mk_core_write_subdir_rule()
{
    if [ "$MK_SUBDIR" != ":" -a "$MK_SUBDIR" != "" ]
    then
	_targets=""
	mk_unquote_list "$SUBDIRS"
	for __subdir in "$@"
	do
	    if [ "$__subdir" != "." ]
	    then
		mk_quote "@${MK_SUBDIR#/}/$__subdir"
		_targets="$_targets $result"
	    fi
	done
	_mk_emit "#"
	_mk_emit "# staging targets in ${MK_SUBDIR#/}"
	_mk_emit "#"
	_mk_emit ""

	mk_target \
	    TARGET="@${MK_SUBDIR#/}" \
	    DEPS="$MK_SUBDIR_TARGETS $_targets"

	mk_add_phony_target "$result"
    fi

    unset MK_SUBDIR_TARGETS
}
