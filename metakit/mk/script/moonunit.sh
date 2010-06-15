#!/bin/sh

MK_MSG_DOMAIN="test"

mk_msg "moonunit"
env LD_LIBRARY_PATH="${MK_STAGE_DIR}${MK_LIBDIR}" \
    ${MOONUNIT} "$@" || mk_fail "unit tests failed"
