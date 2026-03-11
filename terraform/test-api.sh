#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TIMEOUT="${TIMEOUT:-10}"

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

log_info() { echo -e "${YELLOW}[INFO]${NC} $1"; }
log_pass() { echo -e "${GREEN}[PASS]${NC} $1"; PASS_COUNT=$((PASS_COUNT + 1)); }
log_fail() { echo -e "${RED}[FAIL]${NC} $1"; FAIL_COUNT=$((FAIL_COUNT + 1)); }

request() {
  local path="$1"
  local body_file
  body_file="$(mktemp)"

  local status
  status="$(curl -sS --connect-timeout "$TIMEOUT" --max-time "$TIMEOUT" \
    -o "$body_file" -w "%{http_code}" "http://${LB_ADDR}${path}" || true)"

  local body
  body="$(cat "$body_file")"
  rm -f "$body_file"

  printf "%s\n%s" "$status" "$body"
}

assert_status() {
  local actual="$1" expected="$2" name="$3"
  [ "$actual" = "$expected" ] && log_pass "$name (HTTP $actual)" || log_fail "$name (expected $expected, got $actual)"
}

assert_contains() {
  local body="$1" needle="$2" name="$3"
  printf "%s" "$body" | grep -q "$needle" && log_pass "$name" || log_fail "$name (missing '$needle')"
}

main() {
  # Leer LB_ADDR del .env si no está ya en el entorno
  if [ -z "${LB_ADDR:-}" ] && [ -f "$SCRIPT_DIR/.env" ]; then
    set -a; source "$SCRIPT_DIR/.env"; set +a
  fi

  if [ -z "${LB_ADDR:-}" ]; then
    echo "LB_ADDR no definido. Añade LB_ADDR=<ip> a terraform/.env" >&2
    exit 1
  fi

  log_info "LB address: ${LB_ADDR}"
  log_info "URL: http://${LB_ADDR}  ->  ingress-nginx-controller  ->  Ingress  ->  svc/search-api (search-prod)"

  local response status body

  response="$(request '/api/v1/search?year=2010')"
  status="$(printf "%s" "$response" | head -n1)"
  body="$(printf "%s" "$response" | tail -n +2)"
  assert_status "$status" "200" "GET /api/v1/search?year=2010"
  assert_contains "$body" '"songs"' "Response contains songs"
  assert_contains "$body" '"movies"' "Response contains movies"
  assert_contains "$body" '"footballTeams"' "Response contains footballTeams"

  response="$(request '/api/v1/search')"
  status="$(printf "%s" "$response" | head -n1)"
  assert_status "$status" "400" "GET /api/v1/search without params"

  response="$(request '/docs/')"
  status="$(printf "%s" "$response" | head -n1)"
  body="$(printf "%s" "$response" | tail -n +2)"
  assert_status "$status" "200" "GET /docs/"
  assert_contains "$body" 'swagger' "Docs contain swagger"

  echo
  echo "Summary: ${PASS_COUNT} OK, ${FAIL_COUNT} FAIL"
  [ "$FAIL_COUNT" -eq 0 ] || exit 1
}

main "$@"
