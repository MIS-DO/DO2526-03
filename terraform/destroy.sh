#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

log() {
  printf '\n[%s] %s\n' "destroy" "$1"
}

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Error: missing required command '$1'" >&2
    exit 1
  fi
}

load_env_file() {
  if [[ -f "$SCRIPT_DIR/.env" ]]; then
    set -a
    # shellcheck disable=SC1091
    source "$SCRIPT_DIR/.env"
    set +a
  fi
}

main() {
  require_cmd terraform
  require_cmd doctl

  load_env_file

  if [[ ! -f "$SCRIPT_DIR/terraform.tfvars" ]]; then
    echo "Error: terraform.tfvars not found in $SCRIPT_DIR" >&2
    echo "Run: cp terraform.tfvars.example terraform.tfvars" >&2
    exit 1
  fi

  if [[ -z "${TF_VAR_do_token:-}" ]]; then
    echo "Error: TF_VAR_do_token is empty. Set it in terraform/.env or export it." >&2
    exit 1
  fi

  log "Terraform init"
  terraform -chdir="$SCRIPT_DIR" init

  cluster_name="$(terraform -chdir="$SCRIPT_DIR" output -raw cluster_name 2>/dev/null || true)"
  if [[ -n "$cluster_name" ]]; then
    log "Configure kubeconfig for cluster: $cluster_name"
    doctl auth init -t "$TF_VAR_do_token"
    doctl kubernetes cluster kubeconfig save "$cluster_name"
  fi

  log "Destroy all managed resources"
  terraform -chdir="$SCRIPT_DIR" destroy -auto-approve

  log "Completed"
}

main "$@"
