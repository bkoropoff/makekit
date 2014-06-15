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
DEPENDS="core path compiler program"

#<
# @module rust
# @brief Build Rust projects
#
# The <lit>rust</lit> module allows building Rust libraries and programs.
#>

#<
# @var MK_RUSTFLAGS
# @brief Rust compiler flags
# @export
# @inherit
#
# Additional flags to pass to the Rust compiler.
#>

#<
# @var RUSTC
# @brief Rust compiler
# @export
#
# The Rust compiler.
#>

### section common

### section configure

option()
{
    if [ "$MK_DEBUG" = yes ]
    then
        _default_rustflags="-g -C rpath"
    else
        _default_rustflags="-O -C rpath"
    fi

    mk_option \
        OPTION="rustflags" \
        VAR="RUSTFLAGS" \
        PARAM="flags" \
        DEFAULT="$_default_rustflags" \
        HELP="Flags to pass to rustc"
}

configure()
{
    mk_declare -i -e MK_RUSTFLAGS="$RUSTFLAGS"

    mk_msg "rustc flags: $MK_RUSTFLAGS"

    mk_add_scour_target ".mkrust"
}

#<
# @brief Check for rust prerequisites
# @usage
# @option FAIL=yes|no Fail configuration if not found
#
# Checks for whether the build system can build Rust
# code.  The result can be checked with
# <funcref>mk_have_rust</funcref>.
#>
mk_check_rust()
{
    mk_push_vars FAIL=no
    mk_parse_params

    mk_check_program rustc

    if [ "$FAIL" = yes ] && ! mk_have_rust
    then
        mk_fail "rust is not available on this system"
    fi

    if [ ! -x ".mkrust" ]
    then
        mk_msg "building mkrust"
        mk_resolve_resource "rust/mkrust.rs"
        mk_unquote_list "$MK_RUSTFLAGS"
        mk_run_or_fail "$RUSTC" "$@" -o ".mkrust" "$result"
    fi

    mk_pop_vars
}

#<
# @brief Test whether Rust is available
# @usage
#
# Indicates the result of <funcref>mk_check_rust</funcref>.
# Returns <lit>0</lit> (logical true) on success, and
# <lit>1</lit> (logical false) on failure.
#>
mk_have_rust()
{
    [ -n "$RUSTC" ]
}

_mk_rust_output_for_source()
{
    result="$1"
    mk_unquote_list "$MK_RUSTFLAGS $FLAGS"
    mk_capture_lines "$RUSTC" "$@" --print-file-name "$result"
}

_mk_rust_libdeps_for_source()
{
    mk_push_vars tmp rs="$1"
    
    mk_tempfile
    tmp="$result"

    mk_unquote_list "$MK_RUSTFLAGS $FLAGS"
    "$RUSTC" "$@" -Z ast-json "$rs" | ./.mkrust > "$tmp" || mk_fail "could not extract libdeps: $1"
    mk_capture_lines cat "$tmp"
    mk_tempfile_delete
 
    mk_pop_vars
}

_mk_rust_process_libdeps()
{
    _mk_rust_libdeps_for_source "$1"

    mk_unquote_list "$result"
    for _dep
    do
        if mk_have_internal_library "$_dep"
        then
            mk_append_list deps "$MK_LIBDIR/lib$_dep.la"
        fi
    done
}

_mk_rust()
{
    mk_push_vars \
        targets output stamp libname binname installdir \
        input="$1" deps="$DEPS"

    # Add source to dependency list
    mk_append_list deps "$input"

    # Add all external crates to dependency list
    _mk_rust_process_libdeps "${input#@}"

    _mk_rust_output_for_source "${input#@}"
    mk_unquote_list "$result"

    for output
    do
        case "$output" in
            *"$MK_LIB_EXT"|*.rlib|*.a)
                if [ -n "$binname" ]
                then
                    mk_fail "mk_rust: mixed bin/lib crate not supported: ${input#@}"
                fi
                mk_basename "$output"
                libname="${result%.*}"
                libname="${libname%%-*}"
                libname="${libname#lib}"
                installdir="$LIB_INSTALLDIR"
                ;;
            *)
                if [ -n "$libname" ]
                then
                    mk_fail "mk_rust: mixed bin/lib crate not supported: ${input#@}"
                fi
                binname="$output"
                installdir="$BIN_INSTALLDIR"
                ;;
        esac
        mk_resolve_target "$installdir/$output"
        mk_append_list targets "$result"
    done

    mk_multi_target \
        TARGETS="$targets" \
        DEPS="$deps" \
        _mk_rust_build %FLAGS "$input" "*$targets"
    stamp="$result"

    if [ -n "$libname" ]
    then
        mk_declare_internal_library "$libname"
        
        mk_resolve_target "$LIB_INSTALLDIR/lib$libname.la"
        
        mk_target \
            TARGET="$result" \
            DEPS="$stamp" \
            _mk_rust_la "$result" "*$targets"
        
        mk_pop_vars
    fi
}

