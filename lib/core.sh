#!/bin/bash
# ============================================================
# RECON Framework — lib/core.sh
# Workspace initialization & run_phase wrapper with retry logic
# ============================================================

# ─── INITIALIZE COMPLETE WORKSPACE DIRECTORY TREE ────────────
init_workspace() {
  local target_name
  target_name=$(sanitize_target "$TARGET")
  export WORKDIR="${OUTPUT_BASE}/${target_name}"

  log info "Initializing workspace: $WORKDIR"


  # Create the full output directory tree per §8 (safe)
  safe_mkdir "$WORKDIR/meta"
  safe_mkdir "$WORKDIR/01_subdomains/passive"
  safe_mkdir "$WORKDIR/01_subdomains/active"
  safe_mkdir "$WORKDIR/01_subdomains/fuzzing"
  safe_mkdir "$WORKDIR/02_dns"
  safe_mkdir "$WORKDIR/03_live_hosts"
  safe_mkdir "$WORKDIR/04_ports"
  safe_mkdir "$WORKDIR/05_urls/raw"
  safe_mkdir "$WORKDIR/05_urls/categorized"
  safe_mkdir "$WORKDIR/06_content"
  safe_mkdir "$WORKDIR/07_js"
  safe_mkdir "$WORKDIR/08_params"
  safe_mkdir "$WORKDIR/09_vulns/sqlmap"
  safe_mkdir "$WORKDIR/10_cloud"
  safe_mkdir "$WORKDIR/11_secrets"
  safe_mkdir "$WORKDIR/12_screenshots"
  safe_mkdir "$WORKDIR/13_api"
  safe_mkdir "$WORKDIR/14_github"
  safe_mkdir "$WORKDIR/15_origins"
  safe_mkdir "$WORKDIR/intelligence"
  safe_mkdir "$WORKDIR/reports"

  # Set log file
  export LOG_FILE="$WORKDIR/meta/execution.log"
  safe_touch "$LOG_FILE"

  # Initialize state machine
  state_init

  # Snapshot config for reproducibility
  if [ -f "${CONFIG:-config.yaml}" ]; then
    cp "${CONFIG:-config.yaml}" "$WORKDIR/meta/config_snapshot.yaml"
  fi

  # Write run info
  local run_info="$WORKDIR/meta/run_info.json"
  jq -n \
    --arg target "$TARGET" \
    --arg mode "${TARGET_MODE:-single}" \
    --arg start "$(date -Iseconds 2>/dev/null || date '+%Y-%m-%dT%H:%M:%S')" \
    --arg version "$VERSION" \
    '{
      target: $target,
      mode: $mode,
      start_time: $start,
      version: $version
    }' > "$run_info" 2>/dev/null || {
    echo "{\"target\":\"$TARGET\",\"mode\":\"${TARGET_MODE:-single}\",\"start_time\":\"$(date)\",\"version\":\"$VERSION\"}" > "$run_info"
  }

  log success "Workspace initialized: $WORKDIR"
}

# ─── RUN PHASE WRAPPER ──────────────────────────────────────
# Handles: skip logic, retry (3 attempts), logging, notifications
run_phase() {
  local PHASE_NAME="$1"
  local PHASE_FUNC="$2"
  export CURRENT_PHASE=""

  # Check if phase is in the skip list
  if echo "$SKIP_PHASES" | grep -qw "$PHASE_NAME"; then
    log info "Skipping phase $PHASE_NAME (--skip flag)"
    return 0
  fi

  # Check if --only is set and this phase is not in the list
  if [ -n "$ONLY_PHASE" ] && [ "$ONLY_PHASE" != "$PHASE_NAME" ]; then
    return 0
  fi

  # Check state for resume logic
  if state_should_skip "$PHASE_NAME" && [ "$FORCE" != "true" ]; then
    log info "Skipping phase $PHASE_NAME (already completed)"
    return 0
  fi

  export CURRENT_PHASE="$PHASE_NAME"

  log info "═══════════════════════════════════════════"
  log info "Starting phase: $PHASE_NAME"
  log info "═══════════════════════════════════════════"

  local PHASE_START
  PHASE_START=$(date +%s)

  # Run with retry (3 attempts, 10s sleep between)
  local attempt=1
  while [ $attempt -le 3 ]; do
    if $PHASE_FUNC; then
      break
    fi
    log warn "Phase $PHASE_NAME attempt $attempt failed. Retrying..."
    ((attempt++))
    sleep 10
  done

  if [ $attempt -gt 3 ]; then
    state_mark_failed "$PHASE_NAME" "Failed after 3 attempts"
    export CURRENT_PHASE=""
    log error "Phase $PHASE_NAME failed after 3 attempts. Skipping."
    notify "❌ Phase $PHASE_NAME FAILED on $TARGET"
    return 1
  fi

  local PHASE_END
  PHASE_END=$(date +%s)
  local ELAPSED=$((PHASE_END - PHASE_START))

  state_mark_done "$PHASE_NAME"
  export CURRENT_PHASE=""
  log success "Phase $PHASE_NAME completed in ${ELAPSED}s"
  notify "✅ Phase $PHASE_NAME done on $TARGET (${ELAPSED}s)"
}

