#!/bin/bash
# ============================================================
# RECON Framework — lib/burp.sh
# Burp Suite Community proxy + Pro API automation
# ============================================================

# ─── COMMUNITY: PROXY ROUTING ───────────────────────────────
# Used by probe.sh, content.sh — they check BURP_ENABLED and append proxy flags

burp_proxy_arg() {
  # Returns proxy argument string for curl-based tools
  [ "$BURP_ENABLED" = "true" ] && echo "-x $BURP_PROXY" || echo ""
}

burp_httpx_arg() {
  [ "$BURP_ENABLED" = "true" ] && echo "-http-proxy $BURP_PROXY" || echo ""
}

burp_ffuf_arg() {
  [ "$BURP_ENABLED" = "true" ] && echo "-x $BURP_PROXY" || echo ""
}

# ─── PRO: SEND URLS TO ACTIVE SCANNER ───────────────────────
burp_send_to_scanner() {
  local url_file="$1"

  [ -z "$BURP_API_KEY" ] && return 0
  [ "$BURP_AUTO_SCAN" != "true" ] && return 0

  while IFS= read -r url; do
    curl -sk -X POST "${BURP_API_URL}/v0.1/scan" \
      -H "Authorization: Bearer $BURP_API_KEY" \
      -H "Content-Type: application/json" \
      -d "{
        \"urls\": [\"$url\"],
        \"scan_configurations\": [{\"name\": \"Crawl strategy - fastest\"}]
      }" > /dev/null 2>&1
    log info "Sent to Burp scanner: $url"
  done < "$url_file"
}

# ─── PRO: SEND INTERESTING ENDPOINTS ────────────────────────
burp_send_interesting() {
  [ -z "$BURP_API_KEY" ] && return 0
  [ "$BURP_SEND_INTERESTING" != "true" ] && return 0

  local interesting_files=(
    "$WORKDIR/05_urls/categorized/admin_panels.txt"
    "$WORKDIR/05_urls/categorized/api_endpoints.txt"
    "$WORKDIR/05_urls/categorized/upload_endpoints.txt"
    "$WORKDIR/05_urls/categorized/login_flows.txt"
  )

  for f in "${interesting_files[@]}"; do
    [ -f "$f" ] && burp_send_to_scanner "$f"
  done
}

# ─── EXPORT: BURP SUITE XML FORMAT ──────────────────────────
burp_export_xml() {
  local OUT="$WORKDIR/reports/burp_export.xml"
  local live_file="$WORKDIR/03_live_hosts/live.txt"

  if [ ! -s "$live_file" ]; then
    log warn "No live hosts found. Skipping Burp XML export."
    return 0
  fi

  {
    echo '<?xml version="1.0" ?>'
    echo '<!DOCTYPE items ['
    echo '<!ELEMENT items (item*)>'
    echo '<!ELEMENT item (url, host, port, protocol, path, method, request, response)>'
    echo ']>'
    echo '<items burpVersion="2.0" exportTime="'"$(date)"'">'

    while IFS= read -r url; do
      local host proto port path
      host=$(echo "$url" | grep -oE "(https?://[^/]+)" | sed 's|https\?://||')
      proto=$(echo "$url" | grep -oE "https?")
      port=$([ "$proto" = "https" ] && echo "443" || echo "80")
      path=$(echo "$url" | grep -oE "(/[^ ]*)" || echo "/")

      echo "<item>"
      echo "  <url>$url</url>"
      echo "  <host>$host</host>"
      echo "  <port>$port</port>"
      echo "  <protocol>$proto</protocol>"
      echo "  <path>$path</path>"
      echo "  <method>GET</method>"
      echo "  <request></request>"
      echo "  <response></response>"
      echo "</item>"
    done < "$live_file"

    echo '</items>'
  } > "$OUT"

  log info "Burp export saved to $OUT"
}
