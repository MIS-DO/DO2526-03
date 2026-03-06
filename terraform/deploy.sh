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
    echo "Run: cp terraform.tfvars.example terraform.tfvars" >&2
    exit 1
  fi

  if [[ -z "${TF_VAR_do_token:-}" ]]; then
    echo "Error: TF_VAR_do_token is empty. Set it in terraform/.env or export it." >&2
    exit 1
  fi

  local cluster_name preprod_namespace prod_namespace ingress_ip ingress_hostname ingress_output_addr

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

  preprod_namespace="$(terraform -chdir="$SCRIPT_DIR" output -raw preprod_namespace)"
  prod_namespace="$(terraform -chdir="$SCRIPT_DIR" output -raw prod_namespace)"

  log "Quick checks"
  kubectl get nodes
  kubectl -n "$preprod_namespace" get pods
  kubectl -n "$prod_namespace" get pods
  kubectl -n default get svc ingress-nginx-controller

  ingress_ip="$(kubectl -n default get svc ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || true)"
  ingress_hostname="$(kubectl -n default get svc ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || true)"
  ingress_output_addr="$(terraform -chdir="$SCRIPT_DIR" output -raw ingress_lb_address 2>/dev/null || true)"
  if [[ -n "$ingress_output_addr" ]]; then
    echo "Terraform output ingress_lb_address: $ingress_output_addr"
  fi

  if [[ -n "$ingress_ip" ]]; then
    log "Ingress IP: $ingress_ip"
    echo "Prod URL (ingress): http://$ingress_ip"
    echo "Preprod test via port-forward: kubectl -n $preprod_namespace port-forward svc/search-api 8081:80"
    echo "Direct test prod: curl 'http://$ingress_ip/api/v1/search?year=2010'"
  elif [[ -n "$ingress_hostname" ]]; then
    log "Ingress hostname: $ingress_hostname"
    echo "Prod URL (ingress): http://$ingress_hostname"
    echo "Preprod test via port-forward: kubectl -n $preprod_namespace port-forward svc/search-api 8081:80"
    echo "Direct test prod: curl 'http://$ingress_hostname/api/v1/search?year=2010'"
  else
    log "Ingress external address still pending"
  fi
}

main "$@"
