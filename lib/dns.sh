#!/bin/bash
# ============================================================
# RECON Framework — lib/dns.sh
# Phase 02 — DNS Resolution, PTR Records, ASN Mapping
# ============================================================

dns_resolution() {
  local IN="$WORKDIR/01_subdomains/all_subdomains.txt"
  local OUT="$WORKDIR/02_dns"
  local ERR_LOG="$OUT/dns_errors.log"

  : > "$ERR_LOG"

  if [ ! -s "$IN" ]; then
    log warn "No subdomains found. Skipping DNS resolution."
    return 0
  fi

  log info "Phase 02: DNS resolution starting"

  # Resolve with dnsx
  if ! require_tool dnsx; then
    log error "dnsx is required for DNS resolution"
    return 1
  fi

  log info "Running dnsx resolution..."
  dnsx -l "$IN" -o "$OUT/resolved.txt" -silent -retry 3 -threads 200 2>>"$ERR_LOG"
  if ! check_output "$OUT/resolved.txt" "dnsx"; then
    log error "DNS resolution returned no data. See $ERR_LOG"
    return 1
  fi

  # ASN mapping
  if require_tool asnmap; then
    log info "Running ASN mapping..."
    asnmap -d "$TARGET" -silent > "$OUT/asn_mapping.txt" 2>>"$ERR_LOG"
    check_output "$OUT/asn_mapping.txt" "asnmap"

    # PTR (reverse DNS) lookups via ASN CIDR blocks
    if [ -s "$OUT/asn_mapping.txt" ]; then
      log info "Running PTR lookups on ASN CIDRs..."
      while IFS= read -r cidr; do
        echo "$cidr" | dnsx -silent -resp-only -ptr >> "$OUT/ptr_records.txt" 2>>"$ERR_LOG"
      done < "$OUT/asn_mapping.txt"
      sort -u "$OUT/ptr_records.txt" -o "$OUT/ptr_records.txt" 2>>"$ERR_LOG"
    fi
  fi

  # hakrevdns on resolved IPs
  if require_tool hakrevdns && [ -s "$OUT/resolved.txt" ]; then
    log info "Running hakrevdns..."
    cut -d' ' -f1 "$OUT/resolved.txt" 2>>"$ERR_LOG" | \
      hakrevdns -d "$TARGET" -t 200 >> "$OUT/ptr_records.txt" 2>>"$ERR_LOG"
    sort -u "$OUT/ptr_records.txt" -o "$OUT/ptr_records.txt" 2>>"$ERR_LOG"
  fi

  log success "DNS resolution phase complete"
}
