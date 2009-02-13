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
##  The source code contained within this file is also subject to the
##  following additional terms:
## 
##  1. "Program" below refers to metakit or any derivative work thereof
##     under copyright law. "Unmodified" below refers to the Program
##     prior to any modification by the licensee, in a form which was
##     distributed while fully abiding by the terms of the GNU General
##     Public License and these additional clauses. "Unmodified Version"
##     refers to the Unmodified Program or the portion thereof from which
##     the licensee's modified version is derived.  Each licensee is
##     addressed as "you."
## 
##  2. As a special exception to the terms of the GNU General Public License,
##     you are granted unlimited permission to copy, distribute, and modify
##     the output of the Program, even when such output contains portions
##     of the Program source code which are otherwise governed by the terms
##     of the GNU General Public License.  When distributing a modified
##     version of the Program, you may choose to extend this special
##     exception to your modified version as well.
## 
##  3. The exception in clause 2 applies only to portions of the Program which
##     appear in a file containing these additional clauses.  You may not
##     extend this exception to portions of the Program which are contained
##     in a file that does not contain these clauses.  In addition, you may
##     not extend the exception to your modified version under any of the
##     following circumstances:
## 
##     a)  You move, copy, combine, or otherwise modify portions of the
##         Program such that a file is produced which:
##         
##         i.  Contains portions of the Program which, in the Unmodified
##             Version, were contained in a file which contained these
##             additional clauses; and
## 
##         ii. Contains portions of the Program which, in the Unmodified
##             Version, were contained in a file which did not contain these
##             additional clauses.
## 
##     b)  You modify the behavior of the Program such that it may copy portions
##         of the Program into its output where said portions, in the Unmodified
##         Version, were contained in a file which did not contain these clauses.
## 
##  4.  If any of the circumstances in clause 3 apply, you must remove these clauses
##      from the affected portions of your version of the Program in order to
##      distribute it.  In the case of (3.i), this means the offending file which
##      contains the inappropriately combined portions of the Program.  In the case
##      of (3.ii), it means the entirety of the Program.
##

@mk_include lib/constants.sh@
@mk_include lib/util.sh@

DIRNAME="`dirname "$0"`"
MK_ROOT_DIR="`mk_canonical_path "$DIRNAME"`"
MK_WORK_DIR="`pwd`"
MK_PREFIX="/usr/local"
MK_DEFINE_LIST=""
MK_EXPORT_LIST=""

@mk_include lib/paths.sh@

mk_define()
{
    for __var in "$@"
    do
	if echo "${MK_DEFINE_LIST}" | grep " $__var " >/dev/null
	then
	    :
	else
	    MK_DEFINE_LIST="${MK_DEFINE_LIST} $__var "
	fi
    done
}

mk_export()
{
    for __var in "$@"
    do
	if echo "${MK_DEFINE_LIST}" | grep " $__var " >/dev/null
	then
	    :
	else
	    MK_DEFINE_LIST="${MK_DEFINE_LIST} $__var "
	fi
	
	if echo "${MK_EXPORT_LIST}" | grep " $__var " >/dev/null
	then
	    :
	else
	    MK_EXPORT_LIST="${MK_EXPORT_LIST} $__var "
	fi
    done
}

mk_make_define()
{
    printf "$1=$2\n" >&4
}

mk_check_program()
{
    __var="$1"
    shift
    __desc="$1"
    shift
    __val="`mk_deref "$__var"`"

    mk_log_start "$__desc: "
    if type "${__val}" >/dev/null 2>&1
    then
	mk_log_end "$__val"
	return 0
    else
	for __prog in "$@"
	do
	    if type "${__prog}" >/dev/null 2>&1
	    then
		mk_log_end "${__prog}"
		mk_assign "${__var}" "${__prog}"
		return 0
	    fi
	done
    fi

    mk_log_end "not found"
    return 1
}

mk_check_program_path()
{
    __var="$1"
    shift
    __desc="$1"
    shift
    __val="`mk_deref "$__var"`"

    mk_log_start "$__desc: "
    if __path="`mk_resolve_program_path "${__val}"`"
    then
	mk_log_end "$__path"
	mk_assign "${__var}" "${__path}"
	return 0
    else
	for __prog in "$@"
	do
	    if __path="`mk_resolve_program_path "${__prog}"`"
	    then
		mk_log_end "${__path}"
		mk_assign "${__var}" "${__path}"
		return 0
	    fi
	done
    fi

    mk_log_end "not found"
    return 1
}

mk_configure_help()
{
    @mk_generate_configure_help@
}

# Load manifest
. "${MK_MANIFEST_FILE}" || mk_fail "could not read ${MK_MANIFEST_FILENAME}"

# Save our arguments to write to the makefile
MK_CONFIGURE_ARGS=""
for __arg in "$@"
do
    MK_CONFIGURE_ARGS="$MK_CONFIGURE_ARGS `mk_quote "$__arg"`"
done

while [ -n "$1" ]
do
    _param="$1"
    shift
    
    case "${_param}" in
	--help)
	    mk_configure_help
	    exit 0
	    ;;
@mk_generate_configure_parse@
        *)
	    mk_fail "unrecognized option: $_param"
	    exit 1
	    ;;
    esac
done

mk_log "Configuring ${PROJECT_NAME}"
@mk_generate_configure_body@

mk_log "Creating ${MK_CONFIG_FILENAME}"
# Open config file
exec 4>${MK_CONFIG_FILE}

for __var in ${MK_DEFINE_LIST}
do
    __val="`mk_deref "$__var"`"
    echo "$__var=`mk_quote "$__val"`" >&4
done

echo "MK_EXPORT_LIST='`echo "${MK_EXPORT_LIST}" | sed -e 's/  *//' -e 's/^ //' -e 's/ $//'`'" >&4

# Close config file
exec 4>&-

mk_log "Creating ${MK_MAKEFILE_FILENAME}"
# Open up Makefile
exec 4>"${MK_MAKEFILE_FILE}"

sedscript="sed"

for __var in ${MK_DEFINE_LIST}
do
    __val="`mk_deref "$__var"`"
    sedscript="$sedscript -e `mk_quote "s|@$__var@|$__val|g"`"
    echo "$__var=$__val" >&4
done

echo "" >&4
eval ${sedscript} < "${MK_ROOT_DIR}/${MK_MAKEFILE_FILENAME}.in" | grep -v '^##' >&4

# Close Makefile
exec 4>&-

mk_log "Creating ${MK_ACTION_FILENAME}"
# Open up action file
exec 4>"${MK_ACTION_FILE}"

echo "#!${MK_SHELL}" >&4
echo "MK_ROOT_DIR='${MK_ROOT_DIR}'" >&4
echo "MK_WORK_DIR='${MK_WORK_DIR}'" >&4

cat "${MK_ROOT_DIR}/${MK_ACTION_FILENAME}.in" >&4

# Close action file
exec 4>&-

# Set action file executable
chmod +x "${MK_ACTION_FILE}"

# Set up basic directory structure
# FIXME: move this into modules
for dir in ${MK_TARGET_DIRNAME} ${MK_BUILD_DIRNAME} ${MK_STAGE_DIRNAME}
do
    mk_log "Creating directory ${dir}"
    mkdir -p "${MK_WORK_DIR}/${dir}"
done
