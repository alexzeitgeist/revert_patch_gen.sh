#!/bin/bash

function main() {
    trap cleanup ERR

    if [[ $# -eq 0 ]]; then
        echo "You must provide at least one commit hash as an argument."
        exit 1
    fi

    validate_commits "$@"

    current_branch=$(git branch --show-current)
    temp_branch="temp-$(date +%Y%m%d%H%M%S)"
    short_hash=$(git rev-parse --short "$1")

    git checkout -b "$temp_branch"

    if ! git revert --no-commit "$@"; then
        handle_failure "$current_branch" "$temp_branch"
    fi

    git commit -m "Revert of $short_hash"
    git format-patch -1 HEAD --stdout >"$short_hash-revert.patch"

    cleanup
}

function validate_commits() {
    for commit_hash in "$@"; do
        if ! git cat-file -e "${commit_hash}^{commit}" 2>/dev/null; then
            echo "Error: Commit hash $commit_hash is not valid"
            exit 1
        fi
    done
}

function handle_failure() {
    echo "Failed to revert one or more commits due to a merge conflict."
    local response
    read -r -p "Do you want to resolve the merge conflict now? (y/N) " response

    if [[ ! "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
        echo "Exiting without creating a patch."
        git revert --abort
        git checkout "$1"
        git branch -D "$2"
        exit 1
    fi

    echo -e "Please perform the following steps:\n
    - Resolve the merge conflicts.
    - Commit the changes with 'git commit'.
    - Create the patch with 'git format-patch -1 HEAD'.
    - Switch back to the original branch with 'git checkout $current_branch'.
    - Delete the temporary branch with 'git branch -d $temp_branch'."
    exit 1
}

function cleanup() {
    git checkout "$current_branch"
    git branch -D "$temp_branch"
}

main "$@"
