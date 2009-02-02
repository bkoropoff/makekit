MK_COMPONENT_STEPS="prepare build stage install"
MK_DISTCLEAN_ROOT_FILES="${MK_CONFIGURE_FILENAME} ${MK_ACTION_FILENAME}.in ${MK_MAKEFILE_FILENAME}.in ${MK_MANIFEST_FILENAME}"
MK_DISTCLEAN_WORK_FILES="${MK_CONFIG_FILENAME} ${MK_ACTION_FILENAME} ${MK_MAKEFILE_FILENAME}"
MK_DISTCLEAN_WORK_DIRS="${MK_BUILD_DIRNAME} ${MK_DIST_DIRNAME} ${MK_STAGE_DIRNAME} ${MK_TARGET_DIRNAME}"

mk_include()
{
    echo ""
    echo "### Included file: `basename "$1"`"
    echo ""
    cat "${MK_HOME}/$1"
    echo ""
    echo "### End included file"
    echo ""
}

mk_generate_configure_body()
{
    modules="`mk_order_by_depends "${MK_RESOURCE_DIR}/module/"*`" || exit 1
    components="`mk_order_by_depends "${MK_RESOURCE_DIR}/component/"*`" || exit 1

    echo "mk_log 'Loading modules'"
    for file in ${modules}
    do
	name="`basename "$file"`"
	echo "mk_log_enter '${name}'"
	mk_extract_function "${file}" "load"
	echo "mk_log_leave"
    done

    echo "mk_log 'Configuring modules'"
    for file in ${modules}
    do
	name="`basename "$file"`"
	echo "mk_log_enter '${name}'"
	mk_extract_function "${file}" "configure"
	echo "mk_log_leave"
    done

    echo "mk_log 'Configuring components'"
    for file in ${components}
    do
	name="`basename "$file"`"
	echo "mk_log_enter '${name}'"
	mk_extract_function "${file}" "configure"
	echo "mk_log_leave"
    done
}

mk_configure_options()
{
    for file in \
	`mk_order_by_depends "${MK_MODULE_DIR}/"*` \
	`mk_order_by_depends "${MK_COMPONENT_DIR}/"*`
    do
	mk_extract_var "${file}" OPTIONS
    done
}

mk_generate_configure_help()
{
    awk_prog='

/^[a-zA-Z-]+/ {
    print ""
    if ($2 == "-")
    {
        form=sprintf("--%s", $1);
    }
    else
    {
        form=sprintf("--%s=%s", $1, $2);
    }
    i=length(form);
    while (i < justify - 1)
    {
        form = form " ";
        i++;
    }
    i=3
    printf("%s", form);
    while (i <= NF)
    {
        printf(" %s",$i);
        i++
    }
    printf("\n");
}

/^[ \t]+/ {
    i=0;
    while (i < justify - 1)
    {
        printf(" ")
        i++;
    }

    i=1
    while (i <= NF)
    {
        printf(" %s",$i);
        i++;
    }
    printf("\n");
}'

    echo "    cat <<EOF"
    echo "Usage: ${MK_CONFIGURE_FILENAME} [ options ... ]"
    echo ""
    echo "Options:"
    echo ""
    echo "--help 　 　　　     　　　　　         Display this help message"

    mk_configure_options | awk "${awk_prog}" justify=40
    
    echo "EOF"
    echo "    exit 0"
}

mk_generate_configure_parse()
{
    options="`mk_configure_options | grep '^[^ \t]' | awk '{print $1 " " $2;}'`"
    __IFS="$IFS"
    IFS='
'
    for pair in ${options}
    do
	IFS="$IFS"
	option="`echo "${pair}" | cut -d' ' -f1`"
	var="MK_`mk_make_identifier "${option}"`"
	argname="`echo "${pair}" | cut -d' ' -f2`"
	if [ "$argname" = "-" ]
	then
	    echo "        --${option})"
	    echo "            ${var}=true"
	    echo "            ;;"
	else
	    echo "        --${option}=*)"
	    echo '            __val="`echo "${_param}" | cut -d= -f2`"'
	    echo "            ${var}=\"\${__val}\""
	    echo "            ;;"
	fi
	IFS='
'
    done
}

