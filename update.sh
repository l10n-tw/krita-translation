#!/usr/bin/env bash
# -*- coding: utf-8 -*-

tmpdir="$(mktemp -d)";

safe_rm() {
    local dir="$1"

    if [ -d "$dir" ]; then
        rm -rf "$dir"
    fi
}

remove_tmp_dir() {
    safe_rm "$tmpdir"
}

# Register cleanup function after completing all actions
trap "remove_tmp_dir" EXIT


git_checkout() {
    local sparse_dir="$1"
    local path="$tmpdir/__git_checkout"

    git init "$path"
    pushd "$path"
    git remote add origin https://invent.kde.org/localization/l10n-templates.git
    git sparse-checkout set "$sparse_dir"
    git fetch --depth=1 origin master
    git checkout origin/master
    popd

    git_checkout_result=$path
}

checkout() {
    local template_path="$1"
    local revision_file="templates.GIT_COMMIT"
    safe_rm "./templates"

    if git_checkout "$template_path"; then
        local GIT_COMMIT
        if [[ -n $revision_file ]] && GIT_COMMIT=$(git -C "$git_checkout_result" rev-parse HEAD); then
            echo -n "$GIT_COMMIT" > "$revision_file"
        fi
        mkdir "./templates"
        cp -v "$git_checkout_result/$template_path/"*.{po,pot} "./templates"
        safe_rm "$git_checkout_result"
    else
        echo "Execution failed: failed to git_checkout"
        exit 1
    fi

    if [[ -z $(ls -A "./templates") ]]; then
        echo "Error: Checkout result is empty"
        exit 2
    fi
}



checkout "trunk5/messages/krita"

if [[ -f "templates.SVN_REVISION" ]]; then
    rm "templates.SVN_REVISION"
fi
