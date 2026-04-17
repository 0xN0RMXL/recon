#!/bin/bash
# ============================================================
# RECON Framework — lib/chaining.sh
# Intelligence: Bug Chain Detection
# ============================================================

chain_analysis() {
  local OUT="$WORKDIR/intelligence/bug_chains.txt"
  local ERR_LOG="$WORKDIR/intelligence/chaining_errors.log"

  : > "$ERR_LOG"

  log info "Intelligence: Bug chain analysis starting"

  {
    echo "# Bug Chain Analysis for $TARGET"
    echo "# Generated: $(date)"

    # Chain 1: JS token + API endpoint → ATO
    if [ -s "$WORKDIR/07_js/extracted_secrets.txt" ] && \
       [ -s "$WORKDIR/05_urls/categorized/api_endpoints.txt" ]; then
      echo ""
      echo "[CHAIN] API token leaked in JS + API endpoint → Potential Account Takeover"
      echo "  Step 1: Extract token from $WORKDIR/07_js/extracted_secrets.txt"
      echo "  Step 2: Use token against API endpoints in $WORKDIR/05_urls/categorized/api_endpoints.txt"
    fi

    # Chain 2: Upload + Admin → RCE/Privilege escalation
    if [ -s "$WORKDIR/05_urls/categorized/upload_endpoints.txt" ] && \
       [ -s "$WORKDIR/05_urls/categorized/admin_panels.txt" ]; then
      echo ""
      echo "[CHAIN] Upload endpoint + Admin panel → Possible RCE or Privilege Escalation"
      echo "  Step 1: Upload webshell via $WORKDIR/05_urls/categorized/upload_endpoints.txt"
      echo "  Step 2: Access shell via admin context"
    fi

    # Chain 3: Open redirect + OAuth → Token hijack
    if grep -q "redirect\|goto\|return" "$WORKDIR/05_urls/categorized/interesting_endpoints.txt" 2>>"$ERR_LOG" && \
       grep -q "oauth\|auth" "$WORKDIR/05_urls/categorized/login_flows.txt" 2>>"$ERR_LOG"; then
      echo ""
      echo "[CHAIN] Open redirect + OAuth → OAuth token hijacking"
      echo "  Step 1: Confirm open redirect at interesting endpoints"
      echo "  Step 2: Craft OAuth redirect_uri pointing to redirect"
    fi

    # Chain 4: SSRF + Cloud metadata
    if grep -q "url=\|r=\|u=\|dest=" "$WORKDIR/05_urls/categorized/interesting_endpoints.txt" 2>>"$ERR_LOG" && \
       [ -s "$WORKDIR/10_cloud/buckets.txt" ]; then
      echo ""
      echo "[CHAIN] SSRF candidate + Cloud environment → AWS metadata exfiltration"
      echo "  Step 1: Test SSRF at $WORKDIR/05_urls/categorized/interesting_endpoints.txt"
      echo "  Step 2: Point to http://169.254.169.254/latest/meta-data/"
    fi

    # Chain 5: Subdomain takeover + Cookie scope → Session hijack
    if [ -s "$WORKDIR/09_vulns/takeovers_nuclei.txt" ]; then
      echo ""
      echo "[CHAIN] Subdomain takeover → Cookie scope hijacking"
      echo "  Step 1: Claim the subdomain"
      echo "  Step 2: Serve page that reads cookies set on parent domain"
    fi

  } > "$OUT"

  check_output "$OUT" "chain analysis"
  log success "Bug chain analysis complete"
}
