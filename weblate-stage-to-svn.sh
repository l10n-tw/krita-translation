#!/usr/bin/env bash

set -e

. "./svnupdate_common.sh"

language=zh_TW
kde_i18n_package=krita
git_fetch_remote_url="https://github.com/l10n-tw/krita-translation.git"
git_push_remote=origin


command_exists() {
    command -v "$1" &> /dev/null
}

if ! command_exists git; then
    echo "\`git\` not available, aborting."
    exit 1
fi
if ! command_exists svn; then
    echo "\`svn\` not available, aborting."
    exit 1
fi

if [[ $(git rev-parse --abbrev-ref HEAD) != "master" ]]; then
    echo "Not currently on master, aborting."
    exit 1
fi
if [[ -n $(git status -s --untracked-files=no) ]]; then
    echo "Working tree contains uncommitted changes, aborting."
    exit 1
fi

# TODO: Use `wlc` to trigger push from Weblate.

# Fetch and checkout the latest weblate commits to a temporary worktree.
git_stage_dir="$tmpdir/__git_weblate_stage"
git fetch "$git_fetch_remote_url" weblate-stage
git worktree add --detach "$git_stage_dir" FETCH_HEAD

# Run `msgmerge` on the PO files.
for po_file in "$git_stage_dir/$language/"*.po; do
    component="$(basename "$po_file" ".po")"

    echo "Reformatting ${component}.po with \`msgmerge\`."
    msgmerge --previous -o "$po_file" "$po_file" "$po_file"
done

if [[ -n $(git -C "$git_stage_dir" status -s) ]]; then
    git -C "$git_stage_dir" add -A
    git -C "$git_stage_dir" commit -m "Reformat with msgmerge"
else
    echo "No changes after reformat."
fi

# Manual checking and editing.
echo "Staging git worktree at '$git_stage_dir'."
echo "You may now check the changes in the staging tree and add commits."
while : ; do
    read -r -p "Command (bash/continue/quit) " input_command
    case "$input_command" in

        bash)
            pushd "$git_stage_dir" > /dev/null
            bash || true
            popd > /dev/null
            ;;

        continue)
            if [[ -n $(git -C "$git_stage_dir" status -s) ]]; then
                echo "Worktree contains uncommitted changes! Please commit or clean up before continuing."
            else
                break
            fi
            ;;

        quit)
            echo "Quitting..."
            exit
            ;;

        *)
            echo "Unknown option."
            ;;
    esac
done

# Replace trap as we don't want the git tree to be removed.
trap 'echo "WARNING: tmpdir '"'$tmpdir'"' not deleted!"' EXIT

# SVN checkout and prepare for commit.
svn_stage_dir="$tmpdir/__svn_stage"
svn checkout "svn+ssh://svn@svn.kde.org/home/kde/trunk/l10n-kf6/$language/messages/$kde_i18n_package" "$svn_stage_dir"
rm -v "$svn_stage_dir/"*.po
cp -v "$git_stage_dir/$language/"*.po "$svn_stage_dir/"

# Manual checking and editing.
echo "Staging svn checkout at '$svn_stage_dir'."
svn status "$svn_stage_dir"
echo "You may now check the changes in the checkout dir, and add any unversioned files with \`svn add <file>\`."
echo "NOTE: If you modify files inside the checkout dir, they will _not_ be synced back to git."
while : ; do
    read -r -p "Command (bash/commit/quit) " input_command
    case "$input_command" in

        bash)
            pushd "$svn_stage_dir" > /dev/null
            bash || true
            popd > /dev/null
            ;;

        commit)
            svn status "$svn_stage_dir"
            read -r -p "Are you sure? (type 'yes' to confirm) " input_confirm
            if [[ $input_confirm = "yes" ]]; then
                break;
            fi
            ;;

        quit)
            echo "Quitting..."
            exit
            ;;

        *)
            echo "Unknown option."
            ;;
    esac
done

# SVN commit.
svn commit -m "l10n(trunk/$kde_i18n_package/$language): update from Weblate" "$svn_stage_dir"
svn update "$svn_stage_dir"
svn_new_rev=$(svn info --show-item last-changed-revision "$svn_stage_dir")
echo "Committed updated PO catalogs to KDE SVN as r$svn_new_rev."

# Update and merge staging git branch.
echo -n "$svn_new_rev" > "$git_stage_dir/LAST_COMMIT_SVN_REVISION"
git -C "$git_stage_dir" add "$git_stage_dir/LAST_COMMIT_SVN_REVISION"
git -C "$git_stage_dir" commit -m "Mark committed to SVN r$svn_new_rev"

git_commit_to_merge=$(git -C "$git_stage_dir" rev-parse HEAD)
git merge --no-ff -m "Merge translation updates (r$svn_new_rev)" "$git_commit_to_merge"

# echo "Please push the master branch by running \`git push\` and delete the staging branch by \`git push <remote> :weblate-stage\`."
echo "Pushing to remote '$git_push_remote'"
git push "$git_push_remote" master:master :weblate-stage

# Re-register trap.
trap "remove_tmp_dir" EXIT

git worktree remove "$git_stage_dir"

# TODO: Use `wlc` to trigger update from Weblate.
