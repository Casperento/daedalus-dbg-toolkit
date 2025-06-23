#!/bin/bash

# === Git Repository Info ===
REPO_PATH="$1"

if [ -z "$REPO_PATH" ]; then
    echo -e "\nUsage: $0 <path-to-git-repo>"
    exit 1
fi

if [ ! -d "$REPO_PATH/.git" ]; then
    echo -e "\nError: '$REPO_PATH' is not a Git repository."
    exit 1
fi

echo -e "\n===== Git Repository Information ====="
cd "$REPO_PATH" || exit

BRANCH=$(git rev-parse --abbrev-ref HEAD)
COMMIT=$(git rev-parse HEAD)

echo "Repository: $REPO_PATH"
echo "Branch: $BRANCH"
echo "Commit: $COMMIT"
