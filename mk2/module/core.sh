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
			    __object_file="${MK_OBJECT_DIR}${MK_SUBDIR}/${1}"
			    case "$__object_file" in
				*'/../'*|*'/./'*)
				    result="@`echo "$__object_file" | sed -e 's|/\./|/|g' -e ':s;s|[^/]*/\.\./||g; t s'`"
				    ;;
				*)
				    result="@$__object_file"
				    ;;
			    esac
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
	# Change to the source subdirectory so that pathname expansion picks up source files.
	cd "${MK_SOURCE_DIR}${MK_SUBDIR}" || mk_fail "could not change to directory ${MK_SOURCE_DIR}${MK_SUBDIR}"
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
	    _mk_emitf '%s: %s\n\t@MK_SUBDIR='%s'; $(PREAMBLE); \\\n\t%s\n\n' "$__lhs" "${*# }" "${MK_SUBDIR}" "${__command# }"
	else
	    _mk_emitf '%s: %s\n\n' "$__lhs" "${*# }"
	fi
    }
    
    _mk_build_command()
    {
	for __param in "$@"
	do
	    case "$__param" in
		"%<"|"%>"|"%<<"|"%>>")
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
		    _mk_build_command_expand "${__param#\*}"
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
	unset OUTPUT _script
	mk_push_vars INPUT
	mk_parse_params
	
	[ -z "$OUTPUT" ] && OUTPUT="$1"
	[ -z "$INPUT" ] && INPUT="${OUTPUT}.in"

	for _export in ${MK_EXPORTS}
	do
	    # FIXME: deal with this a better way
	    if [ "$_export" = "MK_OPTIONS" ]
	    then
		continue
	    fi
	    mk_get "$_export"
	    case "$result" in
		*'|'*)
		    result="`echo "$result" | sed 's/|/\\\\|/g'`"
		    ;;
	    esac
	    _script="$_script;s|@$_export@|$result|g"
	done

	mk_resolve_file "${INPUT}"
	_input="$result"
	_output="${MK_OBJECT_DIR}${MK_SUBDIR}/${OUTPUT}"

	mk_mkdir "`dirname "$_output"`"
	sed "${_script#;}" < "$_input" > "${_output}.new" || mk_fail "failed to generate $_output"

	if [ -f "${_output}" ] && diff "${_output}" "${_output}.new" >/dev/null 2>&1
	then
	    rm -f "${_output}.new"
	else
	    mv "${_output}.new" "${_output}"
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
}
