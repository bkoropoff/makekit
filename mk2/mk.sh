MK_SCRIPT_DIR="${MK_HOME}/script"
MK_MODULE_DIR="${MK_HOME}/module"

_mk_try()
{
    mk_msg_verbose "run: $@"

    _output=`"$@" 2>&1`
    _ret=$?

    if [ $_ret -ne 0 ]
    then
	mk_msg "FAILED: $@"
	echo "$_output"
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

_mk_deref()
{
    eval echo "\"\$$1\""
}

_mk_set()
{
    eval "${1}=`_mk_quote_shell "${2}"`"
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

_mk_set_arg()
{
    _val="${1#*=}"
    _name="${1%%=*}"
    eval "${_name}='${_val}'"
}

_mk_quote_shell()
{
    case "$1" in
	*\'*)
	    # Calling sed is orders of magnitude
	    # slower than using shell functions and
	    # builtins, and this function is called
	    # frequently, so only do it when necessary
	    printf "'"
	    printf "%s" "$1" | sed "s:':'\\\'':g"
	    printf "'\n"
	    ;;
	*)
	    echo "'$1'"
	    ;;
    esac
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
    _needle="$1"
    shift
    
    for _hay in "$@"
    do
	if [ "$_hay" = "$_needle" ]
	then
	    return 0
	fi
    done

    return 1
}

MK_RANDOM_SEED=`date '+%s'`

_mk_random()
{
    if [ -n "$*" ]
    then
	echo $(( $MK_RANDOM_SEED % ($2 - $1 + 1) + $1 ))
    fi
    MK_RANDOM_SEED=$(( ($MK_RANDOM_SEED * 9301 + 4929) % 233280 ))
}

_mk_random
_mk_random
_mk_random
_mk_random
_mk_random
_mk_random
_mk_random
_mk_random
_mk_random

alias _mk_args='
while true 
do
  case "$1" in
    *"="*)
      eval "${1%%=*}=`_mk_quote_shell "${1#*=}"`"
      shift
    ;;
    *)
      break
    ;;
  esac
done'

mk_command_params()
{
    _params=""

    for _param in "$@"
    do
	_val="`_mk_deref "$_param"`"
	
	if [ -n "$_val" ]
	then
	    _params="$_params $_param=`_mk_quote_shell "$_val"`"
	fi
    done

    echo "${_params# }"
}