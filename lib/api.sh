#!/bin/bash
# ============================================================
# RECON Framework — lib/api.sh
# Phase 13 — API Endpoint Discovery (Kiterunner)
# ============================================================

api_discovery() {
  local IN="$WORKDIR/03_live_hosts/live.txt"
  local OUT="$WORKDIR/13_api"
  local ERR_LOG="$OUT/api_errors.log"

  : > "$ERR_LOG"

  if [ ! -s "$IN" ]; then
    log warn "No live hosts found. Skipping API discovery."
    return 0
  fi

  log info "Phase 13: API endpoint discovery starting"

  if ! require_tool kr; then
    log warn "Kiterunner (kr) not found. Skipping API discovery."
    return 0
  fi

  # kiterunner API route discovery (from methodology)
  log info "Running kiterunner route scan..."
  kr scan "$IN" \
    -A=apiroutes-260227:10000 \
    -x 8 -j 15 -v info \
    > "$OUT/kiterunner_routes.txt" 2>>"$ERR_LOG"
  check_output "$OUT/kiterunner_routes.txt" "kiterunner routes"

  log info "Running kiterunner parameter scan..."
  kr scan "$IN" \
    -A=parameters-260227:5000 \
    -x 5 -j 10 -v info \
    > "$OUT/kiterunner_params.txt" 2>>"$ERR_LOG"
  check_output "$OUT/kiterunner_params.txt" "kiterunner params"

  # Add to interesting endpoints
  if [ -s "$OUT/kiterunner_routes.txt" ]; then
    grep -oE "https?://[^ ]+" "$OUT/kiterunner_routes.txt" 2>>"$ERR_LOG" \
      | sort -u >> "$WORKDIR/05_urls/categorized/api_endpoints.txt"
    sort -u "$WORKDIR/05_urls/categorized/api_endpoints.txt" \
      -o "$WORKDIR/05_urls/categorized/api_endpoints.txt" 2>>"$ERR_LOG"
  fi

  log success "API endpoint discovery phase complete"
}
