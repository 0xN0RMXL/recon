#!/bin/bash
# ============================================================
# RECON Framework — lib/content.sh
# Phase 06 — Directory/Content Fuzzing, VHost, Backup Files
# ============================================================

content_discovery() {
  local IN="$WORKDIR/03_live_hosts/live.txt"
  local OUT="$WORKDIR/06_content"

  if [ ! -s "$IN" ]; then
    log warn "No live hosts found. Skipping content discovery."
    return 0
  fi

  log info "Phase 06: Content discovery starting"

  local PROXY_ARG=""
  [ "$BURP_ENABLED" = "true" ] && PROXY_ARG="-x $BURP_PROXY"

  # ── FFUF directory fuzzing ──
  if require_tool ffuf && [ -s "$WORDLIST_WEB_COMMON" ]; then
    log info "Running ffuf directory fuzzing..."
    while IFS= read -r url; do
      local hash
      hash=$(echo "$url" | md5sum 2>/dev/null | cut -c1-8 || echo "$(date +%s)")
      ffuf -u "${url}/FUZZ" \
        -w "$WORDLIST_WEB_COMMON" \
        -t "$FFUF_THREADS" \
        -mc 200,201,301,302,307,308,401,403 \
        -ac \
        $PROXY_ARG \
        -o "/tmp/ffuf_${hash}.json" \
        -of json -s 2>/dev/null
    done < "$IN"

    # Merge ffuf results
    find /tmp/ -name "ffuf_*.json" -exec jq -r '.results[].url' {} \; \
      2>/dev/null | sort -u > "$OUT/ffuf_dirs.txt"
    find /tmp/ -name "ffuf_*.json" -exec cat {} \; 2>/dev/null > "$OUT/ffuf_dirs.json"
    rm -f /tmp/ffuf_*.json

    # Also run full extension sweep (from methodology)
    if [ -s "$WORDLIST_WEB_RAFT_LARGE_FILES" ]; then
      log info "Running ffuf extension sweep on top hosts..."
      head -20 "$IN" | while IFS= read -r url; do
        ffuf -u "${url}/FUZZ" \
          -w "$WORDLIST_WEB_RAFT_LARGE_FILES" \
          -e ".php,.html,.asp,.aspx,.js,.json,.xml,.config,.bak,.old,.backup,.zip,.rar" \
          -t 200 -mc 200,301,302,401,403 -ac -s \
          $PROXY_ARG \
          2>/dev/null >> "$OUT/ffuf_dirs.txt"
      done
    fi

    # ── 403 bypass attempts (from methodology) ──
    if grep -q "403" "$WORKDIR/03_live_hosts/live_detailed.txt" 2>/dev/null; then
      log info "Attempting 403 bypass..."
      grep " 403 " "$WORKDIR/03_live_hosts/live_detailed.txt" | \
        grep -oE "https?://[^ ]+" | head -20 | \
        while IFS= read -r url; do
          ffuf -u "$url" \
            -w "$DATA_DIR/wordlists/web/403-bypass-headers.txt" \
            -H "FUZZ" -mc 200,301,302 -s 2>/dev/null >> "$OUT/ffuf_dirs.txt"
        done
    fi
  fi

  # ── feroxbuster ──
  if require_tool feroxbuster && [ -s "$WORDLIST_WEB_RAFT_LARGE_DIRS" ]; then
    log info "Running feroxbuster..."
    head -10 "$IN" | while IFS= read -r url; do
      feroxbuster -u "$url" \
        -w "$WORDLIST_WEB_RAFT_LARGE_DIRS" \
        -t 300 -k -d 3 -e \
        -x "php,html,json,js,log,txt,bak,old,zip,tar,gz" \
        --quiet \
        2>/dev/null >> "$OUT/feroxbuster.txt"
    done
    check_output "$OUT/feroxbuster.txt" "feroxbuster"
  fi

  # ── gobuster ──
  if require_tool gobuster && [ -s "$WORDLIST_WEB_COMMON" ]; then
    log info "Running gobuster..."
    head -10 "$IN" | while IFS= read -r url; do
      gobuster dir -u "$url" \
        -w "$WORDLIST_WEB_COMMON" \
        -k -q \
        2>/dev/null >> "$OUT/gobuster.txt"
    done
    check_output "$OUT/gobuster.txt" "gobuster"
  fi

  # ── dirsearch ──
  if command -v dirsearch &>/dev/null || [ -f "$HOME/tools/dirsearch/dirsearch.py" ]; then
    log info "Running dirsearch..."
    local dirsearch_cmd="dirsearch"
    [ -f "$HOME/tools/dirsearch/dirsearch.py" ] && dirsearch_cmd="python3 $HOME/tools/dirsearch/dirsearch.py"

    head -10 "$IN" | while IFS= read -r url; do
      $dirsearch_cmd \
        -u "$url" \
        -i 200,204,301,302,307,308,401,403 \
        --exclude-status=404 \
        --full-url \
        -e "php,asp,aspx,jsp,json,xml,txt,log,ini,cfg,config,conf,bak,old,backup,zip,tar,gz,swp" \
        -t 80 \
        --random-agent \
        -o "$OUT/dirsearch.txt" -q \
        2>/dev/null
    done
    check_output "$OUT/dirsearch.txt" "dirsearch"
  fi

  # ── Virtual Host enumeration ──
  if require_tool ffuf && [ -s "$WORDLIST_DNS_BRUTEFORCE" ]; then
    log info "Running virtual host enumeration..."
    ffuf -u "https://$TARGET" \
      -w "$WORDLIST_DNS_BRUTEFORCE" \
      -H "Host: FUZZ.$TARGET" \
      -mc 200,301,302,307 \
      -t 200 -s 2>/dev/null \
      | sort -u > "$OUT/vhosts.txt"
    check_output "$OUT/vhosts.txt" "vhost enum"
  fi

  # ── bfac backup file checker ──
  if [ -f "$HOME/tools/bfac/bfac.py" ]; then
    log info "Running bfac backup file checker..."
    head -20 "$IN" | while IFS= read -r url; do
      python3 "$HOME/tools/bfac/bfac.py" \
        --url "$url" \
        --detection-technique all \
        --level 3 \
        --exclude-status-codes 404,500 \
        2>/dev/null >> "$OUT/backup_files.txt"
    done
    check_output "$OUT/backup_files.txt" "bfac"
  fi

  log success "Content discovery phase complete"
}
