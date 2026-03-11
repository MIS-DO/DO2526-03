#!/usr/bin/env bash
set -euo pipefail

K8S_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLATFORM_DIR="${K8S_DIR}/manifests/platform"
STACK_FILE="${K8S_DIR}/manifests/stack.yaml"
RUNTIME_DIR="${K8S_DIR}/.runtime"
HEADLAMP_PF_PID_FILE="${RUNTIME_DIR}/headlamp-port-forward.pid"
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

  stop_headlamp_port_forward

  kubectl delete -f "${STACK_FILE}" --ignore-not-found=true
  kubectl delete -f "${PLATFORM_DIR}" --ignore-not-found=true

  rm -f "${HEADLAMP_PF_LOG_FILE}" "${HEADLAMP_PF_PID_FILE}"
}

main "$@"
