#!/bin/sh

. "${MK_HOME}/mk.sh" || exit 1

mk_import

for __dir in ${MK_SEARCH_DIRS}
do
    __script="${__dir}/script/${1}.sh"
    if [ -f "${__script}" ]
    then
	shift
	mk_parse_params
	. "${__script}"
	return $?
    fi
done

mk_fail "Could not find script in search patch: $1"