mk_generate_action_rules()
{
    # Suck in all module bits
    for file in "${MK_MODULE_DIR}/"*
    do
	module="`basename "${file}"`"
	for func in \
	    load pre_prepare post_prepare pre_build post_build \
	    pre_stage post_stage pre_install post_install
	do
	    echo "${module}_${func}()"
	    echo "{"
	    echo "    mk_log_enter '${module}'"
	    mk_extract_function "${file}" "${func}"
	    echo "    mk_log_leave"
	    echo "}"
	    echo ""
	done
    done

    for file in "${MK_COMPONENT_DIR}/"*
    do
	comp="`basename "${file}"`"
	depends="`mk_expand_depends "${MK_COMPONENT_DIR}" "${comp}"`" || exit 1
	modules="`mk_extract_var "${file}" MODULES`" || mk_fail "component not found: ${comp}"
	modules="`mk_expand_depends "${MK_MODULE_DIR}" ${modules}`" || exit 1
	for step in ${MK_COMPONENT_STEPS}
	do
	    echo ""
	    echo "${comp}_${step}()"
	    echo "{"
	    echo "    MK_COMP_DEPENDS=\"${depends}\""
	    for module in ${modules}
	    do
		echo "    ${module}_load"
	    done
	    echo "    mk_log_enter '${comp}-${step}'"
	    for module in ${modules}
	    do
		echo "    ${module}_pre_${step}"
	    done
	    mk_extract_function "${file}" "${step}"
	    for module in `mk_reverse_list ${modules}`
	    do
		echo "    ${module}_post_${step}"
	    done
	    echo "    mk_log_leave"
	    echo "}"
	done
    done
}

mk_generate_makefile_rules()
{
    PHONY=""
    # Emit definitions of depedencies within the resource directory
    # These are preceeded with @MK_RESOURCE_YES@ and @MK_RESOURCE_NO@
    # so that configure can turn them off if resources have been stripped
    # from the source distribution
    printf "### Begin auto-generated dependency lists ###\n\n"
    for file in "${MK_COMPONENT_DIR}/"*
    do
	comp="`basename "${file}"`"
	modules="`mk_extract_var "${file}" "MODULES"`" || mk_fail "module not found: ${comp}"
	modules="`mk_expand_depends "${MK_MODULE_DIR}" ${modules}`" || exit 1
	depstr="${file}"
	
	for module in ${modules}
	do
	    depstr="$depstr ${MK_MODULE_DIR}/${module}"
	done
	
	printf "@MK_RESOURCE_YES@${comp}_resource_deps=${depstr}\n"
	printf "@MK_RESOURCE_NO@${comp}_resource_deps=\n"
    done
    
    # Dependencies for regenerating the makefile
    depstr=""
    for file in "${MK_COMPONENT_DIR}/"*  "${MK_MODULE_DIR}/"*
    do
	depstr="$depstr ${file}"
    done
    printf "@MK_RESOURCE_YES@makefile_resource_deps=${depstr}\n"
    printf "@MK_RESOURCE_NO@makefile_resource_deps=\n\n"
    printf "### End auto-generated dependency lists ###\n\n"

    printf "all: all-comp\n\n"
    PHONY="$PHONY all"

    # Rule for regenerating the makefile
    printf "${MK_MAKEFILE_FILENAME}: \$(makefile_resource_deps)\n"
    printf "\t@mkinit --no-init\n"
    printf "\t@\$(MK_ROOT_DIR)/configure \$(MK_CONFIGURE_ARGS)\n\n"

    # Emit rules for each component
    for file in "${MK_COMPONENT_DIR}/"*
    do
	comp="`basename "${file}"`"
	deps="`mk_extract_var "${file}" "DEPENDS"`" || mk_fail "component not found: ${comp}"

	for dep in ${deps}
	do
	    depstr="$depstr ${MK_TARGET_DIRNAME}/stage_${dep}"
	done

	printf "${MK_TARGET_DIRNAME}/prepare_${comp}:${depstr} \$(${comp}_resource_deps)\n"
	printf "\t@\$(ACTION) prepare ${comp}\n"
	printf "\t@touch ${MK_TARGET_DIRNAME}/prepare_${comp}\n\n"

	printf "${MK_TARGET_DIRNAME}/build_${comp}: ${MK_TARGET_DIRNAME}/prepare_${comp}\n"
	printf "\t@\$(ACTION) build ${comp}\n"
	printf "\t@touch ${MK_TARGET_DIRNAME}/build_${comp}\n\n"

	printf "${MK_TARGET_DIRNAME}/stage_${comp}: ${MK_TARGET_DIRNAME}/build_${comp}\n"
	printf "\t@\$(ACTION) stage ${comp}\n"
	printf "\t@touch ${MK_TARGET_DIRNAME}/stage_${comp}\n\n"

	printf "install_${comp}: ${MK_TARGET_DIRNAME}/stage_${comp}\n"
	printf "\t@\$(ACTION) install ${comp} \$(DESTDIR)\n\n"
	PHONY="$PHONY install_${comp}"

	printf "rebuild_${comp}:\n"
	printf "\t@rm -f ${MK_TARGET_DIRNAME}/build_${comp}\n"
	printf "\t@rm -f ${MK_TARGET_DIRNAME}/stage_${comp}\n"
	printf "\t@\$(MAKE) ${MK_TARGET_DIRNAME}/stage_${comp}\n\n"
	PHONY="$PHONY rebuild_${comp}"

	printf "clean_${comp}:\n"
	printf "\t@echo \"Cleaning component ${comp}\"\n"
	printf "\t@rm -rf ${MK_BUILD_DIRNAME}/${comp} ${MK_STAGE_DIRNAME}/${comp}\n"
	printf "\t@rm -f"
	PHONY="$PHONY clean_${comp}"

	for step in ${MK_COMPONENT_STEPS}
	do
	    printf " ${MK_TARGET_DIRNAME}/${step}_${comp}"
	done
	printf "\n\n"
    done

    # Emit install rule
    printf "install:"
    for file in "${MK_RESOURCE_DIR}/component/"*
    do
	comp="`basename "${file}"`"
	printf " install_${comp}"
    done
    printf "\n\n"
    PHONY="$PHONY install"

    # Emit clean rule
    printf "clean:"
    for file in "${MK_RESOURCE_DIR}/component/"*
    do
	comp="`basename "${file}"`"
	printf " clean_${comp}"
    done
    printf "\n\n"
    PHONY="$PHONY clean"

    # Emit distclean rule
    printf "distclean: clean\n"
    for file in ${MK_DISTCLEAN_ROOT_FILES}
    do
	printf "\trm -f \$(MK_ROOT_DIR)/${file}\n"	
    done
    for file in ${MK_DISTCLEAN_WORK_FILES}
    do
	printf "\trm -f \$(MK_WORK_DIR)/${file}\n"	
    done
    for file in ${MK_DISTCLEAN_WORK_DIRS}
    do
	printf "\trm -rf \$(MK_WORK_DIR)/${file}\n"	
    done
    printf "\n"
    PHONY="$PHONY distclean"

    # Emit all-comp rule
    printf "all-comp:"
    for file in "${MK_COMPONENT_DIR}/"*
    do
	comp="`basename "${file}"`"
	printf " ${MK_TARGET_DIRNAME}/stage_${comp}"
    done
    printf "\n\n"
    PHONY="$PHONY all-comp"

    # Emit phony rule
    printf ".PHONY: $PHONY\n"
}

