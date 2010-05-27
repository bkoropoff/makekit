load()
{
    mk_resolve_input()
    {
	case "$1" in
	    "/"*)
		# Input is a product in the staging area
		RET="${MK_STAGE_DIR}$1"
		;;
	    *)
		__source_file="${MK_SOURCE_DIR}${MK_SUBDIR}/${1}"
		
		if [ -e "${__source_file}" ]
		then
		    # Input is a source file
		    RET="${__source_file}"
		else
		    # Input is an object file
		    __object_file="${MK_OBJECT_DIR}${MK_SUBDIR}/${1}"
		    case "$__object_file" in
			*'/../'*|*'/./'*)
			    RET=`echo "$__object_file" | sed -e 's|/\./|/|g' -e ':s;s|[^/]*/\.\./||g; t s'`
			    ;;
			*)
			    RET="$__object_file"
			    ;;
		    esac
		fi
		;;
	esac
    }

    _mk_rule()
    {
	_lhs="$1"; shift
	_command="$1"; shift
	_inputs=""

	for _input in "$@"
	do
	    mk_resolve_input "$_input"
	    _inputs="$_inputs $RET"
	done

	if [ -n "$_command" ]
	then
	    _mk_emitf '%s:%s\n\t@MK_SUBDIR='%s'; \\\n\t%s\n\n' "$_lhs" "${_inputs}" "${MK_SUBDIR}" "$_command"
	else
	    _mk_emitf '%s:%s\n\n' "$_lhs" "${_inputs}"
	fi
    }
    
    mk_stage()
    {
	unset OUTPUT
	mk_push_vars COMMAND FUNCTION
	mk_parse_params

	if [ -n "$FUNCTION" ]
	then
	    COMMAND="\$(FUNCTION) ${MK_SOURCE_DIR}${MK_SUBDIR}/MetaKitBuild $FUNCTION"
	fi
	
	_mk_rule "${MK_STAGE_DIR}${OUTPUT}" "${COMMAND}" "$@"

	mk_add_scrub_target "$OUTPUT"
	mk_add_all_target "$OUTPUT"

	mk_pop_vars
    }
    
    mk_object()
    {
	unset OUTPUT
	mk_push_vars COMMAND FUNCTION
	mk_parse_params

	if [ -n "$FUNCTION" ]
	then
	    COMMAND="\$(FUNCTION) ${MK_SOURCE_DIR}${MK_SUBDIR}/MetaKitBuild $FUNCTION"
	fi
	
	_mk_rule "${MK_OBJECT_DIR}${MK_SUBDIR}/${OUTPUT}" "${COMMAND}" "$@"
	
	mk_add_clean_target "$OUTPUT"

	mk_pop_vars
    }

    mk_install_file()
    {
	mk_push_vars FILE INSTALLFILE INSTALLDIR MODE
	mk_parse_params

	if [ -z "$INSTALLFILE" ]
	then
	    INSTALLFILE="$INSTALLDIR/$FILE"
	fi

	mk_resolve_input "$FILE"
	_resolved="$RET"
	mk_command_params MODE
	_params="$RET"

	mk_stage \
	    OUTPUT="$INSTALLFILE" \
	    COMMAND="\$(SCRIPT) install $_params \$@ '$_resolved'" \
	    "$FILE" "$@"

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
	    case "$RET" in
		*'|'*)
		    RET="`echo "$RET" | sed 's/|/\\\\|/g'`"
		    ;;
	    esac
	    _script="$_script;s|@$_export@|$RET|g"
	done

	mk_resolve_input "${INPUT}"
	_input="$RET"
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
