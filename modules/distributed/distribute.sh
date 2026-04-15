#!/bin/bash
# ============================================================
# RECON Framework — modules/distributed/distribute.sh
# VPS Cluster Scan Distribution
# ============================================================

# Source utils if not already loaded
[ -z "$CYAN" ] && source "$(dirname "${BASH_SOURCE[0]}")/../../lib/utils.sh"

distribute_nuclei_scan() {
  local TARGET_FILE="$1"

  if [ ! -s "$TARGET_FILE" ]; then
    log warn "No targets to distribute."
    return 0
  fi

  # Read nodes from config
  mapfile -t NODES < <(grep "^\s*-\s*\"[^\"]\\+" config.yaml | \
    grep -v '""' | sed 's/.*"\(.*\)".*/\1/')

  if [ ${#NODES[@]} -eq 0 ]; then
    log warn "No distributed nodes configured. Running locally."
    return 0
  fi

  log info "Distributing scan across ${#NODES[@]} nodes..."

  # Split target file into N chunks
  split -n "l/${#NODES[@]}" "$TARGET_FILE" /tmp/recon_chunk_

  local i=0
  for node in "${NODES[@]}"; do
    local chunk
    chunk=$(ls /tmp/recon_chunk_* 2>/dev/null | sed -n "$((i+1))p")
    [ -z "$chunk" ] && break

    log info "Sending chunk to $node..."
    scp -q "$chunk" "$node:/tmp/recon_targets.txt" 2>/dev/null
    ssh -q "$node" "nuclei -l /tmp/recon_targets.txt \
      -severity low,medium,high,critical \
      -rate-limit 150 -silent \
      -o /tmp/recon_results_${i}.txt" &

    ((i++))
  done

  wait

  # Collect results
  local j=0
  for node in "${NODES[@]}"; do
    scp -q "$node:/tmp/recon_results_*.txt" "$WORKDIR/09_vulns/" 2>/dev/null
    ((j++))
  done

  # Merge
  cat "$WORKDIR/09_vulns/recon_results_"*.txt 2>/dev/null | \
    sort -u >> "$WORKDIR/09_vulns/nuclei_all.txt"

  rm -f /tmp/recon_chunk_* /tmp/recon_results_*
  log info "Distributed scan complete. Results merged."
}
