#
# Copyright (c) Brian Koropoff
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#     * Redistributions of source code must retain the above copyright
#       notice, this list of conditions and the following disclaimer.
#     * Redistributions in binary form must reproduce the above copyright
#       notice, this list of conditions and the following disclaimer in the
#       documentation and/or other materials provided with the distribution.
#     * Neither the name of the MetaKit project nor the names of its
#       contributors may be used to endorse or promote products derived
#       from this software without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS ``AS IS''
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDERS OR CONTRIBUTORS
# BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
# CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
# SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
# INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
# CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
# ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF
# THE POSSIBILITY OF SUCH DAMAGE.
#

##
#
# build.sh -- invoked by make to run a build action
#
##

### section build

# Restores context of particular subdirectory
_mk_restore_context()
{
    # Set subdir
    MK_SUBDIR="$1"

    case "$MK_SUBDIR" in
	":")
	    MK_MSG_DOMAIN="metakit"
	    mk_source_or_fail "${MK_ROOT_DIR}/.MetaKitExports"
	    ;;
	"")
	    MK_MSG_DOMAIN="${MK_SOURCE_DIR##*/}"
	    mk_source_or_fail "${MK_OBJECT_DIR}/.MetaKitExports"
	    mk_source_or_fail "${MK_SOURCE_DIR}/MetaKitBuild"
	    ;;
	*)
	    MK_MSG_DOMAIN="${MK_SUBDIR#/}"
	    mk_source_or_fail "${MK_OBJECT_DIR}${MK_SUBDIR}/.MetaKitExports"
	    mk_source_or_fail "${MK_SOURCE_DIR}${MK_SUBDIR}/MetaKitBuild"
	    ;;
    esac

    unset -f configure make option
}

[ "$1" = "-c" ] || mk_fail "invalid invocation"

eval "$2"
