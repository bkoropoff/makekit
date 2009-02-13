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

MK_MANIFEST_OMIT_VARS=""

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

mk_components_for_module()
{
    (
	for __comp in ${MK_COMPONENT_INVENTORY}
	do
	    __modules="`mk_get_component_var "$__comp" MODULE_CLOSURE`"
	    if mk_contains "$__modules" "$1"
	    then
		echo "$__comp"
	    fi
	done
    ) | xargs
}

mk_module_has_function()
{
    __funcs="`mk_get_module_var "${1}" "FUNCS"`"
    mk_contains "${__funcs}" "$2"
}

mk_component_has_function()
{
    __funcs="`mk_get_component_var "${1}" "FUNCS"`"
    mk_contains "${__funcs}" "$2"
}

mk_calc_unique()
{
    xargs | awk 'BEGIN {RS=" ";} { if (!seen[$1]) { print $1; seen[$1] = 1;} }' | xargs
}

__mk_calc_closure_item()
{
    __mk_calc_closure "$1" "$3"
    echo "$2"
}

__mk_calc_closure()
{
    for __item in ${2}
    do
	__var="MK_${1}_`mk_make_identifier "${__item}"`_DEPENDS"
	__val="`mk_deref "$__var"`"
	__mk_calc_closure_item "$1" "$__item" "$__val"
    done
}

mk_calc_closure()
{
    __mk_calc_closure "$@" | mk_calc_unique
}

__mk_calc_module_closure()
{
    __modules="`mk_get_component_var "${1}" "MODULES"`"
    for __module in ${__modules}
    do
	mk_get_module_var "${__module}" "CLOSURE"
    done
}

mk_calc_module_closure()
{
    __mk_calc_module_closure "$@" | mk_calc_unique
}

__mk_calc_module_phases()
{
    __modules="`mk_get_module_var "${1}" "CLOSURE"`"
    for __module in ${__modules}
    do
	mk_get_module_var "${__module}" "PHASES"
    done
}

mk_calc_module_phases()
{
    __mk_calc_module_phases "$@" | mk_calc_unique
}

__mk_calc_component_phases()
{
    __modules="`mk_get_component_var "${1}" "MODULE_CLOSURE"`"
    for __module in ${__modules}
    do
	mk_get_module_var "${__module}" "PHASES"
    done
}

mk_calc_component_phases()
{
    __mk_calc_component_phases "$@" | mk_calc_unique
}

mk_function_list()
{
    grep '^[a-zA-Z0-9_]* *()$' "$1" | sed 's/()$//g' | xargs
}

mk_manifest_define()
{
    echo "${1}=`mk_quote "${2}"`"
    mk_assign "${1}" "${2}"
}

mk_extract_defines()
{
    . "${1}"
    for __var in `grep "^[a-zA-Z0-9_]*=.*$" "$1" | sed 's/=.*$//g'`
    do
	if mk_contains "$MK_MANIFEST_OMIT_VARS" "$__var"
	then
	    :
	else
	    __val="`mk_deref "$__var"`"
	    mk_manifest_define "${2}${__var}" "$__val"
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
    modules="${MK_MODULE_INVENTORY}"
    components="${MK_COMPONENT_INVENTORY}"

    mk_log "Extracting module loading functions"
    echo "mk_log 'Loading modules'"
    for module in ${modules}
    do
	file="${MK_MODULE_DIR}/${module}"
	echo "mk_log_enter '${module}'"
	mk_extract_function "${file}" "load"
	echo "mk_log_leave"
    done

    mk_log "Extracting module configuration functions"
    echo "mk_log 'Configuring modules'"
    for module in ${modules}
    do
	file="${MK_MODULE_DIR}/${module}"
	echo "mk_log_enter '${module}'"
	mk_extract_function "${file}" "configure"
	echo "mk_log_leave"
    done

    mk_log "Extracting component configuration functions"
    echo "mk_log 'Configuring components'"
    for comp in ${components}
    do
	file="${MK_COMPONENT_DIR}/${comp}"
	echo "mk_log_enter '${comp}'"
	mk_extract_function "${file}" "configure"
	echo "mk_log_leave"
    done
}

mk_configure_options()
{
    for module in ${MK_MODULE_INVENTORY}
    do
	mk_get_module_var "${module}" "OPTIONS"
    done

    for comp in ${MK_COMPONENT_INVENTORY}
    do
	mk_get_component_var "${comp}" "OPTIONS"
    done
}

