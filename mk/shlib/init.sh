#!/bin/sh
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

mk_find_module()
{
    __file=""
    [ -f "${MK_MODULE_DIR}/${1}" ] \
	&& __file="${MK_MODULE_DIR}/${1}"
    [ -f "${MK_HOME}/${MK_MODULE_DIRNAME}/${1}" ] \
	&& __file="${MK_HOME}/${MK_MODULE_DIRNAME}/${1}"

    [ -n "${__file}" ] || mk_fail "Failed to find module ${1}"

    echo "${__file}"
}

mk_load_modules()
{
    __phases=""
    mk_log_enter "module"
    for module in ${MK_MODULE_INVENTORY}
    do
	file="`mk_find_module "${module}"`"

	. "${file}" || mk_fail "Failed to source module ${module}"

	if mk_function_exists "load"
	then
	    mk_log "${module}"
	    load
	    unset -f load
	fi
    done

    mk_log_leave
}

mk_init_component()
{
    name="$1"
    file="${MK_COMPONENT_DIR}/${name}"
    modules="`mk_get_component_var "${name}" MODULE_CLOSURE`"
    MK_COMP="${name}"
    run_file=""
    run_func=""

    mk_log_enter "${name}"
    if mk_component_has_function "${name}" "init"
    then
	run_file="${file}"
	run_func="init"
    else
	for module in `mk_reverse_list ${modules}`
	do
	    if mk_module_has_function "${module}" "default_init"
	    then
		run_file="`mk_find_module "${module}"`"
		run_func="default_init"
		break;
	    fi
	done
    fi

    if [ -n "${run_file}" ]
    then
	for module in ${modules}
	do
	    if mk_module_has_function "${module}" "pre_init"
	    then
		file="`mk_find_module "${module}"`"
		. "${file}" || mk_fail "Could not read module: ${module}"
		pre_init
	    fi
	done
	. "${run_file}" || mk_fail "Could not read component: ${MK_COMP}"
	"${run_func}"
	for module in ${modules}
	do
	    if mk_module_has_function "${module}" "post_init"
	    then
		file="`mk_find_module "${module}"`"
		. "${file}" || mk_fail "Could not read module: ${module}"
		post_init
	    fi
	done
    fi
    mk_log_leave
}

MK_ROOT_DIR="$1"

. "${MK_HOME}/shlib/constants.sh"
. "${MK_HOME}/shlib/paths.sh"
. "${MK_HOME}/shlib/util.sh"
. "${MK_MANIFEST_FILE}"

mk_log "Loading modules"
mk_load_modules

mk_log "Initializing components"
files=""
if [ -n "${OPT_INIT_COMPS}" ]
then
    for name in ${OPT_INIT_COMPS}
    do
	files="${files} ${MK_COMPONENT_DIR}/${name}"
    done
else
    files="${MK_COMPONENT_DIR}/"*
fi

for file in ${files}
do
    mk_init_component "`basename "$file"`"
done
