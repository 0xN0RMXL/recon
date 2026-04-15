#!/bin/bash
# ============================================================
# RECON — Autonomous Bug Bounty Recon Framework
# Main Entry Point
# ============================================================

set -euo pipefail

# Root-run guard: refuse to run as root unless explicitly allowed
if [ "$(id -u)" -eq 0 ]; then
  if [ "${ALLOW_ROOT:-}" != "1" ]; then
    echo "[FATAL] Do not run recon.sh as root. Use a regular user account." >&2
    exit 1
  fi
fi

set -o pipefail

# ─── SCRIPT DIRECTORY DETECTION ──────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# ─── SOURCE ALL LIBRARIES ───────────────────────────────────
for lib in "$SCRIPT_DIR"/lib/*.sh; do
  # shellcheck source=/dev/null
  source "$lib"
done

# ─── DEFAULT VALUES ──────────────────────────────────────────
TARGET=""
TARGET_MODE=""
TARGET_LIST=""
PHASES_TO_RUN=""
SKIP_PHASES=""
ONLY_PHASE=""
FORCE="false"
RESUME="false"
NO_BURP="false"
NO_NOTIFY="false"
THREADS=""
RATE=""
CONFIG="config.yaml"
OUTPUT_BASE="./output"

# ─── PARSE CLI ARGUMENTS ────────────────────────────────────
parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -d|--domain)    TARGET="$2"; TARGET_MODE="single"; shift 2 ;;
      -w|--wildcard)  TARGET=$(echo "$2" | sed 's/^\*\.//'); TARGET_MODE="wildcard"; shift 2 ;;
      -l|--list)      TARGET_LIST="$2"; TARGET_MODE="list"; shift 2 ;;
      -c|--company)   TARGET="$2"; TARGET_MODE="company"; shift 2 ;;
      --phase)        PHASES_TO_RUN="$2"; shift 2 ;;
      --skip)         SKIP_PHASES="$2"; shift 2 ;;
      --only)         ONLY_PHASE="$2"; shift 2 ;;
      --resume)       RESUME="true"; shift ;;
      --force)        FORCE="true"; shift ;;
      --no-burp)      NO_BURP="true"; shift ;;
      --no-notify)    NO_NOTIFY="true"; shift ;;
      --threads)      THREADS="$2"; shift 2 ;;
      --rate)         RATE="$2"; shift 2 ;;
      --config)       CONFIG="$2"; shift 2 ;;
      --output)       OUTPUT_BASE="$2"; shift 2 ;;
      -h|--help)      show_usage; exit 0 ;;
      *)              log error "Unknown option: $1"; show_usage; exit 1 ;;
    esac
  done
}

show_usage() {
  echo "Usage: ./recon.sh [OPTIONS]"
  echo ""
  echo "Target Modes:"
  echo "  -d, --domain TARGET      Single domain (e.g. example.com)"
  echo "  -w, --wildcard TARGET    Wildcard domain (e.g. *.example.com)"
  echo "  -l, --list FILE          File with one domain per line"
  echo "  -c, --company NAME       Company name for OSINT expansion"
  echo ""
  echo "Execution Control:"
  echo "  --phase PHASE            Run specific phase"
  echo "  --skip PHASE             Skip specific phase"
  echo "  --only PHASE             Run ONLY this phase"
  echo "  --resume                 Resume previous run"
  echo "  --force                  Force re-run all phases"
  echo "  --no-burp                Disable Burp proxy routing"
  echo "  --no-notify              Disable notifications"
  echo "  --threads N              Override thread count"
  echo "  --rate N                 Override rate limit"
  echo "  --config PATH            Path to config file"
  echo "  --output DIR             Output directory"
  echo "  -h, --help               Show this help"
}

# ─── INTERACTIVE MENU ────────────────────────────────────────
interactive_menu() {
  echo -e "${CYAN}╔══════════════════════════════════════════╗${RESET}"
  echo -e "${CYAN}║${RESET}${BOLD}          RECON — Target Selection        ${RESET}${CYAN}║${RESET}"
  echo -e "${CYAN}╠══════════════════════════════════════════╣${RESET}"
  echo -e "${CYAN}║${RESET}  1) Single Domain    (e.g. example.com)  ${CYAN}║${RESET}"
  echo -e "${CYAN}║${RESET}  2) Wildcard         (e.g. *.example.com)${CYAN}║${RESET}"
  echo -e "${CYAN}║${RESET}  3) Domain List      (path to file)      ${CYAN}║${RESET}"
  echo -e "${CYAN}║${RESET}  4) Company OSINT    (company name)      ${CYAN}║${RESET}"
  echo -e "${CYAN}╚══════════════════════════════════════════╝${RESET}"
  echo ""
  read -rp "Enter choice [1-4]: " choice

  case "$choice" in
    1)
      TARGET_MODE="single"
      read -rp "Enter domain: " TARGET
      ;;
    2)
      TARGET_MODE="wildcard"
      read -rp "Enter wildcard domain (e.g. *.example.com): " TARGET
      TARGET=$(echo "$TARGET" | sed 's/^\*\.//')
      ;;
    3)
      TARGET_MODE="list"
      read -rp "Enter path to domain list: " TARGET_LIST
      if [ ! -f "$TARGET_LIST" ]; then
        log error "File not found: $TARGET_LIST"
        exit 1
      fi
      TARGET=$(head -1 "$TARGET_LIST")
      ;;
    4)
      TARGET_MODE="company"
      read -rp "Enter company name: " TARGET
      ;;
    *)
      log error "Invalid choice: $choice"
      exit 1
      ;;
  esac

  # Execution mode selection
  echo ""
  echo -e "${CYAN}╔══════════════════════════════════════════╗${RESET}"
  echo -e "${CYAN}║${RESET}${BOLD}        RECON — Execution Mode            ${RESET}${CYAN}║${RESET}"
  echo -e "${CYAN}╠══════════════════════════════════════════╣${RESET}"
  echo -e "${CYAN}║${RESET}  1) Full Pipeline (all phases)           ${CYAN}║${RESET}"
  echo -e "${CYAN}║${RESET}  2) Custom (select phases)               ${CYAN}║${RESET}"
  echo -e "${CYAN}║${RESET}  3) Resume previous run                  ${CYAN}║${RESET}"
  echo -e "${CYAN}╚══════════════════════════════════════════╝${RESET}"
  echo ""
  read -rp "Enter choice [1-3]: " exec_choice

  case "$exec_choice" in
    1)  ;; # Full pipeline — default
    2)  select_custom_phases ;;
    3)  RESUME="true" ;;
    *)  log error "Invalid choice"; exit 1 ;;
  esac
}

# ─── CUSTOM PHASE SELECTOR ──────────────────────────────────
select_custom_phases() {
  local phases=("subdomains" "dns" "probe" "ports" "urls" "content" "js" "params"
                "vulns" "cloud" "secrets" "screenshots" "api" "github" "origins")
  local selected=()

  echo ""
  echo -e "${BOLD}Select phases to run (toggle with number, 'a' for all, 'd' for done):${RESET}"
  echo ""

  local toggles=()
  for i in "${!phases[@]}"; do
    toggles[$i]=0
  done

  while true; do
    for i in "${!phases[@]}"; do
      local num=$((i + 1))
      if [ "${toggles[$i]}" -eq 1 ]; then
        printf "  ${GREEN}[✓]${RESET} %2d) %s\n" "$num" "${phases[$i]}"
      else
        printf "  [ ] %2d) %s\n" "$num" "${phases[$i]}"
      fi
    done

    echo ""
    read -rp "Toggle phase number (a=all, d=done): " input

    case "$input" in
      a)  for i in "${!phases[@]}"; do toggles[$i]=1; done ;;
      d)  break ;;
      *)
        if [[ "$input" =~ ^[0-9]+$ ]] && [ "$input" -ge 1 ] && [ "$input" -le "${#phases[@]}" ]; then
          local idx=$((input - 1))
          if [ "${toggles[$idx]}" -eq 0 ]; then
            toggles[$idx]=1
          else
            toggles[$idx]=0
          fi
        else
          echo -e "${RED}Invalid input.${RESET}"
        fi
        ;;
    esac

    # Clear screen for redraw
    printf '\033[%dA\033[J' $((${#phases[@]} + 3))
  done

  # Build skip list from unselected phases
  SKIP_PHASES=""
  for i in "${!phases[@]}"; do
    if [ "${toggles[$i]}" -eq 0 ]; then
      SKIP_PHASES="$SKIP_PHASES ${phases[$i]}"
    fi
  done
}

# ─── CHECK FOR PREVIOUS RUN ─────────────────────────────────
check_previous_run() {
  local target_dir
  target_dir="$OUTPUT_BASE/$(sanitize_target "$TARGET")"

  if [ -d "$target_dir" ] && [ -f "$target_dir/meta/state.json" ] && [ "$RESUME" != "true" ] && [ "$FORCE" != "true" ]; then
    echo ""
    echo -e "${YELLOW}[!] Previous run found for ${BOLD}$TARGET${RESET}"
    read -rp "    (R)esume / (O)verwrite / (C)ancel? [R/O/C]: " answer
    case "${answer,,}" in
      r|resume)   RESUME="true" ;;
      o|overwrite) FORCE="true" ;;
      c|cancel)   log info "Cancelled."; exit 0 ;;
      *)          log info "Defaulting to Resume."; RESUME="true" ;;
    esac
  fi
}

# ─── RUN ALL PHASES ──────────────────────────────────────────
run_all_phases() {
  # Phase 01-15: Recon phases
  run_phase "subdomains" "subdomains_run"
  run_phase "dns" "dns_resolution"
  run_phase "probe" "probe_hosts"
  run_phase "ports" "port_scan"
  run_phase "urls" "collect_urls"

  # Intelligence phases run after Phase 05 (non-blocking)
  run_phase "analyzer" "analyze_responses"
  run_phase "hypothesis" "generate_hypotheses"

  run_phase "content" "content_discovery"
  run_phase "js" "js_analysis"
  run_phase "params" "param_discovery"
  run_phase "vulns" "nuclei_scan"
  run_phase "cloud" "cloud_enum"
  run_phase "secrets" "secret_scan"
  run_phase "screenshots" "take_screenshots"
  run_phase "api" "api_discovery"
  run_phase "github" "github_dorking"
  run_phase "origins" "origin_ip_hunt"

  # Intelligence: post-scan phases
  run_phase "chaining" "chain_analysis"
  run_phase "scoring" "score_targets"

  # Differential recon
  diff_assets

  # Send interesting endpoints to Burp Pro
  if [ "$BURP_ENABLED" = "true" ] && [ "$NO_BURP" != "true" ]; then
    burp_send_interesting
  fi

  # Decision engine
  run_phase "decision" "decision_engine"

  # Final: Reporting
  run_phase "reporting" "generate_report"
}

# ─── HANDLE DOMAIN LIST MODE ────────────────────────────────
run_for_list() {
  local list_file="$1"

  if [ ! -f "$list_file" ]; then
    log error "Domain list file not found: $list_file"
    exit 1
  fi

  local total
  total=$(wc -l < "$list_file" | tr -d ' ')
  local current=0

  while IFS= read -r domain; do
    [ -z "$domain" ] && continue
    [[ "$domain" =~ ^# ]] && continue  # Skip comments

    current=$((current + 1))
    log info "═══════════════════════════════════════════"
    log info "Processing domain $current/$total: $domain"
    log info "═══════════════════════════════════════════"

    TARGET="$domain"
    init_workspace
    run_all_phases
    print_dashboard

  done < "$list_file"
}

# ─── MAIN ────────────────────────────────────────────────────
main() {
  banner
  parse_args "$@"

  # If no target mode specified, show interactive menu
  if [ -z "$TARGET_MODE" ]; then
    interactive_menu
  fi

  # Validate target
  if [ -z "$TARGET" ] && [ "$TARGET_MODE" != "list" ]; then
    log error "No target specified."
    show_usage
    exit 1
  fi

  # Load configuration
  load_config

  # Override Burp if --no-burp flag
  [ "$NO_BURP" = "true" ] && export BURP_ENABLED="false"

  # Override threads/rate if specified
  [ -n "$THREADS" ] && export HTTPX_THREADS="$THREADS" FFUF_THREADS="$THREADS"
  [ -n "$RATE" ] && export NUCLEI_RATE="$RATE" NAABU_RATE="$RATE"

  # Handle list mode
  if [ "$TARGET_MODE" = "list" ]; then
    run_for_list "$TARGET_LIST"
    log success "All domains in list processed."
    exit 0
  fi

  # Check for previous run
  check_previous_run

  # Initialize workspace
  init_workspace

  # Log start
  local start_time
  start_time=$(date +%s)
  log info "Recon started for: $TARGET (mode: $TARGET_MODE)"
  echo "Start: $(date)" >> "$WORKDIR/meta/execution.log"

  # Run phases
  run_all_phases

  # Calculate total time
  local end_time elapsed_total
  end_time=$(date +%s)
  elapsed_total=$((end_time - start_time))

  # Print dashboard
  print_dashboard

  # Print state summary
  state_print_summary

  log success "Total execution time: ${elapsed_total}s"
  notify "🏁 Full recon completed for $TARGET in ${elapsed_total}s — check reports"
}

# ─── ENTRY POINT ─────────────────────────────────────────────
main "$@"
