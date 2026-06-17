#!/bin/sh
# Toggle Huawei B525 mobile data via Web API (same as UI button).
# Usage: ROUTER_PASS=secret [ROUTER_IP=192.168.8.1] [ROUTER_USER=admin] ./mobile-cycle.sh [off|on|cycle]

set -e

ROUTER_IP="${ROUTER_IP:-192.168.8.1}"
ROUTER_USER="${ROUTER_USER:-admin}"
ACTION="${1:-cycle}"
TMP_HEADER="${TMPDIR:-/tmp}/b525-mobile-cycle.$$"

# --- terminal colors (no-op when not a tty) ---
if [ -t 1 ]; then
  ESC=$(printf '\033')
  C_RESET="${ESC}[0m"
  C_DIM="${ESC}[2m"
  C_CYAN="${ESC}[36m"
  C_GREEN="${ESC}[32m"
  C_YELLOW="${ESC}[33m"
  C_RED="${ESC}[31m"
  C_BOLD="${ESC}[1m"
else
  C_RESET='' C_DIM='' C_CYAN='' C_GREEN='' C_YELLOW='' C_RED='' C_BOLD=''
fi

log_step() { printf '%b🔑 %s%b\n' "$C_CYAN" "$1" "$C_RESET"; }
log_ok() { printf '%b✅ %s%b\n' "$C_GREEN" "$1" "$C_RESET"; }
log_warn() { printf '%b⚠️  %s%b\n' "$C_YELLOW" "$1" "$C_RESET"; }
log_err() { printf '%b❌ %s%b\n' "$C_RED" "$1" "$C_RESET" >&2; }
log_detail() { printf '%b   %s%b\n' "$C_DIM" "$1" "$C_RESET"; }

if [ -z "${ROUTER_PASS:-}" ]; then
  log_err "set ROUTER_PASS environment variable"
  exit 1
fi

cleanup() {
  rm -f "$TMP_HEADER"
}
trap cleanup EXIT INT TERM

sha256_hex() {
  printf '%s' "$1" | shasum -a 256 | awk '{print $1}'
}

b64() {
  printf '%s' "$1" | base64 | tr -d '\n'
}

normalize_cookie() {
  case "$1" in
  SessionID=*) printf '%s' "$1" ;;
  *) printf 'SessionID=%s' "$1" ;;
  esac
}

cookie_preview() {
  value="$1"
  prefix=""
  rest="$value"
  case "$value" in
  SessionID=*)
    prefix="SessionID="
    rest=${value#SessionID=}
    ;;
  esac
  if [ "${#rest}" -gt 16 ]; then
    printf '%s%s…%s' "$prefix" "$(printf '%.8s' "$rest")" "$(printf '%s' "$rest" | awk '{print substr($0, length($0)-7)}')"
  else
    printf '%s' "$value"
  fi
}

update_from_headers() {
  new_cookie=""
  new_token=""

  new_cookie=$(sed -n 's/^[Ss]et-[Cc]ookie:[[:space:]]*\([^;]*\).*$/\1/p' "$TMP_HEADER" | head -n 1)
  new_token=$(sed -n 's/^__RequestVerificationTokentwo:[[:space:]]*\(.*\)$/\1/p' "$TMP_HEADER" | tr -d '\r' | head -n 1)
  if [ -z "$new_token" ]; then
    new_token=$(sed -n 's/^__RequestVerificationTokenone:[[:space:]]*\(.*\)$/\1/p' "$TMP_HEADER" | tr -d '\r' | head -n 1)
  fi

  if [ -n "$new_cookie" ]; then
    COOKIE=$(normalize_cookie "$new_cookie")
  fi
  if [ -n "$new_token" ]; then
    TOKEN="$new_token"
  fi
}

api_error_message() {
  code="$1"
  case "$code" in
  100003) printf 'no rights — session not authenticated' ;;
  125002) printf 'wrong session — login again' ;;
  125003) printf 'stale token — refresh and retry' ;;
  *) printf 'router API error %s' "$code" ;;
  esac
}

