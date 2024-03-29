#!/usr/bin/env bash
set -e

# Commits local changes back to origin repository

# -----------------------------------------------------------------------------

function usage() {
  echo >&2 "Usage: $(basename "$0") [-f|h] [<filename> <filename> ...]

Commits and pushes local changes such as build artifacts backl to the origin
repository.  Accepts a list of files to add as arguments to the script.

Example:

$(basename "$0") -f README.md

Options:
  -f    Force adding .gitignore files
  -h    This help
"
}

# COMMAND LINE OPTIONS
OPTIONS=':fh'
while getopts $OPTIONS option; do
  case $option in
    f) FORCE='true' ;;
    h)
      usage
      exit 0
      ;;
    *)
      usage
      exit 1
      ;;
  esac
done
shift $((OPTIND - 1))

# Files can be specified as optional command line arguments
files=("$@")

# -----------------------------------------------------------------------------

# If the build url isn't set, we're building locally so
if [[ -z "${CIRCLE_BUILD_URL}" ]]; then
  # Don't attempt to update the repository
  echo "Local build, skipping repository update..."
  exit 0
fi

if [[ -z "${CIRCLE_BRANCH}" ]] && [[ -n "${CIRCLE_TAG}" ]]; then
  # Find the branch associated with this commit
  # Why is this so hard, CircleCI?
  git remote update
  # Find which remote branch contains the current commit
  CIRCLE_BRANCH=$(git branch -r --contains "${CIRCLE_SHA1}" | grep -v 'HEAD' | awk '{split($1,a,"/"); print a[2]}')

  if [[ -z "$CIRCLE_BRANCH" ]]; then
    echo >&2 "Could not reliably determine branch"
    echo >&2 "Forcing main (since they should be the only branches tagged)"
    CIRCLE_BRANCH=main
  fi

  # Checkout that branch / tag
  git checkout ${CIRCLE_BRANCH}
  if [[ "$(git rev-parse HEAD)" != "${CIRCLE_SHA1}" ]]; then
    echo >&2 "Found the wrong commit!"
    echo >&2 "Wanted: ${CIRCLE_SHA1}"
    echo >&2 "Got:    $(git rev-parse HEAD)"
    echo >&2 "Not updating build details in repository, continuing ..."
    exit 0
  fi
fi

echo "${CIRCLE_BRANCH}" >/tmp/workspace/var/circle-branch-name
export CIRCLE_BRANCH

# Configure git user
git config user.email "${GIT_USER_EMAIL}"
git config user.name "CircleCI Bot"
git config push.default simple

git_add="git add"
# Add changes, including any .gitignored files
if [ "$FORCE" = "true" ]; then
  echo "Forcing .gitignored files"
  git_add+=" -f"
fi

if [[ ${#files[@]} -gt 0 ]]; then
  # Adding only specified files
  echo "${#files[@]} files to add"
  for f in "${files[@]}"; do
    [ ! -e "$f" ] && {
      echo >&2 "ERROR: File not found: $f"
      exit 1
    }
    eval "$git_add $f"
  done
else
  eval "$git_add ."
fi

# Exit early if no local changes
git diff-index --quiet HEAD -- && exit 0

# Show status
git status

# Get previous commit message and append a message, skipping CI
git commit -F- <<EOF
:robot: Build ${CIRCLE_TAG:-${CIRCLE_BRANCH}}

 - $(git log --format=%B -n1)

[skip ci]
EOF

# Push updated files to the repo
git push --force-with-lease --set-upstream origin ${CIRCLE_BRANCH}
