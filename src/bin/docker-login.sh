#!/usr/bin/env bash
set -euo pipefail

echo "${DOCKERHUB_PASSWORD}" | base64 --decode | docker login --username "$(echo "${DOCKERHUB_USERNAME}" | base64 --decode)" --password-stdin
