while [ -n "$1" ]
do
    action="$1"
    shift
    case "$action" in
	--make)
	    MAKE="$1"
	    shift;
	    export MAKE
	    ;;
	prepare)
	    comp="$1"
	    shift
	    mk_prepare "${comp}"
	    ;;
	build)
	    comp="$1"
	    shift
	    mk_build "${comp}"
	    ;;
	stage)
	    comp="$1"
	    shift
	    mk_stage "${comp}"
	    ;;
	*)
	    mk_fail "Unrecognized parameter: $action"
	    ;;
    esac
done
