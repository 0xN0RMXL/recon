#!/bin/bash
# ============================================================
# RECON Framework — lib/diff.sh
# Intelligence: Differential Recon (New Asset Detection)
# ============================================================

diff_assets() {
  local PREV="$WORKDIR/meta/previous_subdomains.txt"
  local CUR="$WORKDIR/01_subdomains/all_subdomains.txt"
  local OUT="$WORKDIR/intelligence/diff_new_assets.txt"

  log info "Intelligence: Differential asset analysis starting"

  if [ -f "$PREV" ]; then
    comm -13 <(sort "$PREV") <(sort "$CUR") > "$OUT" 2>/dev/null
    local NEW_COUNT
    NEW_COUNT=$(wc -l < "$OUT" 2>/dev/null | tr -d ' ')
    if [ "${NEW_COUNT:-0}" -gt 0 ]; then
      log warn "NEW ASSETS DETECTED: $NEW_COUNT new subdomains since last run!"
      notify "🆕 $NEW_COUNT new subdomains found for $TARGET"
    else
      log info "No new assets detected since last run."
    fi
  else
    log info "No previous run found. Diff will be available on next run."
    touch "$OUT"
  fi

  # Save current as previous for next run
  cp "$CUR" "$PREV" 2>/dev/null

  log success "Differential asset analysis complete"
}
