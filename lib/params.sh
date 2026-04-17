#!/bin/bash
# ============================================================
# RECON Framework — lib/params.sh
# Phase 08 — Parameter Discovery
# ============================================================

param_discovery() {
  local OUT="$WORKDIR/08_params"
  local ERR_LOG="$OUT/params_errors.log"
  local PARAMS_IN="$WORKDIR/03_live_hosts/live.txt"
  local tmp_params_in=""

  : > "$ERR_LOG"

  log info "Phase 08: Parameter discovery starting"

  # Ensure output file exists
  touch "$OUT/all_params.txt"

  # arjun on PHP and interesting endpoints
  if require_tool arjun && [ -s "$WORKDIR/05_urls/categorized/php_urls.txt" ]; then
    log info "Running arjun..."
    arjun -i "$WORKDIR/05_urls/categorized/php_urls.txt" \
      --threads 50 \
      -o "$OUT/arjun.json" 2>>"$ERR_LOG"

    # Parse arjun output
    if [ -s "$OUT/arjun.json" ]; then
      jq -r '.[] | .url + "?" + (.params | join("=FUZZ&")) + "=FUZZ"' \
        "$OUT/arjun.json" 2>>"$ERR_LOG" >> "$OUT/all_params.txt"
    fi
    check_output "$OUT/arjun.json" "arjun"
  fi

  # paramspider
  if require_tool paramspider; then
    log info "Running paramspider..."
    paramspider -d "$TARGET" --output "$OUT/paramspider.txt" 2>>"$ERR_LOG"
    if [ -s "$OUT/paramspider.txt" ]; then
      cat "$OUT/paramspider.txt" >> "$OUT/all_params.txt"
    fi
    check_output "$OUT/paramspider.txt" "paramspider"
  fi

  # Hidden parameter brute-force via ffuf (from methodology)
  if require_tool ffuf && [ -s "$WORDLIST_WEB_PARAMS" ] && [ -s "$WORKDIR/03_live_hosts/live.txt" ]; then
    local total_hosts sampled_hosts
    total_hosts=$(wc -l < "$PARAMS_IN" 2>>"$ERR_LOG" | tr -d ' ')
    total_hosts="${total_hosts:-0}"

    if [ "${PARAMS_MAX_HOSTS:-20}" -gt 0 ] && [ "$total_hosts" -gt "${PARAMS_MAX_HOSTS:-20}" ]; then
      tmp_params_in="/tmp/recon_params_hosts_$$.txt"
      head -n "$PARAMS_MAX_HOSTS" "$PARAMS_IN" > "$tmp_params_in"
      PARAMS_IN="$tmp_params_in"
      sampled_hosts=$(wc -l < "$PARAMS_IN" 2>>"$ERR_LOG" | tr -d ' ')
      log warn "Parameter brute-force sampling enabled: $sampled_hosts/$total_hosts live hosts"
    fi

    log info "Running ffuf hidden parameter brute-force..."
    while IFS= read -r url; do
      ffuf -u "${url}?FUZZ=value" \
        -w "$WORDLIST_WEB_PARAMS" \
        -mc 200 -ac -s 2>>"$ERR_LOG" >> "$OUT/all_params.txt"
    done < "$PARAMS_IN"
  fi

  # Deduplicate
  sort -u "$OUT/all_params.txt" -o "$OUT/all_params.txt" 2>>"$ERR_LOG"

  [ -n "$tmp_params_in" ] && rm -f "$tmp_params_in"

  log info "Parameters discovered: $(wc -l < "$OUT/all_params.txt" 2>>"$ERR_LOG" | tr -d ' ')"
}
