#!/usr/bin/env bash
set -u

repo=$1
user=greenpeace
branch=${2:-develop}
ref=${3:-branch}

json="{
  \"$ref\": \"$branch\"
}"
echo ""
echo "The json is"
echo $json
echo ""
curl \
  --header "Content-Type: application/json" \
  -d "$json" \
  -u "${CIRCLE_TOKEN}:" \
  -X POST \
  https://circleci.com/api/v1.1/project/${VCS_TYPE:-github}/${user}/${repo}/build