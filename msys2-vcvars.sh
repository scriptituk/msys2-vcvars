#!/usr/bin/env bash

#==========================================================================================
# MSYS2 MSVC environment import tool by Raymond Luckhurst, Scriptit UK, https://scriptit.uk
# GitHub: https://github.com/scriptituk/msys2-mcvars   February 2025   MIT Licence
#==========================================================================================

# Wrapper for MSVC vcvarsall.bat and MSYS2 msys2_shell.cmd scripts
#
# Inspired by script extractvcvars.sh from the OpenJDK project
#    https://cr.openjdk.org/~erikj/build-infra5/webrev.01/common/bin/extractvcvars.sh.html
#
# Imports VC++ path and environment variables for command-line builds into current process
# Delegates to MSVC vcvarsall.bat (front end to VsDevCmd.bat) and MSYS2 msys2_shell.cmd scripts
#
# Usage: vcvarsall [args] (args are sent to vcvarsall.bat unaltered)
# args:= [architecture] [platform_type] [winsdk_version] [-vcvars_ver=vcversion] [spectre_mode]
# returns 0 on success
# See https://learn.microsoft.com/en-us/cpp/build/building-on-the-command-line#vcvarsall-syntax
# Default arg is x64 (native x86_64 architecture)
#
# The undocumented /clean_env option is not sent to vcvarsall.bat as its context is temporary,
# instead /clean_env (or -clean_env) reverts the import, restoring the original MSYS2 environment
#
# First, launch a MSYS2 MSYS terminal from the Windows Start Menu shortcut in the MSYS2 folder
# or run C:\msys64\msys2_shell.cmd from a Command Prompt window
# Any MSYS2 environment will work but /usr/bin/link will get masked in $PATH
# There is no need to edit the msys2_shell.cmd MSYS2_PATH_TYPE setting or -use-full-path
# because the full Windows %PATH% is inherited explicitly
#
# Notes:
# 1. source this file, don't exec it; the shebang is only for standalone testing
#    similarly, call function vcvarsall inline, as command substitution will import nothing
# 2. this script uses find to locate vcvarsall.bat, not the complex vswhere.exe tool,
#    or if set $VCVARSALL_PATH as the absolute path to vcvarsall.bat (Unix or Windows format)
#
# All commands used are in the standard msys2 install at /usr/bin: cygpath u2d cmd comm etc.
#
# It is not difficult to modify this script for other Windows unices such as Cygwin and WSL

DEBUG=${DEBUG-no} # set yes to echo commands for debugging

_fd2() { echo "$1" >&2; } # echo to stderr

vcvarsall() { # takes same args as vcvarsall.bat
    local db_setx db_echo='@echo off' db_nul='> nul'
    [[ $DEBUG == yes ]] && db_setx='set -x' db_echo= db_nul=
    local -; $db_setx

    [[ -n $MSYSTEM ]] || { _fd2 'MSYSTEM undefined, aborting'; return 64; }

    # architecture defaults to native x64 (== vcvars64.bat)
    local args="${*-x64}" tmp=$TMP cmd path

    # handle -clean_env
    if [[ $args =~ [-/]clean_env ]]; then
        [[ $# -eq 1 ]] || _fd2 "'-clean_env' specified, other arguments ignored"
        [[ -n $_CLEAN_MD5 ]] || { _fd2 'No environment to clean'; return 0; }
        path=${_CLEAN_MD5#*\*}
        [[ $_CLEAN_MD5 == $(md5sum $path) ]] || { _fd2 "'-clean_env' md5 mismatch"; return 64; }
        cmd=$VCVARSALL_PATH
        unset $(compgen -e) # clear all
        source $path # revert
        export VCVARSALL_PATH=$cmd # cache vcvarsall.bat path
        _fd2 "Environment reverted to $MSYSTEM"
        return 0
    fi

    # abort if VC environment already established
    command -v cl > /dev/null && { _fd2 'Environment already initialized'; return 0; }

    [[ $DEBUG != yes ]] && tmp=$(mktemp -d -p $TMP mv-XXX) || mkdir -p $tmp

    # save current vars for reverting with -clean_env
    export -p | sed 's/^declare -x/export/' > $tmp/clean.env # need -xg for global
    export _CLEAN_MD5=$(md5sum $tmp/clean.env)

    # find vcvarsall.bat
    path=$(cygpath -au "$VCVARSALL_PATH" 2>/dev/null) # either format
    if [[ ! -f $path ]]; then
        find '/c/Program Files (x86)/' '/c/Program Files/' -name vcvarsall.bat 2>/dev/null > $tmp/vcvarsall.txt
        path=$(head -1 $tmp/vcvarsall.txt)
        [[ -f "$path" ]] || { _fd2 'cannot find vcvarsall.bat, aborting'; return 64; }
        [[ $(wc -l $tmp/vcvarsall.txt) =~ ^1\  ]] || _fd2 'multiple vcvarsall.bat found, using first'
    fi
    export VCVARSALL_PATH=$(cygpath -awl "$path")

    # make scripts to capture vars before and after calling vcvarsall.bat
    path=$(cygpath -awl $tmp/winpath.txt)
    cmd=$(cygpath -awl /msys2_shell.cmd)
    cmd+=" -msys2 -defterm -no-start $tmp/vars.sh"
    echo 'export -p | LC_ALL=C sort -o $1' > $tmp/vars.sh
    cat << EOT | u2d > $tmp/vars.bat
$db_echo
cmd /c $cmd $tmp/before.env
call "$VCVARSALL_PATH" $args $db_nul
cmd /c echo %PATH% > $path
cmd /c $cmd $tmp/after.env
EOT

    # run capture scripts
    cmd=$(cygpath -awl $tmp/vars.bat)
    cmd //c $cmd # msys converts /c to C:\ so escape needed

    # get vars unique to post vcvarsall.bat processing
    LC_ALL=C comm -1 -3 $tmp/before.env $tmp/after.env |
        sed 's/^declare -x/export/' > $tmp/vcvars.env

    # ingest VC vars
    path="$PATH" # MSYS2 path
    export _WIN_PATH=$(cat $tmp/winpath.txt) # just for reference
    path+=:$(cygpath -up "$_WIN_PATH") # VC & unwanted paths last
    PATH="$path"
    source $tmp/vcvars.env # ingest vars added by vcvarsall.bat
    path=$(command -v cl)
    path=$(dirname "$path") # path to VC CLI toolchain
    export PATH="$path:$PATH" # mask /usr/bin/link

    # test for correct toolchain
    link | grep -q Microsoft || { _fd2 'failed, VC link.exe not in PATH'; return 64; }

    # success
    _fd2 "Environment initialized for: '$args'"
    return 0
}

(return 0 2>/dev/null) && return # return if sourced

# example usage

echo '---------- TESTING vcvarsall x64 ----------'
DEBUG=yes TMP=tmp vcvarsall
env | sort
echo
echo 'link location'
command -v link
echo
echo '---------- TESTING vcvarsall -clean_env ----------'
DEBUG=yes TMP=tmp vcvarsall -clean_env
env | sort

