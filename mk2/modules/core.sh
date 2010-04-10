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
		    echo "${MK_OBJECT_DIR}${MK_SUBDIR}/${1}"
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
	unset OUTPUT COMMAND
	
	_mk_args
	
	_mk_rule "${MK_STAGE_DIR}${OUTPUT}" "${COMMAND}" "$@"

	mk_add_scrub_target "$OUTPUT"
	mk_add_all_target "$OUTPUT"
    }
    
    mk_object()
    {
	unset OUTPUT COMMAND
	
	_mk_args
	
	_mk_rule "${MK_OBJECT_DIR}${MK_SUBDIR}/${OUTPUT}" "${COMMAND}" "$@"
	
	mk_add_clean_target "$OUTPUT"
    }
}
