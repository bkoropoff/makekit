load()
{
    _mk_resolve_input()
    {
	case "$1" in
	    "/"*)
		# Input is a product in the staging area
		echo "${MK_STAGE_DIR}$1"
		;;
	    *)
		_source_file="${MK_SOURCE_DIR}${MK_SUBDIR}/${1}"
		
		if [ -e "${_source_file}" ]
		then
		    # Input is a source file
		    echo "${_source_file}"
		else
		    # Input is an object file
		    _object="${MK_OBJECT_DIR}${MK_SUBDIR}/${1}"
		    case "$_object" in
			*'/../'*|*'/./'*)
			    echo "$_object" | sed -e 's|/\./|/|g' -e ':s;s|[^/]*/\.\./||g; t s'
			    ;;
			*)
			    echo "$_object"
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
	    _inputs="$_inputs `_mk_resolve_input "$_input"`"
	done

	_mk_emitf '%s:%s\n\t@MK_SUBDIR='%s'; \\\n\t%s\n\n' "$_lhs" "${_inputs}" "${MK_SUBDIR}" "$_command"
    }
    
    mk_stage()
    {
	unset OUTPUT
	mk_push_vars COMMAND
	mk_parse_params
	
	_mk_rule "${MK_STAGE_DIR}${OUTPUT}" "${COMMAND}" "$@"

	mk_add_scrub_target "$OUTPUT"
	mk_add_all_target "$OUTPUT"

	mk_pop_vars
    }
    
    mk_object()
    {
	unset OUTPUT
	mk_push_vars COMMAND
	mk_parse_params
	
	_mk_rule "${MK_OBJECT_DIR}${MK_SUBDIR}/${OUTPUT}" "${COMMAND}" "$@"
	
	mk_add_clean_target "$OUTPUT"

	mk_pop_vars
    }

    mk_install_file()
    {
	mk_push_vars FILE INSTALLFILE INSTALLDIR MODE
	mk_parse_params

	_input="`_mk_resolve_input "$FILE"`"

	if [ -z "$INSTALLFILE" ]
	then
	    INSTALLFILE="$INSTALLDIR/$FILE"
	fi

	mk_stage \
	    OUTPUT="$INSTALLFILE" \
	    COMMAND="\$(SCRIPT)/install.sh `mk_command_params MODE` \$@ '$_input'" \
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
	    _val="`_mk_deref "$_export"`"
	    case "$_val" in
		*'|'*)
		    _val="`echo "$_val" | sed 's/|/\\\\|/g'`"
		    ;;
	    esac
	    _script="$_script;s|@$_export@|$_val|g"
	done

	_input="`_mk_resolve_input "${INPUT}"`"
	_output="${MK_OBJECT_DIR}${MK_SUBDIR}/${OUTPUT}"

	mk_mkdir "`dirname "$_output"`"
	sed "${_script#;}" < "$_input" > "$_output" || mk_fail "failed to generate $_output"

	mk_add_configure_output "${_output}"
	mk_add_configure_input "${_input}"

	mk_pop_vars
    }
}
