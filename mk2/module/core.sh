load()
{
    mk_resolve_input()
    {
	mk_fail "do not call mk_resolve_input"
    }

    mk_resolve_target()
    {
	case "$1" in
	    "@"*)
		# Resolve to absolute target
		set "${1#@}"
		case "$1" in
		    "/"*)
                        # Input is a product in the staging area
			result="${MK_STAGE_DIR}$1"
			;;
		    *)
			__source_file="${MK_SOURCE_DIR}${MK_SUBDIR}/${1}"
			
			if [ -e "${__source_file}" ]
			then
                            # Input is a source file
			    result="${__source_file}"
			else
                            # Input is an object file
			    __object_file="${MK_OBJECT_DIR}${MK_SUBDIR}/${1}"
			    case "$__object_file" in
				*'/../'*|*'/./'*)
				    result=`echo "$__object_file" | sed -e 's|/\./|/|g' -e ':s;s|[^/]*/\.\./||g; t s'`
				    ;;
				*)
				    result="$__object_file"
				    ;;
			    esac
			fi
			;;
		esac
		;;
	    *)
		# Leave as-is
		result="$1"
		;;
	esac
    }

    _mk_rule()
    {
	__lhs="$1"
	shift
	__command="$1"
	shift

	if [ -n "$__command" ]
	then
	    _mk_emitf '%s: %s\n\t@MK_SUBDIR='%s'; \\\n\t%s\n\n' "$__lhs" "$*" "${MK_SUBDIR}" "$__command"
	else
	    _mk_emitf '%s: %s\n\n' "$__lhs" "$*"
	fi
    }
    
    mk_target()
    {
	mk_push_vars COMMAND FUNCTION TARGET DEPS
	mk_parse_params

	__resolved=""

	if [ -n "$FUNCTION" ]
	then
	    COMMAND="\$(FUNCTION) $FUNCTION"
	fi

	for __dep in ${DEPS} "$@"
	do
	    mk_resolve_target "$__dep"
	    __resolved="$__resolved $result"
	done

	mk_resolve_target "$TARGET"

	_mk_rule "$result" "${COMMAND}" ${__resolved}

	mk_pop_vars
    }

    mk_stage()
    {
	mk_fail "do not call mk_stage"
    }
    
    mk_object()
    {
	mk_fail "do not call mk_object"
    }

    mk_install_file()
    {
	mk_push_vars FILE INSTALLFILE INSTALLDIR MODE
	mk_parse_params

	if [ -z "$INSTALLFILE" ]
	then
	    INSTALLFILE="$INSTALLDIR/$FILE"
	fi

	mk_resolve_target "@$FILE"
	_resolved="$result"
	mk_command_params MODE
	_params="$result"

	mk_target \
	    TARGET="@$INSTALLFILE" \
	    COMMAND="\$(SCRIPT) install $_params \$@ '$_resolved'" \
	    "$_resolved" "$@"

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

	mk_resolve_target "@${INPUT}"
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
	env MK_SUBDIR="$MK_SUBDIR" ${MK_SHELL} "${MK_HOME}/script.sh" "$@"
    }
}
