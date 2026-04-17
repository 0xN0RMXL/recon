#!/bin/bash
# ============================================================
# RECON Framework — lib/origins.sh
# Phase 15 — Origin IP Hunting
# ============================================================

origin_ip_hunt() {
  local OUT="$WORKDIR/15_origins"
  local ERR_LOG="$OUT/origins_errors.log"

  : > "$ERR_LOG"

  log info "Phase 15: Origin IP hunting starting"

  touch "$OUT/origin_ips.txt"

  if ! require_tool originiphunter; then
    log warn "originiphunter not found. Skipping."
    return 0
  fi

  if [ ! -s "$WORKDIR/01_subdomains/all_subdomains.txt" ]; then
    log warn "No subdomains found. Skipping origin IP hunting."
    return 0
  fi

  log info "Running originiphunter..."
  cat "$WORKDIR/01_subdomains/all_subdomains.txt" | \
    originiphunter > "$OUT/origin_ips.txt" 2>>"$ERR_LOG"

  check_output "$OUT/origin_ips.txt" "originiphunter"
  log info "Origin IPs: $(wc -l < "$OUT/origin_ips.txt" 2>>"$ERR_LOG" | tr -d ' ')"
  log success "Origin IP hunting phase complete"
}