mk_generate_configure_help()
{
    awk_prog='

/^[a-zA-Z-]+/ {
    print ""
    if ($2 == "-")
    {
        form=sprintf("  --%s", $1);
    }
    else
    {
        form=sprintf("  --%s=%s", $1, $2);
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
    echo "  --help 　 　　　     　　　         Display this help message"

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
    mk_log "Extracting module phase functions"
    # Suck in all module bits
    for module in ${MK_MODULE_INVENTORY}
    do
	file="${MK_MODULE_DIR}/${module}"
	phases="`mk_get_module_var "${module}" "PHASE_CLOSURE"`"
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
	    if mk_module_has_function "${module}" "${func}"
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

    mk_log "Generating phase actions"
    mk_log_enter "component"
    for comp in ${MK_COMPONENT_INVENTORY}
    do
	mk_log "${comp}"
	file="${MK_COMPONENT_DIR}/${comp}"
	depends="`mk_get_component_var "${comp}" CLOSURE`"
	modules="`mk_get_component_var "${comp}" MODULE_CLOSURE`"
	phases="`mk_get_component_var "${comp}" PHASE_CLOSURE`"

	for phase in ${phases}
	do
	    extract_file=""
	    extract_func=""
	    
	    if mk_component_has_function "${comp}" "${phase}"
	    then
		extract_file="${file}"
		extract_func="${phase}"
	    else
		# The phase is not defined in the component, so look through
		# the list of modules for a default implementation
		for module in `mk_reverse_list ${modules}`
		do
		    if mk_module_has_function "${module}" "default_${phase}"
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
		    if mk_module_has_function "${module}" "load"
		    then
			echo "    ${module}_load"
		    fi
		done
		echo "    mk_log_enter '${comp}-${phase}'"
		for module in ${modules}
		do
		    if mk_module_has_function "${module}" "pre_${phase}"
		    then
			echo "    ${module}_pre_${phase} \"\$@\""
		    fi
		done
		mk_extract_function "${extract_file}" "${extract_func}"
		for module in `mk_reverse_list ${modules}`
		do	
		    if mk_module_has_function "${module}" "post_${phase}"
		    then
			echo "    ${module}_post_${phase} \"\$@\""
		    fi
		done
		echo "    mk_log_leave"
		echo "}"
	    fi
	done
    done
    mk_log_leave
}

mk_expand_targets()
{
    __frontier="$*"

    while [ -n "$__frontier" ]
    do
	__work="$__frontier"
	__frontier=""
	__vars="`echo $__work | awk 'BEGIN { RS=\"[^%{}]*%{|}[^%{}]*|^[^%{}]*$\"; ORS=" "; } { print; }'`"
	if [ -n "${__vars}" ]
	then
	    for __var in ${__vars}
	    do
		__val="`mk_deref ${__var}`"
		for __each in ${__val}
		do
		    __sub="`echo $__work | sed "s:%{$__var}:$__each:g"`"
		    __frontier="$__frontier $__sub"
		done
	    done
	fi
    done

    (
	for __each in ${__work}
	do
	    echo "${MK_TARGET_DIRNAME}/${__each}"
	done
    ) | grep -v '%' | xargs
}

mk_action_invocation()
{
    echo "\$(ACTION) MAKE=\"\$(MAKE)\" MAKEFLAGS=\"\$(MAKEFLAGS)\" MAKELEVEL=\"\$(MAKELEVEL)\" $*"
}

mk_generate_makefile_rules()
{
    phony=""
    all_virtuals=""

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

    mk_log "Generating phase rules"
    mk_log_enter "component"
    for comp in ${MK_COMPONENT_INVENTORY}
    do
	mk_log "$comp"
	phases="`mk_get_component_var "$comp" PHASE_CLOSURE`"
	modules="`mk_get_component_var "$comp" MODULE_CLOSURE`"
	DEPENDS="`mk_get_component_var "$comp" DEPENDS`"
	COMPONENT="$comp"

	for phase in ${phases}
	do
	    varname="`mk_make_identifier PHASE_${phase}`"
	    for module in ${modules}
	    do
		rule="`mk_get_module_var "$module" "$varname"`"
		if [ -n "$rule" ]
		then
		    break
		fi
	    done
	    
	    [ -z "$rule" ] && mk_fail "No dependency rule found for component $comp phase $phase"
	    type="`echo "$rule" | cut -d: -f1`"
	    deps="`echo "$rule" | cut -d: -f2`"
	    deps="`mk_expand_targets "$deps"`"
	    
	    if [ "$type" = "once" ]
	    then
		printf "%s\n" "${MK_TARGET_DIRNAME}/${phase}-${comp}: ${deps}"
		printf "\t@%s\n" "`mk_action_invocation ${phase} ${comp}`"
		printf "\t@%s\n" "touch \$@"
		printf "\n"
		printf "%s\n" "${phase}-${comp}: ${MK_TARGET_DIRNAME}/${phase}-${comp}"
		printf "\n"
		phony="$phony ${phase}-${comp}"
	    elif [ "$type" = "always" ]
	    then
		printf "%s\n" "${MK_TARGET_DIRNAME}/${phase}-${comp}: ${deps}"
		printf "\t@%s\n" "`mk_action_invocation ${phase} ${comp}`"
		printf "\n"
		printf "%s\n" "${phase}-${comp}: ${MK_TARGET_DIRNAME}/${phase}-${comp}"
		printf "\n"
		phony="$phony ${MK_TARGET_DIRNAME}/${phase}-${comp} ${phase}-${comp}"
	    else
		mk_fail "unrecognized phase rule type: $type"
	    fi
	done
    done
    mk_log_leave

    mk_log "Generating virtual rules"
    mk_log_enter "module"
    for module in ${MK_MODULE_INVENTORY}
    do
	mk_log "$module"
	virtuals="`mk_get_module_var "$module" VIRTUALS`"
	COMPONENTS="`mk_components_for_module "$module"`"
	all_virtuals="$all_virtuals $virtuals"
	for virtual in ${virtuals}
	do
	    varname="`mk_make_identifier "VIRTUAL_$virtual"`"
	    deps="`mk_get_module_var "$module" "$varname"`"
	    deps="`mk_expand_targets "$deps"`"
	    varname="virtual_deps_$virtual"
	    value="`mk_deref "$varname"`"
	    mk_assign "$varname" "$value $deps"
	done
    done

    for virtual in `mk_unique_list ${all_virtuals}`
    do
	varname="virtual_deps_$virtual"
	value="`mk_deref "$varname"`"
	value="`mk_unique_list ${value}`"
	printf "%s\n\n" "${virtual}: ${value}"
	phony="$phony $virtual"
    done
    mk_log_leave
    
    printf ".PHONY:%s\n\n" "$phony"
}

mk_generate_manifest()
{
    cat "${MK_MANIFEST_FILE}.in"
    echo ""

    modules=""
    components=""

    mk_log "Extracting basic information"
    for file in "${MK_MODULE_DIR}"/*
    do
	name="`basename "${file}"`"
	modules="${modules} ${name}"
	mk_extract_defines "${file}" "`mk_make_identifier "MK_MODULE_${name}"`_"
	mk_manifest_define "MK_MODULE_`mk_make_identifier "${name}"`_FUNCS" "`mk_function_list "${file}"`"
    done

    for file in "${MK_COMPONENT_DIR}"/*
    do
	name="`basename "${file}"`"
	components="${components} ${name}"
	mk_extract_defines "${file}" "`mk_make_identifier "MK_COMPONENT_${name}"`_"
	mk_manifest_define "MK_COMPONENT_`mk_make_identifier "${name}"`_FUNCS" "`mk_function_list "${file}"`"
    done
    
    mk_log "Calculating module attributes"
    for name in ${modules}
    do
	mk_manifest_define "MK_MODULE_`mk_make_identifier "${name}"`_CLOSURE" "`mk_calc_closure "MODULE" "${name}"`"
	mk_manifest_define "MK_MODULE_`mk_make_identifier "${name}"`_PHASE_CLOSURE" "`mk_calc_module_phases "${name}"`"
    done

    mk_log "Calculating component attributes"
    for name in ${components}
    do
	mk_manifest_define "MK_COMPONENT_`mk_make_identifier "${name}"`_CLOSURE" "`mk_calc_closure "COMPONENT" "${name}"`"
	mk_manifest_define "MK_COMPONENT_`mk_make_identifier "${name}"`_MODULE_CLOSURE" "`mk_calc_module_closure "${name}"`"
	mk_manifest_define "MK_COMPONENT_`mk_make_identifier "${name}"`_PHASE_CLOSURE" "`mk_calc_component_phases "${name}"`"
    done

    mk_log "Calculating inventories"
    mk_manifest_define "MK_MODULE_INVENTORY" "`mk_calc_closure "MODULE" "${modules}"`"
    mk_manifest_define "MK_COMPONENT_INVENTORY" "`mk_calc_closure "COMPONENT" "${components}"`"
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
