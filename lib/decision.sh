#!/bin/bash
# ============================================================
# RECON Framework — lib/decision.sh
# Intelligence: Priority Decision Engine
# ============================================================

decision_engine() {
  local OUT="$WORKDIR/intelligence/decision_report.txt"

  log info "Intelligence: Priority decision engine starting"

  {
    echo "# Priority Decision Report for $TARGET"
    echo "# Generated: $(date)"
    echo "# ─────────────────────────────────────────────"

    [ -s "$WORKDIR/05_urls/categorized/api_endpoints.txt" ] && \
      echo "[CRITICAL PRIORITY] API endpoints found → Focus on IDOR, BOLA, Mass Assignment"

    [ -s "$WORKDIR/05_urls/categorized/upload_endpoints.txt" ] && \
      echo "[HIGH PRIORITY] Upload endpoints found → Test file upload bypass, RCE"

    [ -s "$WORKDIR/05_urls/categorized/admin_panels.txt" ] && \
      echo "[HIGH PRIORITY] Admin panels found → Test auth bypass, default credentials"

    grep -q "graphql" "$WORKDIR/05_urls/all_urls.txt" 2>/dev/null && \
      echo "[HIGH PRIORITY] GraphQL detected → Test introspection, depth attacks"

    [ -s "$WORKDIR/07_js/extracted_secrets.txt" ] && \
      echo "[CRITICAL PRIORITY] Secrets in JS → Immediately test leaked credentials"

    [ -s "$WORKDIR/09_vulns/takeovers_nuclei.txt" ] && \
      echo "[CRITICAL PRIORITY] Subdomain takeover candidates → Verify and claim"

    [ -s "$WORKDIR/09_vulns/nuclei_critical.txt" ] && \
      echo "[CRITICAL PRIORITY] Critical nuclei findings → Verify immediately"

    [ -s "$WORKDIR/09_vulns/nuclei_high.txt" ] && \
      echo "[HIGH PRIORITY] High nuclei findings → Verify and exploit"

    [ -s "$WORKDIR/10_cloud/accessible_buckets.txt" ] && \
      echo "[HIGH PRIORITY] Accessible cloud storage → Check for sensitive data"

    [ -s "$WORKDIR/05_urls/categorized/login_flows.txt" ] && \
      echo "[MEDIUM PRIORITY] Login flows found → Test OAuth, password reset, brute force"

    [ -s "$WORKDIR/05_urls/categorized/idor_candidates.txt" ] && \
      echo "[MEDIUM PRIORITY] IDOR candidates (numeric IDs in URLs) → Test parameter manipulation"

  } > "$OUT"

  cat "$OUT"  # Also print to terminal
  log success "Priority decision report generated"
}
