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

state_phase_checkpoint_file() {
  local phase="$1"
  echo "$WORKDIR/meta/.phase_${phase}.inprogress"
}

state_require_jq() {
  if ! command -v jq &>/dev/null; then
    log error "jq is required for safe state updates but was not found"
    return 1
  fi
  return 0
}

state_mark_running() {
  local phase="$1"
  local attempt="${2:-1}"
  local state_file="$WORKDIR/meta/state.json"
  local checkpoint_file
  local ts

  checkpoint_file=$(state_phase_checkpoint_file "$phase")
  ts=$(date -Iseconds 2>/dev/null || date '+%Y-%m-%dT%H:%M:%S')

  echo "running attempt=$attempt ts=$ts" > "$checkpoint_file"

  state_require_jq || return 1
  [ -f "$state_file" ] || echo '{}' > "$state_file"

  if ! jq --arg p "$phase" --arg t "$ts" --argjson a "$attempt" \
    '.[$p] = {"status":"running","ts":$t,"attempt":$a}' \
    "$state_file" > "${state_file}.tmp"; then
    rm -f "${state_file}.tmp"
    log error "Failed to update state for running phase: $phase"
    return 1
  fi

  if ! mv "${state_file}.tmp" "$state_file"; then
    rm -f "${state_file}.tmp"
    log error "Failed to finalize state update for running phase: $phase"
    return 1
  fi
}

state_clear_running() {
  local phase="$1"
  local checkpoint_file
  checkpoint_file=$(state_phase_checkpoint_file "$phase")
  rm -f "$checkpoint_file" 2>/dev/null || true
}

state_phase_has_partial_artifact() {
  local phase="$1"
  local checkpoint_file
  checkpoint_file=$(state_phase_checkpoint_file "$phase")
  [ -f "$checkpoint_file" ]
}

state_primary_output_file() {
  local phase="$1"
  case "$phase" in
    subdomains)   echo "$WORKDIR/01_subdomains/all_subdomains.txt" ;;
    dns)          echo "$WORKDIR/02_dns/resolved.txt" ;;
    probe)        echo "$WORKDIR/03_live_hosts/live.txt" ;;
    ports)        echo "$WORKDIR/04_ports/naabu_ports.txt" ;;
    urls)         echo "$WORKDIR/05_urls/all_urls.txt" ;;
    content)      echo "$WORKDIR/06_content/ffuf_dirs.txt" ;;
    js)           echo "$WORKDIR/07_js/js_urls.txt" ;;
    params)       echo "$WORKDIR/08_params/all_params.txt" ;;
    vulns)        echo "$WORKDIR/09_vulns/nuclei_all.txt" ;;
    cloud)        echo "$WORKDIR/10_cloud/buckets.txt" ;;
    secrets)      echo "$WORKDIR/11_secrets/regex_secrets.txt" ;;
    screenshots)  echo "$WORKDIR/12_screenshots/gowitness.db" ;;
    api)          echo "$WORKDIR/13_api/kiterunner_routes.txt" ;;
    github)       echo "$WORKDIR/14_github/gitdorker_results.txt" ;;
    origins)      echo "$WORKDIR/15_origins/origin_ips.txt" ;;
    analyzer)     echo "$WORKDIR/intelligence/response_anomalies.txt" ;;
    hypothesis)   echo "$WORKDIR/intelligence/hypotheses.txt" ;;
    chaining)     echo "$WORKDIR/intelligence/bug_chains.txt" ;;
    scoring)      echo "$WORKDIR/reports/prioritized_targets.json" ;;
    decision)     echo "$WORKDIR/intelligence/decision_report.txt" ;;
    reporting)    echo "$WORKDIR/reports/summary.json" ;;
    *)            echo "" ;;
  esac
}

