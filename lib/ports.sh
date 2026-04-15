#!/bin/bash
# ============================================================
# RECON Framework — lib/ports.sh
# Phase 04 — Port Scanning + Service Detection
# ============================================================

port_scan() {
  local IN="$WORKDIR/03_live_hosts/live.txt"
  local OUT="$WORKDIR/04_ports"

  if [ ! -s "$IN" ]; then
    log warn "No live hosts found. Skipping port scan."
    return 0
  fi

  log info "Phase 04: Port scanning starting"

  # naabu fast port scan
  if require_tool naabu; then
    log info "Running naabu fast port scan..."
    naabu -l "$IN" \
      -p - \
      -rate "$NAABU_RATE" \
      -o "$OUT/naabu_ports.txt" \
      -silent 2>/dev/null
    check_output "$OUT/naabu_ports.txt" "naabu"
  fi

  # nmap service/version detection on discovered open ports
  if require_tool nmap && [ -s "$OUT/naabu_ports.txt" ]; then
    log info "Running nmap service detection..."
    local tmp_ips="/tmp/recon_ips_$$.txt"
    awk -F: '{print $1}' "$OUT/naabu_ports.txt" | sort -u > "$tmp_ips"
    nmap -iL "$tmp_ips" \
      -T4 -Pn -sV \
      -o "$OUT/nmap_services.txt" 2>/dev/null
    rm -f "$tmp_ips"
    check_output "$OUT/nmap_services.txt" "nmap"
  fi

  log success "Port scanning phase complete"
}
