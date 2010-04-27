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
    eval RET="\"\$$1\""
}

_mk_set()
{
    eval "${1}=\${2}"
}

_mk_def_name()
{
    echo "$1" | tr 'a-z-./' 'A-Z___'
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
    RET=""
    __rem="$1"
    while true
    do
	__prefix="${__rem%%\'*}"

	if [ "$__prefix" != "$__rem" ]
	then
	    RET="${RET}${__prefix}'\\''"
	    __rem="${__rem#*\'}"
	else
	    RET="${RET}${__rem}"
	    break
	fi
    done

    RET="'${RET}'"
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

    for _file in "${MK_HOME}/module/"*.sh
    do
	_module="`basename "$_file"`"
	_module="${_module%.sh}"
	unset DEPENDS
	. "$_file"
	_mk_modules_rec "$_module" "$DEPENDS"
    done

    echo "$_list"
}

_mk_load_modules()
{
    for _module in `_mk_modules`
    do
	MK_MSG_DOMAIN="metakit"
	mk_msg "loading module: ${_module}"

	unset load
	. "${MK_HOME}/module/${_module}.sh"
	case "`type load 2>&1`" in
	    *"function"*)
		MK_MSG_DOMAIN="${_module}"
		load
		;;
	esac
    done
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
	
	if [ -n "$RET" ]
	then
	    mk_quote "$RET"
	    _params="$_params $_param=$RET"
	fi
    done

    RET="$_params"
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