state_phase_output_valid() {
  local phase="$1"
  local output_file

  output_file=$(state_primary_output_file "$phase")
  [ -z "$output_file" ] && return 0

  case "$phase" in
    subdomains)
      [ -s "$output_file" ] || return 1
      grep -Eq '^[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)+$' "$output_file" 2>/dev/null
      ;;
    dns)
      [ -s "$output_file" ] || return 1
      grep -Eq '([0-9]{1,3}\.){3}[0-9]{1,3}|[0-9a-fA-F:]{2,}:[0-9a-fA-F:]+' "$output_file" 2>/dev/null
      ;;
    probe|urls)
      [ -s "$output_file" ] || return 1
      grep -Eq '^https?://[^ ]+' "$output_file" 2>/dev/null
      ;;
    ports)
      [ -s "$output_file" ] || return 1
      grep -Eq '^[^ :]+:[0-9]{1,5}$' "$output_file" 2>/dev/null
      ;;
    decision)
      [ -s "$output_file" ] || return 1
      grep -Eq 'Priority Decision Report|PRIORITY' "$output_file" 2>/dev/null
      ;;
    chaining)
      [ -s "$output_file" ] || return 1
      grep -Eq 'Bug Chain Analysis|\[CHAIN\]' "$output_file" 2>/dev/null
      ;;
    scoring)
      [ -s "$output_file" ] || return 1
      if command -v jq &>/dev/null; then
        jq -e 'type == "array"' "$output_file" >/dev/null 2>/dev/null
      else
        grep -Eq '^\[' "$output_file" 2>/dev/null
      fi
      ;;
    reporting)
      [ -s "$output_file" ] || return 1
      if command -v jq &>/dev/null; then
        jq -e '.target and .timestamp and .stats' "$output_file" >/dev/null 2>/dev/null
      else
        grep -Eq '"target"|"timestamp"|"stats"' "$output_file" 2>/dev/null
      fi
      ;;
    *)
      # Non-foundational phases can be informational and may legitimately be empty.
      return 0
      ;;
  esac
}

# ─── MARK PHASE AS DONE ─────────────────────────────────────
state_mark_done() {
  local phase="$1"
  local state_file="$WORKDIR/meta/state.json"
  local ts
  ts=$(date -Iseconds 2>/dev/null || date '+%Y-%m-%dT%H:%M:%S')

  state_require_jq || return 1
  [ -f "$state_file" ] || echo '{}' > "$state_file"

  if ! jq --arg p "$phase" --arg t "$ts" \
    '.[$p] = {"status":"done","ts":$t}' \
    "$state_file" > "${state_file}.tmp"; then
    rm -f "${state_file}.tmp"
    log error "Failed to update state for completed phase: $phase"
    return 1
  fi

  if ! mv "${state_file}.tmp" "$state_file"; then
    rm -f "${state_file}.tmp"
    log error "Failed to finalize state update for completed phase: $phase"
    return 1
  fi
}

# ─── MARK PHASE AS FAILED ───────────────────────────────────
state_mark_failed() {
  local phase="$1"
  local error_msg="${2:-unknown error}"
  local state_file="$WORKDIR/meta/state.json"
  local ts
  ts=$(date -Iseconds 2>/dev/null || date '+%Y-%m-%dT%H:%M:%S')

  state_require_jq || return 1
  [ -f "$state_file" ] || echo '{}' > "$state_file"

  if ! jq --arg p "$phase" --arg t "$ts" --arg e "$error_msg" \
    '.[$p] = {"status":"failed","ts":$t,"error":$e}' \
    "$state_file" > "${state_file}.tmp"; then
    rm -f "${state_file}.tmp"
    log error "Failed to update state for failed phase: $phase"
    return 1
  fi

  if ! mv "${state_file}.tmp" "$state_file"; then
    rm -f "${state_file}.tmp"
    log error "Failed to finalize state update for failed phase: $phase"
    return 1
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

  # If a partial artifact marker exists, force rerun.
  if state_phase_has_partial_artifact "$phase"; then
    return 1
  fi

  # If output is missing or fails sanity checks, rerun.
  if ! state_phase_output_valid "$phase"; then
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
