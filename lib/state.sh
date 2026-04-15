#!/bin/bash
# ============================================================
# RECON Framework — lib/state.sh
# Checkpoint state machine for phase tracking and resume logic
# ============================================================

# ─── INITIALIZE STATE ────────────────────────────────────────
state_init() {
  local state_file="$WORKDIR/meta/state.json"
  mkdir -p "$WORKDIR/meta"
  if [ ! -f "$state_file" ]; then
    echo '{}' > "$state_file"
    log info "State file initialized: $state_file"
  fi
}

# ─── MARK PHASE AS DONE ─────────────────────────────────────
state_mark_done() {
  local phase="$1"
  local state_file="$WORKDIR/meta/state.json"
  local ts
  ts=$(date -Iseconds 2>/dev/null || date '+%Y-%m-%dT%H:%M:%S')

  if command -v jq &>/dev/null; then
    jq --arg p "$phase" --arg t "$ts" \
      '.[$p] = {"status":"done","ts":$t}' \
      "$state_file" > "${state_file}.tmp" && \
    mv "${state_file}.tmp" "$state_file"
  else
    # Fallback: simple append (not ideal but works)
    sed -i "s/}$/,\"${phase}\":{\"status\":\"done\",\"ts\":\"${ts}\"}}/" "$state_file" 2>/dev/null
  fi
}

# ─── MARK PHASE AS FAILED ───────────────────────────────────
state_mark_failed() {
  local phase="$1"
  local error_msg="${2:-unknown error}"
  local state_file="$WORKDIR/meta/state.json"
  local ts
  ts=$(date -Iseconds 2>/dev/null || date '+%Y-%m-%dT%H:%M:%S')

  if command -v jq &>/dev/null; then
    jq --arg p "$phase" --arg t "$ts" --arg e "$error_msg" \
      '.[$p] = {"status":"failed","ts":$t,"error":$e}' \
      "$state_file" > "${state_file}.tmp" && \
    mv "${state_file}.tmp" "$state_file"
  else
    sed -i "s/}$/,\"${phase}\":{\"status\":\"failed\",\"ts\":\"${ts}\",\"error\":\"${error_msg}\"}}/" "$state_file" 2>/dev/null
  fi
}

# ─── CHECK IF PHASE SHOULD BE SKIPPED ────────────────────────
# Returns 0 (skip) or 1 (run)
state_should_skip() {
  local phase="$1"
  local status
  status=$(state_get_status "$phase")

  # Always run if --force is set
  [ "$FORCE" = "true" ] && return 1

  # Run if status is not "done"
  [ "$status" != "done" ] && return 1

  # Check that the primary output file for this phase exists and is non-empty
  local output_file=""
  case "$phase" in
    subdomains)   output_file="$WORKDIR/01_subdomains/all_subdomains.txt" ;;
    dns)          output_file="$WORKDIR/02_dns/resolved.txt" ;;
    probe)        output_file="$WORKDIR/03_live_hosts/live.txt" ;;
    ports)        output_file="$WORKDIR/04_ports/naabu_ports.txt" ;;
    urls)         output_file="$WORKDIR/05_urls/all_urls.txt" ;;
    content)      output_file="$WORKDIR/06_content/ffuf_dirs.txt" ;;
    js)           output_file="$WORKDIR/07_js/js_urls.txt" ;;
    params)       output_file="$WORKDIR/08_params/all_params.txt" ;;
    vulns)        output_file="$WORKDIR/09_vulns/nuclei_all.txt" ;;
    cloud)        output_file="$WORKDIR/10_cloud/buckets.txt" ;;
    secrets)      output_file="$WORKDIR/11_secrets/regex_secrets.txt" ;;
    screenshots)  output_file="$WORKDIR/12_screenshots/gowitness.db" ;;
    api)          output_file="$WORKDIR/13_api/kiterunner_routes.txt" ;;
    github)       output_file="$WORKDIR/14_github/gitdorker_results.txt" ;;
    origins)      output_file="$WORKDIR/15_origins/origin_ips.txt" ;;
    analyzer)     output_file="$WORKDIR/intelligence/response_anomalies.txt" ;;
    hypothesis)   output_file="$WORKDIR/intelligence/hypotheses.txt" ;;
    chaining)     output_file="$WORKDIR/intelligence/bug_chains.txt" ;;
    scoring)      output_file="$WORKDIR/reports/prioritized_targets.json" ;;
    decision)     output_file="$WORKDIR/intelligence/decision_report.txt" ;;
    reporting)    output_file="$WORKDIR/reports/summary.json" ;;
    *)            return 1 ;;
  esac

  # If output file is missing or empty, run the phase
  if [ -n "$output_file" ] && [ ! -s "$output_file" ]; then
    return 1
  fi

  # All checks passed — skip this phase
  return 0
}

# ─── GET PHASE STATUS ────────────────────────────────────────
state_get_status() {
  local phase="$1"
  local state_file="$WORKDIR/meta/state.json"

  if [ ! -f "$state_file" ]; then
    echo "pending"
    return
  fi

  if command -v jq &>/dev/null; then
    local status
    status=$(jq -r --arg p "$phase" '.[$p].status // "pending"' "$state_file" 2>/dev/null)
    echo "$status"
  else
    if grep -q "\"${phase}\"" "$state_file" 2>/dev/null; then
      if grep -q "\"${phase}\".*\"done\"" "$state_file"; then
        echo "done"
      elif grep -q "\"${phase}\".*\"failed\"" "$state_file"; then
        echo "failed"
      else
        echo "pending"
      fi
    else
      echo "pending"
    fi
  fi
}

# ─── PRINT STATE SUMMARY TABLE ──────────────────────────────
state_print_summary() {
  local phases=("subdomains" "dns" "probe" "ports" "urls" "content" "js" "params"
                "vulns" "cloud" "secrets" "screenshots" "api" "github" "origins"
                "analyzer" "hypothesis" "chaining" "scoring" "decision" "reporting")

  echo ""
  echo -e "${CYAN}╔══════════════════════════════════════════════════════╗${RESET}"
  echo -e "${CYAN}║          RECON — Phase Status Summary                ║${RESET}"
  echo -e "${CYAN}╠══════════════════════════════════════════════════════╣${RESET}"

  for phase in "${phases[@]}"; do
    local status
    status=$(state_get_status "$phase")
    local icon
    case "$status" in
      done)    icon="${GREEN}✅${RESET}" ;;
      failed)  icon="${RED}❌${RESET}" ;;
      pending) icon="${YELLOW}⏳${RESET}" ;;
      *)       icon="❓" ;;
    esac
    printf "${CYAN}║${RESET}  %-20s %b  %-10s               ${CYAN}║${RESET}\n" "$phase" "$icon" "$status"
  done

  echo -e "${CYAN}╚══════════════════════════════════════════════════════╝${RESET}"
  echo ""
}