# ─── PRINT COMPLETION DASHBOARD ─────────────────────────────
print_dashboard() {
  local subs live urls js params crit high secrets takeovers
  subs=$(wc -l < "$WORKDIR/01_subdomains/all_subdomains.txt" 2>/dev/null || echo 0)
  live=$(wc -l < "$WORKDIR/03_live_hosts/live.txt" 2>/dev/null || echo 0)
  urls=$(wc -l < "$WORKDIR/05_urls/all_urls.txt" 2>/dev/null || echo 0)
  js=$(wc -l < "$WORKDIR/07_js/js_urls.txt" 2>/dev/null || echo 0)
  params=$(wc -l < "$WORKDIR/08_params/all_params.txt" 2>/dev/null || echo 0)
  crit=$(wc -l < "$WORKDIR/09_vulns/nuclei_critical.txt" 2>/dev/null || echo 0)
  high=$(wc -l < "$WORKDIR/09_vulns/nuclei_high.txt" 2>/dev/null || echo 0)
  secrets=$(wc -l < "$WORKDIR/11_secrets/regex_secrets.txt" 2>/dev/null || echo 0)
  takeovers=$(wc -l < "$WORKDIR/09_vulns/takeovers_nuclei.txt" 2>/dev/null || echo 0)

  # Trim whitespace
  subs=$(echo "$subs" | tr -d ' ')
  live=$(echo "$live" | tr -d ' ')
  urls=$(echo "$urls" | tr -d ' ')
  js=$(echo "$js" | tr -d ' ')
  params=$(echo "$params" | tr -d ' ')
  crit=$(echo "$crit" | tr -d ' ')
  high=$(echo "$high" | tr -d ' ')
  secrets=$(echo "$secrets" | tr -d ' ')
  takeovers=$(echo "$takeovers" | tr -d ' ')

  echo ""
  echo -e "${CYAN}╔══════════════════════════════════════════════════════════╗${RESET}"
  printf "${CYAN}║${RESET}${BOLD}          RECON COMPLETE — %-28s${RESET}${CYAN}║${RESET}\n" "$TARGET"
  echo -e "${CYAN}╠══════════════════════════════════════════════════════════╣${RESET}"
  printf "${CYAN}║${RESET}  Subdomains Discovered  ................  %-14s ${CYAN}║${RESET}\n" "$subs"
  printf "${CYAN}║${RESET}  Live Hosts             ................  %-14s ${CYAN}║${RESET}\n" "$live"
  printf "${CYAN}║${RESET}  URLs Collected         ................  %-14s ${CYAN}║${RESET}\n" "$urls"
  printf "${CYAN}║${RESET}  JS Files               ................  %-14s ${CYAN}║${RESET}\n" "$js"
  printf "${CYAN}║${RESET}  Parameters             ................  %-14s ${CYAN}║${RESET}\n" "$params"
  echo -e "${CYAN}╠══════════════════════════════════════════════════════════╣${RESET}"
  printf "${CYAN}║${RESET}  ${RED}⚠  Critical Findings${RESET}   ................  %-14s ${CYAN}║${RESET}\n" "$crit"
  printf "${CYAN}║${RESET}  ${YELLOW}⚠  High Findings${RESET}       ................  %-14s ${CYAN}║${RESET}\n" "$high"
  printf "${CYAN}║${RESET}  ${YELLOW}⚠  Secrets Found${RESET}       ................  %-14s ${CYAN}║${RESET}\n" "$secrets"
  printf "${CYAN}║${RESET}  ${YELLOW}⚠  Takeover Candidates${RESET} ................  %-14s ${CYAN}║${RESET}\n" "$takeovers"
  echo -e "${CYAN}╠══════════════════════════════════════════════════════════╣${RESET}"
  printf "${CYAN}║${RESET}  Reports saved to: %-36s ${CYAN}║${RESET}\n" "${WORKDIR}/reports/"
  echo -e "${CYAN}╚══════════════════════════════════════════════════════════╝${RESET}"
  echo ""
}
