#!/usr/bin/env bats

REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"

setup() {
  cd "$REPO_ROOT"

  SCRIPT_FILE="$(mktemp)"
  bash "${BATS_TEST_DIRNAME}/helpers/extract_script.sh" > "$SCRIPT_FILE"

  export GITHUB_REPOSITORY="test-org/test-repo"
  export RUNNER_TEMP="$(mktemp -d)"
  export GITHUB_OUTPUT="$(mktemp)"

  # Default inputs matching action.yml defaults.
  # INPUT_VERSION is set here to skip pnpm by default; unset it in version-specific tests.
  export INPUT_REGISTRY="myregistry.example.com"
  export INPUT_IMAGE_NAME=""
  export INPUT_APP_NAME=""
  export INPUT_VERSION="1.0.0"
  export INPUT_PROJECT_PATH="."
  export INPUT_PLATFORMS="linux/amd64,linux/arm64"
  export INPUT_TAG_LATEST="true"
  export INPUT_DOCKERFILE="Dockerfile"
  export INPUT_CONTEXT="."

  export PATH="${BATS_TEST_DIRNAME}/mocks:${PATH}"

  unset MOCK_PNPM_EXIT MOCK_PNPM_VERSION MOCK_DOCKER_EXIT
}

teardown() {
  rm -f "$SCRIPT_FILE"
  rm -rf "$RUNNER_TEMP"
  rm -f "$GITHUB_OUTPUT"
}

# ---------------------------------------------------------------------------
# Image name resolution
# ---------------------------------------------------------------------------

@test "no image-name: falls back to repository name and logs source" {
  run bash "$SCRIPT_FILE"
  [ "$status" -eq 0 ]
  [[ "$output" == *"test-repo"* ]]
  [[ "$output" == *"repository name"* ]]
}

@test "explicit image-name: used and source is logged" {
  export INPUT_IMAGE_NAME="my-custom-image"
  run bash "$SCRIPT_FILE"
  [ "$status" -eq 0 ]
  [[ "$output" == *"my-custom-image"* ]]
  [[ "$output" == *"explicit 'image-name' input"* ]]
}

@test "deprecated app-name: warning emitted and value is used" {
  export INPUT_APP_NAME="old-image-name"
  run bash "$SCRIPT_FILE"
  [ "$status" -eq 0 ]
  [[ "$output" == *"::warning::"* ]]
  [[ "$output" == *"deprecated"* ]]
  [[ "$output" == *"old-image-name"* ]]
}

# ---------------------------------------------------------------------------
# Version resolution
# ---------------------------------------------------------------------------

@test "explicit version: logged" {
  export INPUT_VERSION="3.1.4"
  run bash "$SCRIPT_FILE"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Using explicit version: 3.1.4"* ]]
}

@test "version from package.json: extracted and logged" {
  export INPUT_VERSION=""
  export INPUT_PROJECT_PATH="tests/fixtures/valid-project"
  export MOCK_PNPM_VERSION="2.3.4"
  run bash "$SCRIPT_FILE"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Extracted version"* ]]
  [[ "$output" == *"2.3.4"* ]]
}

# ---------------------------------------------------------------------------
# project-path validation
# ---------------------------------------------------------------------------

@test "absolute project-path: fails with clear error" {
  export INPUT_VERSION=""
  export INPUT_PROJECT_PATH="/absolute/path"
  run bash "$SCRIPT_FILE"
  [ "$status" -eq 1 ]
  [[ "$output" == *"must be a relative path"* ]]
}

@test "project-path with ..: fails with clear error" {
  export INPUT_VERSION=""
  export INPUT_PROJECT_PATH="../outside"
  run bash "$SCRIPT_FILE"
  [ "$status" -eq 1 ]
  [[ "$output" == *"must not contain"* ]]
}

@test "missing package.json: fails with clear error" {
  export INPUT_VERSION=""
  export INPUT_PROJECT_PATH="tests/fixtures/nonexistent"
  run bash "$SCRIPT_FILE"
  [ "$status" -eq 1 ]
  [[ "$output" == *"package.json not found"* ]]
}

@test "pnpm failure: fails with clear error" {
  export INPUT_VERSION=""
  export INPUT_PROJECT_PATH="tests/fixtures/valid-project"
  export MOCK_PNPM_EXIT="1"
  run bash "$SCRIPT_FILE"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Failed to extract version"* ]]
}

# ---------------------------------------------------------------------------
# Build configuration logging
# ---------------------------------------------------------------------------

@test "tag-latest=false: skip is logged" {
  export INPUT_TAG_LATEST="false"
  run bash "$SCRIPT_FILE"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Skipping ':latest' tag"* ]]
}

@test "platforms: logged before build" {
  export INPUT_PLATFORMS="linux/amd64"
  run bash "$SCRIPT_FILE"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Building for platforms: linux/amd64"* ]]
}

# ---------------------------------------------------------------------------
# Docker build
# ---------------------------------------------------------------------------

@test "docker build failure: contextual error includes input values" {
  export MOCK_DOCKER_EXIT="1"
  run bash "$SCRIPT_FILE"
  [ "$status" -eq 1 ]
  [[ "$output" == *"docker buildx build failed"* ]]
  [[ "$output" == *"Dockerfile"* ]]
  [[ "$output" == *"myregistry.example.com"* ]]
}

@test "successful build: summary block shown with digest" {
  run bash "$SCRIPT_FILE"
  [ "$status" -eq 0 ]
  [[ "$output" == *"--- Build Summary ---"* ]]
  [[ "$output" == *"sha256:deadbeef"* ]]
}
