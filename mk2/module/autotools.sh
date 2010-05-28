DEPENDS="core path compiler platform"

load()
{
    mk_autotools()
    {
	mk_push_vars SOURCEDIR HEADERS LIBS LIBDEPS HEADERDEPS CPPFLAGS CFLAGS LDFLAGS INSTALL TARGETS
	mk_parse_params

	unset _stage_deps

	_stamp="`echo "$SOURCEDIR" | tr '/.' '__'`"
	
	_mk_emit ""
	_mk_emit "#"
	_mk_emit "# autotools source component $SOURCEDIR"
	_mk_emit "#"
	_mk_emit ""

	for _lib in ${LIBDEPS}
	do
	    _stage_deps="$_stage_deps ${MK_LIBDIR}/lib${_lib}${MK_LIB_EXT}"
	done
	
	for _header in ${HEADERDEPS}
	do
	    _stage_deps="$_stage_deps ${MK_INCLUDEDIR}/${_header}"
	done
	
	mk_command_params SOURCEDIR CPPFLAGS CFLAGS LDFLAGS

	mk_object \
	    OUTPUT=".at_configure_${_stamp}" \
	    COMMAND="\$(SCRIPT) at-configure $result \$@ $*" \
	    ${_stage_deps}

	mk_command_params SOURCEDIR INSTALL
        
	mk_object \
	    OUTPUT=".at_build_${_stamp}" \
	    COMMAND="\$(SCRIPT) at-build MAKE='\$(MAKE)' MFLAGS='\$(MFLAGS)' $result \$@" \
	    "$OUTPUT"

	# Add dummy rules for headers or libraries built by this component
	for _header in ${HEADERS}
	do
	    _mk_emit "${MK_STAGE_DIR}${MK_INCLUDEDIR}/${_header}: ${MK_OBJECT_DIR}${MK_SUBDIR}/$OUTPUT"
	    _mk_emit ""

	    mk_add_all_target "${MK_INCLUDEDIR}/${_header}"
	    MK_INTERNAL_HEADERS="$MK_INTERNAL_HEADERS $_header"
	done

	for _lib in ${LIBS}
	do
	    _mk_emit "${MK_STAGE_DIR}${MK_LIBDIR}/lib${_lib}${MK_LIB_EXT}: ${MK_OBJECT_DIR}${MK_SUBDIR}/$OUTPUT"
	    _mk_emit ""

	    mk_add_all_target "${MK_LIBDIR}/lib${_lib}${MK_LIB_EXT}"
	    MK_INTERNAL_LIBS="$MK_INTERNAL_LIBS $_lib"
	done

	for _target in ${TARGETS}
	do
	    case "$_target" in
		"/"*)
		    _mk_emit "${MK_STAGE_DIR}${_target}: ${MK_OBJECT_DIR}${MK_SUBDIR}/$OUTPUT"
		    _mk_emit ""
		    ;;
		*)
		    _mk_emit "${MK_OBJECT_DIR}${MK_SUBDIR}/${SOURCEDIR}/${_target}: ${MK_OBJECT_DIR}${MK_SUBDIR}/$OUTPUT"
		    _mk_emit ""
		    ;;
	    esac
	    _mk_emit ""
	done

	mk_add_clean_target "${MK_SUBDIR}${SOURCEDIR}"

	if ! [ -f "${MK_SOURCE_DIR}${MK_SUBDIR}/${SOURCEDIR}/configure" ]
	then
	    if [ -f "${MK_SOURCE_DIR}${MK_SUBDIR}/${SOURCEDIR}/autogen.sh" ]
	    then
		mk_msg "running autogen.sh for ${SOURCEDIR}"
		cd "${MK_SOURCE_DIR}${MK_SUBDIR}/${SOURCEDIR}" && _mk_try "./autogen.sh"
		cd "${MK_ROOT_DIR}"
	    else
		mk_msg "running autoreconf for ${SOURCEDIR}"
		cd "${MK_SOURCE_DIR}${MK_SUBDIR}/${SOURCEDIR}" && _mk_try autoreconf -fi
		cd "${MK_ROOT_DIR}"
	    fi
	fi

	mk_pop_vars
    }
}