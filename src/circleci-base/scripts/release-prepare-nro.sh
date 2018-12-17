#!/usr/bin/env bash
set -euo pipefail

# Description: Prepare NRO release branch
#
# Triggered in CI after successful develop branch build/deploy
# Starts or continues a new branch release/vx.x.x
# Merges changes from develop
# Deletes previous release branch from origin
# Pushes changes to origin
#

old_release=${1:-$(git-current-tag.sh)}
new_release=${2:-$(increment-version.sh "$old_release")}

echo "--0.1 The old release is $old_release"
echo "--0.2 The new release is $new_release"

merged=false

mkdir -p /tmp/workspace


echo "--1.0 Before the first if"
if release-start.sh "$new_release"
then
  echo "--1.1 The release-start returned true. We change the variable merged to true"
  merged=true
else
  echo "--1.1 The release-start returned false. The Release branch already exists"
  # Release branch already exists
  git checkout "release/$new_release"

  # If there are any changes from develop
  # Merge changes from develop to release
  git merge -Xtheirs --no-edit --log -m ":robot: release/$new_release Merge develop" develop | tee /tmp/workspace/merge.log
  grep -q "Already up-to-date." /tmp/workspace/merge.log || {
    echo "--1.2 We merged changes from develop into release/$new_release"
    merged=true;
  }
fi

# Perform NRO develop to release manipulations
pin-composer-versions.sh

# If there are any local changes
if ! git diff --exit-code
then
  git add .
  echo "---2. We have local changes"
  # We have local changes
  if [[ "$merged" = "true" ]]
  then
    echo "---2.1. Since we've merged changes from develop, let's amend that commit"
    git commit --amend --no-edit --allow-empty
  else
    echo "---2.2 New commit with automated modifications"
    git commit -m ":robot: release/$new_release Automated modifications "
    merged=true
  fi
fi

echo "--3.0 Before the final if"
if [[ "$merged" = "false" ]]
then
  # No local changes
  echo "---3.1 No local changes. Triggering"
  REPO=$(git remote get-url origin | cut -d'/' -f 2 | cut -d'.' -f1)
  echo "---3.1.1 The repo we will try to trigger is $REPO"
  trigger-build-api.sh "${REPO}" "release/$new_release"
else
  echo "---3.2 Local changes. Pushing by git"
  message=$(git show --format=%B | grep -v ":robot: Build trigger")

  echo "---3.2.1 Remove all the build trigger notifications from the latest commit message"
  # Remove all the build trigger notifications from the latest commit message
  git commit --allow-empty --amend -m "$message"

  echo "---3.2.2 Create/push the new release branch "
  # Create the new release branch
  git push -u origin "release/$new_release"

  echo "---3.2.3 Check if old release branch still exists "
  gitlsremote=$(git ls-remote)
  if [[ $gitlsremote =~ release/$old_release ]]
  then
    # Delete the old release branch
    echo "---3.2.4 Old branch exists, delete it "
    git push origin --delete "release/$old_release"
  fi

fi


