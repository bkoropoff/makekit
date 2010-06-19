### section common

# Work around bashisms
if [ -n "$BASH_VERSION" ]
then
    # Make bash process aliases in non-interactive mode
    shopt -s expand_aliases
    # Unset special variable GROUPS so it becomes normal
    unset GROUPS
fi

alias mk_unquote_list='eval set --'

mk_function_exists()
{
    __exists_PATH="$PATH"
    PATH=""
    hash -r
    type "$1" >/dev/null 2>&1
    __exists_ret="$?"
    PATH="$__exists_PATH"
    return "$__exists_ret"
}

mk_safe_source()
{
    if [ -f "$1" ]
    then
	. "$1"
    else
	return 1
    fi
}

mk_source_or_fail()
{
    mk_safe_source "$1" || mk_fail "could not source file: $1"
}

mk_fail()
{
    mk_msg "ERROR: $@" >&2
    exit 1
}

mk_mkdir()
{
    for __dir in "$@"
        do
	mkdir -p "$__dir" || mk_fail "Could not create directory: $__dir"
    done
}

mk_get()
{
    eval result="\"\$$1\""
}

mk_set()
{
    eval "${1}=\${2}"
}

mk_is_set()
{
    eval [ -n "\"\${$1+yes}\"" ]
}

_mk_define_name()
{
    __rem="$1"
    result=""

    while [ -n "$__rem" ]
    do
	__rem2="${__rem#?}"
	__char="${__rem%"$__rem2"}"
	__rem="$__rem2"
	
	case "$__char" in
	    # Convert lowercase letters to uppercase
	    a) __char="A";; h) __char="H";; o) __char="O";; v) __char="V";;
	    b) __char="B";; i) __char="I";; p) __char="P";; w) __char="W";; 
	    c) __char="C";; j) __char="J";; q) __char="Q";; x) __char="X";; 
	    d) __char="D";; k) __char="K";; r) __char="R";; y) __char="Y";; 
	    e) __char="E";; l) __char="L";; s) __char="S";; z) __char="Z";; 
	    f) __char="F";; m) __char="M";; t) __char="T";;
	    g) __char="G";; n) __char="N";; u) __char="U";;
	    # Leave uppercase letters and numbers alone
	    A|B|C|D|E|F|G|H|I|J|K|L|M|N|O|P|Q|R|T|S|U|V|W|X|Y|Z|1|2|3|4|5|6|7|8|9) :;;
	    # Convert * to P
	    \*) __char="P";;
	    # Convert everything else to _
	    *) __char="_";;
	esac

	result="${result}${__char}"
    done
}

_mk_slashless_name()
{
    __rem="$1"
    result=""

    while [ -n "$__rem" ]
    do
	__rem2="${__rem#?}"
	__char="${__rem%"$__rem2"}"
	__rem="$__rem2"
	
	case "$__char" in
	    # Convert / to _
	    /) __char="_";;
	    # Leave everything else alone
	    *) :;;
	esac

	result="${result}${__char}"
    done
}

mk_msg_format()
{
    printf "%20s %s\n" "[$1]" "$2"
}

mk_log()
{
    [ -n "${MK_LOG_FD}" ] && mk_msg_format "$MK_MSG_DOMAIN" "$*" >&${MK_LOG_FD}
}

mk_log_verbose()
{
    [ -n "${MK_VERBOSE}" ] && mk_log "$@"
}

mk_msg()
{
    mk_log "$@"
    mk_msg_format "$MK_MSG_DOMAIN" "$*"
}

mk_msg_verbose()
{
    [ -n "${MK_VERBOSE}" ] && mk_msg "$@"
}

mk_quote()
{
    result=""
    __rem="$1"
    while true
    do
	__prefix="${__rem%%\'*}"

	if [ "$__prefix" != "$__rem" ]
	then
	    result="${result}${__prefix}'\\''"
	    __rem="${__rem#*\'}"
	else
	    result="${result}${__rem}"
	    break
	fi
    done

    result="'${result}'"
}

mk_quote_list()
{
    ___result=""
    for ___item in "$@"
    do
	mk_quote "$___item"
	___result="$___result $result"
    done

    result="${___result# }"
}

mk_quote_space()
{
    result=""
    __rem="$1"
    while true
    do
	__prefix="${__rem%%\ *}"

	if [ "$__prefix" != "$__rem" ]
	then
	    result="${result}${__prefix}\\ "
	    __rem="${__rem#*\ }"
	else
	    result="${result}${__rem}"
	    break
	fi
    done
}

mk_quote_list_space()
{
    ___result=""
    for ___item in "$@"
    do
	mk_quote_space "$___item"
	___result="$___result $result"
    done

    result="${___result# }"
}

mk_quote_c_string()
{
    result=""
    __rem="$1"
    while true
    do
	__prefix="${__rem%%[\"\\]*}"

	if [ "$__prefix" != "$__rem" ]
	then
	    __rem="${__rem#$__prefix}"
	    case "$__rem" in
		"\\"*)
		    result="${result}${__prefix}\\\\"
		    ;;
		"\""*)
		    result="${result}${__prefix}\\\""
		    ;;
	    esac
	    __rem="${__rem#?}"
	else
	    result="${result}${__rem}"
	    break
	fi
    done

    result="\"${result}\""
}

mk_expand_pathnames()
{
    ___result=""
    ___pwd="$PWD"
    ___dir="${2-${MK_SOURCE_DIR}${MK_SUBDIR}}"

    cd "$___dir" || return 1
    mk_unquote_list "$1"
    cd "$___pwd" || mk_fail "where did my directory go?"
    
    for ___item in "$@"
    do
	mk_quote "$___item"
	___result="$___result $result"
    done
    result="${___result# }"
}

