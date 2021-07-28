#!/usr/bin/env bash
# -*- coding: utf-8 -*-

declare -A svn_repositories=(
    ["templates"]="svn://anonsvn.kde.org/home/kde/trunk/l10n-kf5/templates/messages/krita"
    ["zh_TW"]="svn://anonsvn.kde.org/home/kde/trunk/l10n-kf5/zh_TW/messages/krita"
)

tmpdir="$(mktemp -d)";

svn_checkout() {
    local address=$1
    local path="$tmpdir/__svn_checkout"

    svn co -rHEAD "$address" "$path"
    
    svn_checkout_result=$path
}

safe_rm() {
    local dir="$1"

    if [ -d "$dir" ]; then
        rm -rf "$dir"
    fi
}

remove_tmp_dir() {
    trap "saferm ""$tmpdir" EXIT
}

checkout() {
    svn_repo="$1"
    safe_rm "./$svn_repo"

    if svn_checkout "${svn_repositories[$svn_repo]}"; then
        mkdir "./$svn_repo"
        cp -v "$svn_checkout_result/"*.{po,pot} "./$svn_repo"
        safe_rm "$svn_checkout_result"
    else
        echo "Execution failed:  failed to svn_checkout"
        exit 1
    fi
}

# Register cleanup function after completing all actions
trap "remove_tmp_dir" EXIT
