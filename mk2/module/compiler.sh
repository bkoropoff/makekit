DEPENDS="core platform"

load()
{
    #
    # Helper functions for make() stage
    #
    mk_compile()
    {
	mk_push_vars SOURCE COMMAND HEADERDEPS INCLUDEDIRS CPPFLAGS CFLAGS PIC
	mk_parse_params

	unset _headers_abs
	
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
	
	for _header in ${HEADERDEPS}
	do
	    if _mk_contains "$_header" ${MK_INTERNAL_HEADERS}
	    then
		_header_abs="$header_abs ${MK_INCLUDE_DIR}/${_header}"
	    fi
	done
	
	mk_object \
	    OUTPUT="$_object" \
	    COMMAND="\$(SCRIPT)/compile.sh `mk_command_params INCLUDEDIRS CPPFLAGS CFLAGS PIC` \$@ '`_mk_resolve_input "${SOURCE}"`'" \
	    "${SOURCE}" ${_header_abs}

	mk_pop_vars
    }
    
    mk_library()
    {
	mk_push_vars INSTALL LIB SOURCES GROUPS CPPFLAGS CFLAGS LDFLAGS LIBDEPS HEADERDEPS LIBDIRS INCLUDEDIRS
	mk_parse_params

	unset _objects _libs_abs _resolved_objects
	
	_mk_emit "#"
	_mk_emit "# library ${LIB} from ${MK_SUBDIR#/}"
	_mk_emit "#"
	_mk_emit ""

	case "$INSTALL" in
	    no)
		_cmd="mk_object"
		_library="lib${LIB}${MK_LIB_EXT}"
		;;
	    *)
		_cmd="mk_stage"
		_library="${MK_LIB_DIR}/lib${LIB}${MK_LIB_EXT}"
		;;
	esac


	
	for _source in ${SOURCES}
	do
	    mk_compile \
		SOURCE="$_source" \
		HEADERDEPS="$HEADERDEPS" \
		INCLUDEDIRS="$INCLUDEDIRS" \
		CPPFLAGS="$CPPFLAGS" \
		CFLAGS="$CFLAGS" \
		PIC="yes"
	    
	    _objects="$_objects $OUTPUT"
	    _resolved_objects="$_resolved_objects '`_mk_resolve_input "$OUTPUT"`'"
	done
	
	_objects="$_objects ${GROUPS}"
	
	for _lib in ${LIBDEPS}
	do
	    if _mk_contains "$_lib" ${MK_INTERNAL_LIBS}
	    then
		_libs_abs="$_libs_abs ${MK_LIB_DIR}/lib${_lib}${MK_LIB_EXT}"
	    fi
	done
	
	"$_cmd" \
	    OUTPUT="$_library" \
	    COMMAND="\$(SCRIPT)/link.sh MODE=library `mk_command_params GROUPS LIBDEPS LIBDIRS LDFLAGS` \$@${_resolved_objects}" \
	    ${_libs_abs} ${_objects}
	
	MK_INTERNAL_LIBS="$MK_INTERNAL_LIBS $LIB"

	mk_pop_vars
    }

    mk_dso()
    {
	mk_push_vars INSTALL DSO SOURCES GROUPS CPPFLAGS CFLAGS LDFLAGS LIBDEPS HEADERDEPS LIBDIRS INCLUDEDIRS
	mk_parse_params

	unset _objects _libs_abs _resolved_objects
	
	_mk_emit "#"
	_mk_emit "# dso ${DSO} from ${MK_SUBDIR#/}"
	_mk_emit "#"
	_mk_emit ""

	case "$INSTALL" in
	    no)
		_cmd="mk_object"
		_library="${DSO}${MK_DSO_EXT}"
		;;
	    *)
		_cmd="mk_stage"
		_library="${MK_LIB_DIR}/${DSO}${MK_DSO_EXT}"
		;;
	esac
	
	for _source in ${SOURCES}
	do
	    mk_compile \
		SOURCE="$_source" \
		HEADERDEPS="$HEADERDEPS" \
		INCLUDEDIRS="$INCLUDEDIRS" \
		CPPFLAGS="$CPPFLAGS" \
		CFLAGS="$CFLAGS" \
		PIC="yes"
	    
	    _objects="$_objects $OUTPUT"
	    _resolved_objects="$_resolved_objects '`_mk_resolve_input "$OUTPUT"`'"
	done
	
	_objects="$_objects ${GROUPS}"
	
	for _lib in ${LIBDEPS}
	do
	    if _mk_contains "$_lib" ${MK_INTERNAL_LIBS}
	    then
		_libs_abs="$_libs_abs ${MK_LIB_DIR}/lib${_lib}${MK_LIB_EXT}"
	    fi
	done
	
	"$_cmd" \
	    OUTPUT="$_library" \
	    COMMAND="\$(SCRIPT)/link.sh MODE=dso `mk_command_params GROUPS LIBDEPS LIBDIRS LDFLAGS` \$@${_resolved_objects}" \
	    ${_libs_abs} ${_objects}

	mk_pop_vars
    }

    mk_group()
    {
	mk_push_vars GROUP SOURCES CPPFLAGS CFLAGS LDFLAGS LIBDEPS HEADERDEPS GROUPDEPS LIBDIRS INCLUDEDIRS
	mk_parse_params

	unset _objects _libs_abs _resolved_objects
	
	_mk_emit "#"
	_mk_emit "# group ${GROUP} from ${MK_SUBDIR#/}"
	_mk_emit "#"
	_mk_emit ""
	
	for _source in ${SOURCES}
	do
	    mk_compile \
		SOURCE="$_source" \
		HEADERDEPS="$HEADERDEPS" \
		INCLUDEDIRS="$INCLUDEDIRS" \
		CPPFLAGS="$CPPFLAGS" \
		CFLAGS="$CFLAGS" \
		PIC="yes"
	    
	    _objects="$_objects $OUTPUT"
	    _resolved_objects="$_resolved_objects '`_mk_resolve_input "$OUTPUT"`'"
	done
	
	for _lib in ${LIBDEPS}
	do
	    if _mk_contains "$_lib" ${MK_INTERNAL_LIBS}
	    then
		_libs_abs="$_libs_abs ${MK_LIB_DIR}/lib${_lib}${MK_LIB_EXT}"
	    fi
	done

	mk_object \
	    OUTPUT="$GROUP" \
	    COMMAND="\$(SCRIPT)/group.sh `mk_command_params GROUPDEPS LIBDEPS LIBDIRS LDFLAGS` \$@${_resolved_objects}" \
	    ${_libs_abs} ${_objects} ${GROUPDEPS}
    }
    
    mk_program()
    {
	mk_push_vars \
	    PROGRAM SOURCES GROUPS CPPFLAGS CFLAGS \
	    LDFLAGS LIBDEPS HEADERDEPS LIBDIRS INCLUDEDIRS INSTALLDIR
	# Default to installing programs in bin dir
	INSTALLDIR="${MK_BIN_DIR}"
	mk_parse_params

	unset _libs_abs _objects _resolved_objects
	
	_executable="${INSTALLDIR}/${PROGRAM}"
	
	_mk_emit "#"
	_mk_emit "# program ${PROGRAM} from ${MK_SUBDIR#/}"
	_mk_emit "#"
	_mk_emit ""

	for _source in ${SOURCES}
	do
	    mk_compile \
		SOURCE="$_source" \
		HEADERDEPSS="$HEADERDEPS" \
		INCLUDEDIRS="$INCLUDEDIRS" \
		CPPFLAGS="$CPPFLAGS" \
		CFLAGS="$CFLAGS"
	    
	    _objects="$_objects $OUTPUT"
	    _resolved_objects="$_resolved_objects '`_mk_resolve_input "$OUTPUT"`'"
	done
	
	_objects="$_objects ${GROUPS}"

	for _lib in ${LIBDEPS}
	do
	    if _mk_contains "$_lib" ${MK_INTERNAL_LIBS}
	    then
		_libs_abs="$_libs_abs ${MK_LIB_DIR}/lib${_lib}${MK_LIB_EXT}"
	    fi
	done
	
	mk_stage \
	    OUTPUT="$_executable" \
	    COMMAND="\$(SCRIPT)/link.sh MODE=program `mk_command_params GROUPS LIBDEPS LDFLAGS` \$@ ${_resolved_objects} $@" \
	    ${_libs_abs} ${_objects} "$@"

	mk_pop_vars
    }
    
    mk_headers()
    {
	mk_push_vars HEADERS MASTER
	mk_parse_params
	
	unset _all_headers
	
	_mk_emit "#"
	_mk_emit "# headers from ${MK_SUBDIR#/}"
	_mk_emit "#"
	_mk_emit ""
	
	for _header in ${HEADERS}
	do
	    mk_stage \
	        OUTPUT="${MK_INCLUDE_DIR}/${_header}" \
		COMMAND="\$(SCRIPT)/install.sh \$@ ${MK_SOURCE_DIR}${MK_SUBDIR}/${_header}" \
		"${_header}"
	    
	    MK_INTERNAL_HEADERS="$MK_INTERNAL_HEADERS $_header"

	    _all_headers="$_all_headers $OUTPUT"
	done
	
	for _header in ${MASTER}
	do
	    mk_stage \
		OUTPUT="${MK_INCLUDE_DIR}/${_header}" \
		COMMAND="\$(SCRIPT)/install.sh \$@ ${MK_SOURCE_DIR}${MK_SUBDIR}/${_header}" \
		"${_header}" ${_all_headers}
	    
	    MK_INTERNAL_HEADERS="$MK_INTERNAL_HEADERS $_header"
	done

	mk_pop_vars
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
	__test=".check_`echo "$2" | tr './-' '___'`"
	cat > "${__test}.c"
	
	case "${1}" in
	    compile)
		"${MK_SCRIPT_DIR}/compile.sh" \
		    DISABLE_DEPGEN=yes \
		    CPPFLAGS="$CPPFLAGS" \
		    CFLAGS="$CFLAGS" \
		    "${__test}.o" "${__test}.c" >&${MK_LOG_FD} 2>&1	    
		 _ret="$?"
		 rm -f "${__test}.o"
		 ;;
	    link-program)
		"${MK_SCRIPT_DIR}/link.sh" \
		    MODE=program \
		    LIBDEPS="$LIBDEPS" \
		    LDFLAGS="$CPPFLAGS $CFLAGS $LDFLAGS" \
		    "${__test}" "${__test}.c" >&${MK_LOG_FD} 2>&1
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
	mk_push_vars HEADERDEPS
	mk_parse_params
	
	{
	    for _include in ${HEADERDEPS}
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
    
	_ret="$?"

	mk_pop_vars

	return "$_ret"
    }
    
    mk_check_header()
    {
	mk_push_vars HEADER FAIL CPPFLAGS CFLAGS
	mk_parse_params

	_def="HAVE_`_mk_def_name "$HEADER"`"
	
	if mk_check_cache "$_def"
	then
	    _result="$CACHED"
	elif _mk_contains "$HEADER" ${MK_INTERNAL_HEADERS}
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
		} | _mk_build_test compile "header_$HEADER"
	    then
		_result="external"
	    else
		_result="no"
	    fi
	    
	    mk_cache_export "$_def" "$_result"
	fi

	if [ -n "$CACHED" ]
	then
	    mk_msg "header $HEADER: $_result (cached)"
	else
	    mk_msg "header $HEADER: $_result"
	fi
	
	case "$_result" in
	    external|internal)
		mk_define "$_def" ""
		mk_pop_vars
		return 0
		;;
	    no)
		if [ "$FAIL" = "yes" ]
		then
		    mk_fail "missing header: $HEADER"
		fi
		mk_pop_vars
		return 1
		;;
	esac
    }
    
    mk_check_function()
    {
	mk_push_vars LIBDEPS FUNCTION HEADERDEPS CPPFLAGS LDFLAGS CFLAGS FAIL PROTOTYPE
	mk_parse_params

	if [ -n "$PROTOTYPE" ]
	then
	    _parts="`echo "$PROTOTYPE" | sed 's/^\(.*[^a-zA-Z_]\)\([a-zA-Z_][a-zA-Z0-9_]*\) *(\([^)]*\)).*$/\1|\2|\3/g'`"
	    _ret="${_parts%%|*}"
	    _parts="${_parts#*|}"
	    FUNCTION="${_parts%%|*}"
	    _args="${_parts#*|}"
	    _checkname="$PROTOTYPE"
	else
	    _checkname="$FUNCTION()"
	fi
	
	_def="HAVE_`_mk_def_name "$FUNCTION"`"
	
	if [ -z "$PROTOTYPE" ] && mk_check_cache "$_def"
	then
	    _result="$CACHED"
	else
	    if {
		    for _include in ${HEADERDEPS}
		    do
			echo "#include <${_include}>"
		    done
		    
		    echo ""
		    
		    if [ -n "$PROTOTYPE" ]
		    then
			cat <<EOF
int main(int argc, char** argv)
{
    $_ret (*__func)($_args) = &$FUNCTION;
    return __func ? 0 : 1;
}
EOF
		    else
			cat <<EOF
int main(int argc, char** argv)
{
    void* __func = &$FUNCTION;
    return __func ? 0 : 1;
}
EOF
		    fi
		} | _mk_build_test 'link-program' "func_$FUNCTION"
	    then
		_result="yes"
	    else
		_result="no"
	    fi

	    if [ -z "$PROTOTYPE" ]
	    then
		mk_cache_export "$_def" "$_result"
	    else
		mk_export "$_def"="$_result"
	    fi
	fi

	if [ -n "$CACHED" ]
	then
	    mk_msg "function $_checkname: $_result (cached)"
	else
	    mk_msg "function $_checkname: $_result"
	fi
	
	case "$_result" in
	    yes)
		mk_define "$_def" ""
		mk_pop_vars
		return 0
		;;
	    no)
		if [ "$FAIL" = "yes" ]
		then
		    mk_fail "missing function: $FUNCTION"
		fi
		mk_pop_vars
		return 1
		;;
	esac
    }

    mk_check_library()
    {
	mk_push_vars LIBDEPS LIB CPPFLAGS LDFLAGS CFLAGS FAIL
	mk_parse_params

	LIBDEPS="$LIBDEPS $LIB"
	
	_def="HAVE_LIB_`_mk_def_name "$LIB"`"
	
	if mk_check_cache "$_def"
	then
	    _result="$CACHED"
	elif _mk_contains "$LIB" ${MK_INTERNAL_LIBS}
	then
	    _result="internal"
	    mk_cache_export "$_def" "$_result"
	else
	    if {
		    cat <<EOF
int main(int argc, char** argv)
{
    return 0;
}
EOF
		} | _mk_build_test 'link-program' "lib_$LIB"
	    then
		_result="external"
	    else
		_result="no"
	    fi

	    mk_cache_export "$_def" "$_result"
	fi

	if [ -n "$CACHED" ]
	then
	    mk_msg "library $LIB: $_result (cached)"
	else
	    mk_msg "library $LIB: $_result"
	fi
	
	case "$_result" in
	    external|internal)
		mk_export "LIB_`_mk_def_name "$LIB"`=$LIB"
		mk_pop_vars
		return 0
		;;
	    no)
		if [ "$FAIL" = "yes" ]
		then
		    mk_fail "missing library: $LIB"
		fi
		mk_export "LIB_`_mk_def_name "$LIB"`="
		mk_pop_vars
		return 1
		;;
	esac
    }
    
    mk_check_functions()
    {
	mk_push_vars LIBDEPS FUNCTIONS PROTOTYPES HEADERDEPS CPPFLAGS LDFLAGS CFLAGS FAIL
	mk_parse_params
	
	for _name in ${FUNCTIONS} "$@"
	do
	    mk_check_function \
		FAIL="$FAIL" \
		FUNCTION="$_name" \
		HEADERDEPS="$HEADERDEPS" \
		CPPFLAGS="$CPPFLAGS" \
		LDFLAGS="$LDFLAGS" \
		CFLAGS="$CFLAGS" \
		LIBDEPS="$LIBDEPS" \
		"$@"
	done

	_ifs="$IFS"
	IFS=";"
	for _proto in ${PROTOTYPES}
	do
	    IFS="$_ifs"
	    mk_check_function \
		FAIL="$FAIL" \
		PROTOTYPE="$_proto" \
		HEADERDEPS="$HEADERDEPS" \
		CPPFLAGS="$CPPFLAGS" \
		LDFLAGS="$LDFLAGS" \
		CFLAGS="$CFLAGS" \
		LIBDEPS="$LIBDEPS" \
		"$@"
	    IFS=";"
	done
	IFS="$_ifs"

	mk_pop_vars
    }

    mk_check_libraries()
    {
	mk_push_vars LIBS LIBDEPS CPPFLAGS LDFLAGS CFLAGS FAIL
	mk_parse_params
	
	for _name in ${LIBS} "$@"
	do
	    mk_check_library \
		FAIL="$FAIL" \
		LIB="$_name" \
		CPPFLAGS="$CPPFLAGS" \
		LDFLAGS="$LDFLAGS" \
		CFLAGS="$CFLAGS" \
		LIBDEPS="$LIBDEPS" \
		"$@"
	done

	mk_pop_vars
    }
    
    mk_check_headers()
    {
	mk_push_vars HEADERS FAIL CPPFLAGS CFLAGS
	mk_parse_params
	
	for _name in ${HEADERS} "$@"
	do
	    mk_check_header \
		HEADER="$_name" \
		FAIL="$FAIL" \
		CPPFLAGS="$CPPFLAGS" \
		CFLAGS="$CFLAGS" \
		"$@"
	done

	mk_pop_vars
    }
}

configure()
{
    MK_CC="`mk_option cc 'gcc'`"
    MK_CPPFLAGS="`mk_option cppflags ''`"
    MK_CFLAGS="`mk_option cflags ''`"
    MK_LDFLAGS="`mk_option ldflags ''`"

    mk_msg "C compiler: $MK_CC"
    mk_msg "C preprocessor flags: $MK_CPPFLAGS"
    mk_msg "C compiler flags: $MK_CFLAGS"
    mk_msg "linker flags: $MK_LDFLAGS"

    mk_export MK_CC MK_CPPFLAGS MK_CFLAGS MK_LDFLAGS
}