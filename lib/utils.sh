# Safe file helpers for runtime/reporting
safe_touch() {
  local file="$1"
  if ! touch "$file" 2>/dev/null; then
    echo "[ERROR] Cannot create or write to $file (permission denied)" >&2
    return 1
  fi
  return 0
}

safe_mkdir() {
  local dir="$1"
  if [ ! -d "$dir" ]; then
    if ! mkdir -p "$dir" 2>/dev/null; then
      echo "[ERROR] Cannot create directory $dir (permission denied)" >&2
      return 1
    fi
  fi
  return 0
}
#!/bin/bash
# ============================================================
# RECON Framework — lib/utils.sh
# Banner, logging, notifications, config loading, safety helpers
# ============================================================

# ─── COLORS ──────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

# ─── VERSION ─────────────────────────────────────────────────
VERSION="1.0.0"

# ─── LOG FILE (set by init_workspace) ────────────────────────
LOG_FILE=""
NO_NOTIFY="${NO_NOTIFY:-false}"
SKIP_PHASES="${SKIP_PHASES:-}"
ONLY_PHASE="${ONLY_PHASE:-}"
FORCE="${FORCE:-false}"

# ─── BANNER ──────────────────────────────────────────────────
banner() {
  echo -e "${CYAN}"
  echo '  ██████╗ ███████╗ ██████╗ ██████╗ ███╗   ██╗'
  echo '  ██╔══██╗██╔════╝██╔════╝██╔═══██╗████╗  ██║'
  echo '  ██████╔╝█████╗  ██║     ██║   ██║██╔██╗ ██║'
  echo '  ██╔══██╗██╔══╝  ██║     ██║   ██║██║╚██╗██║'
  echo '  ██║  ██║███████╗╚██████╗╚██████╔╝██║ ╚████║'
  echo '  ╚═╝  ╚═╝╚══════╝ ╚═════╝ ╚═════╝ ╚═╝  ╚═══╝'
  echo -e "${RESET}"
  echo -e "${BOLD}  Autonomous Bug Bounty Recon Framework v${VERSION}${RESET}"
  echo -e "${CYAN}  ────────────────────────────────────────────${RESET}"
  echo ""
  echo -e "${YELLOW}  ⚠  LEGAL DISCLAIMER${RESET}"
  echo -e "  This tool is designed for ${BOLD}authorized security testing${RESET} and"
  echo -e "  ${BOLD}bug bounty programs ONLY${RESET}. Unauthorized use against systems"
  echo -e "  you do not own or have written permission to test is ${RED}ILLEGAL${RESET}."
  echo -e "  The authors accept ${BOLD}no liability${RESET} for misuse."
  echo ""
  echo -e "${CYAN}  ────────────────────────────────────────────${RESET}"
  echo ""
}

# ─── LOGGING ─────────────────────────────────────────────────
log() {
  local level="$1"
  local msg="$2"
  local ts
  ts=$(date '+%Y-%m-%d %H:%M:%S')

  case "$level" in
    info)    local color="${CYAN}";   local prefix="[*]" ;;
    success) local color="${GREEN}";  local prefix="[+]" ;;
    warn)    local color="${YELLOW}"; local prefix="[!]" ;;
    error)   local color="${RED}";    local prefix="[-]" ;;
    *)       local color="${RESET}";  local prefix="[?]" ;;
  esac

  # Colored terminal output
  echo -e "${color}${prefix} ${msg}${RESET}"

  # Plain log file (append)
  if [ -n "$LOG_FILE" ] && [ -d "$(dirname "$LOG_FILE")" ]; then
    echo "[$ts] [$level] $msg" >> "$LOG_FILE"
  fi
}

# ─── NOTIFICATION SYSTEM ─────────────────────────────────────
notify() {
  local MESSAGE="$1"
  local FULL_MSG="[RECON:${TARGET:-unknown}] $MESSAGE"

  # Skip if --no-notify flag is set
  [ "$NO_NOTIFY" = "true" ] && return 0

  # Telegram
  if [ -n "$TELEGRAM_BOT_TOKEN" ] && [ -n "$TELEGRAM_CHAT_ID" ]; then
    curl -sk -X POST \
      "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
      -d "chat_id=${TELEGRAM_CHAT_ID}" \
      -d "text=${FULL_MSG}" \
      -d "parse_mode=HTML" > /dev/null 2>&1
  fi

  # Discord
  if [ -n "$DISCORD_WEBHOOK" ]; then
    curl -sk -X POST "$DISCORD_WEBHOOK" \
      -H "Content-Type: application/json" \
      -d "{\"content\": \"$FULL_MSG\"}" > /dev/null 2>&1
  fi

  # Slack
  if [ -n "$SLACK_WEBHOOK" ]; then
    curl -sk -X POST "$SLACK_WEBHOOK" \
      -H "Content-Type: application/json" \
      -d "{\"text\": \"$FULL_MSG\"}" > /dev/null 2>&1
  fi
}

