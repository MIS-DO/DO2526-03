#!/usr/bin/env bash
set -euo pipefail

# Pega aqui IP del Load Balancer o usar LB_ADDR="203.0.113.10" ./terraform/test-prod-lb.sh
LB_ADDR="${LB_ADDR:-REPLACE_WITH_LB_IP_OR_HOSTNAME}"

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

request() {
  local path="$1"
  local body_file
  body_file="$(mktemp)"

  local status
  status="$(curl -sS --connect-timeout "$TIMEOUT" --max-time "$TIMEOUT" -o "$body_file" -w "%{http_code}" "http://${LB_ADDR}${path}" || true)"

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

main() {
  require_cmd curl

  if [ -z "$LB_ADDR" ] || [ "$LB_ADDR" = "REPLACE_WITH_LB_IP_OR_HOSTNAME" ]; then
    echo "Edita este script y pon LB_ADDR con la IP/hostname real del LB." >&2
    exit 1
  fi

  log_info "Testing prod via LB address: ${LB_ADDR}"

  local response status body

  response="$(request '/api/v1/search?year=2010')"
  status="$(printf "%s" "$response" | head -n1)"
  body="$(printf "%s" "$response" | tail -n +2)"
  assert_status "$status" "200" "GET /api/v1/search?year=2010 via LB"
  assert_contains "$body" '"songs"' "Response contains songs"
  assert_contains "$body" '"movies"' "Response contains movies"
  assert_contains "$body" '"footballTeams"' "Response contains footballTeams"

  response="$(request '/api/v1/search')"
  status="$(printf "%s" "$response" | head -n1)"
  assert_status "$status" "400" "GET /api/v1/search without params via LB"

  response="$(request '/docs/')"
  status="$(printf "%s" "$response" | head -n1)"
  body="$(printf "%s" "$response" | tail -n +2)"
  assert_status "$status" "200" "GET /docs/ via LB"
  assert_contains "$body" 'swagger' "Docs contain swagger"

  echo
  echo "Summary: ${PASS_COUNT} OK, ${FAIL_COUNT} FAIL"
  if [ "$FAIL_COUNT" -gt 0 ]; then
    exit 1
  fi
}

main "$@"
