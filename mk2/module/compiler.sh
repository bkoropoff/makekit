DEPENDS="core"

load()
{
    #
    # Helper functions for make() stage
    #
    mk_compile()
    {
	unset SOURCE COMMAND HEADERS INCLUDEDIRS CPPFLAGS CFLAGS _headers_abs
		
	_mk_args
	
	if [ -z "$SOURCE" ]
	then
	    SOURCE="$1"
	    shift
	fi
	
	case "$SOURCE" in
	    *.c)
		_object="${SOURCE%.c}.o"
		;;
	    *)
		mk_fail "Unsupported file type: $SOURCE"
		;;
	esac
	
	for _header in ${HEADERS}
	do
	    if _mk_contains "$_header" ${MK_GENERATED_HEADERS}
	    then
		_header_abs="$header_abs ${MK_INCLUDE_DIR}/${_header}"
	    fi
	done
	
	mk_object \
	    OUTPUT="$_object" \
	    COMMAND="\$(COMPILE) INCLUDEDIRS='$INCLUDEDIRS' CPPFLAGS='$CPPFLAGS' CFLAGS='$CFLAGS' \$@ '`_mk_resolve_input "${SOURCE}"`'" \
	    "${SOURCE}" ${_header_abs}
    }
    
    mk_library()
    {
	unset LIBS INSTALL LIBRARY SOURCES CPPFLAGS CFLAGS LDFLAGS HEADERS LIBDIRS INCLUDEDIRS _objects _libs_abs _resolved_objects
	
	_mk_args
	
	_mk_emit "#"
	_mk_emit "# library ${LIBRARY} from ${MK_SUBDIR#/}"
	_mk_emit "#"
	_mk_emit ""

	case "$INSTALL" in
	    no)
		_cmd="mk_object"
		_library="lib${LIBRARY}${MK_LIB_EXT}"
		;;
	    *)
		_cmd="mk_stage"
		_library="${MK_LIB_DIR}/lib${LIBRARY}${MK_LIB_EXT}"
		;;
	esac


	
	for _source in ${SOURCES}
	do
	    mk_compile \
		SOURCE="$_source" \
		HEADERS="$HEADERS" \
		INCLUDEDIRS="$INCLUDEDIRS" \
		CPPFLAGS="$CPPFLAGS" \
		CFLAGS="$CFLAGS"
	    
	    _objects="$_objects $OUTPUT"
	    _resolved_objects="$_resolved_objects '`_mk_resolve_input "$OUTPUT"`'"
	done
	
	for _lib in ${LIBS}
	do
	    _libs_abs="$_libs_abs ${MK_LIB_DIR}/lib${_lib}${MK_LIB_EXT}"
	done
	
	"$_cmd" \
	    OUTPUT="$_library" \
	    COMMAND="\$(LINK) MODE=library LIBS='$LIBS' LIBDIRS='$LIBDIRS' LDFLAGS='$LDFLAGS' \$@${_resolved_objects}" \
	    ${_libs_abs} ${_objects}
	
	MK_GENERATED_LIBS="$MK_GENERATED_LIBS $LIBRARY"
    }
    
    mk_program()
    {
	unset PROGRAM SOURCES CPPFLAGS CFLAGS LDFLAGS _libs_abs _objects _resolved_objects
	
	_mk_args
	
	_executable="${MK_BIN_DIR}/${PROGRAM}"
	
	_mk_emit "#"
	_mk_emit "# program ${PROGRAM} from ${MK_SUBDIR#/}"
	_mk_emit "#"
	_mk_emit ""

	for _source in ${SOURCES}
	do
	    mk_compile \
		SOURCE="$_source" \
		HEADERS="$HEADERS" \
		INCLUDEDIRS="$INCLUDEDIRS" \
		CPPFLAGS="$CPPFLAGS" \
		CFLAGS="$CFLAGS"
	    
	    _objects="$_objects $OUTPUT"
	    _resolved_objects="$_resolved_objects '`_mk_resolve_input "$OUTPUT"`'"
	done
	
	for _lib in ${LIBS}
	do
	    _libs_abs="$_libs_abs ${MK_LIB_DIR}/lib${_lib}${MK_LIB_EXT}"
	done
	
	mk_stage \
	    OUTPUT="$_executable" \
	    COMMAND="\$(LINK) MODE=program LIBS='${LIBS}' LDFLAGS='${LDFLAGS}' \$@ ${_resolved_objects} $@" \
	    ${_libs_abs} ${_objects} "$@"
    }
    
    mk_headers()
    {
	unset HEADERS MASTER _all_headers
	
	_mk_args
	
	_mk_emit "#"
	_mk_emit "# headers from ${MK_SUBDIR#/}"
	_mk_emit "#"
	_mk_emit ""
	
	for _header in ${HEADERS}
	do
	    mk_stage \
	        OUTPUT="${MK_INCLUDE_DIR}/${_header}" \
		COMMAND="\$(INSTALL) \$@ ${MK_SOURCE_DIR}${MK_SUBDIR}/${_header}" \
		"${_header}"
	    
	    MK_GENERATED_HEADERS="$MK_GENERATED_HEADERS $_header"

	    _all_headers="$_all_headers $OUTPUT"
	done
	
	for _header in ${MASTER}
	do
	    mk_stage \
		OUTPUT="${MK_INCLUDE_DIR}/${_header}" \
		COMMAND="\$(INSTALL) \$@ ${MK_SOURCE_DIR}${MK_SUBDIR}/${_header}" \
		"${_header}" ${_all_headers}
	    
	    MK_GENERATED_HEADERS="$MK_GENERATED_HEADERS $_header"
	done
    }

    #
    # Helper functions for configure() stage
    # 

    mk_check_cache()
    {
	_cached="`_mk_deref "${1}__CACHED"`"
	if [ -n "$_cached" ]
	then
	    CACHED="$_cached"
	    mk_export "${1}=$CACHED"
	    return 0
	else
	    CACHED=""
	    return 1
	fi
    }

    mk_cache_export()
    {
	mk_export "$1=$2"
	_mk_set "${1}__CACHED" "$2"
    }

    _mk_build_test()
    {
	__test=".test_`echo "$2" | tr './-' '___'`"
	cat > "${__test}.c"
	
	case "${1}" in
	    compile)
		"${MK_SCRIPT_DIR}/compile.sh" \
		    DISABLE_DEPGEN=yes \
		    CPPFLAGS="$CPPFLAGS" \
		    CFLAGS="$CFLAGS" \
		    "${__test}.o" "${__test}.c" >&4 2>&1	    
		 _ret="$?"
		 rm -f "${__test}.o"
		 ;;
	    link-program)
		"${MK_SCRIPT_DIR}/link.sh" \
		    MODE=program \
		    LIBS="$LIBS" \
		    LDFLAGS="$CPPFLAGS $CFLAGS $LDFLAGS" \
		    "${__test}" "${__test}.c" >&4 2>&2
		 _ret="$?"
		 rm -f "${__test}"
		 ;;
	    *)
		mk_fail "Unsupported build type: ${1}"
		;;
	esac

	if [ "$_ret" -ne 0 ]
	then
	    {
		echo ""
		echo "Failed code:"
		echo ""
		cat "${__test}.c" | awk 'BEGIN { no = 1; } { printf("%3i  %s\n", no, $0); no++; }'
		echo ""
	    } >&4
	fi

	rm -f "${__test}.c"

	return "$_ret"
    }
    
    mk_try_compile()
    {
	unset HEADERS
	
	_mk_args
	
	{
	    for _include in ${HEADERS}
	    do
		echo "#include <${_include}>"
	    done
	    
	    cat <<EOF
int main(int argc, char** argv)
{
${CODE}
}
EOF
	} | _mk_build_test 'compile' 'try-compile'
    
	return "$?"
    }   
    
    mk_check_header()
    {
	unset HEADER FAIL CPPFLAGS CFLAGS
	
	_mk_args

	CFLAGS="$CFLAGS -Wall -Werror"
	
	_def="HAVE_`_mk_def_name "$HEADER"`"
	
	if mk_check_cache "$_def"
	then
	    _result="$CACHED"
	elif _mk_contains "$HEADER" ${MK_GENERATED_HEADERS}
	then
	    _result="internal"
	    mk_cache_export "$_def" "$_result"
	else
	    if {
		echo "#include <${HEADER}>"
		echo ""
		
		cat <<EOF
int main(int argc, char** argv)
{
    return 0;
}
EOF
		} | _mk_build_test compile "$HEADER"
	    then
		_result="external"
	    else
		_result="no"
	    fi
	    
	    mk_cache_export "$_def" "$_result"
	fi
	
	if [ -n "$CACHED" ]
	then
	    mk_log "header $HEADER: $_result (cached)"
	else
	    mk_log "header $HEADER: $_result"
	fi
	
	case "$_result" in
	    external|internal)
		mk_define "$_def" ""
		return 0
		;;
	    no)
		if [ "$FAIL" = "yes" ]
		then
		    mk_fail "missing header: $HEADER"
		fi
		return 1
		;;
	esac
    }
    
    mk_check_function()
    {
	unset LIBS FUNCTION HEADERS CPPFLAGS LDFLAGS CFLAGS
	
	_mk_args
	
	_def="HAVE_`_mk_def_name "$FUNCTION"`"
	
	if mk_check_cache "$_def"
	then
	    _result="$CACHED"
	else
	    if {
		    for _include in ${HEADERS}
		    do
			echo "#include <${_include}>"
		    done
		    
		    echo ""
		    
		    cat <<EOF
int main(int argc, char** argv)
{
    void* __func = $FUNCTION;
    return __func ? 0 : 1;
}
EOF
		} | _mk_build_test 'link-program' "$FUNCTION"
	    then
		_result="yes"
	    else
		_result="no"
	    fi

	    mk_cache_export "$_def" "$_result"
	fi
	
	if [ -n "$CACHED" ]
	then
	    mk_log "function $FUNCTION(): $_result (cached)"
	else
	    mk_log "function $FUNCTION(): $_result"
	fi
	
	case "$_result" in
	    yes)
		mk_define "$_def" ""
		return 0
		;;
	    no)
		if [ "$FAIL" = "yes" ]
		then
		    mk_fail "missing header: $HEADER"
		fi
		return 1
		;;
	esac
    }
    
    mk_check_functions()
    {
	unset LIBS FUNCTION HEADERS CPPFLAGS LDFLAGS CFLAGS
	
	_mk_args
	
	for _name in ${FUNCTIONS} "$@"
	do
	    mk_check_function \
		FUNCTION="$_name" \
		HEADERS="$HEADERS" \
		CPPFLAGS="$CPPFLAGS" \
		LDFLAGS="$LDFLAGS" \
		CFLAGS="$CFLAGS" \
		LIBS="$LIBS" \
		"$@"
	done
    }
    
    mk_check_headers()
    {
	unset HEADERS FAIL CPPFLAGS CFLAGS
	
	_mk_args
	
	for _name in ${HEADERS} "$@"
	do
	    mk_check_header \
		HEADER="$_name" \
		FAIL="$FAIL" \
		CPPFLAGS="$CPPFLAGS" \
		CFLAGS="$CFLAGS" \
		"$@"
	done
    }
}

configure()
{
    MK_CC="`mk_option cc 'gcc'`"
    MK_CPPFLAGS="`mk_option cppflags ''`"
    MK_CFLAGS="`mk_option cflags ''`"
    MK_LDFLAGS="`mk_option ldflags ''`"

    mk_log "C compiler: $MK_CC"
    mk_log "C preprocessor flags: $MK_CPPFLAGS"
    mk_log "C compiler flags: $MK_CFLAGS"
    mk_log "linker flags: $MK_LDFLAGS"

    mk_export MK_CC MK_CPPFLAGS MK_CFLAGS MK_LDFLAGS
}