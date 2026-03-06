#!/usr/bin/env bash
set -euo pipefail

K8S_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TMP_DIR="${K8S_DIR}/.rendered"
TEMPLATE_FILE="${K8S_DIR}/manifests/stack.yaml.tmpl"
RENDERED_FILE="${TMP_DIR}/stack.yaml"
PLATFORM_DIR="${K8S_DIR}/manifests/platform"
RUNTIME_DIR="${K8S_DIR}/.runtime"
HEADLAMP_PF_PID_FILE="${RUNTIME_DIR}/headlamp-port-forward.pid"
HEADLAMP_TOKEN_FILE="${RUNTIME_DIR}/headlamp-token.txt"
HEADLAMP_PF_LOG_FILE="${RUNTIME_DIR}/headlamp-port-forward.log"

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

  rm -f "${HEADLAMP_PF_PID_FILE}" "${HEADLAMP_TOKEN_FILE}" "${HEADLAMP_PF_LOG_FILE}"
}

main() {
  ensure_path
  require_cmd kubectl
  require_cmd envsubst

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

  stop_headlamp_port_forward

  kubectl delete -f "${RENDERED_FILE}" --ignore-not-found=true
  kubectl delete -f "${PLATFORM_DIR}" --ignore-not-found=true

  rm -f "${HEADLAMP_TOKEN_FILE}" "${HEADLAMP_PF_LOG_FILE}" "${HEADLAMP_PF_PID_FILE}"
}

main "$@"
