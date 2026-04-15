#!/bin/bash
# ============================================================
# RECON Framework — lib/scoring.sh
# Scoring & Priority Engine v2
# ============================================================

score_targets() {
  local IN="$WORKDIR/05_urls/all_urls.txt"
  local OUT="$WORKDIR/reports/prioritized_targets.json"

  if [ ! -s "$IN" ]; then
    log warn "No URLs found. Skipping scoring."
    echo "[]" > "$OUT"
    return 0
  fi

  log info "Scoring: Priority scoring engine starting"

  echo "[" > "$OUT"
  local first=true

  while IFS= read -r url; do
    local score=0
    local tags=()

    # High-value patterns (additive scoring)
    [[ "$url" =~ admin ]]           && score=$((score+50)) && tags+=("admin")
    [[ "$url" =~ graphql ]]         && score=$((score+50)) && tags+=("graphql")
    [[ "$url" =~ /api/v[0-9] ]]     && score=$((score+45)) && tags+=("api_versioned")
    [[ "$url" =~ /api/ ]]           && score=$((score+40)) && tags+=("api")
    [[ "$url" =~ auth|oauth|token ]]&& score=$((score+40)) && tags+=("auth")
    [[ "$url" =~ login|signin ]]    && score=$((score+35)) && tags+=("login")
    [[ "$url" =~ upload|file ]]     && score=$((score+30)) && tags+=("upload")
    [[ "$url" =~ redirect|goto ]]   && score=$((score+25)) && tags+=("redirect_ssrf")
    [[ "$url" =~ reset|password ]]  && score=$((score+25)) && tags+=("password_reset")
    [[ "$url" =~ =[0-9]{1,10}$ ]]   && score=$((score+20)) && tags+=("idor_candidate")
    [[ "$url" =~ debug|test|dev ]]  && score=$((score+15)) && tags+=("debug_env")
    [[ "$url" =~ backup|\.bak ]]    && score=$((score+20)) && tags+=("backup")
    [[ "$url" =~ \.env|config|\.sql ]] && score=$((score+30)) && tags+=("sensitive_file")

    if [ $score -gt 0 ]; then
      local tags_json
      tags_json=$(printf '"%s",' "${tags[@]}" | sed 's/,$//')

      [ "$first" = true ] && first=false || echo "," >> "$OUT"
      printf '{"url":"%s","score":%d,"tags":[%s]}' \
        "$url" "$score" "$tags_json" >> "$OUT"
    fi

  done < "$IN"

  echo "]" >> "$OUT"

  # Sort by score descending
  if command -v jq &>/dev/null; then
    jq 'sort_by(-.score)' "$OUT" > /tmp/sorted_targets_$$.json 2>/dev/null && \
      mv /tmp/sorted_targets_$$.json "$OUT"
  fi

  log info "Priority targets saved to $OUT"
  if command -v jq &>/dev/null; then
    log info "Top 10 targets:"
    jq -r '.[:10] | .[] | "  Score: \(.score) | \(.url) | Tags: \(.tags | join(","))"' "$OUT" 2>/dev/null
  fi
  log success "Priority scoring complete"
}
