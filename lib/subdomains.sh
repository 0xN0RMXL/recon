#!/bin/bash
# ============================================================
# RECON Framework — lib/subdomains.sh
# Phase 01 — Passive + Active + Bruteforce Subdomain Enumeration
# ============================================================

subdomains_run() {
  local OUT="$WORKDIR/01_subdomains"

  log info "Phase 01: Subdomain enumeration starting for $TARGET"

  # ── PASSIVE ENUMERATION ─────────────────────────────────────

  # subfinder (with all sources if API keys in config)
  if require_tool subfinder; then
    log info "Running subfinder..."
    subfinder -d "$TARGET" -all -recursive -silent \
      -o "$OUT/passive/subfinder.txt" 2>/dev/null
    check_output "$OUT/passive/subfinder.txt" "subfinder"
  fi

  # assetfinder
  if require_tool assetfinder; then
    log info "Running assetfinder..."
    assetfinder --subs-only "$TARGET" > "$OUT/passive/assetfinder.txt" 2>/dev/null
    check_output "$OUT/passive/assetfinder.txt" "assetfinder"
  fi

  # amass (passive only, with config if available)
  if require_tool amass; then
    log info "Running amass (passive)..."
    timeout 600 amass enum -passive -d "$TARGET" -o "$OUT/passive/amass.txt" 2>/dev/null
    check_output "$OUT/passive/amass.txt" "amass"
  fi

  # findomain
  if require_tool findomain; then
    log info "Running findomain..."
    findomain -t "$TARGET" -u "$OUT/passive/findomain.txt" 2>/dev/null
    check_output "$OUT/passive/findomain.txt" "findomain"
  fi

  # chaos (if API key set)
  if [ -n "$CHAOS_KEY" ] && require_tool chaos; then
    log info "Running chaos..."
    chaos -d "$TARGET" -o "$OUT/passive/chaos.txt" -key "$CHAOS_KEY" 2>/dev/null
    check_output "$OUT/passive/chaos.txt" "chaos"
  else
    [ -z "$CHAOS_KEY" ] && log info "Skipping chaos: no API key configured"
  fi

  # github-subdomains (if GitHub token set)
  if [ -n "$GITHUB_TOKEN" ] && require_tool github-subdomains; then
    log info "Running github-subdomains..."
    github-subdomains -d "$TARGET" -t "$GITHUB_TOKEN" \
      -o "$OUT/passive/github.txt" 2>/dev/null
    check_output "$OUT/passive/github.txt" "github-subdomains"
  else
    [ -z "$GITHUB_TOKEN" ] && log info "Skipping github-subdomains: no GitHub token configured"
  fi

  # crt.sh via curl + jq
  log info "Querying crt.sh..."
  curl -s "https://crt.sh/?q=%25.$TARGET&output=json" \
    | jq -r '.[].name_value' 2>/dev/null \
    | sed 's/\*\.//g' | tr ',' '\n' \
    | grep -oE "[A-Za-z0-9._-]+\.$TARGET" \
    | sort -u > "$OUT/passive/crtsh.txt" 2>/dev/null
  check_output "$OUT/passive/crtsh.txt" "crt.sh"

  # SecurityTrails API (if key set)
  if [ -n "$SECURITYTRAILS_KEY" ]; then
    log info "Querying SecurityTrails API..."
    curl -s "https://api.securitytrails.com/v1/domain/$TARGET/subdomains" \
      -H "apikey: $SECURITYTRAILS_KEY" \
      | jq -r '.subdomains[]' 2>/dev/null \
      | sed "s/$/.$TARGET/" \
      > "$OUT/passive/securitytrails.txt"
    check_output "$OUT/passive/securitytrails.txt" "SecurityTrails"
  else
    log info "Skipping SecurityTrails: no API key configured"
  fi

  # VirusTotal API (if key set)
  if [ -n "$VIRUSTOTAL_KEY" ]; then
    log info "Querying VirusTotal API..."
    curl -s "https://www.virustotal.com/api/v3/domains/$TARGET/subdomains?limit=40" \
      -H "x-apikey: $VIRUSTOTAL_KEY" \
      | jq -r '.data[].id' 2>/dev/null \
      > "$OUT/passive/virustotal.txt"
    check_output "$OUT/passive/virustotal.txt" "VirusTotal"
  else
    log info "Skipping VirusTotal: no API key configured"
  fi

  # AlienVault OTX API (if key set)
  if [ -n "$OTX_KEY" ]; then
    log info "Querying AlienVault OTX API..."
    curl -s "https://otx.alienvault.com/api/v1/indicators/domain/$TARGET/passive_dns" \
      -H "X-OTX-API-KEY: $OTX_KEY" \
      | jq -r '.passive_dns[].hostname' 2>/dev/null \
      > "$OUT/passive/otx.txt"
    check_output "$OUT/passive/otx.txt" "AlienVault OTX"
  else
    log info "Skipping AlienVault OTX: no API key configured"
  fi

  # URLScan.io API (if key set)
  if [ -n "$URLSCAN_KEY" ]; then
    log info "Querying URLScan.io API..."
    curl -s "https://urlscan.io/api/v1/search/?q=domain:$TARGET&size=200" \
      -H "API-Key: $URLSCAN_KEY" \
      | jq -r '.results[].page.domain' 2>/dev/null \
      > "$OUT/passive/urlscan.txt"
    check_output "$OUT/passive/urlscan.txt" "URLScan.io"
  else
    log info "Skipping URLScan.io: no API key configured"
  fi

  # ── ACTIVE / BRUTEFORCE ENUMERATION ────────────────────────

  # puredns bruteforce with resolvers
  if require_tool puredns; then
    if [ -f "$WORDLIST_DNS_BEST" ] && [ -f "$RESOLVERS" ]; then
      log info "Running puredns bruteforce..."
      puredns bruteforce \
        "$WORDLIST_DNS_BEST" \
        "$TARGET" \
        -r "$RESOLVERS" \
        -w "$OUT/active/puredns.txt" 2>/dev/null
      check_output "$OUT/active/puredns.txt" "puredns"
    else
      log warn "Skipping puredns: wordlist or resolvers missing"
    fi
  fi

  # dnsx bruteforce
  if require_tool dnsx; then
    if [ -f "$WORDLIST_DNS_BRUTEFORCE" ]; then
      log info "Running dnsx bruteforce..."
      dnsx -silent -d "$TARGET" \
        -w "$WORDLIST_DNS_BRUTEFORCE" \
        -o "$OUT/active/dnsx_brute.txt" 2>/dev/null
      check_output "$OUT/active/dnsx_brute.txt" "dnsx bruteforce"
    else
      log warn "Skipping dnsx bruteforce: wordlist missing"
    fi
  fi

  # ── SUBDOMAIN FUZZING ──────────────────────────────────────

  if require_tool ffuf; then
    if [ -f "$WORDLIST_DNS_BRUTEFORCE" ]; then
      log info "Running ffuf subdomain fuzzing..."
      ffuf -u "https://FUZZ.$TARGET" \
        -w "$WORDLIST_DNS_BRUTEFORCE" \
        -mc 200,301,302,307 \
        -t 200 -silent \
        -o "$OUT/fuzzing/ffuf_subdomains.json" \
        -of json 2>/dev/null

      # Parse ffuf json to extract found subdomains
      jq -r '.results[].host' "$OUT/fuzzing/ffuf_subdomains.json" 2>/dev/null \
        > "$OUT/fuzzing/ffuf_subdomains.txt"
    else
      log warn "Skipping ffuf subdomain fuzzing: wordlist missing"
    fi
  fi

  # ── MERGE & DEDUPLICATE ────────────────────────────────────

  log info "Merging and deduplicating all subdomains..."
  cat "$OUT/passive/"*.txt "$OUT/active/"*.txt "$OUT/fuzzing/"*.txt 2>/dev/null \
    | grep -v "^$" | sort -u \
    | grep -E "^[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?)*$" \
    | anew "$OUT/all_subdomains.txt" 2>/dev/null || {
      # Fallback if anew not available
      cat "$OUT/passive/"*.txt "$OUT/active/"*.txt "$OUT/fuzzing/"*.txt 2>/dev/null \
        | grep -v "^$" | sort -u \
        | grep -E "^[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?)*$" \
        > "$OUT/all_subdomains.txt"
    }

  local count
  count=$(wc -l < "$OUT/all_subdomains.txt" 2>/dev/null | tr -d ' ')
  log success "Total unique subdomains: ${count:-0}"
}
