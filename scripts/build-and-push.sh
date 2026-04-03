#!/usr/bin/env bash
set -euo pipefail

# Determine image name (prefer image-name, fall back to app-name for backward compatibility)
if [ -n "${INPUT_IMAGE_NAME}" ]; then
  IMAGE_NAME="${INPUT_IMAGE_NAME}"
  IMAGE_NAME_SOURCE="explicit 'image-name' input"
elif [ -n "${INPUT_APP_NAME}" ]; then
  echo "::warning::The 'app-name' input is deprecated. Please use 'image-name' instead."
  IMAGE_NAME="${INPUT_APP_NAME}"
  IMAGE_NAME_SOURCE="deprecated 'app-name' input"
else
  # Extract image name from repository name
  IMAGE_NAME=$(basename ${GITHUB_REPOSITORY})
  IMAGE_NAME_SOURCE="repository name (no 'image-name' input provided)"
fi
echo "Using image name: ${IMAGE_NAME} (source: ${IMAGE_NAME_SOURCE})"

# Determine version
if [ -n "${INPUT_VERSION}" ]; then
  VERSION="${INPUT_VERSION}"
  echo "Using explicit version: ${VERSION}"
else
  # Validate project-path before using it
  PROJECT_PATH="${INPUT_PROJECT_PATH}"
  case "${PROJECT_PATH}" in
    /*) echo "::error::'project-path' must be a relative path, got: '${PROJECT_PATH}'"; exit 1 ;;
    *../*|*..) echo "::error::'project-path' must not contain '..', got: '${PROJECT_PATH}'"; exit 1 ;;
  esac

  # Extract version from package.json using pnpm
  if [ -f "${PROJECT_PATH}/package.json" ]; then
    PNPM_STDERR_FILE=$(mktemp)
    PNPM_EXIT=0
    VERSION=$(cd "${PROJECT_PATH}" && pnpm -s pkg get version 2>"${PNPM_STDERR_FILE}") || PNPM_EXIT=$?
    PNPM_ERROR=$(tr '\n\r' '  ' < "${PNPM_STDERR_FILE}" | sed 's/::/ /g')
    rm -f "${PNPM_STDERR_FILE}"
    VERSION="${VERSION//\"/}"
    VERSION="${VERSION//[[:space:]]/}"
    if [ "$PNPM_EXIT" -ne 0 ]; then
      echo "::error::Failed to extract version from '${PROJECT_PATH}/package.json': ${PNPM_ERROR}. Provide an explicit 'version' input or ensure 'pnpm pkg get version' works in that directory."
      exit 1
    elif [ -z "${VERSION}" ] || [ "${VERSION}" = "undefined" ] || [ "${VERSION}" = "null" ]; then
      echo "::error::No version field found in '${PROJECT_PATH}/package.json'. Add a version field or provide an explicit 'version' input."
      exit 1
    else
      echo "Extracted version from ${PROJECT_PATH}/package.json: ${VERSION}"
    fi
  else
    echo "::error::package.json not found at '${PROJECT_PATH}/package.json'. Provide an explicit 'version' input or a valid 'project-path'."
    exit 1
  fi
fi

# Build full image names
VERSIONED_IMAGE="${INPUT_REGISTRY}/${IMAGE_NAME}:${VERSION}"

# Build tag arguments
TAGS="-t ${VERSIONED_IMAGE}"

# Add latest tag if requested
if [ "${INPUT_TAG_LATEST}" = "true" ]; then
  LATEST_IMAGE="${INPUT_REGISTRY}/${IMAGE_NAME}:latest"
  TAGS="${TAGS} -t ${LATEST_IMAGE}"
else
  echo "Skipping ':latest' tag (tag-latest=false)"
fi

echo "Building and pushing Docker image: ${VERSIONED_IMAGE}"
if [ "${INPUT_TAG_LATEST}" = "true" ]; then
  echo "Also tagging as: ${LATEST_IMAGE}"
fi
echo "Building for platforms: ${INPUT_PLATFORMS}"

# Build and push the image, capturing metadata for digest
METADATA_FILE="${RUNNER_TEMP}/docker-metadata-$$.json"
docker buildx build \
  --platform ${INPUT_PLATFORMS} \
  ${TAGS} \
  -f ${INPUT_DOCKERFILE} \
  --push \
  --metadata-file "${METADATA_FILE}" \
  ${INPUT_CONTEXT}
DOCKER_EXIT=$?
if [ "${DOCKER_EXIT}" -ne 0 ]; then
  echo "::error::docker buildx build failed (exit ${DOCKER_EXIT}). Check Dockerfile path ('${INPUT_DOCKERFILE}'), build context ('${INPUT_CONTEXT}'), platforms ('${INPUT_PLATFORMS}'), and registry authentication for '${INPUT_REGISTRY}'."
  exit "${DOCKER_EXIT}"
fi

# Get the image digest from build metadata
if ! command -v jq &> /dev/null; then
  echo "::error::jq is required but not installed"
  exit 1
fi

if [ ! -f "${METADATA_FILE}" ]; then
  echo "::error::Build metadata file not found at '${METADATA_FILE}'. The image may have been pushed but the digest cannot be retrieved."
  exit 1
fi

DIGEST=$(jq -r '.["containerimage.digest"]' "${METADATA_FILE}") || {
  echo "::error::Failed to parse build metadata at '${METADATA_FILE}'"
  exit 1
}

if [ -n "$DIGEST" ] && [ "$DIGEST" != "null" ]; then
  echo "Image digest: $DIGEST"
else
  echo "::warning::No digest found in build metadata. The image was pushed but the digest is unavailable — downstream steps that require a digest (e.g. manifest dispatch) will be skipped."
  DIGEST=""
fi

# Clean up metadata file
rm -f "${METADATA_FILE}"

# Build summary
echo "--- Build Summary ---"
echo "  Image  : ${VERSIONED_IMAGE}"
echo "  Digest : ${DIGEST:-<unavailable>}"
echo "  Version: ${VERSION}"

# Set outputs
echo "digest=${DIGEST}" >> $GITHUB_OUTPUT
echo "image-name=${VERSIONED_IMAGE}" >> $GITHUB_OUTPUT
echo "version=${VERSION}" >> $GITHUB_OUTPUT
