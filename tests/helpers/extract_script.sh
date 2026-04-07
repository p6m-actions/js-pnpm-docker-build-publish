#!/usr/bin/env bash
# Outputs the build-and-push script for use in tests.
# Previously extracted and transformed the run: | block from action.yml;
# now simply reads the standalone script directly.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cat "${REPO_ROOT}/scripts/build-and-push.sh"
