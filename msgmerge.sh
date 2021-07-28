#!/usr/bin/env bash
# -*- coding: utf-8 -*-

language=$1

for template_file in ./templates/*; do
    component="$(basename "$template_file" ".pot")"

    if [ -f "$language/${component}.po" ]; then
        echo "${component} has been localized. Updating base..."
        msgmerge --previous -U "${language}/${component}.po" "$template_file"
    else
        echo "${component} has not been localized. Copying..."
        cp "$template_file" "$language/${component}.po"
    fi
done
