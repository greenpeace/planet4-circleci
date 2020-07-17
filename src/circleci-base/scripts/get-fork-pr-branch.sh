#!/usr/bin/env bash
set -euo pipefail

# shellcheck disable=SC2034
CIRCLE_PR_BRANCH=\
$(curl -s "https://api.github.com/repos/${CIRCLE_PROJECT_USERNAME}/${CIRCLE_PROJECT_REPONAME}/pulls/${CIRCLE_PR_NUMBER}" \
 | jq -r '.head.ref')

echo CIRCLE_PR_BRANCH

