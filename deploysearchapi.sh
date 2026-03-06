#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TF_DIR="${REPO_DIR}/terraform"

log() {
  printf '\n[%s] %s\n' "deploysearchapi" "$1"
}

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Error: missing required command '$1'" >&2
    exit 1
  fi
}

get_tfvar() {
  local key="$1"
  local default="$2"
  local value=""

  if [[ -f "$TF_DIR/terraform.tfvars" ]]; then
    value="$(awk -F= -v k="$key" '$1 ~ "^[[:space:]]*"k"[[:space:]]*$" {gsub(/[\"[:space:]]/, "", $2); print $2}' "$TF_DIR/terraform.tfvars" | tail -n 1)"
  fi

  if [[ -z "$value" ]]; then
    value="$default"
  fi

  echo "$value"
}

main() {
  require_cmd docker

  local search_image
  search_image="$(get_tfvar search_api_image jorgeflorentino8/searchapi:latest)"

  log "Build and push search-api image to Docker Hub: $search_image"
  echo "If push fails, run: docker login"
  docker build -t "$search_image" "$REPO_DIR/search-api"
  docker push "$search_image"

  log "Completed"
}

main "$@"
