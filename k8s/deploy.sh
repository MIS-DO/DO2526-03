#!/usr/bin/env bash
set -euo pipefail

K8S_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TMP_DIR="${K8S_DIR}/.rendered"
TEMPLATE_FILE="${K8S_DIR}/manifests/stack.yaml.tmpl"
RENDERED_FILE="${TMP_DIR}/stack.yaml"
PLATFORM_DIR="${K8S_DIR}/manifests/platform"
RUNTIME_DIR="${K8S_DIR}/.runtime"
HEADLAMP_PORT="${HEADLAMP_PORT:-8080}"
HEADLAMP_TOKEN_FILE="${RUNTIME_DIR}/headlamp-token.txt"
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

render_manifests() {
  mkdir -p "${TMP_DIR}"
  envsubst < "${TEMPLATE_FILE}" > "${RENDERED_FILE}"
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
  require_cmd envsubst
  require_cmd curl

  export PREPROD_NAMESPACE="${PREPROD_NAMESPACE:-search-preprod}"
  export PROD_NAMESPACE="${PROD_NAMESPACE:-search-prod}"

  export SEARCH_API_IMAGE="${SEARCH_API_IMAGE:-jorgeflorentino8/searchapi:latest}"
  export SONGS_API_IMAGE="${SONGS_API_IMAGE:-danvelcam621/songs-api:latest}"
  export MOVIES_API_IMAGE="${MOVIES_API_IMAGE:-migencmar/moviesapi:latest}"
  export FOOTBALL_API_IMAGE="${FOOTBALL_API_IMAGE:-jorgeflorentino8/footballteamapi:latest}"
  export MONGO_IMAGE="${MONGO_IMAGE:-mongo:7}"

  export API_REPLICAS="${API_REPLICAS:-1}"
  export MONGO_STORAGE_SIZE="${MONGO_STORAGE_SIZE:-1Gi}"
  export API_REQUEST_CPU="${API_REQUEST_CPU:-50m}"
  export API_REQUEST_MEMORY="${API_REQUEST_MEMORY:-96Mi}"
  export API_LIMIT_CPU="${API_LIMIT_CPU:-200m}"
  export API_LIMIT_MEMORY="${API_LIMIT_MEMORY:-256Mi}"
  export MONGO_REQUEST_CPU="${MONGO_REQUEST_CPU:-75m}"
  export MONGO_REQUEST_MEMORY="${MONGO_REQUEST_MEMORY:-128Mi}"
  export MONGO_LIMIT_CPU="${MONGO_LIMIT_CPU:-300m}"
  export MONGO_LIMIT_MEMORY="${MONGO_LIMIT_MEMORY:-384Mi}"

  render_manifests

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

  log "Applying app manifests (preprod + prod)"
  kubectl apply -f "${RENDERED_FILE}"

  log "Waiting for platform"
  kubectl -n default wait --for=condition=Available deployment/metrics-server --timeout=300s
  kubectl -n default wait --for=condition=Available deployment/headlamp --timeout=300s
  kubectl wait --for=condition=Available apiservice/v1beta1.metrics.k8s.io --timeout=300s

  log "Waiting for preprod deployments"
  kubectl -n "${PREPROD_NAMESPACE}" wait --for=condition=Available deployment/songs-mongo --timeout=300s
  kubectl -n "${PREPROD_NAMESPACE}" wait --for=condition=Available deployment/movies-mongo --timeout=300s
  kubectl -n "${PREPROD_NAMESPACE}" wait --for=condition=Available deployment/football-mongo --timeout=300s
  kubectl -n "${PREPROD_NAMESPACE}" wait --for=condition=Available deployment/songs-api --timeout=300s
  kubectl -n "${PREPROD_NAMESPACE}" wait --for=condition=Available deployment/movies-api --timeout=300s
  kubectl -n "${PREPROD_NAMESPACE}" wait --for=condition=Available deployment/football-api --timeout=300s
  kubectl -n "${PREPROD_NAMESPACE}" wait --for=condition=Available deployment/search-api --timeout=300s

  log "Waiting for prod deployments"
  kubectl -n "${PROD_NAMESPACE}" wait --for=condition=Available deployment/songs-mongo --timeout=300s
  kubectl -n "${PROD_NAMESPACE}" wait --for=condition=Available deployment/movies-mongo --timeout=300s
  kubectl -n "${PROD_NAMESPACE}" wait --for=condition=Available deployment/football-mongo --timeout=300s
  kubectl -n "${PROD_NAMESPACE}" wait --for=condition=Available deployment/songs-api --timeout=300s
  kubectl -n "${PROD_NAMESPACE}" wait --for=condition=Available deployment/movies-api --timeout=300s
  kubectl -n "${PROD_NAMESPACE}" wait --for=condition=Available deployment/football-api --timeout=300s
  kubectl -n "${PROD_NAMESPACE}" wait --for=condition=Available deployment/search-api --timeout=300s

  mkdir -p "${RUNTIME_DIR}"

  HEADLAMP_TOKEN="$(kubectl -n default create token headlamp-viewer)"
  printf "%s\n" "${HEADLAMP_TOKEN}" > "${HEADLAMP_TOKEN_FILE}"
  chmod 600 "${HEADLAMP_TOKEN_FILE}"

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

  log "Deployment completed"
  kubectl -n "${PREPROD_NAMESPACE}" get pods
  kubectl -n "${PROD_NAMESPACE}" get pods

  echo "Prod via Ingress: http://<INGRESS_LB>/api/v1/search?year=2010"
  echo "Preprod test (port-forward): kubectl -n ${PREPROD_NAMESPACE} port-forward svc/search-api 8081:80"
  echo "Local deterministic prod test:"
  echo "  kubectl -n default port-forward svc/ingress-nginx-controller 18081:80"
  echo "  curl 'http://127.0.0.1:18081/api/v1/search?year=2010'"
  if [ -n "${INGRESS_IP}" ]; then
    echo "Ingress external IP: ${INGRESS_IP}"
    echo "Test prod via LB: curl 'http://${INGRESS_IP}/api/v1/search?year=2010'"
  elif [ -n "${INGRESS_HOSTNAME}" ]; then
    echo "Ingress external hostname: ${INGRESS_HOSTNAME}"
    echo "Test prod via LB: curl 'http://${INGRESS_HOSTNAME}/api/v1/search?year=2010'"
  else
    echo "Ingress external address is still pending."
  fi

  if [ "${PF_READY}" -eq 1 ]; then
    echo "Headlamp URL: http://localhost:${HEADLAMP_PORT}"
  else
    echo "Headlamp port-forward started but not ready yet. Log: ${HEADLAMP_PF_LOG_FILE}"
  fi
  echo "Headlamp token file: ${HEADLAMP_TOKEN_FILE}"
}

main "$@"
