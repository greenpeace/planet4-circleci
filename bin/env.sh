#!/usr/bin/env bash
# shellcheck disable=SC2034
set -ao pipefail

# CONFIG FILE
# Read parameters from key->value configuration files
# Note this will override environment variables at this stage
# @todo prioritise ENV over config file ?

DEFAULT_CONFIG_FILE="${BUILD_DIR}/config.default"
if [[ ! -f "${DEFAULT_CONFIG_FILE}" ]]
then
  fatal "ERROR :: Default configuration file not found: ${DEFAULT_CONFIG_FILE}"
fi
# shellcheck source=/dev/null
. ${DEFAULT_CONFIG_FILE}

# Read from custom config file from command line parameter
if [ ! -z "${CONFIG_FILE}" ]; then
  if [ ! -f "${CONFIG_FILE}" ]; then
    fatal "ERROR: Custom config file not found: ${CONFIG_FILE}"
  fi

  echo "Reading config from: ${CONFIG_FILE}"

  # https://github.com/koalaman/shellcheck/wiki/SC1090
  # shellcheck source=/dev/null
  . ${CONFIG_FILE}
fi

# Envsubst and cloudbuild.yaml variable consolidation
ACK_VERSION="${ACK_VERSION:-${DEFAULT_ACK_VERSION}}"
APPLICATION_NAME=${APPLICATION_NAME:-${DEFAULT_APPLICATION_NAME}}
BASE_IMAGE="${BASE_IMAGE:-${DEFAULT_BASE_IMAGE}}"
BASE_NAMESPACE="${BASE_NAMESPACE:-${DEFAULT_BASE_NAMESPACE}}"
BASE_TAG="${BASE_TAG:-${DEFAULT_BASE_TAG}}"
BRANCH_NAME="${CIRCLE_BRANCH:-$(git rev-parse --abbrev-ref HEAD)}"
DOCKER_COMPOSE_VERSION="${DOCKER_COMPOSE_VERSION:-${DEFAULT_DOCKER_COMPOSE_VERSION}}"
GOOGLE_SDK_VERSION="${GOOGLE_SDK_VERSION:-${DEFAULT_GOOGLE_SDK_VERSION}}"
IMAGE_FROM="${BASE_NAMESPACE}/${BASE_IMAGE}:${BASE_TAG}"
IMAGE_MAINTAINER="${MAINTAINER:-${DEFAULT_MAINTAINER}}"