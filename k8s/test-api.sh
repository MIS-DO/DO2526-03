#!/usr/bin/env bash
set -euo pipefail

K8S_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RUNTIME_DIR="${K8S_DIR}/.runtime"
PREPROD_NAMESPACE="${PREPROD_NAMESPACE:-search-preprod}"
PROD_NAMESPACE="${PROD_NAMESPACE:-search-prod}"
PREPROD_PORT="${PREPROD_PORT:-18080}"
INGRESS_PORT="${INGRESS_PORT:-18081}"

RED=""
GREEN=""
YELLOW=""
NC=""
if [ -t 1 ]; then
  RED="\033[0;31m"
  GREEN="\033[0;32m"
  YELLOW="\033[1;33m"
  NC="\033[0m"
fi

PASS_COUNT=0
FAIL_COUNT=0
PREPROD_PF_PID=""
INGRESS_PF_PID=""

log_info() {
  echo -e "${YELLOW}[INFO]${NC} $1"
}

log_pass() {
  echo -e "${GREEN}[PASS]${NC} $1"
  PASS_COUNT=$((PASS_COUNT + 1))
}

log_fail() {
  echo -e "${RED}[FAIL]${NC} $1"
  FAIL_COUNT=$((FAIL_COUNT + 1))
}

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing command: $1" >&2
    exit 1
  fi
}

ensure_path() {
  export PATH="${PATH}:/snap/bin:/usr/local/bin:/usr/bin:/bin"
}

request() {
  local method="$1"
  local url="$2"
  local body_file
  body_file="$(mktemp)"

  local status
  status="$(curl -sS -o "$body_file" -w "%{http_code}" -X "$method" "$url" || true)"

  local body
  body="$(cat "$body_file")"
  rm -f "$body_file"

  printf "%s\n%s" "$status" "$body"
}

assert_status() {
  local actual="$1"
  local expected="$2"
  local name="$3"
  if [ "$actual" = "$expected" ]; then
    log_pass "$name (HTTP $actual)"
  else
    log_fail "$name (expected $expected, got $actual)"
  fi
}

assert_contains() {
  local body="$1"
  local needle="$2"
  local name="$3"
  if printf "%s" "$body" | grep -q "$needle"; then
    log_pass "$name"
  else
    log_fail "$name (missing '$needle')"
  fi
}

cleanup() {
  if [ -n "$PREPROD_PF_PID" ] && kill -0 "$PREPROD_PF_PID" >/dev/null 2>&1; then
    kill "$PREPROD_PF_PID" >/dev/null 2>&1 || true
  fi
  if [ -n "$INGRESS_PF_PID" ] && kill -0 "$INGRESS_PF_PID" >/dev/null 2>&1; then
    kill "$INGRESS_PF_PID" >/dev/null 2>&1 || true
  fi
}
trap cleanup EXIT

main() {
  ensure_path
  require_cmd kubectl
  require_cmd curl

  mkdir -p "$RUNTIME_DIR"

  log_info "Validating both environments are deployed"
  if ! kubectl get ns "$PREPROD_NAMESPACE" >/dev/null 2>&1; then
    log_fail "Namespace '$PREPROD_NAMESPACE' not found. Run ./k8s/deploy.sh first."
    exit 1
  fi
  if ! kubectl get ns "$PROD_NAMESPACE" >/dev/null 2>&1; then
    log_fail "Namespace '$PROD_NAMESPACE' not found. Run ./k8s/deploy.sh first."
    exit 1
  fi
  if ! kubectl -n "$PREPROD_NAMESPACE" wait --for=condition=Available deployment/search-api --timeout=120s >/dev/null 2>&1; then
    log_fail "search-api in '$PREPROD_NAMESPACE' is not available."
    exit 1
  fi
  if ! kubectl -n "$PROD_NAMESPACE" wait --for=condition=Available deployment/search-api --timeout=120s >/dev/null 2>&1; then
    log_fail "search-api in '$PROD_NAMESPACE' is not available."
    exit 1
  fi
  if ! kubectl -n "$PROD_NAMESPACE" get ingress search-api-ingress-prod >/dev/null 2>&1; then
    log_fail "Prod ingress 'search-api-ingress-prod' not found in '$PROD_NAMESPACE'."
    exit 1
  fi
  if ! kubectl -n default get svc ingress-nginx-controller >/dev/null 2>&1; then
    log_fail "Service default/ingress-nginx-controller not found."
    exit 1
  fi
  log_pass "Both environments exist and search-api is available in preprod + prod"

  log_info "Starting port-forward to preprod service"
  kubectl -n "$PREPROD_NAMESPACE" port-forward svc/search-api "${PREPROD_PORT}:80" >"$RUNTIME_DIR/test-preprod-pf.log" 2>&1 &
  PREPROD_PF_PID="$!"

  log_info "Starting port-forward to ingress controller"
  kubectl -n default port-forward svc/ingress-nginx-controller "${INGRESS_PORT}:80" >"$RUNTIME_DIR/test-ingress-pf.log" 2>&1 &
  INGRESS_PF_PID="$!"

  sleep 2

  local response status body

  response="$(request GET "http://127.0.0.1:${PREPROD_PORT}/api/v1/search?year=2010")"
  status="$(printf "%s" "$response" | head -n1)"
  body="$(printf "%s" "$response" | tail -n +2)"
  assert_status "$status" "200" "Preprod GET /api/v1/search?year=2010"
  assert_contains "$body" '"songs"' "Preprod response contains songs"
  assert_contains "$body" '"movies"' "Preprod response contains movies"
  assert_contains "$body" '"footballTeams"' "Preprod response contains footballTeams"

  response="$(request GET "http://127.0.0.1:${PREPROD_PORT}/api/v1/search")"
  status="$(printf "%s" "$response" | head -n1)"
  body="$(printf "%s" "$response" | tail -n +2)"
  assert_status "$status" "400" "Preprod GET /api/v1/search without params"

  response="$(request GET "http://127.0.0.1:${INGRESS_PORT}/api/v1/search?minYear=2000&maxYear=2010")"
  status="$(printf "%s" "$response" | head -n1)"
  body="$(printf "%s" "$response" | tail -n +2)"
  assert_status "$status" "200" "Prod via Ingress GET /api/v1/search?minYear=2000&maxYear=2010"
  assert_contains "$body" '"songs"' "Prod Ingress response contains songs"

  response="$(request GET "http://127.0.0.1:${INGRESS_PORT}/docs/")"
  status="$(printf "%s" "$response" | head -n1)"
  body="$(printf "%s" "$response" | tail -n +2)"
  assert_status "$status" "200" "Prod via Ingress GET /docs/"
  assert_contains "$body" 'swagger' "Prod /docs returns swagger content"

  echo
  echo "Summary: ${PASS_COUNT} OK, ${FAIL_COUNT} FAIL"
  if [ "$FAIL_COUNT" -gt 0 ]; then
    exit 1
  fi
}

main "$@"
