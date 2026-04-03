#!/usr/bin/env bash
# Extracts the run: | block from action.yml and substitutes
# ${{ inputs.XXX }} GitHub Actions template vars with ${INPUT_XXX} env vars
# so the script can be executed directly in tests.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

awk '
  /^      run: \|/ { found=1; next }
  found && /^[[:space:]]*$/ { print ""; next }
  found && /^        / { print substr($0, 9); next }
  found { exit }
' "${REPO_ROOT}/action.yml" | sed \
  -e 's/\${{ inputs\.image-name }}/\${INPUT_IMAGE_NAME}/g' \
  -e 's/\${{ inputs\.app-name }}/\${INPUT_APP_NAME}/g' \
  -e 's/\${{ inputs\.version }}/\${INPUT_VERSION}/g' \
  -e 's/\${{ inputs\.project-path }}/\${INPUT_PROJECT_PATH}/g' \
  -e 's/\${{ inputs\.platforms }}/\${INPUT_PLATFORMS}/g' \
  -e 's/\${{ inputs\.tag-latest }}/\${INPUT_TAG_LATEST}/g' \
  -e 's/\${{ inputs\.dockerfile }}/\${INPUT_DOCKERFILE}/g' \
  -e 's/\${{ inputs\.context }}/\${INPUT_CONTEXT}/g' \
  -e 's/\${{ inputs\.registry }}/\${INPUT_REGISTRY}/g'
