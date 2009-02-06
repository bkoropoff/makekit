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
@mk_include lib/paths.sh@
@mk_include lib/util.sh@

. "${MK_MANIFEST_FILE}" || mk_fail "could not read ${MK_MANIFEST_FILENAME}"
. "${MK_CONFIG_FILE}" || mk_fail "coould not read ${MK_CONFIG_FILENAME}"

if [ -n "${MK_EXPORT_LIST}" ]
then
    export ${MK_EXPORT_LIST}
fi

@mk_generate_action_rules@

while [ -n "$1" ]
do
    action="$1"
    shift
    case "$action" in
	--make)
	    MAKE="$1"
	    shift;
	    export MAKE
	    ;;
	--*)
	    mk_fail "Unrecognized option: ${action}"
	    ;;
	*)
	    MK_COMP="$1"
	    shift
	    if mk_function_exists "${MK_COMP}_${action}"
	    then
		"${MK_COMP}_${action}" "$@"
		exit $?
	    else
		mk_fail "Invalid action and component: ${action} ${MK_COMP}"
	    fi
	    ;;
    esac
done