mk_generate_manifest()
{
    cat "${MK_MANIFEST_FILE}.in"
    echo ""

    # Generate a list of modules and components
    printf "MK_MODULE_INVENTORY='"
    for file in `mk_order_by_depends "${MK_MODULE_DIR}/"*`
    do
	if [ -f "${file}" ]
	then
	    printf "`basename "${file}"` "
	fi
    done
    printf "'\n"

    printf "MK_COMPONENT_INVENTORY='"
    for file in `mk_order_by_depends "${MK_COMPONENT_DIR}/"*`
    do
	if [ -f "${file}" ]
	then
	    printf "`basename "${file}"` "
	fi
    done
    printf "'\n"
    
    for file in "${MK_MODULE_DIR}/"*
    do
	if [ -f "${file}" ]
	then
	    name="`basename "${file}"`"
	    mk_extract_defines "${file}" "`mk_make_identifier "MK_MODULE_${name}"`_"
	fi
    done

    for file in "${MK_COMPONENT_DIR}/"*
    do
	if [ -f "${file}" ]
	then
	    name="`basename "${file}"`"
	    mk_extract_defines "${file}" "`mk_make_identifier "MK_COMPONENT_${name}"`_"
	fi
    done
}

mk_process_template()
{
    __IFS="$IFS"
    IFS=""
    while read -r __line
    do
	IFS="$__IFS"
	if echo "$__line" | grep "^[ \t]*@[^@]*@[ \t]*$" >/dev/null
	then
	    __func="`echo "$__line" | sed -e 's/[ \t]*@//' -e 's/@[ \t]*//'`"
	    ${__func}
	else
	    echo "$__line"
	fi
	IFS=""
    done
    IFS="$__IFS"
}
