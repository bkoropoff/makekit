#!/bin/sh

. "${MK_HOME}/mk.sh" || exit 1

_mk_load_modules()
{
    for _module in `_mk_modules`
    do
	unset load

	_mk_source_module "$_module"

	case "`type load 2>&1`" in
	    *"function"*)
		MK_MSG_DOMAIN="${_module}"
		load
		;;
	esac
    done
}

mk_import

for __dir in ${MK_SEARCH_DIRS}
do
    __script="${__dir}/script/${1}.sh"
    if [ -f "${__script}" ]
    then
	shift
	mk_parse_params
	_mk_load_modules
	. "${__script}"
	return $?
    fi
done

mk_fail "Could not find script in search patch: $1"
