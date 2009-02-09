## 
##  metakit -- the extensible meta-build system
##  Copyright (C) Brian Koropoff
## 
##  This program is free software; you can redistribute it and/or
##  modify it under the terms of the GNU General Public License
##  as published by the Free Software Foundation; either version 2
##  of the License, or (at your option) any later version.
## 
##  This program is distributed in the hope that it will be useful,
##  but WITHOUT ANY WARRANTY; without even the implied warranty of
##  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
##  GNU General Public License for more details.
## 
##  You should have received a copy of the GNU General Public License
##  along with this program; if not, write to the Free Software
##  Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
## 

# Override these utility functions to look in files directly
mk_get_component_var()
{
    mk_extract_var "${MK_COMPONENT_DIR}/${1}" "$2"
}

mk_get_module_var()
{
    mk_extract_var "${MK_MODULE_DIR}/${1}" "$2"
}

mk_load_modules()
{
    __phases=""
    mk_log_enter "module"
    for file in "${MK_MODULE_DIR}/"*
    do
	module="$(basename "${file}")"
	. "${file}" || mk_fail "Failed to source module ${module}"
	if mk_function_exists "load"
	then
	    mk_log "${module}"
	    load
	    unset -f load
	fi
	__phases="$__phases `mk_extract_var "${file}" "PHASES"`"
    done

    MK_ALL_PHASES="`mk_unique_list ${__phases}`"

    mk_log_leave
}

mk_modules_for_component()
{
    __modules="`mk_extract_var "${MK_COMPONENT_DIR}/${1}" "MODULES"`" || mk_fail "could not read component $1"
    mk_expand_depends "${MK_MODULE_DIR}" ${__modules} || exit 1
}

mk_phases_for_module()
{
    __modules="`mk_expand_depends "${MK_MODULE_DIR}" "${1}"`" || exit 1
    __list="$(for __module in ${__modules}
	do
	    mk_extract_var "${MK_MODULE_DIR}/${__module}" "PHASES" || mk_fail "could not read module $__module"
	done
    )" || exit 1

    mk_unique_list ${__list}
}

mk_phases_for_component()
{
    __modules="`mk_modules_for_component "$1"`"
    __list="$(for __module in ${__modules}
	do
	    mk_extract_var "${MK_MODULE_DIR}/${__module}" "PHASES" || mk_fail "could not read module $__module"
	done
    )" || exit 1

    mk_unique_list ${__list}
}

mk_components_for_module()
{
    # This reverse calculation is really hairy
    for __file in "${MK_COMPONENT_DIR}/"*
    do
	__comp="`basename "$__file"`"
	__modules="`mk_modules_for_component "$__comp"`" || exit 1
	if mk_contains "$__modules" "$1"
	then
	    echo "$__comp"
	    continue
	fi
    done
}

mk_include()
{
    echo ""
    echo "### Included file: `basename "$1"`"
    echo ""
    grep -v "^##" < "${MK_HOME}/$1"
    echo ""
    echo "### End included file"
    echo ""
}

