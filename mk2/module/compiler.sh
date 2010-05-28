DEPENDS="core platform"

load()
{
    #
    # Helper functions for make() stage
    #
    mk_compile()
    {
	mk_push_vars SOURCE COMMAND HEADERDEPS DEPS INCLUDEDIRS CPPFLAGS CFLAGS PIC
	mk_parse_params

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
		DEPS="$DEPS @${MK_INCLUDEDIR}/${_header}"
	    fi
	done
	
	mk_resolve_target "@${SOURCE}"
	_res="$result"
	mk_command_params INCLUDEDIRS CPPFLAGS CFLAGS PIC
	_params="$result"

	mk_target \
	    TARGET="@$_object" \
	    COMMAND="\$(SCRIPT) compile $_params \$@ '$_res'" \
	    "${_res}" ${DEPS}

	mk_pop_vars
    }
    
    mk_library()
    {
	mk_push_vars INSTALL LIB SOURCES GROUPS CPPFLAGS CFLAGS LDFLAGS LIBDEPS HEADERDEPS LIBDIRS INCLUDEDIRS VERSION DEPS OBJECTS
	mk_parse_params

	unset _deps
	
	_mk_emit "#"
	_mk_emit "# library ${LIB} from ${MK_SUBDIR#/}"
	_mk_emit "#"
	_mk_emit ""

	case "$INSTALL" in
	    no)
		_library="lib${LIB}${MK_LIB_EXT}"
		;;
	    *)
		_library="${MK_LIBDIR}/lib${LIB}${MK_LIB_EXT}"
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
		PIC="yes" \
		DEPS="$DEPS"
	    
	    _deps="$_deps $result"
	    OBJECTS="$OBJECTS '$result'"
	done
	
	for _group in ${GROUPS}
	do
	    _deps="$_deps @$_group"
	done
	
	for _lib in ${LIBDEPS}
	do
	    if _mk_contains "$_lib" ${MK_INTERNAL_LIBS}
	    then
		_deps="$_deps @${MK_LIBDIR}/lib${_lib}${MK_LIB_EXT}"
	    fi
	done

	mk_command_params GROUPS LIBDEPS LIBDIRS LDFLAGS VERSION
	
	mk_target \
	    TARGET="@$_library" \
	    COMMAND="\$(SCRIPT) link MODE=library $result \$@${OBJECTS}" \
	    ${_deps}
	
	if [ "$INSTALL" != "no" ]
	then
	    mk_add_all_target "$result"
	fi

	MK_INTERNAL_LIBS="$MK_INTERNAL_LIBS $LIB"

	mk_pop_vars
    }

    mk_dso()
    {
	mk_push_vars INSTALL DSO SOURCES GROUPS CPPFLAGS CFLAGS LDFLAGS LIBDEPS HEADERDEPS LIBDIRS INCLUDEDIRS VERSION OBJECTS DEPS
	mk_parse_params
	
	unset _deps

	_mk_emit "#"
	_mk_emit "# dso ${DSO} from ${MK_SUBDIR#/}"
	_mk_emit "#"
	_mk_emit ""

	case "$INSTALL" in
	    no)
		_library="${DSO}${MK_DSO_EXT}"
		;;
	    *)
		_library="${MK_LIBDIR}/${DSO}${MK_DSO_EXT}"
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
		PIC="yes" \
		DEPS="$DEPS"
	    
	    _deps="$_deps $result"
	    OBJECTS="$OBJECTS '$result'"
	done
	
	for _group in ${GROUPS}
	do
	    _deps="$_deps @$_group"
	done
	
	for _lib in ${LIBDEPS}
	do
	    if _mk_contains "$_lib" ${MK_INTERNAL_LIBS}
	    then
		_deps="$_deps @${MK_LIBDIR}/lib${_lib}${MK_LIB_EXT}"
	    fi
	done
	
	mk_command_params GROUPS LIBDEPS LIBDIRS LDFLAGS VERSION

	mk_target \
	    TARGET="@$_library" \
	    COMMAND="\$(SCRIPT) link MODE=dso $result \$@${OBJECTS}" \
	    ${_deps}

	if [ "$INSTALL" != "no" ]
	then
	    mk_add_all_target "$result"
	fi

	mk_pop_vars
    }

    mk_group()
    {
	mk_push_vars GROUP SOURCES CPPFLAGS CFLAGS LDFLAGS LIBDEPS \
	             HEADERDEPS GROUPDEPS LIBDIRS INCLUDEDIRS OBJECTS DEPS
	mk_parse_params

	unset _deps

	_mk_emit "#"
	_mk_emit "# group ${GROUP} from ${MK_SUBDIR#/}"
	_mk_emit "#"
	_mk_emit ""
	
	for _source in ${SOURCES}
	do
	    mk_compile \
		SOURCE="$_source" \
		DEPS="$DEPS" \
		HEADERDEPS="$HEADERDEPS" \
		INCLUDEDIRS="$INCLUDEDIRS" \
		CPPFLAGS="$CPPFLAGS" \
		CFLAGS="$CFLAGS" \
		PIC="yes"
	    
	    _deps="$_deps $result"
	    OBJECTS="$OBJECTS '$result'"
	done

	for _group in ${GROUPDEPS}
	do
	    _deps="$_deps @$_group"
	done
	
	for _lib in ${LIBDEPS}
	do
	    if _mk_contains "$_lib" ${MK_INTERNAL_LIBS}
	    then
		_deps="$_deps @${MK_LIBDIR}/lib${_lib}${MK_LIB_EXT}"
	    fi
	done

	mk_command_params GROUPDEPS LIBDEPS LIBDIRS LDFLAGS

	mk_target \
	    TARGET="@$GROUP" \
	    COMMAND="\$(SCRIPT) group $result \$@${OBJECTS}" \
	    ${_deps}

	mk_pop_vars
    }
    
    mk_program()
    {
	mk_push_vars \
	    PROGRAM SOURCES OBJECTS GROUPS CPPFLAGS CFLAGS \
	    LDFLAGS LIBDEPS HEADERDEPS DEPS LIBDIRS INCLUDEDIRS INSTALLDIR
	# Default to installing programs in bin dir
	INSTALLDIR="${MK_BINDIR}"
	mk_parse_params
	
	unset _deps

	_executable="${INSTALLDIR}/${PROGRAM}"
	
	_mk_emit "#"
	_mk_emit "# program ${PROGRAM} from ${MK_SUBDIR#/}"
	_mk_emit "#"
	_mk_emit ""

	for _source in ${SOURCES}
	do
	    mk_compile \
		SOURCE="$_source" \
		HEADERDEPS="$HEADERDEPS" \
		DEPS="$DEPS" \
		INCLUDEDIRS="$INCLUDEDIRS" \
		CPPFLAGS="$CPPFLAGS" \
		CFLAGS="$CFLAGS"
	    
	    _deps="$_deps $result"
	    OBJECTS="$OBJECTS '$result'"
	done
	
	for _group in ${GROUPS}
	do
	    _deps="$_deps @$_group"
	done

	for _lib in ${LIBDEPS}
	do
	    if _mk_contains "$_lib" ${MK_INTERNAL_LIBS}
	    then
		_deps="$_deps @${MK_LIBDIR}/lib${_lib}${MK_LIB_EXT}"
	    fi
	done
	
	mk_command_params GROUPS LIBDEPS LDFLAGS

	mk_target \
	    TARGET="@$_executable" \
	    COMMAND="\$(SCRIPT) link MODE=program $result \$@ ${OBJECTS} $@" \
	    ${_deps} "$@"

	if [ "$INSTALL" != "no" ]
	then
	    mk_add_all_target "$result"
	fi

	MK_INTERNAL_PROGRAMS="$MK_INTERNAL_PROGRAMS $PROGRAM"

	mk_pop_vars
    }
    
    mk_headers()
    {
	mk_push_vars HEADERS MASTER INSTALLDIR HEADERDEPS DEPS
	INSTALLDIR="${MK_INCLUDEDIR}"
	mk_parse_params
	
	unset _all_headers
	
	_mk_emit "#"
	_mk_emit "# headers from ${MK_SUBDIR#/}"
	_mk_emit "#"
	_mk_emit ""
	
	for _header in ${HEADERDEPS}
	do
	    if _mk_contains "$_header" ${MK_INTERNAL_HEADERS}
	    then
		DEPS="$DEPS @${MK_INCLUDEDIR}/${_header}"
	    fi
	done

	for _header in ${HEADERS}
	do
	    mk_resolve_target "@$_header"
	    
	    mk_target \
	        TARGET="@${INSTALLDIR}/${_header}" \
		COMMAND="\$(SCRIPT) install \$@ $result" \
		"$result" ${DEPS}

	    mk_add_all_target "$result"

	    _rel="${INSTALLDIR#$MK_INCLUDEDIR/}"
	    
	    if [ "$_rel" != "$INSTALLDIR" ]
	    then
		_rel="$_rel/$_header"
	    else
		_rel="$_header"
	    fi
	    
	    MK_INTERNAL_HEADERS="$MK_INTERNAL_HEADERS $_rel"

	    _all_headers="$_all_headers $result"
	done
	
	DEPS="$DEPS $_all_headers"

	for _header in ${MASTER}
	do
	    mk_resolve_target "@$_header"
	    
	    mk_target \
	        TARGET="@${INSTALLDIR}/${_header}" \
		COMMAND="\$(SCRIPT) install \$@ $result" \
		"$result" ${DEPS}

	    mk_add_all_target "$result"

	    _rel="${INSTALLDIR#$MK_INCLUDEDIR/}"
	    
	    if [ "$_rel" != "$INSTALLDIR" ]
	    then
		_rel="$_rel/$_header"
	    else
		_rel="$_header"
	    fi
	    
	    MK_INTERNAL_HEADERS="$MK_INTERNAL_HEADERS $_rel"
	done

	mk_pop_vars
    }

    #
    # Helper functions for configure() stage
    # 

    mk_check_cache()
    {
	mk_get "${1}__CACHED"
	if [ -n "$result" ]
	then
	    CACHED="$result"
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
		mk_run_script compile \
		    DISABLE_DEPGEN=yes \
		    CPPFLAGS="$CPPFLAGS" \
		    CFLAGS="$CFLAGS" \
		    "${__test}.o" "${__test}.c" >&${MK_LOG_FD} 2>&1	    
		 _ret="$?"
		 rm -f "${__test}.o"
		 ;;
	    link-program|run-program)
		mk_run_script link \
		    MODE=program \
		    LIBDEPS="$LIBDEPS" \
		    LDFLAGS="$CPPFLAGS $CFLAGS $LDFLAGS" \
		    "${__test}" "${__test}.c" >&${MK_LOG_FD} 2>&1
		 _ret="$?"
		 if [ "$_ret" -eq 0 -a "$1" = "run-program" ]
		 then
		     ./"${__test}"
		     _ret="$?"
		 fi
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

	CFLAGS="$CFLAGS -Wall -Werror"

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
		mk_define "$_def" "1"
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

	unset CACHED

	CFLAGS="$CFLAGS -Wall -Werror"

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
		mk_define "$_def" "1"
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

	CFLAGS="$CFLAGS -Wall -Werror"
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

    mk_check_sizeof()
    {
	mk_push_vars TYPE HEADERDEPS CPPFLAGS LDFLAGS CFLAGS LIBDEPS
	mk_parse_params

	if [ -z "$TYPE" ]
	then
	    TYPE="$1"
	fi

	CFLAGS="$CFLAGS -Wall -Werror"
	HEADERDEPS="$HEADERDEPS stdio.h"
	
	_def="SIZEOF_`_mk_def_name "$TYPE"`"
	
	if mk_check_cache "$_def"
	then
	    _result="$CACHED"
	else
	    if {
		    for _include in ${HEADERDEPS}
		    do
			echo "#include <${_include}>"
		    done
		    
		    echo ""

		    cat <<EOF
int main(int argc, char** argv)
{ 
    printf("%i\n", sizeof($TYPE));
    return 0;
}
EOF
		} | _mk_build_test 'run-program' "$_def" >".result_${_def}"
	    then
		read _result <.result_${_def}
		rm -f ".result_${_def}"
	    else
		rm -f ".result_${_def}"
		mk_fail "could not determine sizeof($TYPE)"
	    fi
	    
	    mk_cache_export "$_def" "$_result"
	    mk_define "$_def" "$_result"
	fi

	if [ -n "$CACHED" ]
	then
	    mk_msg "$MK_ARCH sizeof($TYPE): $_result (cached)"
	else
	    mk_msg "$MK_ARCH sizeof($TYPE): $_result"
	fi
	
	mk_pop_vars
    }

    mk_check_endian()
    {
	mk_push_vars CPPFLAGS LDFLAGS CFLAGS LIBDEPS
	mk_parse_params

	CFLAGS="$CFLAGS -Wall -Werror"
	HEADERDEPS="$HEADERDEPS stdio.h"
	
	_def="ENDIANNESS"
	
	if mk_check_cache "$_def"
	then
	    _result="$CACHED"
	else
	    if {
		    cat <<EOF
#include <stdio.h>

int main(int argc, char** argv)
{ 
    union
    {
      int a;
      char b[sizeof(int)];
    } u;

    u.a = 1;

    if (u.b[0] == 1)
    {
        printf("little\n");
    }
    else
    {
        printf("big\n");
    }

    return 0;
}
EOF
		} | _mk_build_test 'run-program' "$_def" >".result_${_def}"
	    then
		read _result <.result_${_def}
		rm -f ".result_${_def}"
	    else
		rm -f ".result_${_def}"
		mk_fail "could not determine endianness"
	    fi
	    
	    mk_cache_export "$_def" "$_result"

	    if [ "$_result" = "big" ]
	    then
		mk_define WORDS_BIGENDIAN 1
	    fi
	fi

	if [ -n "$CACHED" ]
	then
	    mk_msg "$MK_ARCH endianness: $_result (cached)"
	else
	    mk_msg "$MK_ARCH endianness: $_result"
	fi
	
	mk_pop_vars
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

option()
{
    mk_option MK_CC cc 'gcc'
    mk_option MK_CPPFLAGS cppflags ''
    mk_option MK_CFLAGS cflags ''
    mk_option MK_LDFLAGS ldflags ''
}

configure()
{
    mk_msg "C compiler: $MK_CC"
    mk_msg "C preprocessor flags: $MK_CPPFLAGS"
    mk_msg "C compiler flags: $MK_CFLAGS"
    mk_msg "linker flags: $MK_LDFLAGS"

    mk_export MK_CC MK_CPPFLAGS MK_CFLAGS MK_LDFLAGS
}