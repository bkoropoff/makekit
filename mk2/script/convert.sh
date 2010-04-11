#!/bin/sh

. "${MK_HOME}/mk.sh"

# Convert all variables in Makefile.am into a shell script we can source
_IFS="$IFS"
IFS='
'

{
    for line in `cat "$1" | sed ':START;N;s/\\\\\\n//;b START' | sed -e 's/$(\([^)]*\))/${\1}/g' -e 's/@\([^@]*\)@/\\\\${\1}/g'  | grep '^[a-zA-Z_]*[ \t]*+*='`
    do
	case "$line" in
	    *"+="*)
		_var="`echo $line | sed 's/[ \t]*+=.*//'`"
		_val="`echo $line | sed -e 's/[^+]*+=[ \t]*//' -e 's/[ \t][ \t]*/ /g'`"
		echo "$_var=\"\$$_var $_val\""
		;;
	    **)
		_var="`echo $line | sed 's/[ \t]*=.*//'`"
		_val="`echo $line | sed -e 's/[^+]*=[ \t]*//' -e 's/[ \t][ \t]*/ /g'`"
		echo "$_var=\"$_val\""
		;;
	esac
    done
} > .temp

IFS="$_IFS"

. "./.temp"

for var in `sed 's/=.*$//g' < .temp | sort | uniq`
do
    case "$var" in
	*_LTLIBRARIES)
	    for lib in `_mk_deref "$var"`
	    do
		canon="`echo "$lib" | tr './' '__'`"

		for libadd in `_mk_deref "${canon}_LIBADD"`
		do
		    _temp="`basename "${libadd}"`"
		    _temp="${_temp#-l}"
		    _temp="${_temp#lib}"
		    _temp="${_temp%.la}"
		    libs="$libs $_temp"
		done

		echo $canon
		echo 'mk_library \'
		echo "    SOURCES='`_mk_deref "${canon}_SOURCES"`' \\"
		echo "    LIBS='$libs'"
		echo ""
	    done
	    ;;
    esac
done