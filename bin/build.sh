#!/usr/bin/env bash
set -eo pipefail

# Builds the planet4-circleci:base containers
# Optionally builds locally or on Google's cloud builder service

# UTILITY

function usage {
  >&2 echo "Usage: $0 [-l|r|v] [-c <configfile>] ...

Build and test the CircleCI base image.

Options:
  -c    Config file for environment variables, eg:
        $0 -c config
  -l    Perform the CircleCI task locally (requires circlecli)
  -r    Submits a build request to Google Container Builder
  -v    Verbose
"
}

# -----------------------------------------------------------------------------

# COMMAND LINE OPTIONS

OPTIONS=':vc:lr'
while getopts $OPTIONS option
do
    case $option in
        c  )    # shellcheck disable=SC2034
                CONFIG_FILE=$OPTARG;;
        l  )    BUILD_LOCALLY='true';;
        r  )    BUILD_REMOTELY='true';;
        v  )    VERBOSITY='debug'
                set -x;;
        *  )    usage
                exit 1;;
    esac
done
shift $((OPTIND - 1))

# -----------------------------------------------------------------------------

# CREATE TEMP DIR AND CLEAN ON EXIT

function finish() {
  rm -fr "$TMPDIR"
}
trap finish EXIT

TMPDIR=$(mktemp -d "${TMPDIR:-/tmp/}$(basename 0).XXXXXXXXXXXX")

# -----------------------------------------------------------------------------

# OUTPUT HELPERS
wget -q -O "${TMPDIR}/pretty-print.sh" https://gist.githubusercontent.com/27Bslash6/ffa9cfb92c25ef27cad2900c74e2f6dc/raw/7142ba210765899f5027d9660998b59b5faa500a/bash-pretty-print.sh
# shellcheck disable=SC1090
. "${TMPDIR}/pretty-print.sh"

# -----------------------------------------------------------------------------

# Reads key-value file as function argument, extracts and wraps key with ${..}
# for use in envsubst file templating
function get_var_array() {
  set -eu
  local file
  file="$1"
  declare -a var_array
  while IFS=$'\n' read -r line
  do
    var_array+=("$line")
  done < <(grep '=' "${file}" | awk -F '=' '{if ($0!="" && $0 !~ /^\s*#/) print $1}' | sed -e "s/^/\"\${/" | sed -e "s/$/}\" \\\\/" | tr -s '}')

  echo "${var_array[@]}"
}

# Rewrite only the variables we want to change
declare -a ENVVARS
while IFS=$'\n' read -r line
do
  ENVVARS+=("$line")
done < <(get_var_array "config.default")
ENVVARS_STRING="$(printf "%s:" "${ENVVARS[@]}")"
ENVVARS_STRING="${ENVVARS_STRING%:}"

envsubst "${ENVVARS_STRING}" < "src/circleci-base/templates/Dockerfile.in" > "src/circleci-base/Dockerfile.tmp"
envsubst "${ENVVARS_STRING}" < "README.md.in" > "README.md.tmp"

DOCKER_BUILD_STRING="# gcr.io/planet-4-151612/circleci-base:${BUILD_TAG}
# $(echo "${APPLICATION_DESCRIPTION}" | tr -d '"')
# Branch: ${CIRCLE_TAG:-${CIRCLE_BRANCH:-$(git rev-parse --abbrev-ref HEAD)}}
# Commit: ${CIRCLE_SHA1:-$(git rev-parse HEAD)}
# Build:  ${BUILD_NUM}
# ------------------------------------------------------------------------
#                     DO NOT MAKE CHANGES HERE
# This file is built automatically from ./templates/Dockerfile.in
# ------------------------------------------------------------------------
"

_build "Rewriting Dockerfile from template ..."
echo "${DOCKER_BUILD_STRING}
$(cat "src/circleci-base/Dockerfile.tmp")" > "src/circleci-base/Dockerfile"
rm "src/circleci-base/Dockerfile.tmp"

_build "Rewriting README.md from template ..."
echo "$(cat "README.md.tmp")
Build: ${CIRCLE_BUILD_URL:-"(local)"}" > "README.md"
rm "README.md.tmp"

# -----------------------------------------------------------------------------

# Submit the build
# @todo Implement local build
# $ circlecli build . -e GCLOUD_SERVICE_KEY=$(base64 ~/.config/gcloud/Planet-4-circleci.json)
if [[ "$BUILD_LOCALLY" = 'true' ]]
then
  time docker build "src/circleci-base" \
    --tag "${NAMESPACE}/${GOOGLE_PROJECT_ID}/circleci-base:${BUILD_BRANCH}" \
    --tag "${NAMESPACE}/${GOOGLE_PROJECT_ID}/circleci-base:${BUILD_NUM}" \
    --tag "${NAMESPACE}/${GOOGLE_PROJECT_ID}/circleci-base:${BUILD_TAG}"
fi

if [[ "${BUILD_REMOTELY}" = 'true' ]]
then
  # Process array of cloudbuild substitutions
  function getSubstitutions() {
    local -a arg=("$@")
    s="$(printf "%s," "${arg[@]}" )"
    echo "${s%,}"
  }

  # Cloudbuild.yaml template substitutions
  CLOUDBUILD_SUBSTITUTIONS=(
    "_BRANCH_TAG=${BUILD_BRANCH}" \
    "_BUILD_NUMBER=${CIRCLE_BUILD_NUM:-$(git rev-parse --short HEAD)}" \
    "_GOOGLE_PROJECT_ID=${GOOGLE_PROJECT_ID}" \
    "_NAMESPACE=${NAMESPACE}" \
    "_REVISION_TAG=${BUILD_NUM:-${CIRCLE_TAG:-$(git rev-parse --short HEAD)}}" \
  )
  CLOUDBUILD_SUBSTITUTIONS_STRING=$(getSubstitutions "${CLOUDBUILD_SUBSTITUTIONS[@]}")

  _build "Sending build request to GCR ..."
  # Avoid sending entire .git history as build context to save some time and bandwidth
  # Since git builtin substitutions aren't available unless triggered
  # https://cloud.google.com/container-builder/docs/concepts/build-requests#substitutions
  tar --exclude='.git/' --exclude='.circleci/' -zcf "${TMPDIR}/docker-source.tar.gz" .

  time gcloud builds submit \
    --verbosity=${VERBOSITY:-"warning"} \
    --timeout=10m \
    --config cloudbuild.yaml \
    --substitutions "${CLOUDBUILD_SUBSTITUTIONS_STRING}" \
    "${TMPDIR}/docker-source.tar.gz"
fi

if [[ -z "$BUILD_LOCALLY" ]] && [[ -z "${BUILD_REMOTELY}" ]]
then
  _notice "No build option specified"
fi
