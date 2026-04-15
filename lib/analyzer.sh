#!/bin/bash
# ============================================================
# RECON Framework — lib/analyzer.sh
# Intelligence: Response Anomaly Detection
# ============================================================

analyze_responses() {
  local IN="$WORKDIR/03_live_hosts/live.txt"
  local OUT="$WORKDIR/intelligence/response_anomalies.txt"

  if [ ! -s "$IN" ]; then
    log warn "No live hosts found. Skipping response analysis."
    touch "$OUT"
    return 0
  fi

  log info "Intelligence: Response anomaly analysis starting"

  {
    echo "# Response Anomaly Analysis for $TARGET"
    echo "# Generated: $(date)"
    echo ""

    while IFS= read -r url; do
      local response
      response=$(curl -sk -i --max-time 10 "$url" 2>/dev/null)

      [ -z "$response" ] && continue

      echo "$response" | grep -qi "stack trace\|java.lang\|traceback\|at line " && \
        echo "[DEBUG_EXPOSURE] $url → Stack trace / debug info in response"

      echo "$response" | grep -qi "sql syntax\|mysql_fetch\|ORA-[0-9]\|Microsoft SQL\|SQLite" && \
        echo "[SQL_ERROR] $url → SQL error message exposed"

      echo "$response" | grep -qi "api_key\|apikey\|access_token\|client_secret" && \
        echo "[TOKEN_EXPOSURE] $url → API token/key in response"

      echo "$response" | grep -qi "root:\|/etc/passwd\|/bin/bash" && \
        echo "[LFI_INDICATOR] $url → Possible file inclusion output"

      if echo "$response" | grep -qi "X-Powered-By\|Server:"; then
        local server
        server=$(echo "$response" | grep -i "Server:" | head -1 | tr -d '\r')
        echo "[TECH_DISCLOSURE] $url → $server"
      fi

      echo "$response" | grep -qi '"message"\s*:\s*"Internal Server Error"' && \
        echo "[SERVER_ERROR] $url → Internal server error leaked in JSON"

      echo "$response" | grep -qi 'eyJ[a-zA-Z0-9_-]\{10,\}' && \
        echo "[JWT_EXPOSED] $url → JWT token visible in response"

    done < <(head -50 "$IN")  # Limit to first 50 to avoid timeout

  } > "$OUT"

  check_output "$OUT" "response analyzer"
  log success "Response anomaly analysis complete"
}
