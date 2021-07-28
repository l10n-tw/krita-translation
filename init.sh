#!/usr/bin/env bash
# -*- coding: utf-8 -*-

. "./svnupdate_common.sh"

# Checkout the SVN repository
for svn_repo in "${!svn_repositories[@]}"; do
    checkout "$svn_repo"
done
