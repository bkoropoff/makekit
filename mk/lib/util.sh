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

MK_LOG_DEPTH="0"
MK_LOG_DOMAIN=""
MK_LOG_FD="3"

exec 3>&1

mk_head()
{
    echo "$1"
}

mk_tail()
{
    shift
    echo "$@"
}

mk_quote()
{
    printf "'"
    printf "%s" "$1" | sed "s/'/'\\\\''/g"
    printf "'"
}

mk_first()
{
    echo "$1"
}

mk_fail()
{
    mk_log "Error: $@"
    exit 1
}

mk_log_pipe()
{
    __prefix=""
    __space=""
    __depth="0"
    
    while [ "$__depth" -lt "$MK_LOG_DEPTH" ]
    do
	__space="${__space}  "
	__depth="`expr "$__depth" + 1`"
    done

    __domain="`mk_head ${MK_LOG_DOMAIN}`"
    if [ -n "$__domain" ]
    then
	__prefix="[${__domain}] "
    fi

    IFS=''
    while read -r REPLY
    do
	unset IFS
	__date="`date '+(%H:%M:%S) '`"

	printf "%s\n" "${__date}${__space}${__prefix}$REPLY"
	IFS=''
    done

    return 0
}

mk_log_start()
{
    __prefix=""
    __space=""
    __depth="0"
    
    while [ "$__depth" -lt "$MK_LOG_DEPTH" ]
    do
	__space="${__space}  "
	__depth="`expr "$__depth" + 1`"
    done

    __domain="`mk_head ${MK_LOG_DOMAIN}`"
    if [ -n "$__domain" ]
    then
	__prefix="[${__domain}] "
    fi

    __date="`date '+(%H:%M:%S) '`"

    printf "%s" "${__date}${__space}${__prefix}$*" >&${MK_LOG_FD}
    return 0
}

mk_log_middle()
{
    printf "%s" "$*" >&${MK_LOG_FD}
}

mk_log_end()
{
    printf "%s\n" "$*" >&${MK_LOG_FD}
}

mk_log()
{
    mk_log_start "$*"
    mk_log_end
}

mk_log_enter()
{
    MK_LOG_DEPTH="`expr "${MK_LOG_DEPTH}" + 1`"
    MK_LOG_DOMAIN="$1 $MK_LOG_DOMAIN"
    return 0
}

mk_log_leave()
{
    MK_LOG_DEPTH="`expr "${MK_LOG_DEPTH}" - 1`"
    MK_LOG_DOMAIN="`mk_tail ${MK_LOG_DOMAIN}`"
    return 0
}

mk_log_domain()
{
    MK_LOG_DOMAIN="$1"
}

mk_show()
{
    mk_log "$@"
    if [ "${MK_SUPPRESS_COMMAND_OUTPUT}" = "true" ]
    then
	"$@" >/dev/null 2>&1
    else
	"$@"
    fi
}

mk_show_args()
{
    __first="$1"
    shift
    (
	echo "`basename "$__first"`"
	for __arg in "$@"
	do
	    echo "  $__arg"
	done
    ) | mk_log_pipe

    if [ "${MK_SUPPRESS_COMMAND_OUTPUT}" = "true" ]
    then
	"$__first" "$@" >/dev/null 2>&1
    else
	"$__first" "$@"
    fi
}

mk_extract_function()
{
    if grep "^$2 *\(\)" "$1" >/dev/null
    then
	echo ""
	echo "### Included function: $2() from `basename "$1"`"
	echo ""
	awk 'BEGIN { found=0; } /^}/ { found = 0; } { if (found == 2) print; } /^'"$2"' *\(\)/ { found=1; } /^{/ { if (found == 1) found = 2; }' < "$1"
	echo ""
	echo "### End included function"
	echo ""
    fi
}

mk_extract_defines()
{
    __vars="`grep "^[a-zA-Z0-9_]*=.*$" "$1" | sed 's/=.*$//g'`"
    for __var in ${__vars}
    do
	__val="`mk_extract_var "$1" "${__var}"`"
	echo "${2}${__var}=`mk_quote "${__val}"`"
    done
}

