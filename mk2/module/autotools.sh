DEPENDS="core path compiler"

load()
{
    mk_autotools()
    {
	unset SRCDIR HEADERS LIBS LIB_DEPS HEADER_DEPS CPPFLAGS CFLAGS LDFLAGS _stage_deps

	_mk_args

	_stamp="`echo "$SRCDIR" | tr '/.' '__'`"
	
	_mk_emit ""
	_mk_emit "#"
	_mk_emit "# autotools source component $SRCDIR"
	_mk_emit "#"
	_mk_emit ""

	for _lib in ${LIB_DEPS}
	do
	    _stage_deps="$_stage_deps ${MK_LIB_DIR}/lib${_lib}${MK_LIB_EXT}"
	done
	
	for _header in ${HEADER_DEPS}
	do
	    _stage_deps="$_stage_deps ${MK_INCLUDE_DIR}/${_header}"
	done
	
	mk_object \
	    OUTPUT=".at_configure_${_stamp}" \
	    COMMAND="\$(SCRIPT)/at-configure.sh SRCDIR='$SRCDIR' CPPFLAGS='$CPPFLAGS' CFLAGS='$CFLAGS' LDFLAGS='$LDFLAGS' \$@ $*" \
	    ${_stage_deps}
        
	mk_object \
	    OUTPUT=".at_build_${_stamp}" \
	    COMMAND="\$(SCRIPT)/at-build.sh MAKE='\$(MAKE)' MFLAGS='\$(MFLAGS)' SRCDIR='$SRCDIR' \$@" \
	    "$OUTPUT"

	# Add dummy rules for headers or libraries built by this component
	for _header in ${HEADERS}
	do
	    _mk_emit "${MK_STAGE_DIR}${MK_INCLUDE_DIR}/${_header}: ${MK_OBJECT_DIR}/$OUTPUT"
	    _mk_emit ""

	    mk_add_all_target "${MK_INCLUDE_DIR}/${_header}"
	done

	for _lib in ${LIBS}
	do
	    _mk_emit "${MK_STAGE_DIR}${MK_LIB_DIR}/lib${_lib}${MK_LIB_EXT}: ${MK_OBJECT_DIR}/$OUTPUT"
	    _mk_emit ""

	    mk_add_all_target "${MK_INCLUDE_DIR}/${_header}"
	done


	mk_add_clean_target "${MK_SUBDIR}${SRCDIR}"

	if ! [ -f "${MK_SOURCE_DIR}${SUBDIR}/${SRCDIR}/configure" ]
	then
	    if [ -f "${MK_SOURCE_DIR}${SUBDIR}/${SRCDIR}/autogen.sh" ]
	    then
		mk_log "running autogen.sh for ${SRCDIR}"
		cd "${MK_SOURCE_DIR}${SUBDIR}/${SRCDIR}" && _mk_try "./autogen.sh"
		cd "${MK_ROOT_DIR}"
	    fi
	fi
    }
}