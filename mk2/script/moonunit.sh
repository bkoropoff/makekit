#!/bin/sh

MK_MSG_DOMAIN="test"

mk_msg "moonunit"
mk_run_program ${MOONUNIT} "$@" || mk_fail "unit tests failed"