mk_generate_configure_body()
{
    modules="`mk_order_by_depends "${MK_MODULE_DIR}/"*`" || exit 1
    components="`mk_order_by_depends "${MK_COMPONENT_DIR}/"*`" || exit 1

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
    basic_funcs="load"
    # Suck in all module bits
    for file in "${MK_MODULE_DIR}/"*
    do
	module="`basename "${file}"`"
	phases="`mk_phases_for_module "${module}"`"
	funcs="${basic_funcs}"
	for phase in ${phases}
	do
	    for step in pre default post
	    do
		funcs="${funcs} ${step}_${phase}"
	    done
	done

	for func in ${funcs}
	do
	    if mk_function_exists_in_file "${file}" "${func}"
	    then
		echo "${module}_${func}()"
		echo "{"
		echo "    mk_log_enter '${module}'"
		mk_extract_function "${file}" "${func}"
		echo "    mk_log_leave"
		echo "}"
		echo ""
	    fi
	done
    done

    for file in "${MK_COMPONENT_DIR}/"*
    do
	comp="`basename "${file}"`"
	depends="`mk_expand_depends "${MK_COMPONENT_DIR}" "${comp}"`" || exit 1
	modules="`mk_modules_for_component "${comp}"`" || exit 1
	phases="`mk_phases_for_component "${comp}"`" || exit 1

	for phase in ${phases}
	do
	    extract_file=""
	    extract_func=""
	    
	    if mk_function_exists_in_file "${file}" "${phase}"
	    then
		extract_file="${file}"
		extract_func="${phase}"
	    else
		# The phase is not defined in the component, so look through
		# the list of modules for a default implementation
		for module in `mk_reverse_list ${modules}`
		do
		    if mk_function_exists_in_file "${MK_MODULE_DIR}/${module}" "default_${phase}"
		    then
			extract_file="${MK_MODULE_DIR}/${module}"
			extract_func="default_${phase}"
			break;
		    fi
		done
	    fi
	    
	    if [ -n "${extract_file}" ]
	    then
		echo ""
		echo "${comp}_${phase}()"
		echo "{"
		echo "    MK_COMP_DEPENDS=\"${depends}\""
		for module in ${modules}
		do
		    if mk_function_exists_in_file "${MK_MODULE_DIR}/${module}" "load"
		    then
			echo "    ${module}_load"
		    fi
		done
		echo "    mk_log_enter '${comp}-${phase}'"
		for module in ${modules}
		do
		    if mk_function_exists_in_file "${MK_MODULE_DIR}/${module}" "pre_${phase}"
		    then
			echo "    ${module}_pre_${phase} \"\$@\""
		    fi
		done
		mk_extract_function "${extract_file}" "${extract_func}"
		for module in `mk_reverse_list ${modules}`
		do	
		    if mk_function_exists_in_file "${MK_MODULE_DIR}/${module}" "post_${phase}"
		    then
			echo "    ${module}_post_${phase} \"\$@\""
		    fi
		done
		echo "    mk_log_leave"
		echo "}"
	    fi
	done
    done
}

mk_generate_makefile_rules()
{
    # Emit definitions of depedencies within the resource directory
    # These are preceeded with @MK_RESOURCE_YES@ and @MK_RESOURCE_NO@
    # so that configure can turn them off if resources have been stripped
    # from the source distribution

    # Dependencies for regenerating the makefile
    depstr=""
    for file in "${MK_COMPONENT_DIR}/"*  "${MK_MODULE_DIR}/"*
    do
	depstr="$depstr ${file}"
    done
    printf "@MK_RESOURCE_YES@makefile_resource_deps=${depstr}\n"
    printf "@MK_RESOURCE_NO@makefile_resource_deps=\n\n"

    # Rule for regenerating the makefile
    printf "${MK_MAKEFILE_FILENAME}: \$(makefile_resource_deps)\n"
    printf "\t@mkinit --no-init\n"
    printf "\t@\$(MK_ROOT_DIR)/configure \$(MK_CONFIGURE_ARGS)\n\n"

    # Emit rules for each component
    for file in "${MK_COMPONENT_DIR}/"*
    do
	comp="`basename "${file}"`"
	modules="`mk_modules_for_component "${comp}"`" || exit 1
	phases="`mk_phases_for_component "${comp}"`" || exit 1
	deps="`mk_extract_var "${file}" "DEPENDS"`" || mk_fail "could not read component: $comp"

	for phase in ${phases}
	do
	    makedeps=""
	    for module in ${modules}
	    do
		if mk_function_exists_in_file "${MK_MODULE_DIR}/${module}" "makerule_${phase}"
		then
		    (
			. "${MK_MODULE_DIR}/${module}" || mk_fail "could not read module: ${module}"
			if mk_function_exists "makerule_${phase}"
			then
			    "makerule_${phase}" "${comp}" "${deps}"
			fi
		    ) || exit 1
		fi
	    done
	done
    done

    # Emit custom rules for each module
    for file in "${MK_MODULE_DIR}/"*
    do
	if mk_function_exists_in_file "${file}" "makerule_all"
	then
	    module="`basename "${file}"`"
	    comps="`mk_components_for_module "${module}"`" || exit 1
	    (
		. "${MK_MODULE_DIR}/${module}" || mk_fail "could not read module: ${module}"
		makerule_all "$comps"
	    ) || exit 1
	fi
    done
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
    grep -v "^##" | (
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
    )
}
