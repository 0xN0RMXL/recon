#!/bin/bash
# ============================================================
# RECON Framework — lib/urls.sh
# Phase 05 — URL + Endpoint Collection & Categorization
# ============================================================

collect_urls() {
  local IN="$WORKDIR/03_live_hosts/live.txt"
  local OUT="$WORKDIR/05_urls"

  if [ ! -s "$IN" ]; then
    log warn "No live hosts found. Skipping URL collection."
    return 0
  fi

  log info "Phase 05: URL collection starting"

  # waybackurls
  if require_tool waybackurls; then
    log info "Running waybackurls..."
    cat "$IN" | waybackurls > "$OUT/raw/waybackurls.txt" 2>/dev/null
    check_output "$OUT/raw/waybackurls.txt" "waybackurls"
  fi

  # waymore
  if require_tool waymore; then
    log info "Running waymore..."
    waymore -i "$IN" -mode U -l 1000 -from 2020 \
      -oU "$OUT/raw/waymore.txt" 2>/dev/null
    check_output "$OUT/raw/waymore.txt" "waymore"
  fi

  # gau (with GitHub and OTX sources if keys available)
  if require_tool gau; then
    log info "Running gau..."
    local GAU_PROVIDERS="wayback,commoncrawl,otx,urlscan"
    cat "$IN" | gau \
      --threads "$GAU_THREADS" \
      --providers "$GAU_PROVIDERS" \
      >> "$OUT/raw/gau.txt" 2>/dev/null
    check_output "$OUT/raw/gau.txt" "gau"
  fi

  # hakrawler
  if require_tool hakrawler; then
    log info "Running hakrawler..."
    cat "$IN" | hakrawler -subs -u -insecure \
      > "$OUT/raw/hakrawler.txt" 2>/dev/null
    check_output "$OUT/raw/hakrawler.txt" "hakrawler"
  fi

  # katana (JavaScript-aware crawler)
  if require_tool katana; then
    log info "Running katana..."
    katana -l "$IN" \
      -jc -kf all \
      -d "$KATANA_DEPTH" \
      -concurrency "$KATANA_CONCURRENCY" \
      -headless -fx -aff \
      -fs rdn -f url -silent \
      > "$OUT/raw/katana.txt" 2>/dev/null
    check_output "$OUT/raw/katana.txt" "katana"
  fi

  # gospider
  if require_tool gospider; then
    log info "Running gospider..."
    local tmp_gospider="/tmp/gospider_raw_$$"
    gospider -S "$IN" \
      -t 20 -d 3 \
      --js --sitemap --robots \
      -o "$tmp_gospider/" 2>/dev/null
    find "$tmp_gospider/" -type f -exec cat {} \; 2>/dev/null \
      | grep -oE "https?://[^ ]+" \
      > "$OUT/raw/gospider.txt"
    rm -rf "$tmp_gospider/"
    check_output "$OUT/raw/gospider.txt" "gospider"
  fi

  # ── MERGE ALL URLs ────────────────────────────────────────
  log info "Merging all URLs..."
  cat "$OUT/raw/"*.txt 2>/dev/null \
    | grep -oE "https?://[^ '\"]+" \
    | grep -v "^$" \
    | sort -u > "$OUT/all_urls.txt"

  # Use anew if available for dedup
  if command -v anew &>/dev/null; then
    local tmp_urls="/tmp/recon_urls_merge_$$.txt"
    mv "$OUT/all_urls.txt" "$tmp_urls"
    cat "$tmp_urls" | anew "$OUT/all_urls.txt" >/dev/null 2>&1
    rm -f "$tmp_urls"
  fi

  local total
  total=$(wc -l < "$OUT/all_urls.txt" 2>/dev/null | tr -d ' ')
  log info "Total URLs collected: ${total:-0}"

  # ── CATEGORIZE URLs ───────────────────────────────────────
  log info "Categorizing URLs..."
  local ALLURLS="$OUT/all_urls.txt"
  local CAT="$OUT/categorized"

  grep -iE '\.js(\?|$)' "$ALLURLS" 2>/dev/null | sort -u > "$CAT/js_urls.txt"
  grep -iE '\.php(\?|$)' "$ALLURLS" 2>/dev/null | sort -u > "$CAT/php_urls.txt"
  grep -iE '\.(asp|aspx)(\?|$)' "$ALLURLS" 2>/dev/null | sort -u > "$CAT/asp_urls.txt"
  grep -iE '\.(jsp|jspx)(\?|$)' "$ALLURLS" 2>/dev/null | sort -u > "$CAT/jsp_urls.txt"
  grep -iE '\.(json|xml|graphql|gql)(\?|$)' "$ALLURLS" 2>/dev/null | sort -u > "$CAT/api_endpoints.txt"
  grep -iE 'login|signin|auth|oauth|reset|password' "$ALLURLS" 2>/dev/null | sort -u > "$CAT/login_flows.txt"
  grep -iE 'upload|file|download|image|media' "$ALLURLS" 2>/dev/null | sort -u > "$CAT/upload_endpoints.txt"
  grep -iE 'admin|dashboard|internal|manage' "$ALLURLS" 2>/dev/null | sort -u > "$CAT/admin_panels.txt"
  grep -iE '\.(env|bak|config|sql|log)(\?|$)' "$ALLURLS" 2>/dev/null | sort -u > "$CAT/sensitive_files.txt"
  grep -iE '\.(php|asp|aspx|jsp|cfm|cgi)(\?|$)' "$ALLURLS" 2>/dev/null | sort -u > "$CAT/backend_files.txt"
  grep -E '=[0-9]{2,}' "$ALLURLS" 2>/dev/null | sort -u > "$CAT/idor_candidates.txt"
  grep -iE 'admin|login|signup|redirect|callback|auth|dev|test|beta|debug|staging|url=|r=|u=|goto=|return=|dest=' "$ALLURLS" 2>/dev/null | sort -u > "$CAT/interesting_endpoints.txt"
  grep -iE 'aws|s3|bucket|gcp|azure|vault|token|apikey|secret' "$ALLURLS" 2>/dev/null | sort -u > "$CAT/cloud_leaks.txt"
  grep '=' "$ALLURLS" 2>/dev/null | sort -u > "$CAT/param_urls.txt"

  # Wayback sensitive file enumerator (full regex from methodology)
  grep -E \
    "\.xls|\.xlsx|\.csv|\.sql|\.db|\.bak|\.backup|\.old|\.tar\.gz|\.tgz|\.zip|\.7z|\.rar|\.pdf|\.doc|\.docx|\.pptx|\.txt|\.log|\.ini|\.conf|\.config|\.env|\.json|\.xml|\.yml|\.yaml|\.pem|\.key|\.crt|\.ssh|\.git|\.htaccess|\.htpasswd|\.php|\.swp|\.swo|\.dump|\.dmp" \
    "$ALLURLS" 2>/dev/null | sort -u >> "$CAT/sensitive_files.txt"
  sort -u "$CAT/sensitive_files.txt" -o "$CAT/sensitive_files.txt" 2>/dev/null

  # Parameter extraction (qsreplace method from methodology)
  if command -v qsreplace &>/dev/null; then
    grep '=' "$ALLURLS" | qsreplace "FUZZ" >> "$WORKDIR/08_params/all_params.txt" 2>/dev/null
  fi

  # Filter live URLs
  if require_tool httpx; then
    log info "Filtering live URLs..."
    httpx -l "$OUT/all_urls.txt" -status-code -content-length -silent \
      -threads 200 \
      > "$OUT/live_urls.txt" 2>/dev/null
  fi

  log success "URL collection and categorization complete"
}