# Matches a list of pathname patterns that specify absolute paths
# against a directory (by default, the staging directory).  Because
# the pathnames are absolute we have to be clever in order to get
# the shell to match against the working directory instead of
# the root of the filesstem
mk_expand_absolute_pathnames()
{
    ___result=""
    ___pwd="$PWD"
    ___dir="${2-${MK_STAGE_DIR}}"

    # Unquote list with globbing turned off
    # This gives us a list of unexpanded patterns in $@
    set -f
    mk_unquote_list "$1"
    set +f

    # Enter the directory where matching should take place
    cd "$___dir" || return 1

    for ___item in "$@"
    do
	# Prefix with .
	# For example, /usr/bin/* becomes ./usr/bin/*
	___item=".${___item}"
	# Now we can actually expand the pattern
	# First, make IFS empty to prevent field splitting
	___ifs="$IFS"
	IFS=""
	# Set $@ to the expansion.  Note that this doesn't
	# interfere with the outer for loop
	set -- ${___item}
	# Restore IFS
	IFS="$___ifs"

	# Now iterate over each match
	for ___item in "$@"
	do
	    # Strip the leading . we added
	    mk_quote "${___item#.}"
	    ___result="$___result $result"
	done
	IFS=""
    done

    # Go back home
    cd "$___pwd" || mk_fail "where did my directory go?"

    result="${___result# }"
}

mk_normalize_path()
{
    __path_IFS="$IFS"
    IFS="/"
    set -f
    set -- ${1}
    set +f
    IFS="$__path_IFS"

    result=""
    
    for __path_item in "$@"
    do
	case "$__path_item" in
	    '.')
		continue;
		;;
	    '..')
		if [ -z "$result" ]
		then
		    result="/.."
		else
		    result="${result%/*}"
		fi
		;;
	    *)
		result="${result}/${__path_item}"
		;;
	esac
    done

    result="${result#/}"
    unset __path_IFS __path_item
}

_mk_find_resource()
{
    for __dir in ${MK_SEARCH_DIRS}
    do
	__file="${__dir}/$1"
	if [ -f "$__file" ]   
	then
	    result="$__file"
	    return 0
	fi
    done

    return 1
}

_mk_contains()
{
    ___needle="$1"
    shift
    
    for ___hay in "$@"
    do
	if [ "$___hay" = "$___needle" ]
	then
	    return 0
	fi
    done

    return 1
}

_mk_reverse()
{
    result=""
    for ___item in "$@"
    do
	result="$___item $result"
    done

    result="${result% }"
}

_mk_random()
{
    if [ -z "$MK_RANDOM_SEED" ]
    then
	MK_RANDOM_SEED=`date '+%s'`
	_mk_random
	_mk_random
	_mk_random
	_mk_random
	_mk_random
	_mk_random
	_mk_random
	_mk_random
	_mk_random
    fi

    if [ -n "$*" ]
    then
	echo $(( $MK_RANDOM_SEED % ($2 - $1 + 1) + $1 ))
    fi

    MK_RANDOM_SEED=$(( ($MK_RANDOM_SEED * 9301 + 4929) % 233280 ))
}

mk_command_params()
{
    _params=""

    for _param in "$@"
    do
	mk_get "$_param"
	
	if [ -n "$result" ]
	then
	    mk_quote "$result"
	    _params="$_params $_param=$result"
	fi
    done

    result="$_params"
}

#
# Extended parameter support
#
# The following functions/aliases implement keyword parameters and
# local variables on top of basic POSIX sh:
#
# mk_push_vars var1 [ var2 ... ]
#
#   Saves the given list of variables to a safe location and unsets them
#
# mk_pop_vars
#
#   Restores the variables saved by the last mk_push_vars
#
# mk_parse_params
#
#   Parses all keyword parameters in $@ and sets them to variables.
#   Leaves the first non-keyword parameter at $1
#

if [ -n "$BASH_VERSION" ]
then
    # If we are running in bash, implement these features in terms
    # of the 'local' builtin.  This is much faster than the POSIX sh
    # versions below.
    alias mk_parse_params='
while true 
do
  case "$1" in
    *"="*)
      local "$1"
      shift
    ;;
    *)
      break
    ;;
  esac
done'
    # Simply declare variables we wish to save as local to avoid overwriting them
    alias mk_push_vars=local
    # Pop becomes a no-op since local variables go out of scope automatically
    alias mk_pop_vars=:
else
    # These versions work on any POSIX-compliant sh implementation
    alias mk_parse_params='
while true 
do
  case "$1" in
    *"="*)
      mk_set "${1%%=*}" "${1#*=}"
      shift
    ;;
    *)
      break
    ;;
  esac
done'

    _MK_VAR_SP="0"
    
    mk_push_vars()
    {
	for ___var in "$@" _MK_VARS
	do
	    eval "_MK_VAR_${_MK_VAR_SP}_${___var}=\"\$${___var}\""
	    unset "$___var"
	done
	
	_MK_VARS="$*"
	_MK_VAR_SP=$(( $_MK_VAR_SP + 1 ))
    }
    
    mk_pop_vars()
    {
	_MK_VAR_SP=$(( $_MK_VAR_SP - 1 ))
	
	for ___var in ${_MK_VARS} _MK_VARS
	do
	    eval "$___var=\"\$_MK_VAR_${_MK_VAR_SP}_${___var}\""
	    unset "_MK_VAR_${_MK_VAR_SP}_${___var}"
	done
    }
fi
