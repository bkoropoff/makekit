DIRNAME="`dirname "$0"`"
MK_ROOT_DIR="`mk_canonical_path "$DIRNAME"`"
MK_WORK_DIR="`pwd`"
MK_PREFIX="/usr/local"

MK_CONFIG_FD="4"
MK_DEFINE_LIST=""
MK_EXPORT_LIST=""

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
	--with-*)
	    __var="MK_`echo "$_param" | sed -e 's/^--with-//' -e 's/=.*$//' | tr 'a-z' 'A-Z' | tr '-' '_'`"
	    __val="`echo "$_param" | cut -d= -f2`"
	    __quoted="`mk_quote $__val`"
	    eval "${__var}=${__quoted}"
	    ;;	
	-*|--*)
	    mk_fail "Unrecognized option: ${_param}"
	    ;;
    esac
done

# Insert basic settings
mk_define MK_PREFIX

mk_log Configuring project
