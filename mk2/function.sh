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

__script="$1"
shift
_mk_load_modules
mk_safe_source "${__script}"
"$@"

