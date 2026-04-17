#!/bin/bash
# ============================================================
# RECON Framework — lib/github.sh
# Phase 14 — GitHub Dorking (GitDorker)
# ============================================================

github_dorking() {
  local OUT="$WORKDIR/14_github"
  local ERR_LOG="$OUT/github_errors.log"

  : > "$ERR_LOG"

  log info "Phase 14: GitHub dorking starting"

  if [ -z "$GITHUB_TOKEN" ]; then
    log warn "GitHub token not set. Skipping GitHub dorking."
    touch "$OUT/gitdorker_results.txt"
    return 0
  fi

  if [ ! -f "$HOME/tools/GitDorker/GitDorker.py" ]; then
    log warn "GitDorker not installed. Skipping."
    touch "$OUT/gitdorker_results.txt"
    return 0
  fi

  if [ ! -s "$DATA_DIR/dorks/github_dorks.txt" ]; then
    log warn "GitHub dorks file is missing or empty. Run install.sh to refresh data files."
    touch "$OUT/gitdorker_results.txt"
    return 0
  fi

  # Write token to temp file for GitDorker
  local token_file="/tmp/github_token_$$.txt"
  echo "$GITHUB_TOKEN" > "$token_file"

  # GitDorker (from methodology)
  log info "Running GitDorker..."
  python3 "$HOME/tools/GitDorker/GitDorker.py" \
    -tf "$token_file" \
    -q "$TARGET" \
    -d "$DATA_DIR/dorks/github_dorks.txt" \
    -o "$OUT/gitdorker_results.txt" \
    2>>"$ERR_LOG"

  rm -f "$token_file"
  check_output "$OUT/gitdorker_results.txt" "GitDorker"

  log info "GitHub dork results: $OUT/gitdorker_results.txt"
  log success "GitHub dorking phase complete"
}
