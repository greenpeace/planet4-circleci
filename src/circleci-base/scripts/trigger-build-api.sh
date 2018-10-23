#!/usr/bin/env bash
set -u

repo=$1
user=greenpeace
branch=${2:-develop}

json=$(jq -n \
  --arg REF "$ref" \
  --arg VAL "$branch" \
'{
  "branch": $VAL
}')

curl \
  --header "Content-Type: application/json" \
  -d "$json" \
  -u "${CIRCLE_TOKEN}:" \
  -X POST \
  https://circleci.com/api/v1.1/project/${VCS_TYPE:-github}/${user}/${repo}/build