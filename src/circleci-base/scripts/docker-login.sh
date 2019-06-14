#!/usr/bin/env bash
set -eo pipefail

docker login --username $(echo "${DOCKER_USER_64}" | base64 --decode) --password $(echo "${DOCKER_PASS_64}" | base64 --decode)
