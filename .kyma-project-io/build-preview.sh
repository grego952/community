#!/usr/bin/env bash
# Script for build preview of this repo like in https://kyma-project.io/community/ on every PR.
# For more information, please contact with: @m00g3n @aerfio @magicmatatjahu

set -eo pipefail

on_error() {
    echo -e "${RED}✗ Failed${NC}"
    exit 1
}
trap on_error ERR

readonly KYMA_PROJECT_IO_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

readonly WEBSITE_DIR="website"
readonly WEBSITE_REPO="https://github.com/kyma-project/website"

readonly BUILD_DIR="${KYMA_PROJECT_IO_DIR}/${WEBSITE_DIR}"
readonly COMMUNITY_DIR="$( cd "${KYMA_PROJECT_IO_DIR}/.." && pwd )"

# Colors
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[0;33m'
readonly NC='\033[0m' # No Color

pass() {
  local message="$1"
  echo -e "${GREEN}√ ${message}${NC}"
}

step() {
  local message="$1"
  echo -e "\\n${YELLOW}${message}${NC}"
}

remove-cached-content() {
  ( rm -rf "${BUILD_DIR}" ) || true
}

merge-community() {
  git config --global user.email "ci-website@kyma-project.io"
  git config --global user.name "CI/CD"
  step "Newest commit"
  git log --max-count=1

  git checkout -B pull-request
  git checkout main

  # grep return 1 as exit code when no line matches, so we need to suppress it
  HAS_ORIGIN="$(git remote | grep -c "origin" || true)"

  if [[ "${HAS_ORIGIN}" -eq "0" ]]; then
    step "add origin as it is not available"
    git remote add origin https://github.com/kyma-project/community.git
  fi

  git fetch origin
  git pull origin main

  step "Last commit from main"
  git log --max-count=1
  # as netlify caches component state between runs,
  # there is need to recreate branch to be sure that newest main is main from origin,
  # not merged one in previous run
  git checkout -B merged

  step "merging changes from pull request to main"
  git merge pull-request
}

copy-website-repo() {
  git clone -b "main" --single-branch "${WEBSITE_REPO}" "${WEBSITE_DIR}"
}

build-preview() {
  export APP_COMMUNITY_SOURCE_DIR="${COMMUNITY_DIR}"
  make -C "${BUILD_DIR}" netlify-community-preview
}

add-redirect() {
  echo "/ /community/" > "${BUILD_DIR}"/public/_redirects
}

main() {
  step "Remove website cached content"
  remove-cached-content
  pass "Removed"

  step "Merge changes from PR with main branch"
  merge-community
  step "Merged"

  step "Copying kyma/website repo"
  copy-website-repo
  pass "Copied"

  step "Remove old content from website"
  rm -rf "${BUILD_DIR}"/content/community
  step "Removed"

  step "Building preview"
  build-preview
  pass "Builded"

  step "Add redirect"
  add-redirect
  pass "Added"
}
main
