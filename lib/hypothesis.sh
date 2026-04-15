#!/bin/bash
# ============================================================
# RECON Framework — lib/hypothesis.sh
# Intelligence: Vulnerability Hypothesis Generation
# ============================================================

generate_hypotheses() {
  local IN="$WORKDIR/05_urls/all_urls.txt"
  local OUT="$WORKDIR/intelligence/hypotheses.txt"

  if [ ! -s "$IN" ]; then
    log warn "No URLs found. Skipping hypothesis generation."
    touch "$OUT"
    return 0
  fi

  log info "Intelligence: Vulnerability hypothesis generation starting"

  {
    echo "# Vulnerability Hypotheses for $TARGET"
    echo "# Generated: $(date)"
    echo "# ─────────────────────────────────────────────"

    grep -iE "/api/|/v[0-9]+/" "$IN" 2>/dev/null | head -20 | while IFS= read -r url; do
      echo "[$url]"
      echo "  → TEST: IDOR / BOLA (change numeric/UUID ID values)"
      echo "  → TEST: Mass assignment (add extra JSON fields)"
      echo "  → TEST: HTTP method switching (GET→PUT→DELETE)"
      echo ""
    done

    grep -iE "upload|file" "$IN" 2>/dev/null | head -10 | while IFS= read -r url; do
      echo "[$url]"
      echo "  → TEST: File upload bypass (change Content-Type, extension)"
      echo "  → TEST: Path traversal in filename parameter"
      echo "  → TEST: Remote code execution via webshell upload"
      echo ""
    done

    grep -iE "redirect|return|goto|url=|r=|u=|dest=" "$IN" 2>/dev/null | head -10 | while IFS= read -r url; do
      echo "[$url]"
      echo "  → TEST: Open redirect (replace with attacker.com)"
      echo "  → TEST: SSRF (replace with internal IPs: 169.254.169.254, 127.0.0.1)"
      echo ""
    done

    grep -iE "graphql" "$IN" 2>/dev/null | head -5 | while IFS= read -r url; do
      echo "[$url]"
      echo "  → TEST: Introspection enabled (query __schema)"
      echo "  → TEST: BOLA via GraphQL (change user IDs)"
      echo "  → TEST: Query depth attack"
      echo ""
    done

    grep -iE "admin|dashboard|manage" "$IN" 2>/dev/null | head -10 | while IFS= read -r url; do
      echo "[$url]"
      echo "  → TEST: Auth bypass (remove Authorization header)"
      echo "  → TEST: Privilege escalation (change role parameter)"
      echo "  → TEST: Default credentials"
      echo ""
    done

    grep -iE "login|signin|auth|oauth" "$IN" 2>/dev/null | head -10 | while IFS= read -r url; do
      echo "[$url]"
      echo "  → TEST: Brute force / credential stuffing"
      echo "  → TEST: OAuth token leakage / misconfiguration"
      echo "  → TEST: Account takeover via password reset"
      echo ""
    done

    grep -iE "reset|forgot|password" "$IN" 2>/dev/null | head -5 | while IFS= read -r url; do
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