#<
# @brief Build Rust crates
# @usage sources...
# @option FLAGS=flags     Specifies additional flags to the Rust
#                         compiler, which are placed after those in
#                         <varref>MK_RUSTFLAGS</varref>.
# @option BIN_INSTALLDIR=bindir  Directory where program binaries are installed.
#                                Defaults to <lit>$MK_BINDIR</lit>.
# @option LIB_INSTALLDIR=libdir  Directory where libraries are installed.
#                                Defaults to <lit>$MK_LIBDIR</lit>.
# @option sources         A list of Rust source files, each of which is compiled
#                         to its own crate of the appropriate type.
#
# Builds a list of Rust sources into crates.
#>
mk_rust()
{
    mk_push_vars \
        DEPS FLAGS \
        LIB_INSTALLDIR="$MK_LIBDIR" BIN_INSTALLDIR="$MK_BINDIR" \
        source targets
    mk_parse_params

    mk_have_rust || mk_fail "mk_rust: rust not available on this system"

    for source
    do
        mk_resolve_target "$source"
        [ -f "${result#@}" ] || mk_fail "mk_rust: source file does not exist: $source"

        # Information about dependencies and build targets is extracted
        # from the crate source file, so configure must be rerun when it
        # changes to regenerate Makefile
        mk_add_configure_input "$input"

        _mk_rust "$result"
        mk_append_list targets "$result"
    done

    [ $# -gt 1 ] && mk_stamp_target DEPS="$targets"
}

### section build

# FIXME: this should be in core
_mk_rust_depfile_pre()
{
    # $1 = source

    _mk_slashless_name "$1"
    result=".MakeKitDeps/$result.dep"
    mk_mkdirname "$result"
}

# FIXME: this should be in core
_mk_rust_depfile_post()
{
    # $1 = depfile
    # $2 = new

    if diff -q -- "$1" "$2" >/dev/null 2>&1
    then
        mk_safe_rm "$2"
    else
        mk_run_or_fail mv -f "$2" "$1"
        mk_incremental_deps_changed
    fi
}

_mk_rust_build()
{
    mk_push_vars FLAGS depfile source target outdir
    mk_parse_params

    source="$1"
    shift

    mk_msg_domain rust

    mk_pretty_path "$source"
    mk_msg "$result"

    for target
    do
        mk_mkdirname "$target"
    done

    mk_dirname "$target"
    outdir="$result"

    _mk_rust_depfile_pre "$target"
    depfile="$result"

    mk_unquote_list "$MK_RUSTFLAGS $FLAGS"

    mk_run_or_fail "$RUSTC" \
        -L "$MK_STAGE_DIR$MK_LIBDIR" \
        --dep-info "$depfile.new" \
        --out-dir "$outdir" \
        -C link-args="$MK_RPATHFLAGS" \
        "$@" \
        "$source"

    _mk_rust_depfile_post "$depfile" "$depfile.new"
}

_mk_rust_la()
{
    mk_push_vars target="$1" bin libdir names base
    shift

    mk_msg_domain la
    
    mk_pretty_path "$target"
    mk_msg "$result"

    { 
        echo "# Generated by MakeKit (libtool compatible)"
        for bin
        do
            mk_basename "$bin"
            base="$result"
            mk_append_list names "$base"

            case "$base" in
                *"$MK_LIB_EXT")
                    mk_quote "$base"
                    echo "dlname=$result"
                    mk_dirname "$bin"
                    libdir="$result"
                    ;;
                *.rlib)
                    mk_quote "$base"
                    echo "rlib=$result"
                    ;;
            esac
        done
        echo "library_names=$names"

        if [ -n "$libdir" ]
        then
            mk_quote "-L$libdir"
            echo "dependency_libs=$result"

            mk_quote "$libdir"
            echo "libdir=$result"
        fi
            
        echo "installed='yes'"
    } > "$target.new" || mk_fail "could not create $target"
    
    mk_run_or_fail mv -f -- "$target.new" "$target"
    mk_run_or_fail touch "$target"

    mk_pop_vars
}
