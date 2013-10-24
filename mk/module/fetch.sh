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
#     * Neither the name of the MakeKit project nor the names of its
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

#<
# @module fetch
# @brief Remote file fetching and unpacking
#
# This module provides functions for fetching remote
# file and unpacking archives.
#>

DEPENDS="program"

### section configure

option()
{
    mk_option \
        OPTION="fetch-dir" \
        VAR="MK_FETCH_DIR" \
        PARAM="dir" \
        DEFAULT="fetch" \
        HELP="Directory where fetched resources are placed"
}

configure()
{
    mk_check_program curl
    mk_check_program wget
}

make()
{
    mk_add_scrub_target "@$MK_FETCH_DIR"
}

#<
# @brief Fetch remote file
# @usage TARGET=dest URL=url
# @option TARGET=dest Destination where file will be placed.
# @option URL=url The URL to fetch.
#
# Fetches the remote file at <param>url</param> and stores
# it at <param>dest</param>, which is a target in the usual
# notation.
#
# Sets <var>result</var> to the resulting target.
#>
mk_fetch()
{
    mk_push_vars TARGET URL
    mk_parse_params

    mk_target \
        TARGET="$TARGET" \
        _mk_fetch '$@' "$URL"

    mk_pop_vars
}

#<
# @brief Unpack archive
# @usage ARCHIVE=archive DIR=dir
# @option ARCHIVE=archive The target archive to unpack.
# @option DIR=dir The target directory to create by unpacking the archive.
# @option FILES=files An optional list of files, relative to <param>dir</param>,
#                     which will be created.  Specifying this is optional, but
#                     it ensures that anything that depends on an unpacked file
#                     will depend on the archive being unpacked.
#
# Unpacks the archive <param>archive</param> to the create the
# directory <param>dir</param>.  If the archive contains a single
# top-level directory, this directory will become <param>dir</param>.
# This is generally convenient for unpacking source tarballs to
# build, as by <funcref>mk_chain_autotools</funcref>.  Otherwise,
# <param>dir</param> is created and the contents are placed
# within.
#
# Sets <var>result</var> to a target which depends on the
# the output directory target and all file targets generated.
#>
mk_unpack()
{
    mk_push_vars ARCHIVE DIR FILES file targets
    mk_parse_params

    mk_resolve_target "$DIR"
    [ -d "${result#@}" ] || mk_append_list targets "$result"

    mk_unquote_list "$FILES"
    for file
    do
        mk_append_list targets "$DIR/$file"
    done

    mk_multi_target \
        TARGETS="$targets" \
        @DEPS={ "$ARCHIVE" } \
        _mk_unpack "&$DIR" "&$ARCHIVE"

    mk_pop_vars
}

#<
# @brief Fetch and unpack archive
# @usage URL=url DIR=dir
# @option URL=url The URL where the archive can be found.
# @option DIR=dir The target directory to create by unpacking the archive.
# @option FILES=files An optional list of files, relative to <param>dir</param>,
#                     which will be created.  Specifying this is optional, but
#                     it ensures that anything that depends on an unpacked file
#                     will depend on the archive being unpacked.
#
# Similar to <funcref>mk_unpack</funcref>, but first fetches the
# archive using <funcref>mk_fetch</funcref>.
#>
mk_fetch_unpack()
{
    mk_push_vars DIR URL FILES
    mk_parse_params

    mk_basename "$URL"
    mk_fetch TARGET="@$MK_FETCH_DIR/$result" URL="$URL"
    mk_unpack ARCHIVE="$result" DIR="$DIR" FILES="$FILES"

    mk_pop_vars
}

### section build

# Build-time function to perform fetch of file with curl/wget
_mk_fetch()
{
    # $1 = output
    # $2 = resource

    mk_msg_domain fetch
    mk_msg "$2"

    mk_mkdirname "$1"

    if [ -n "$WGET" ]
    then
        mk_run_quiet_or_fail "$WGET" -O "$1" "$2"
    elif [ -n "$CURL" ]
    then
        mk_run_quiet_or_fail "$CURL" -o "$1" "$2"
    else
        mk_fail "No program available to download $2 to $1.  Please download the file manually."
    fi

    mk_run_quiet_or_fail touch "$1"
}

# Build-time function to unpack archive
_mk_unpack()
{
    dir="$1"
    archive="$2"

    mk_msg_domain unpack
    mk_basename "$archive"
    mk_msg "$result"

    mk_tempfile unpack
    tmpdir="$result"

    mk_mkdir "$tmpdir"

    # Figure out how to unpack archive and do it
    # FIXME: support more formats
    # FIXME: support versions of tar that don't understand z/j flags
    case "$2" in
        *.tar.gz|*.tgz)
            mk_run_quiet_or_fail tar -C "$tmpdir" -xzf "$archive"
            ;;
        *.tar.bz2)
            mk_run_quiet_or_fail tar -C "$tmpdir" -xjf "$archive"
            ;;
        *.tar)
            mk_run_quiet_or_fail tar -C "$tmpdir" -xf "$archive"
            ;;
        *)
            mk_basename "$archive"
            mk_fail "Don't know how to unpack archive: $result"
            ;;
    esac

    # Take a look at what we unpacked
    set -- "$tmpdir"/*

    if [ $# -eq 1 -a -d "$1" ]
    then
        # Archive contained a single top-level directory.
        # This is typical for many source tarballs.
        # Simply rename it to be the destination directory.
        mk_safe_rm "$dir"
        mk_run_quiet_or_fail mv "$1" "$dir"
        mk_run_quiet_or_fail touch "$dir"
    else
        # Archive contained loose files or multiple directories.
        # Create the destination directory and move everything into
        # it.
        mk_safe_rm "$dir"
        mk_mkdir "$dir"
        mk_run_quiet_or_fail mv "$tmpdir"/* "$dir/"
    fi
}