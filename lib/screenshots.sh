#!/bin/bash
# ============================================================
# RECON Framework — lib/screenshots.sh
# Phase 12 — GoWitness Screenshots
# ============================================================

take_screenshots() {
  local IN="$WORKDIR/03_live_hosts/live.txt"
  local OUT="$WORKDIR/12_screenshots"
  local ERR_LOG="$OUT/screenshots_errors.log"

  : > "$ERR_LOG"

  if [ ! -s "$IN" ]; then
    log warn "No live hosts found. Skipping screenshots."
    return 0
  fi

  log info "Phase 12: Screenshot capture starting"

  if ! require_tool gowitness; then
    log error "gowitness not found. Skipping screenshots."
    return 1
  fi

  if gowitness scan \
    --file "$IN" \
    --screenshot-path "$OUT/" \
    --db-path "$OUT/gowitness.db" \
    --threads 10 \
    --timeout 10 \
    2>>"$ERR_LOG"; then
    :
  elif gowitness scan file \
    -f "$IN" \
    --screenshot-path "$OUT/" \
    --db-path "$OUT/gowitness.db" \
    --threads 10 \
    --timeout 10 \
    2>>"$ERR_LOG"; then
    log warn "gowitness v3 scan syntax failed; used scan file compatibility mode"
  elif gowitness file \
    -f "$IN" \
    --screenshot-path "$OUT/" \
    --db-path "$OUT/gowitness.db" \
    --threads 10 \
    --timeout 10 \
    2>>"$ERR_LOG"; then
    log warn "gowitness scan modes failed; used legacy file mode"
  else
    log error "gowitness failed with v3 and legacy syntax. See $ERR_LOG"
    return 1
  fi

  log info "Screenshots saved to $OUT/"
  log success "Screenshot capture phase complete"
}
