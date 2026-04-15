#!/bin/bash
# ============================================================
# RECON Framework — lib/probe.sh
# Phase 03 — Live Host Detection + Tech Fingerprinting
# ============================================================

probe_hosts() {
  local IN="$WORKDIR/01_subdomains/all_subdomains.txt"
  local OUT="$WORKDIR/03_live_hosts"

  if [ ! -s "$IN" ]; then
    log warn "No subdomains found. Skipping probe."
    return 0
  fi

  log info "Phase 03: Live host probing starting"

  if ! require_tool httpx; then
    log error "httpx is required for probing. Skipping."
    return 1
  fi

  local PROXY_ARGS=""
  if [ "$BURP_ENABLED" = "true" ]; then
    PROXY_ARGS="-http-proxy $BURP_PROXY"
  fi

  # Full httpx probe with tech detection
  log info "Running httpx with tech detection..."
  httpx -l "$IN" \
    -title -tech-detect -status-code -content-length \
    -web-server -follow-redirects \
    -threads "$HTTPX_THREADS" \
    $PROXY_ARGS \
    -o "$OUT/live_detailed.txt" \
    -silent 2>/dev/null

  # Extract plain URL list
  if [ -s "$OUT/live_detailed.txt" ]; then
    grep -oE "https?://[^ ]+" "$OUT/live_detailed.txt" > "$OUT/live.txt"
    sort -u "$OUT/live.txt" -o "$OUT/live.txt"
  fi

  local count
  count=$(wc -l < "$OUT/live.txt" 2>/dev/null | tr -d ' ')
  log success "Live hosts: ${count:-0}"

  # Send to Burp Pro scanner if enabled
  if [ "$BURP_AUTO_SCAN" = "true" ] && [ -s "$OUT/live.txt" ]; then
    burp_send_to_scanner "$OUT/live.txt"
  fi
}
