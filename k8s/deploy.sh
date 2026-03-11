#!/usr/bin/env bash
set -euo pipefail

K8S_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLATFORM_DIR="${K8S_DIR}/manifests/platform"
STACK_FILE="${K8S_DIR}/manifests/stack.yaml"
RUNTIME_DIR="${K8S_DIR}/.runtime"
HEADLAMP_PORT="${HEADLAMP_PORT:-8080}"
HEADLAMP_PF_PID_FILE="${RUNTIME_DIR}/headlamp-port-forward.pid"
HEADLAMP_PF_LOG_FILE="${RUNTIME_DIR}/headlamp-port-forward.log"

log() {
  printf '\n[%s] %s\n' "k8s-deploy" "$1"
}

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Error: missing required command '$1'" >&2
    exit 1
  fi
}

ensure_path() {
  export PATH="${PATH}:/snap/bin:/usr/local/bin:/usr/bin:/bin"
}

stop_headlamp_port_forward() {
  if [ ! -f "${HEADLAMP_PF_PID_FILE}" ]; then
    return 0
  fi

  local pf_pid
  pf_pid="$(cat "${HEADLAMP_PF_PID_FILE}" 2>/dev/null || true)"
  if [ -n "${pf_pid}" ] && kill -0 "${pf_pid}" >/dev/null 2>&1; then
    kill "${pf_pid}" >/dev/null 2>&1 || true
  fi

  rm -f "${HEADLAMP_PF_PID_FILE}" "${HEADLAMP_PF_LOG_FILE}"
}

main() {
  ensure_path
  require_cmd kubectl
  require_cmd curl

  log "Applying platform manifests (ingress-nginx, metrics-server, headlamp)"
  kubectl apply -f "${PLATFORM_DIR}"

  log "Waiting for ingress admission webhook readiness"
  kubectl -n default wait --for=condition=complete job/ingress-nginx-admission-create --timeout=300s
  kubectl -n default wait --for=condition=complete job/ingress-nginx-admission-patch --timeout=300s
  kubectl -n default wait --for=condition=Available deployment/ingress-nginx-controller --timeout=300s

  ADMISSION_READY=0
  for _ in $(seq 1 30); do
    ADMISSION_EP="$(kubectl -n default get endpoints ingress-nginx-controller-admission -o jsonpath='{.subsets[0].addresses[0].ip}' 2>/dev/null || true)"
    if [ -n "${ADMISSION_EP}" ]; then
      ADMISSION_READY=1
      break
    fi
    sleep 2
  done
  if [ "${ADMISSION_READY}" -ne 1 ]; then
    echo "Error: ingress admission endpoint is not ready." >&2
    exit 1
  fi

  sleep 5

  log "Applying app manifests (preprod + prod)"
  kubectl apply -f "${STACK_FILE}"

  log "Waiting for platform"
  kubectl -n default wait --for=condition=Available deployment/metrics-server --timeout=300s
  kubectl -n default wait --for=condition=Available deployment/headlamp --timeout=300s
  kubectl wait --for=condition=Available apiservice/v1beta1.metrics.k8s.io --timeout=300s

  log "Waiting for preprod deployments"
  kubectl -n search-preprod wait --for=condition=Available deployment/songs-mongo --timeout=300s
  kubectl -n search-preprod wait --for=condition=Available deployment/movies-mongo --timeout=300s
  kubectl -n search-preprod wait --for=condition=Available deployment/football-mongo --timeout=300s
  kubectl -n search-preprod wait --for=condition=Available deployment/songs-api --timeout=300s
  kubectl -n search-preprod wait --for=condition=Available deployment/movies-api --timeout=300s
  kubectl -n search-preprod wait --for=condition=Available deployment/football-api --timeout=300s
  kubectl -n search-preprod wait --for=condition=Available deployment/search-api --timeout=300s

  log "Waiting for prod deployments"
  kubectl -n search-prod wait --for=condition=Available deployment/songs-mongo --timeout=300s
  kubectl -n search-prod wait --for=condition=Available deployment/movies-mongo --timeout=300s
  kubectl -n search-prod wait --for=condition=Available deployment/football-mongo --timeout=300s
  kubectl -n search-prod wait --for=condition=Available deployment/songs-api --timeout=300s
  kubectl -n search-prod wait --for=condition=Available deployment/movies-api --timeout=300s
  kubectl -n search-prod wait --for=condition=Available deployment/football-api --timeout=300s
  kubectl -n search-prod wait --for=condition=Available deployment/search-api --timeout=300s

  mkdir -p "${RUNTIME_DIR}"

  HEADLAMP_TOKEN="$(kubectl -n default create token headlamp-viewer)"
  echo "Headlamp token: ${HEADLAMP_TOKEN}"

  stop_headlamp_port_forward
  kubectl -n default port-forward service/headlamp "${HEADLAMP_PORT}:80" >"${HEADLAMP_PF_LOG_FILE}" 2>&1 &
  HEADLAMP_PF_PID="$!"
  printf "%s\n" "${HEADLAMP_PF_PID}" > "${HEADLAMP_PF_PID_FILE}"

  PF_READY=0
  for _ in $(seq 1 20); do
    if curl -fsS "http://127.0.0.1:${HEADLAMP_PORT}/" >/dev/null 2>&1; then
      PF_READY=1
      break
    fi
    sleep 1
  done

  INGRESS_IP="$(kubectl -n default get svc ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || true)"
  INGRESS_HOSTNAME="$(kubectl -n default get svc ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || true)"

  kubectl -n search-preprod port-forward svc/search-api 8081:80 >"${RUNTIME_DIR}/pf-preprod-search.log" 2>&1 &

  sleep 2

  log "Deployment completed"
  kubectl -n search-preprod get pods
  kubectl -n search-prod get pods

  echo ""
  echo "=== PROD (via Ingress) ==="
  echo "  search-api: http://localhost/docs/"
  echo ""
  echo "=== PREPROD (via port-forward) ==="
  echo "  search-api: http://localhost:8081/docs/"
  echo ""
  if [ "${PF_READY}" -eq 1 ]; then
    echo "  Headlamp: http://localhost:${HEADLAMP_PORT}"
  fi
}

main "$@"
