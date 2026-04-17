#!/bin/bash
# ============================================================
# RECON Framework — lib/dns.sh
# Phase 02 — DNS Resolution, PTR Records, ASN Mapping
# ============================================================

dns_resolution() {
  local IN="$WORKDIR/01_subdomains/all_subdomains.txt"
  local OUT="$WORKDIR/02_dns"
  local ERR_LOG="$OUT/dns_errors.log"
  local tmp_dnsx_raw="/tmp/recon_dnsx_raw_$$.txt"
  local tmp_resolved_ips="/tmp/recon_resolved_ips_$$.txt"
  local tmp_asn_cidrs="/tmp/recon_asn_cidrs_$$.txt"
  local tmp_asn_ips="/tmp/recon_asn_ips_$$.txt"

  : > "$ERR_LOG"
  : > "$OUT/ptr_records.txt"

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
  if ! dnsx -l "$IN" -a -resp -o "$tmp_dnsx_raw" -silent -retry 3 -threads 200 2>>"$ERR_LOG"; then
    rm -f "$tmp_dnsx_raw" "$tmp_resolved_ips" "$tmp_asn_cidrs" "$tmp_asn_ips"
    log error "dnsx execution failed during DNS resolution. See $ERR_LOG"
    return 1
  fi

  # Normalize output to "domain ip" format where possible.
  awk '
    {
      host=$1
      ip=""
      for (i=1; i<=NF; i++) {
        gsub(/^[\[]|[\],]$/, "", $i)
        if ($i ~ /^([0-9]{1,3}\.){3}[0-9]{1,3}$/ || $i ~ /^([0-9A-Fa-f]{0,4}:){2,}[0-9A-Fa-f:]+$/) {
          ip=$i
          break
        }
      }
      if (host != "" && ip != "") print host " " ip
    }
  ' "$tmp_dnsx_raw" | sort -u > "$OUT/resolved.txt"

  if [ ! -s "$OUT/resolved.txt" ]; then
    log warn "dnsx -resp parsing returned no IP-bearing records; trying -resp-only fallback"
    if dnsx -l "$IN" -a -resp-only -o "$tmp_resolved_ips" -silent -retry 3 -threads 200 2>>"$ERR_LOG" && [ -s "$tmp_resolved_ips" ]; then
      sort -u "$tmp_resolved_ips" > "$OUT/resolved.txt"
    fi
  fi

  if ! check_output "$OUT/resolved.txt" "dnsx"; then
    rm -f "$tmp_dnsx_raw" "$tmp_resolved_ips" "$tmp_asn_cidrs" "$tmp_asn_ips"
    log error "DNS resolution returned no data. See $ERR_LOG"
    return 1
  fi

  grep -oE '([0-9]{1,3}\.){3}[0-9]{1,3}|([0-9A-Fa-f]{0,4}:){2,}[0-9A-Fa-f:]+' "$OUT/resolved.txt" \
    | sort -u > "$tmp_resolved_ips"

  if [ ! -s "$tmp_resolved_ips" ]; then
    rm -f "$tmp_dnsx_raw" "$tmp_resolved_ips" "$tmp_asn_cidrs" "$tmp_asn_ips"
    log error "DNS resolution did not produce extractable IPs. See $ERR_LOG"
    return 1
  fi

  # ASN mapping
  if require_tool asnmap; then
    log info "Running ASN mapping..."
    asnmap -d "$TARGET" -silent > "$OUT/asn_mapping.txt" 2>>"$ERR_LOG"
    check_output "$OUT/asn_mapping.txt" "asnmap"

    # PTR lookups via ASN CIDRs. Expand to individual IPs when possible.
    if [ -s "$OUT/asn_mapping.txt" ]; then
      log info "Running PTR lookups on ASN CIDRs..."
      grep -oE '([0-9]{1,3}\.){3}[0-9]{1,3}/[0-9]{1,2}' "$OUT/asn_mapping.txt" | sort -u > "$tmp_asn_cidrs"

      if [ -s "$tmp_asn_cidrs" ]; then
        : > "$tmp_asn_ips"
        if require_tool nmap; then
          while IFS= read -r cidr; do
            local cidr_ips
            cidr_ips=$(nmap -n -sL "$cidr" 2>>"$ERR_LOG" \
              | awk '/Nmap scan report for / {print $NF}' \
              | grep -E '^([0-9]{1,3}\.){3}[0-9]{1,3}$' || true)

            if [ -n "$cidr_ips" ]; then
              printf '%s\n' "$cidr_ips" >> "$tmp_asn_ips"
            else
              log warn "Could not expand ASN CIDR $cidr; trying direct PTR lookup fallback"
              echo "$cidr" | dnsx -silent -resp-only -ptr >> "$OUT/ptr_records.txt" 2>>"$ERR_LOG" || true
            fi
          done < "$tmp_asn_cidrs"

          if [ -s "$tmp_asn_ips" ]; then
            sort -u "$tmp_asn_ips" -o "$tmp_asn_ips"
            dnsx -l "$tmp_asn_ips" -silent -resp-only -ptr >> "$OUT/ptr_records.txt" 2>>"$ERR_LOG" || true
          fi
        else
          log warn "nmap not found; using direct PTR lookups on ASN CIDRs without expansion"
          dnsx -l "$tmp_asn_cidrs" -silent -resp-only -ptr >> "$OUT/ptr_records.txt" 2>>"$ERR_LOG" || true
        fi
      fi
    fi
  fi

  # hakrevdns on resolved IPs
  if require_tool hakrevdns && [ -s "$tmp_resolved_ips" ]; then
    log info "Running hakrevdns..."
    hakrevdns -d "$TARGET" -t 200 < "$tmp_resolved_ips" >> "$OUT/ptr_records.txt" 2>>"$ERR_LOG"
  fi

  [ -s "$OUT/ptr_records.txt" ] && sort -u "$OUT/ptr_records.txt" -o "$OUT/ptr_records.txt" 2>>"$ERR_LOG"
  rm -f "$tmp_dnsx_raw" "$tmp_resolved_ips" "$tmp_asn_cidrs" "$tmp_asn_ips"

  log success "DNS resolution phase complete"
}
