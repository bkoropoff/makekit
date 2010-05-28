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
	    _stage_deps="$_stage_deps @${MK_LIBDIR}/lib${_lib}${MK_LIB_EXT}"
	done
	
	for _header in ${HEADERDEPS}
	do
	    _stage_deps="$_stage_deps @${MK_INCLUDEDIR}/${_header}"
	done
	
	mk_command_params SOURCEDIR CPPFLAGS CFLAGS LDFLAGS

	mk_target \
	    TARGET="@.at_configure_${_stamp}" \
	    COMMAND="\$(SCRIPT) at-configure $result \$@ $*" \
	    ${_stage_deps}

	__configure_stamp="$result"

	mk_command_params SOURCEDIR INSTALL
        
	mk_target \
	    TARGET="@.at_build_${_stamp}" \
	    COMMAND="\$(SCRIPT) at-build MAKE='\$(MAKE)' MFLAGS='\$(MFLAGS)' $result \$@" \
	    DEPS="$__configure_stamp"

	__build_stamp="$result"

	# Add dummy rules for headers or libraries built by this component
	for _header in ${HEADERS}
	do
	    mk_target \
		TARGET="@${MK_INCLUDEDIR}/${_header}" \
		DEPS="$__build_stamp"

	    mk_add_all_target "$result"

	    MK_INTERNAL_HEADERS="$MK_INTERNAL_HEADERS $_header"
	done

	for _lib in ${LIBS}
	do
	    mk_target \
		TARGET="@${MK_LIBDIR}/lib${_lib}${MK_LIB_EXT}" \
		DEPS="$__build_stamp"

	    mk_add_all_target "$result"

	    MK_INTERNAL_LIBS="$MK_INTERNAL_LIBS $_lib"
	done

	for _target in ${TARGETS}
	do
	    mk_target \
		TARGET="$_target" \
		DEPS="$__build_stamp"
	done

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