# ─── CONFIG LOADER ───────────────────────────────────────────
load_config() {
  local config_file="${CONFIG:-config.yaml}"

  if [ ! -f "$config_file" ]; then
    log error "Config file not found: $config_file"
    log info "Run: cp config.yaml.example config.yaml && nano config.yaml"
    exit 1
  fi

  log info "Loading config from $config_file"

  # Helper: extract YAML value (supports yq or awk fallback)
  _yaml_val() {
    local key="$1"
    local file="$2"
    if command -v yq &>/dev/null; then
      yq -r "$key" "$file" 2>/dev/null | grep -v "^null$"
    else
      # Fallback: basic awk parser for simple key: value pairs
      local flat_key
      flat_key=$(echo "$key" | sed 's/\.\([^.]*\)$//' | sed 's/^\.//;s/\./_/g')
      local leaf
      leaf=$(echo "$key" | grep -oE '[^.]+$')
      grep -E "^\s+${leaf}:" "$file" | head -1 | sed 's/.*:\s*"\?\([^"]*\)"\?.*/\1/' | sed 's/^\s*//;s/\s*$//'
    fi
  }

  # ── API Keys
  export CHAOS_KEY=$(_yaml_val '.api_keys.chaos' "$config_file")
  export GITHUB_TOKEN=$(_yaml_val '.api_keys.github' "$config_file")
  export SHODAN_KEY=$(_yaml_val '.api_keys.shodan' "$config_file")
  export SECURITYTRAILS_KEY=$(_yaml_val '.api_keys.securitytrails' "$config_file")
  export CENSYS_ID=$(_yaml_val '.api_keys.censys_id' "$config_file")
  export CENSYS_SECRET=$(_yaml_val '.api_keys.censys_secret' "$config_file")
  export VIRUSTOTAL_KEY=$(_yaml_val '.api_keys.virustotal' "$config_file")
  export URLSCAN_KEY=$(_yaml_val '.api_keys.urlscan' "$config_file")
  export OTX_KEY=$(_yaml_val '.api_keys.otx' "$config_file")
  export NETLAS_KEY=$(_yaml_val '.api_keys.netlas' "$config_file")
  export C99_KEY=$(_yaml_val '.api_keys.c99' "$config_file")
  export FOFA_EMAIL=$(_yaml_val '.api_keys.fofa_email' "$config_file")
  export FOFA_KEY=$(_yaml_val '.api_keys.fofa_key' "$config_file")
  export ZOOMEYE_KEY=$(_yaml_val '.api_keys.zoomeye' "$config_file")

  # ── Burp Suite
  export BURP_ENABLED=$(_yaml_val '.burp.enabled' "$config_file")
  export BURP_PROXY=$(_yaml_val '.burp.proxy' "$config_file")
  export BURP_API_URL=$(_yaml_val '.burp.api_url' "$config_file")
  export BURP_API_KEY=$(_yaml_val '.burp.api_key' "$config_file")
  export BURP_AUTO_SCAN=$(_yaml_val '.burp.auto_scan' "$config_file")
  export BURP_SEND_INTERESTING=$(_yaml_val '.burp.send_interesting' "$config_file")

  # Defaults
  [ -z "$BURP_ENABLED" ] && export BURP_ENABLED="false"
  [ -z "$BURP_PROXY" ] && export BURP_PROXY="http://127.0.0.1:8080"
  [ -z "$BURP_AUTO_SCAN" ] && export BURP_AUTO_SCAN="false"
  [ -z "$BURP_SEND_INTERESTING" ] && export BURP_SEND_INTERESTING="true"

  # ── Notifications
  export TELEGRAM_BOT_TOKEN=$(_yaml_val '.notifications.telegram_bot_token' "$config_file")
  export TELEGRAM_CHAT_ID=$(_yaml_val '.notifications.telegram_chat_id' "$config_file")
  export DISCORD_WEBHOOK=$(_yaml_val '.notifications.discord_webhook' "$config_file")
  export SLACK_WEBHOOK=$(_yaml_val '.notifications.slack_webhook' "$config_file")

  # ── Performance
  export HTTPX_THREADS=$(_yaml_val '.performance.httpx_threads' "$config_file")
  export NUCLEI_RATE=$(_yaml_val '.performance.nuclei_rate' "$config_file")
  export FFUF_THREADS=$(_yaml_val '.performance.ffuf_threads' "$config_file")
  export NAABU_RATE=$(_yaml_val '.performance.naabu_rate' "$config_file")
  export GAU_THREADS=$(_yaml_val '.performance.gau_threads' "$config_file")
  export KATANA_DEPTH=$(_yaml_val '.performance.katana_depth' "$config_file")
  export KATANA_CONCURRENCY=$(_yaml_val '.performance.katana_concurrency' "$config_file")

  # Defaults
  [ -z "$HTTPX_THREADS" ] && export HTTPX_THREADS=200
  [ -z "$NUCLEI_RATE" ] && export NUCLEI_RATE=150
  [ -z "$FFUF_THREADS" ] && export FFUF_THREADS=200
  [ -z "$NAABU_RATE" ] && export NAABU_RATE=2000
  [ -z "$GAU_THREADS" ] && export GAU_THREADS=200
  [ -z "$KATANA_DEPTH" ] && export KATANA_DEPTH=5
  [ -z "$KATANA_CONCURRENCY" ] && export KATANA_CONCURRENCY=50

  # ── Wordlists (relative to SCRIPT_DIR/data/wordlists/)
  local wl_base="${SCRIPT_DIR}/data/wordlists"
  export WORDLIST_DNS_BRUTEFORCE="${wl_base}/$(_yaml_val '.wordlists.dns_bruteforce' "$config_file")"
  export WORDLIST_DNS_BEST="${wl_base}/$(_yaml_val '.wordlists.dns_best' "$config_file")"
  export WORDLIST_DNS_JHADDIX="${wl_base}/$(_yaml_val '.wordlists.dns_jhaddix' "$config_file")"
  export WORDLIST_WEB_RAFT_LARGE_DIRS="${wl_base}/$(_yaml_val '.wordlists.web_raft_large_dirs' "$config_file")"
  export WORDLIST_WEB_RAFT_LARGE_FILES="${wl_base}/$(_yaml_val '.wordlists.web_raft_large_files' "$config_file")"
  export WORDLIST_WEB_COMMON="${wl_base}/$(_yaml_val '.wordlists.web_common' "$config_file")"
  export WORDLIST_WEB_PARAMS="${wl_base}/$(_yaml_val '.wordlists.web_params' "$config_file")"
  export RESOLVERS="${SCRIPT_DIR}/data/resolvers/resolvers.txt"

  # ── Scope
  export SCOPE_STRICT=$(_yaml_val '.scope.strict' "$config_file")
  [ -z "$SCOPE_STRICT" ] && export SCOPE_STRICT="false"

  # ── Output
  export OUTPUT_BASE=$(_yaml_val '.output.base_dir' "$config_file")
  [ -z "$OUTPUT_BASE" ] && export OUTPUT_BASE="./output"

  # ── Data directory
  export DATA_DIR="${SCRIPT_DIR}/data"

  log success "Config loaded successfully"
}

# ─── TOOL REQUIREMENT CHECK ──────────────────────────────────
require_tool() {
  local tool="$1"
  if ! command -v "$tool" &>/dev/null; then
    log warn "Tool not found: $tool. Run install.sh to install missing tools."
    return 1
  fi
}

# ─── OUTPUT VALIDATION ───────────────────────────────────────
check_output() {
  local file="$1"
  local tool="$2"
  if [ ! -s "$file" ]; then
    log warn "$tool produced no output"
    return 1
  fi
  return 0
}

# ─── SANITIZE TARGET NAME ───────────────────────────────────
sanitize_target() {
  echo "$1" | sed 's/[^a-zA-Z0-9._-]/_/g' | sed 's/^\*\.//g'
}
