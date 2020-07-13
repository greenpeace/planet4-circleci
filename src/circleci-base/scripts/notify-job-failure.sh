#!/usr/bin/env bash
set -eu

MSG_TYPE="FAILURE: ${TYPE:-Job} - ${CIRCLE_PROJECT_REPONAME} - ${CIRCLE_JOB}" \
MSG_TITLE="${CIRCLE_PROJECT_USERNAME}/${CIRCLE_PROJECT_REPONAME} @ ${CIRCLE_BRANCH:-${CIRCLE_TAG}}" \
MSG_LINK="${CIRCLE_BUILD_URL}" \
MSG_TEXT="Build: #${CIRCLE_BUILD_NUM} Diff: ${CIRCLE_COMPARE_URL} ${EXTRA_TEXT:-}" \
MSG_COLOUR="red" \
"${HOME}/scripts/notify-slack.sh"
