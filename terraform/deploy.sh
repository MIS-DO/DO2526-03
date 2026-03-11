#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

log() {
  printf '\n[%s] %s\n' "deploy" "$1"
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
  require_cmd kubectl

  load_env_file

  if [[ ! -f "$SCRIPT_DIR/terraform.tfvars" ]]; then
    echo "Error: terraform.tfvars not found in $SCRIPT_DIR" >&2
    exit 1
  fi

  if [[ -z "${TF_VAR_do_token:-}" ]]; then
    echo "Error: TF_VAR_do_token is empty. Set it in terraform/.env or export it." >&2
    exit 1
  fi

  local cluster_name ingress_ip ingress_hostname

  log "Terraform init"
  terraform -chdir="$SCRIPT_DIR" init

  log "Terraform validate"
  terraform -chdir="$SCRIPT_DIR" validate

  log "Create DOKS cluster first"
  terraform -chdir="$SCRIPT_DIR" apply -auto-approve -target=digitalocean_kubernetes_cluster.main

  cluster_name="$(terraform -chdir="$SCRIPT_DIR" output -raw cluster_name)"

  log "Configure kubeconfig for cluster: $cluster_name"
  doctl auth init -t "$TF_VAR_do_token"
  doctl kubernetes cluster kubeconfig save "$cluster_name"

  log "Apply full infrastructure and workloads"
  terraform -chdir="$SCRIPT_DIR" apply -auto-approve

  log "Quick checks"
  kubectl get nodes
  kubectl -n search-preprod get pods
  kubectl -n search-prod get pods

  ingress_ip="$(kubectl -n default get svc ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || true)"
  ingress_hostname="$(kubectl -n default get svc ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || true)"
  local lb_addr="${ingress_ip:-$ingress_hostname}"

  if [[ -n "$lb_addr" ]]; then
    log "Ingress LB: $lb_addr"
    echo ""
    echo "=== PROD (via Ingress LB) ==="
    echo "  search-api: http://$lb_addr/docs/"
    echo "  search:     http://$lb_addr/api/v1/search?year=2010"
  else
    log "Ingress external address still pending"
  fi
}

main "$@"
