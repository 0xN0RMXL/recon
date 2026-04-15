#!/bin/bash
# ============================================================
# RECON Framework — lib/params.sh
# Phase 08 — Parameter Discovery
# ============================================================

param_discovery() {
  local OUT="$WORKDIR/08_params"

  log info "Phase 08: Parameter discovery starting"

  # Ensure output file exists
  touch "$OUT/all_params.txt"

  # arjun on PHP and interesting endpoints
  if require_tool arjun && [ -s "$WORKDIR/05_urls/categorized/php_urls.txt" ]; then
    log info "Running arjun..."
    arjun -i "$WORKDIR/05_urls/categorized/php_urls.txt" \
      --threads 50 \
      -o "$OUT/arjun.json" 2>/dev/null

    # Parse arjun output
    if [ -s "$OUT/arjun.json" ]; then
      jq -r '.[] | .url + "?" + (.params | join("=FUZZ&")) + "=FUZZ"' \
        "$OUT/arjun.json" 2>/dev/null >> "$OUT/all_params.txt"
    fi
    check_output "$OUT/arjun.json" "arjun"
  fi

  # paramspider
  if require_tool paramspider; then
    log info "Running paramspider..."
    paramspider -d "$TARGET" --output "$OUT/paramspider.txt" 2>/dev/null
    if [ -s "$OUT/paramspider.txt" ]; then
      cat "$OUT/paramspider.txt" >> "$OUT/all_params.txt"
    fi
    check_output "$OUT/paramspider.txt" "paramspider"
  fi

  # Hidden parameter brute-force via ffuf (from methodology)
  if require_tool ffuf && [ -s "$WORDLIST_WEB_PARAMS" ] && [ -s "$WORKDIR/03_live_hosts/live.txt" ]; then
    log info "Running ffuf hidden parameter brute-force..."
    head -20 "$WORKDIR/03_live_hosts/live.txt" | while IFS= read -r url; do
      ffuf -u "${url}?FUZZ=value" \
        -w "$WORDLIST_WEB_PARAMS" \
        -mc 200 -ac -s 2>/dev/null >> "$OUT/all_params.txt"
    done
  fi

  # Deduplicate
  sort -u "$OUT/all_params.txt" -o "$OUT/all_params.txt" 2>/dev/null

  log info "Parameters discovered: $(wc -l < "$OUT/all_params.txt" 2>/dev/null | tr -d ' ')"
}
