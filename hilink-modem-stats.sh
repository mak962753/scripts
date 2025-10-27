#!/usr/bin/env zsh

# ------------------------------------------------------------------
# Configuration – change these if your device uses a different IP
# ------------------------------------------------------------------
DEVICE_IP="192.168.8.1"

# Log file – adjust the path if you want it somewhere else
LOG_FILE="${HOME}/Documents/signal_log.txt"

# Interval between samples (seconds)
INTERVAL=10

# ------------------------------------------------------------------
# Helper functions – XML extraction helpers
# ------------------------------------------------------------------

# Try xmlstarlet first, fall back to xmllint
extract_xml() {
  local xpath=$1   # e.g. "/response/rsrq"
  local xml=$2

  if command -v xmlstarlet >/dev/null; then
    echo "$(xmlstarlet sel -t -m "$xpath" -v . -n <<<"$xml")"
  elif command -v xmllint >/dev/null; then 
    # xmllint is always available on macOS
    echo "$(xmllint --xpath "$xpath/text()" - <<<"$xml" 2>/dev/null)"
  else
      echo "ERROR: No XML parser (xmlstarlet or xmllint) found!"
      echo "# Install the utility that contains xmllint"
      echo "sudo apt install -y libxml2-utils   # gives you xmllint"
      exit 1
  fi
}

# ------------------------------------------------------------------
# 1️⃣ Get session token & ID
# ------------------------------------------------------------------

resp=$(curl -s "http://${DEVICE_IP}/api/webserver/SesTokInfo")
# The response is XML – extract <SesInfo> and <TokInfo>
Sesi=$(extract_xml "/response/SesInfo" "$resp")
Toki=$(extract_xml "/response/TokInfo" "$resp")

# SesInfo looks like "SessionID=xxxxxx". Grab the part after '='
SESSION_ID=${Sesi#*=}
echo "Session ID: $SESSION_ID"
echo "Token     : $Toki"

# ------------------------------------------------------------------
# 2️⃣ Send the network‑mode XML payload
# ------------------------------------------------------------------

NET_MODE_XML='<?xml version="1.0" encoding="UTF-8"?>
<request>
  <NetworkMode>03</NetworkMode>
  <NetworkBand>3FFFFFFF</NetworkBand>
  <LTEBand>80</LTEBand>
</request>'

# Warm‑up GET – same as the PowerShell Out‑Null
curl -s "http://${DEVICE_IP}/api/net/net-mode" >/dev/null

# POST the XML
POST_RESP=$(curl -s \
  -H "Content-Type: application/xml" \
  -b "SessionID=${SESSION_ID}" \
  --data-binary "$NET_MODE_XML" \
  "http://${DEVICE_IP}/api/net/net-mode")

echo "Net‑mode POST response:"
echo "$POST_RESP"

# ------------------------------------------------------------------
# 3️⃣ Prepare logging header
# ------------------------------------------------------------------

HEADER="Timestamp,RSRQ,RSRP,RSSI,SINR,CellID,Band"
if [[ ! -f $LOG_FILE ]]; then
  echo "$HEADER" >"$LOG_FILE"
fi

echo "Logging to $LOG_FILE"

# ------------------------------------------------------------------
# 4️⃣ Main loop – fetch signal data forever
# ------------------------------------------------------------------

while true; do

  # GET the signal information (with the session cookie)
  SIG_RESP=$(curl -s \
    -H "Accept: text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.7" \
    -H "Accept-Encoding: gzip, deflate" \
    -H "Accept-Language: ru,en;q=0.9,en-GB;q=0.8,en-US;q=0.7" \
    -H "Cache-Control: max-age=0" \
    -H "Upgrade-Insecure-Requests: 1" \
    -b "SessionID=${SESSION_ID}" \
    "http://${DEVICE_IP}/api/device/signal")

  # Quick error check – if /error/code exists, abort
  err_code=$(extract_xml "/error/code" "$SIG_RESP")
  if [[ -n $err_code ]]; then
    echo "Error from device: code=$err_code"
    break
  fi

  # Extract all the fields we care about
  rsrq=$(extract_xml "/response/rsrq" "$SIG_RESP")
  rsrp=$(extract_xml "/response/rsrp" "$SIG_RESP")
  rssi=$(extract_xml "/response/rssi" "$SIG_RESP")
  sinr=$(extract_xml "/response/sinr" "$SIG_RESP")
  cell_id=$(extract_xml "/response/cell_id" "$SIG_RESP")
  mode=$(extract_xml "/response/mode" "$SIG_RESP")

  # Build a CSV line
  ts=$(date '+%Y-%m-%d %H:%M:%S')
  line="${ts},${rsrq},${rsrp},${rssi},${sinr},${cell_id},${mode}"

  # Print to console
  echo "$line"

  # Append to log file
  echo "$line" >>"$LOG_FILE"

  # Sleep before next sample
  sleep $INTERVAL

done
