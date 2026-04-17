#!/bin/bash
# ============================================================
# RECON Framework — lib/hypothesis.sh
# Intelligence: Vulnerability Hypothesis Generation
# ============================================================

generate_hypotheses() {
  local IN="$WORKDIR/05_urls/all_urls.txt"
  local OUT="$WORKDIR/intelligence/hypotheses.txt"
  local ERR_LOG="$WORKDIR/intelligence/hypothesis_errors.log"
  local max_per_pattern="${HYPOTHESIS_MAX_PER_PATTERN:-20}"
  local medium_limit
  local small_limit

  : > "$ERR_LOG"

  [[ "$max_per_pattern" =~ ^[0-9]+$ ]] || max_per_pattern=20
  [ "$max_per_pattern" -lt 1 ] && max_per_pattern=20

  medium_limit=$((max_per_pattern / 2))
  [ "$medium_limit" -lt 1 ] && medium_limit=1

  small_limit=$((max_per_pattern / 4))
  [ "$small_limit" -lt 1 ] && small_limit=1

  if [ ! -s "$IN" ]; then
    log warn "No URLs found. Skipping hypothesis generation."
    touch "$OUT"
    return 0
  fi

  log info "Intelligence: Vulnerability hypothesis generation starting"

  emit_pattern_sample() {
    local pattern="$1"
    local limit="$2"
    local label="$3"
    local tmp_file="/tmp/recon_hypothesis_${label}_$$.txt"

    grep -iE "$pattern" "$IN" 2>>"$ERR_LOG" > "$tmp_file" || true

    local total
    total=$(wc -l < "$tmp_file" 2>>"$ERR_LOG" | tr -d ' ')
    total="${total:-0}"

    if [ "$limit" -gt 0 ] && [ "$total" -gt "$limit" ]; then
      log warn "Hypothesis sampling for $label URLs: $limit/$total"
      head -n "$limit" "$tmp_file"
    else
      cat "$tmp_file"
    fi

    rm -f "$tmp_file"
  }

  {
    echo "# Vulnerability Hypotheses for $TARGET"
    echo "# Generated: $(date)"
    echo "# ─────────────────────────────────────────────"

    emit_pattern_sample "/api/|/v[0-9]+/" "$max_per_pattern" "api" | while IFS= read -r url; do
      echo "[$url]"
      echo "  → TEST: IDOR / BOLA (change numeric/UUID ID values)"
      echo "  → TEST: Mass assignment (add extra JSON fields)"
      echo "  → TEST: HTTP method switching (GET→PUT→DELETE)"
      echo ""
    done

    emit_pattern_sample "upload|file" "$medium_limit" "upload" | while IFS= read -r url; do
      echo "[$url]"
      echo "  → TEST: File upload bypass (change Content-Type, extension)"
      echo "  → TEST: Path traversal in filename parameter"
      echo "  → TEST: Remote code execution via webshell upload"
      echo ""
    done

    emit_pattern_sample "redirect|return|goto|url=|r=|u=|dest=" "$medium_limit" "redirect" | while IFS= read -r url; do
      echo "[$url]"
      echo "  → TEST: Open redirect (replace with attacker.com)"
      echo "  → TEST: SSRF (replace with internal IPs: 169.254.169.254, 127.0.0.1)"
      echo ""
    done

    emit_pattern_sample "graphql" "$small_limit" "graphql" | while IFS= read -r url; do
      echo "[$url]"
      echo "  → TEST: Introspection enabled (query __schema)"
      echo "  → TEST: BOLA via GraphQL (change user IDs)"
      echo "  → TEST: Query depth attack"
      echo ""
    done

    emit_pattern_sample "admin|dashboard|manage" "$medium_limit" "admin" | while IFS= read -r url; do
      echo "[$url]"
      echo "  → TEST: Auth bypass (remove Authorization header)"
      echo "  → TEST: Privilege escalation (change role parameter)"
      echo "  → TEST: Default credentials"
      echo ""
    done

    emit_pattern_sample "login|signin|auth|oauth" "$medium_limit" "auth" | while IFS= read -r url; do
      echo "[$url]"
      echo "  → TEST: Brute force / credential stuffing"
      echo "  → TEST: OAuth token leakage / misconfiguration"
      echo "  → TEST: Account takeover via password reset"
      echo ""
    done

    emit_pattern_sample "reset|forgot|password" "$small_limit" "password" | while IFS= read -r url; do
      echo "[$url]"
      echo "  → TEST: Host header injection in password reset"
      echo "  → TEST: Token reuse / weak token entropy"
      echo ""
    done

    if [ -s "$WORKDIR/07_js/extracted_secrets.txt" ]; then
      echo "[JS SECRETS DETECTED]"
      echo "  → REVIEW: $WORKDIR/07_js/extracted_secrets.txt"
      echo "  → TEST: Use leaked tokens/keys directly against API"
      echo ""
    fi

    if [ -s "$WORKDIR/09_vulns/takeovers_nuclei.txt" ]; then
      echo "[SUBDOMAIN TAKEOVER CANDIDATES DETECTED]"
      echo "  → VERIFY: $WORKDIR/09_vulns/takeovers_nuclei.txt"
      echo ""
    fi

  } > "$OUT"

  log info "Hypotheses written to $OUT"
  log success "Vulnerability hypothesis generation complete"
}
