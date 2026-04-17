#!/bin/bash
# ============================================================
# RECON Framework — lib/vulns.sh
# Phase 09 — Nuclei Smart Scan + Subdomain Takeover + XSS + SQLi
# ============================================================

nuclei_scan() {
  local IN="$WORKDIR/03_live_hosts/live.txt"
  local OUT="$WORKDIR/09_vulns"
  local ERR_LOG="$OUT/vulns_errors.log"
  local SCAN_INPUT="$IN"
  local tmp_scan_input=""
  local background_pids=()

  : > "$ERR_LOG"

  if [ ! -s "$IN" ]; then
    log warn "No live hosts found. Skipping vulnerability scanning."
    return 0
  fi

  log info "Phase 09: Vulnerability scanning starting"

  local total_hosts sampled_hosts
  total_hosts=$(wc -l < "$IN" 2>>"$ERR_LOG" | tr -d ' ')
  total_hosts="${total_hosts:-0}"

  if [ "${VULNS_MAX_HOSTS:-0}" -gt 0 ] && [ "$total_hosts" -gt "${VULNS_MAX_HOSTS:-0}" ]; then
    tmp_scan_input="/tmp/recon_vuln_hosts_$$.txt"
    head -n "$VULNS_MAX_HOSTS" "$IN" > "$tmp_scan_input"
    SCAN_INPUT="$tmp_scan_input"
    sampled_hosts=$(wc -l < "$SCAN_INPUT" 2>>"$ERR_LOG" | tr -d ' ')
    log warn "Vuln scan sampling enabled: $sampled_hosts/$total_hosts live hosts"
  fi

  # ── SMART NUCLEI SELECTION ────────────────────────────────
  if ! require_tool nuclei; then
    [ -n "$tmp_scan_input" ] && rm -f "$tmp_scan_input"
    log error "nuclei is required for vulnerability scanning"
    return 1
  fi

  local NUCLEI_TAGS="misconfig,exposure,cve"

  # WordPress detected?
  grep -qi "wordpress" "$WORKDIR/03_live_hosts/live_detailed.txt" 2>>"$ERR_LOG" && \
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
  grep -q "graphql" "$WORKDIR/05_urls/all_urls.txt" 2>>"$ERR_LOG" && \
    NUCLEI_TAGS="$NUCLEI_TAGS,graphql"

  log info "Nuclei tags selected: $NUCLEI_TAGS"

  # Run nuclei with smart tags
  log info "Running nuclei scan..."
  if ! nuclei -l "$SCAN_INPUT" \
    -tags "$NUCLEI_TAGS" \
    -severity "info,low,medium,high,critical" \
    -rate-limit "$NUCLEI_RATE" \
    -bulk-size 50 \
    -concurrency 25 \
    -jsonl -o "$OUT/nuclei_all.json" \
    -silent 2>>"$ERR_LOG"; then
    [ -n "$tmp_scan_input" ] && rm -f "$tmp_scan_input"
    log error "nuclei execution failed. See $ERR_LOG"
    return 1
  fi

  if [ -s "$OUT/nuclei_all.json" ]; then
    jq -r '.matched_at + " [" + .info.severity + "] " + .info.name' \
      "$OUT/nuclei_all.json" 2>>"$ERR_LOG" > "$OUT/nuclei_all.txt"
  else
    : > "$OUT/nuclei_all.txt"
  fi

  # Split by severity
  for sev in critical high medium low info; do
    grep "\"severity\":\"$sev\"" "$OUT/nuclei_all.json" 2>>"$ERR_LOG" \
      > "$OUT/nuclei_${sev}.json"
    jq -r '.matched_at + " [" + .info.severity + "] " + .info.name' \
      "$OUT/nuclei_${sev}.json" 2>>"$ERR_LOG" \
      > "$OUT/nuclei_${sev}.txt"
  done

  # Notify on critical findings
  if [ -s "$OUT/nuclei_critical.txt" ]; then
    local crit_count
    crit_count=$(wc -l < "$OUT/nuclei_critical.txt" | tr -d ' ')
    notify "🚨 $crit_count CRITICAL nuclei findings on $TARGET!"
  fi

  # ── SUBDOMAIN TAKEOVER ────────────────────────────────────
  log info "Checking for subdomain takeovers..."

  # nuclei takeover templates
  if require_tool nuclei && [ -s "$WORKDIR/01_subdomains/all_subdomains.txt" ]; then
    nuclei -l "$WORKDIR/01_subdomains/all_subdomains.txt" \
      -t "$HOME/nuclei-templates/http/takeovers/" \
      -o "$OUT/takeovers_nuclei.txt" \
      -silent 2>>"$ERR_LOG"
    check_output "$OUT/takeovers_nuclei.txt" "nuclei takeover"
  fi

  # subjack
  if require_tool subjack && [ -s "$WORKDIR/01_subdomains/all_subdomains.txt" ]; then
    log info "Running subjack..."
    subjack -w "$WORKDIR/01_subdomains/all_subdomains.txt" \
      -t 100 -timeout 30 \
      -o "$OUT/takeovers_subjack.txt" \
      -ssl 2>>"$ERR_LOG"
    check_output "$OUT/takeovers_subjack.txt" "subjack"
  fi

  # ── DALFOX XSS SCAN ──────────────────────────────────────
  if require_tool dalfox && [ -s "$WORKDIR/05_urls/categorized/param_urls.txt" ]; then
    log info "Running dalfox XSS scan..."
    cat "$WORKDIR/05_urls/categorized/param_urls.txt" | \
      timeout 900 dalfox pipe \
        --skip-bav \
        --no-spinner \
        -o "$OUT/dalfox_xss.txt" 2>>"$ERR_LOG" &
    background_pids+=("$!")
  fi

  # ── SQLMAP on parameter URLs ──────────────────────────────
  if [ -f "$HOME/tools/sqlmap/sqlmap.py" ] && [ -s "$WORKDIR/05_urls/categorized/php_urls.txt" ]; then
    log info "Running sqlmap on parameter URLs..."
    mkdir -p "$OUT/sqlmap"

    local sqlmap_targets_file="/tmp/recon_sqlmap_targets_$$.txt"
    grep '=' "$WORKDIR/05_urls/categorized/php_urls.txt" 2>>"$ERR_LOG" \
      | head -n "${SQLMAP_MAX_TARGETS:-20}" > "$sqlmap_targets_file"

    local max_sqlmap_jobs
    max_sqlmap_jobs="${SQLMAP_MAX_CONCURRENT:-4}"

    while IFS= read -r url; do
      [ -z "$url" ] && continue

      while [ "$(jobs -pr | wc -l | tr -d ' ')" -ge "$max_sqlmap_jobs" ]; do
        sleep 1
      done

      python3 "$HOME/tools/sqlmap/sqlmap.py" \
        -u "$url" \
        --dbs --banner --batch --random-agent \
        --output-dir="$OUT/sqlmap/" \
        -q 2>>"$ERR_LOG" &
      background_pids+=("$!")
    done < "$sqlmap_targets_file"

    rm -f "$sqlmap_targets_file"
  fi

  # Wait for background jobs
  if [ "${#background_pids[@]}" -gt 0 ]; then
    log info "Waiting for background vulnerability jobs to finish..."
    local pid
    for pid in "${background_pids[@]}"; do
      wait "$pid" 2>>"$ERR_LOG" || true
    done
  fi

  # Ensure output files exist
  touch "$OUT/nuclei_all.txt" "$OUT/nuclei_critical.txt" "$OUT/nuclei_high.txt"
  touch "$OUT/nuclei_medium.txt" "$OUT/nuclei_low.txt" "$OUT/nuclei_info.txt"
  touch "$OUT/takeovers_nuclei.txt" "$OUT/takeovers_subjack.txt" "$OUT/dalfox_xss.txt"

  [ -n "$tmp_scan_input" ] && rm -f "$tmp_scan_input"

  log success "Vulnerability scanning phase complete"
}
