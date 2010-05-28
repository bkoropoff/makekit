# Make bash process aliases in non-interactive mode
if [ -n "$BASH_VERSION" ]
then
    shopt -s expand_aliases
fi

MK_SCRIPT_DIR="${MK_HOME}/script"
MK_MODULE_DIR="${MK_HOME}/module"

_mk_try()
{
    mk_msg_verbose "=> $*"

    ___output=`"$@" 2>&1`
    ___ret=$?

    if [ $___ret -ne 0 ]
    then
	mk_msg "FAILED: $@"
	echo "$___output"
	exit 1
    fi
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

mk_import()
{
    mk_safe_source "${MK_ROOT_DIR}/.MetaKitExports" || mk_fail "Could not read configuration"
    [ "$MK_SUBDIR" != ":" ] && mk_safe_source "${MK_OBJECT_DIR}${MK_SUBDIR}/.MetaKitExports"
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

_mk_deref()
{
    eval echo "\"\$$1\""
}

mk_get()
{
    eval result="\"\$$1\""
}

_mk_set()
{
    eval "${1}=\${2}"
}

_mk_def_name()
{
    echo "$1" | tr 'a-z-./ *' 'A-Z____P'
}

mk_log()
{
    [ -n "${MK_LOG_FD}" ] && echo "[$MK_MSG_DOMAIN] $*" >&${MK_LOG_FD}
}

mk_log_verbose()
{
    [ -n "${MK_VERBOSE}" ] && mk_log "$@"
}

mk_msg()
{
    mk_log "$@"
    echo "[$MK_MSG_DOMAIN] $*"
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

_mk_modules_rec()
{
    if ! _mk_contains "$1" ${_list}
    then
	for _dep in ${2}
	do
	    unset DEPENDS
	    . "${MK_HOME}/module/${_dep}.sh"
	    _mk_modules_rec "$_dep" "$DEPENDS"
	done
	_list="$_list $1"
    fi
}

_mk_modules()
{
    _list=""
    
    for __dir in ${MK_SEARCH_DIRS}
    do
	for __file in "${__dir}/module/"*.sh
	do
	    if [ -f "$__file" ]
	    then
		_module="`basename "$__file"`"
		_module="${_module%.sh}"
		unset DEPENDS
		. "$__file"
		_mk_modules_rec "$_module" "$DEPENDS"
	    fi
	done
    done

    echo "$_list"
}

_mk_source_module()
{
    for __dir in ${MK_SEARCH_DIRS}
    do
	__module="${__dir}/module/$1.sh"
	if [ -f "$__module" ]
	then
	    . "${__module}"
	    return $?
	fi
    done

    mk_fail "could not find module in search path: $1"
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
      _mk_set "${1%%=*}" "${1#*=}"
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