mk_extract_var()
{
    ( mk_assign "$2" ""; . "$1" >/dev/null 2>&1 && mk_deref "$2" )
}

mk_canonical_path()
{
    if echo "$1" | grep "^/" >/dev/null
    then
	echo "$1"
    else
	echo "`pwd`/$1" | sed \
	    -e 's:/[^/]*/\.\.::g' \
	    -e 's:\./::g' \
	    -e 's:/\.::g' \
	    -e 's://*:/:g'
    fi
}

mk_order_by_depends()
{
    __pending="$*"
    __list=""

    while [ -n "$__pending" ]
    do
	__waiting=""
	for __candidate in ${__pending}
	do
	    __dirname="`dirname "$__candidate"`"
	    __typename="`basename "$__dirname"`"
	    __good=true
	    __base="`basename "$__candidate"`"
	    __deps="`mk_extract_var "$__candidate" DEPENDS`" || mk_fail "file not found: $__candidate"
	    for __dep in ${__deps}
	    do
		if echo "$__pending $__list" | grep "/$__dep " >/dev/null
		then
		    if echo "$__list" | grep "/$__dep " >/dev/null
		    then
			:
		    else
			__good=false
			break
		    fi
		else
		    # Uh-oh
		    mk_fail "$__typename `basename "$__candidate"`: dependency '$__dep' not found"
		fi
	    done

	    if $__good
	    then
		__list="$__list $__candidate "
	    else
		__waiting="$__waiting $__candidate "
	    fi
	done
	__pending="$__waiting"
    done

    echo "$__list"
}

mk_unique_list()
{
    echo "$@" | awk 'BEGIN { RS=" "; } { print; }' | sort | uniq | xargs
}

mk_expand_depends()
{
    __dir="$1"
    __typename="`basename "$__dir"`"
    shift;

    __list=""
    __pending=" $* "
    __working=""

    while [ -n "$__pending" ]
    do
	__working="$__pending"
	__pending=""

	for __guy in ${__working}
	do
	    if echo "$__list" | grep " $__guy " >/dev/null
	    then
		:
	    else
		__list=" $__guy $__list"
		__deps="`mk_extract_var "$__dir/$__guy" DEPENDS`" || mk_fail "$__typename not found: $__guy"
		__pending="`mk_extract_var "$__dir/$__guy" DEPENDS` $__pending"
	    fi
	done
    done

    echo "${__list}"
}

mk_function_exists()
{
    type "$1" 2>/dev/null | grep "function" >/dev/null
}

mk_function_exists_in_file()
{
    grep "^${2} *\(\)" "${1}" >/dev/null 2>&1
}

mk_sed_file()
{
    __file="$1"
    shift
    sed "$@" < "${__file}" > "${__file}.sed"
    mv "${__file}.sed" "${__file}"
}

mk_deref()
{
    eval "echo \"\${$1}\""
}

mk_assign()
{
    eval "$1=`mk_quote "$2"`"
}

mk_resolve_program_path()
{
    if [ -z "$1" ]
    then
	return 1
    elif [ -x "/$1" ]
    then
	echo "$1"
	return 0
    else
	(
	    IFS=":"
	    for __path in ${PATH}
	    do
		if [ -x "${__path}/$1" ]
		then
		    echo "${__path}/${1}"
		    return 0
		fi
	    done
	    return 1
	)
	return $?
    fi
    set +x
}

mk_reverse_list()
{
    (
	for __i
	do
	    echo "$__i"
	done
    ) | tac
}

mk_recreate_dir()
{
    rm -rf "$1"
    mkdir -p "$1"
}

mk_make_identifier()
{
    echo "$1" | tr -- '-a-z' '_A-Z'
}

mk_sync()
{
    if echo "$1" | grep '/$' >/dev/null 2>&1
    then
	cp -fpPR "$1"* "$2"
    else
	cp -fpPR "$1" "$2"
    fi
}

mk_contains()
{
    for __ele in ${1}
    do
	if [ "$__ele" = "$2" ]
	then
	    return 0
	fi
    done
    
    return 1
}
