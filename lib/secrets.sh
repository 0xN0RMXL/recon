#!/bin/bash
# ============================================================
# RECON Framework — lib/secrets.sh
# Phase 11 — TruffleHog + GitLeaks + Regex Scanning
# ============================================================

secret_scan() {
  local OUT="$WORKDIR/11_secrets"
  local ERR_LOG="$OUT/secrets_errors.log"

  : > "$ERR_LOG"

  log info "Phase 11: Secret scanning starting"

  # trufflehog on filesystem (JS content dump)
  if require_tool trufflehog && [ -d "$WORKDIR/07_js/" ]; then
    log info "Running trufflehog..."
    trufflehog filesystem "$WORKDIR/07_js/" \
      --json \
      > "$OUT/trufflehog.json" 2>>"$ERR_LOG"
    check_output "$OUT/trufflehog.json" "trufflehog"
  fi

  # gitleaks on output directory
  if require_tool gitleaks; then
    log info "Running gitleaks..."
    gitleaks detect \
      --source="$WORKDIR" \
      --report-format=json \
      --report-path="$OUT/gitleaks.json" \
      -q 2>>"$ERR_LOG"
    check_output "$OUT/gitleaks.json" "gitleaks"
  fi

  # Regex secrets scan (from methodology)
  touch "$OUT/regex_secrets.txt"
  if [ -s "$WORKDIR/07_js/js_content_dump.txt" ]; then
    log info "Running regex secret scan..."
    grep -rE \
      "(AKIA[0-9A-Z]{16}|api[_-]?key[\s]*=[\s]*['\"][a-zA-Z0-9_-]{10,}['\"]|token[\s]*=[\s]*['\"][a-zA-Z0-9_-]{20,}['\"]|secret[\s]*=[\s]*['\"][a-zA-Z0-9_-]{8,}['\"]|password[\s]*=[\s]*['\"][^'\"]{6,}['\"]|-----BEGIN (RSA|EC|DSA|OPENSSH) PRIVATE KEY-----)" \
      "$WORKDIR/07_js/js_content_dump.txt" \
      2>>"$ERR_LOG" > "$OUT/regex_secrets.txt"
  fi

  log info "Secrets found: $(wc -l < "$OUT/regex_secrets.txt" 2>>"$ERR_LOG" | tr -d ' ')"
  log success "Secret scanning phase complete"
}