check_api_response() {
  resp="$1"
  label="$2"

  if printf '%s' "$resp" | grep -q '<response>OK</response>'; then
    log_ok "$label"
    return 0
  fi

  code=$(printf '%s' "$resp" | sed -n 's:.*<code>\([0-9]*\)</code>.*:\1:p' | head -n 1)
  if [ -n "$code" ]; then
    log_err "$label failed: $(api_error_message "$code")"
  else
    log_err "$label failed"
  fi
  log_detail "$(printf '%s' "$resp" | tr '\n' ' ')"
  return 1
}

get_sess_tok() {
  log_step "getting session token"
  xml=""
  if [ -n "${COOKIE:-}" ]; then
    xml=$(curl -s "http://${ROUTER_IP}/api/webserver/SesTokInfo" -H "Cookie: ${COOKIE}")
  else
    xml=$(curl -s "http://${ROUTER_IP}/api/webserver/SesTokInfo")
  fi

  ses=$(printf '%s' "$xml" | sed -n 's:.*<SesInfo>\(.*\)</SesInfo>.*:\1:p')
  tok=$(printf '%s' "$xml" | sed -n 's:.*<TokInfo>\(.*\)</TokInfo>.*:\1:p')
  COOKIE=$(normalize_cookie "$ses")
  TOKEN="$tok"

  if [ -z "$COOKIE" ] || [ -z "$TOKEN" ]; then
    log_err "failed to get session/token from router"
    exit 1
  fi

  log_detail "cookie: $(cookie_preview "$COOKIE")"
  log_detail "token:  ${TOKEN}"
}

login() {
  get_sess_tok
  log_step "logging in"

  p1=$(b64 "$(sha256_hex "$ROUTER_PASS")")
  p2=$(b64 "$(sha256_hex "${ROUTER_USER}${p1}${TOKEN}")")
  resp=$(curl -s -D "$TMP_HEADER" -X POST "http://${ROUTER_IP}/api/user/login" \
    -H "Cookie: ${COOKIE}" \
    -H "__RequestVerificationToken: ${TOKEN}" \
    -H "Content-Type: application/x-www-form-urlencoded; charset=UTF-8" \
    -H "X-Requested-With: XMLHttpRequest" \
    --data "<?xml version=\"1.0\" encoding=\"UTF-8\"?><request><Username>${ROUTER_USER}</Username><Password>${p2}</Password><password_type>4</password_type></request>")

  update_from_headers

  if ! check_api_response "$resp" "login"; then
    exit 1
  fi

  # authenticated session needs a fresh CSRF token
  get_sess_tok
}

mobile_data() {
  sw="$1"
  label="$2"

  get_sess_tok
  log_step "$label"

  resp=$(curl -s -D "$TMP_HEADER" -X POST "http://${ROUTER_IP}/api/dialup/mobile-dataswitch" \
    -H "Cookie: ${COOKIE}" \
    -H "__RequestVerificationToken: ${TOKEN}" \
    -H "Content-Type: application/x-www-form-urlencoded; charset=UTF-8" \
    -H "X-Requested-With: XMLHttpRequest" \
    --data "<?xml version=\"1.0\" encoding=\"UTF-8\"?><request><dataswitch>${sw}</dataswitch></request>")

  update_from_headers
  check_api_response "$resp" "$label" || exit 1
}

log_step "Huawei B525 mobile data — ${ACTION}"
login

case "$ACTION" in
off)
  mobile_data 0 "disabling mobile data 📴"
  ;;
on)
  mobile_data 1 "enabling mobile data 📶"
  ;;
cycle)
  mobile_data 0 "disabling mobile data 📴"
  log_warn "waiting 3s before reconnect…"
  sleep 3
  mobile_data 1 "enabling mobile data 📶"
  log_ok "cycle complete 🔄"
  ;;
*)
  log_err "usage: $0 [off|on|cycle]"
  exit 1
  ;;
esac
