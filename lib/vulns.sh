#!/bin/bash
# ============================================================
# RECON Framework — lib/vulns.sh
# Phase 09 — Nuclei Smart Scan + Subdomain Takeover + XSS + SQLi
# ============================================================

nuclei_scan() {
  local IN="$WORKDIR/03_live_hosts/live.txt"
  local OUT="$WORKDIR/09_vulns"
  local background_pids=()

  if [ ! -s "$IN" ]; then
    log warn "No live hosts found. Skipping vulnerability scanning."
    return 0
  fi

  log info "Phase 09: Vulnerability scanning starting"

  # ── SMART NUCLEI SELECTION ────────────────────────────────
  if require_tool nuclei; then
    local NUCLEI_TAGS="misconfig,exposure,cve"

    # WordPress detected?
    grep -qi "wordpress" "$WORKDIR/03_live_hosts/live_detailed.txt" 2>/dev/null && \
      NUCLEI_TAGS="$NUCLEI_TAGS,wordpress"

    # API endpoints found?
    [ -s "$WORKDIR/05_urls/categorized/api_endpoints.txt" ] && \
      NUCLEI_TAGS="$NUCLEI_TAGS,api"

    # Auth/login endpoints?
    [ -s "$WORKDIR/05_urls/categorized/login_flows.txt" ] && \
      NUCLEI_TAGS="$NUCLEI_TAGS,auth,default-login"

    # Upload endpoints?
    [ -s "$WORKDIR/05_urls/categorized/upload_endpoints.txt" ] && \
      NUCLEI_TAGS="$NUCLEI_TAGS,file-upload,rce"

    # GraphQL?
    grep -q "graphql" "$WORKDIR/05_urls/all_urls.txt" 2>/dev/null && \
      NUCLEI_TAGS="$NUCLEI_TAGS,graphql"

    log info "Nuclei tags selected: $NUCLEI_TAGS"

    # Run nuclei with smart tags
    log info "Running nuclei scan..."
    nuclei -l "$IN" \
      -tags "$NUCLEI_TAGS" \
      -severity "info,low,medium,high,critical" \
      -rate-limit "$NUCLEI_RATE" \
      -bulk-size 50 \
      -concurrency 25 \
      -o "$OUT/nuclei_all.txt" \
      -jsonl -output "$OUT/nuclei_all.json" \
      -silent 2>/dev/null

    # Split by severity
    for sev in critical high medium low info; do
      grep "\"severity\":\"$sev\"" "$OUT/nuclei_all.json" 2>/dev/null \
        > "$OUT/nuclei_${sev}.json"
      jq -r '.matched_at + " [" + .info.severity + "] " + .info.name' \
        "$OUT/nuclei_${sev}.json" 2>/dev/null \
        > "$OUT/nuclei_${sev}.txt"
    done

    # Notify on critical findings
    if [ -s "$OUT/nuclei_critical.txt" ]; then
      local crit_count
      crit_count=$(wc -l < "$OUT/nuclei_critical.txt" | tr -d ' ')
      notify "🚨 $crit_count CRITICAL nuclei findings on $TARGET!"
    fi
  fi

  # ── SUBDOMAIN TAKEOVER ────────────────────────────────────
  log info "Checking for subdomain takeovers..."

  # nuclei takeover templates
  if require_tool nuclei && [ -s "$WORKDIR/01_subdomains/all_subdomains.txt" ]; then
    nuclei -l "$WORKDIR/01_subdomains/all_subdomains.txt" \
      -t "$HOME/nuclei-templates/http/takeovers/" \
      -o "$OUT/takeovers_nuclei.txt" \
      -silent 2>/dev/null
    check_output "$OUT/takeovers_nuclei.txt" "nuclei takeover"
  fi

  # subjack
  if require_tool subjack && [ -s "$WORKDIR/01_subdomains/all_subdomains.txt" ]; then
    log info "Running subjack..."
    subjack -w "$WORKDIR/01_subdomains/all_subdomains.txt" \
      -t 100 -timeout 30 \
      -o "$OUT/takeovers_subjack.txt" \
      -ssl 2>/dev/null
    check_output "$OUT/takeovers_subjack.txt" "subjack"
  fi

  # ── DALFOX XSS SCAN ──────────────────────────────────────
  if require_tool dalfox && [ -s "$WORKDIR/05_urls/categorized/param_urls.txt" ]; then
    log info "Running dalfox XSS scan..."
    cat "$WORKDIR/05_urls/categorized/param_urls.txt" | \
      dalfox pipe \
      --skip-bav \
      --no-spinner \
      -o "$OUT/dalfox_xss.txt" 2>/dev/null &
    background_pids+=("$!")
  fi

  # ── SQLMAP on parameter URLs ──────────────────────────────
  if [ -f "$HOME/tools/sqlmap/sqlmap.py" ] && [ -s "$WORKDIR/05_urls/categorized/php_urls.txt" ]; then
    log info "Running sqlmap on parameter URLs..."
    mkdir -p "$OUT/sqlmap"
    while IFS= read -r url; do
      python3 "$HOME/tools/sqlmap/sqlmap.py" \
        -u "$url" \
        --dbs --banner --batch --random-agent \
        --output-dir="$OUT/sqlmap/" \
        -q 2>/dev/null &
      background_pids+=("$!")
    done < <(grep '=' "$WORKDIR/05_urls/categorized/php_urls.txt" 2>/dev/null | head -20)
  fi

  # Wait for background jobs
  if [ "${#background_pids[@]}" -gt 0 ]; then
    log info "Waiting for background vulnerability jobs to finish..."
    local pid
    for pid in "${background_pids[@]}"; do
      wait "$pid" 2>/dev/null || true
    done
  fi

  # Ensure output files exist
  touch "$OUT/nuclei_all.txt" "$OUT/nuclei_critical.txt" "$OUT/nuclei_high.txt"
  touch "$OUT/nuclei_medium.txt" "$OUT/nuclei_low.txt" "$OUT/nuclei_info.txt"
  touch "$OUT/takeovers_nuclei.txt" "$OUT/takeovers_subjack.txt" "$OUT/dalfox_xss.txt"

  log success "Vulnerability scanning phase complete"
}
