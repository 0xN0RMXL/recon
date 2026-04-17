#!/bin/bash
# ============================================================
# RECON Framework — lib/ports.sh
# Phase 04 — Port Scanning + Service Detection
# ============================================================

port_scan() {
  local IN="$WORKDIR/03_live_hosts/live.txt"
  local OUT="$WORKDIR/04_ports"
  local ERR_LOG="$OUT/ports_errors.log"

  : > "$ERR_LOG"

  if [ ! -s "$IN" ]; then
    log warn "No live hosts found. Skipping port scan."
    return 0
  fi

  log info "Phase 04: Port scanning starting"

  local tmp_hosts="/tmp/recon_port_hosts_$$.txt"
  awk '{print $1}' "$IN" 2>>"$ERR_LOG" \
    | sed -E 's#^https?://##; s#/.*$##; s#:[0-9]+$##' \
    | grep -v '^$' \
    | sort -u > "$tmp_hosts"

  if [ ! -s "$tmp_hosts" ]; then
    rm -f "$tmp_hosts"
    log error "No valid hosts extracted from live host list. Port scan cannot continue."
    return 1
  fi

  # naabu fast port scan
  if ! require_tool naabu; then
    rm -f "$tmp_hosts"
    log error "naabu is required for port scanning"
    return 1
  fi

  log info "Running naabu fast port scan..."
  naabu -l "$tmp_hosts" \
    -p - \
    -rate "$NAABU_RATE" \
    -o "$OUT/naabu_ports.txt" \
    -silent 2>>"$ERR_LOG"
  if ! check_output "$OUT/naabu_ports.txt" "naabu"; then
    rm -f "$tmp_hosts"
    log error "naabu produced no output for live hosts. See $ERR_LOG"
    return 1
  fi

  # nmap service/version detection on discovered open ports
  if require_tool nmap && [ -s "$OUT/naabu_ports.txt" ]; then
    log info "Running nmap service detection..."
    local tmp_ips="/tmp/recon_ips_$$.txt"
    awk -F: '{print $1}' "$OUT/naabu_ports.txt" | sort -u > "$tmp_ips"
    nmap -iL "$tmp_ips" \
      -T4 -Pn -sV \
      -o "$OUT/nmap_services.txt" 2>>"$ERR_LOG"
    rm -f "$tmp_ips"
    check_output "$OUT/nmap_services.txt" "nmap"
  fi

  rm -f "$tmp_hosts"

  log success "Port scanning phase complete"
}
