#!/bin/bash
# ============================================================
# RECON Framework — lib/js.sh
# Phase 07 — JavaScript Analysis + Secret Extraction
# ============================================================

js_analysis() {
  local JS_URLS="$WORKDIR/05_urls/categorized/js_urls.txt"
  local OUT="$WORKDIR/07_js"
  local ERR_LOG="$OUT/js_errors.log"

  : > "$ERR_LOG"

  log info "Phase 07: JavaScript analysis starting"

  # Initialize JS URL list if not exists
  touch "$JS_URLS"

  # subjs — discover JS files from live hosts
  if require_tool subjs && [ -s "$WORKDIR/03_live_hosts/live.txt" ]; then
    log info "Running subjs..."
    cat "$WORKDIR/03_live_hosts/live.txt" | subjs > "$OUT/subjs_output.txt" 2>>"$ERR_LOG"
    if [ -s "$OUT/subjs_output.txt" ]; then
      cat "$OUT/subjs_output.txt" >> "$JS_URLS"
      sort -u "$JS_URLS" -o "$JS_URLS"
    fi
    check_output "$OUT/subjs_output.txt" "subjs"
  fi

  # mantra — JS secret scanning
  if command -v mantra &>/dev/null && [ -s "$JS_URLS" ]; then
    log info "Running mantra..."
    cat "$JS_URLS" | mantra > "$OUT/mantra_output.txt" 2>>"$ERR_LOG"
    check_output "$OUT/mantra_output.txt" "mantra"
  fi

  if [ ! -s "$JS_URLS" ]; then
    log warn "No JS URLs found. Skipping JS content analysis."
    touch "$OUT/js_urls.txt" "$OUT/extracted_endpoints.txt" "$OUT/extracted_secrets.txt"
    return 0
  fi

  # Copy JS URLs to output directory
  cp "$JS_URLS" "$OUT/js_urls.txt" 2>>"$ERR_LOG"

  : > "$OUT/js_content_dump.txt"
  : > "$OUT/extracted_endpoints.txt"
  : > "$OUT/extracted_secrets.txt"

  # Download and dump all JS files
  log info "Downloading and analyzing JS files..."
  local js_count=0
  while IFS= read -r js_url; do
    local content
    content=$(curl -sk --max-time 10 "$js_url" 2>>"$ERR_LOG")

    if [ -n "$content" ]; then
      echo "// === $js_url ===" >> "$OUT/js_content_dump.txt"
      echo "$content" >> "$OUT/js_content_dump.txt"

      # Extract embedded endpoints
      echo "$content" | grep -oE "(https?://[^\"' ,<>]+)" | \
        grep -v "^$" >> "$OUT/extracted_endpoints.txt"

      # Extract secrets via regex
      echo "$content" | grep -Ei \
        "(AKIA[0-9A-Z]{16}|api[_-]?key[\"' ]*[:=][\"' ]*[a-zA-Z0-9_-]{10,}|token[\"' ]*[:=][\"' ]*[a-zA-Z0-9_-]{10,}|secret[\"' ]*[:=][\"' ]*[a-zA-Z0-9_-]{10,}|password[\"' ]*[:=][\"' ]*[a-zA-Z0-9_-]{8,}|bearer [a-zA-Z0-9_-]{20,})" \
        >> "$OUT/extracted_secrets.txt" 2>>"$ERR_LOG"

      ((js_count++))
    fi
  done < "$JS_URLS"

  # Deduplicate outputs
  sort -u "$OUT/extracted_endpoints.txt" -o "$OUT/extracted_endpoints.txt" 2>>"$ERR_LOG"
  sort -u "$OUT/extracted_secrets.txt" -o "$OUT/extracted_secrets.txt" 2>>"$ERR_LOG"

  # Ensure files exist even if empty
  touch "$OUT/extracted_endpoints.txt" "$OUT/extracted_secrets.txt"

  log info "JS files analyzed: $js_count"
  log info "Endpoints extracted: $(wc -l < "$OUT/extracted_endpoints.txt" 2>>"$ERR_LOG" | tr -d ' ')"
  log info "Potential secrets: $(wc -l < "$OUT/extracted_secrets.txt" 2>>"$ERR_LOG" | tr -d ' ')"
}
