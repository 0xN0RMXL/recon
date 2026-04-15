#!/bin/bash
# ============================================================
# RECON Framework — lib/screenshots.sh
# Phase 12 — GoWitness Screenshots
# ============================================================

take_screenshots() {
  local IN="$WORKDIR/03_live_hosts/live.txt"
  local OUT="$WORKDIR/12_screenshots"

  if [ ! -s "$IN" ]; then
    log warn "No live hosts found. Skipping screenshots."
    return 0
  fi

  log info "Phase 12: Screenshot capture starting"

  if ! require_tool gowitness; then
    log error "gowitness not found. Skipping screenshots."
    return 1
  fi

  gowitness scan file \
    -f "$IN" \
    --screenshot-path "$OUT/" \
    --db-path "$OUT/gowitness.db" \
    --threads 10 \
    --timeout 10 \
    2>/dev/null

  log info "Screenshots saved to $OUT/"
  log success "Screenshot capture phase complete"
}
