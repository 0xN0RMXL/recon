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
      local leaf
      leaf=$(echo "$key" | grep -oE '[^.]+$')
      grep -E "^\s+${leaf}:" "$file" | head -1 | sed 's/.*:\s*"\?\([^"]*\)"\?.*/\1/' | sed 's/^\s*//;s/\s*$//'
    fi
  }

  _export_yaml_key() {
    local var_name="$1"
    local yaml_key="$2"
    local value
    value=$(_yaml_val "$yaml_key" "$config_file")
    printf -v "$var_name" '%s' "$value"
    export "${var_name?}"
  }

  # ── API Keys
  _export_yaml_key CHAOS_KEY '.api_keys.chaos'
  _export_yaml_key GITHUB_TOKEN '.api_keys.github'
  _export_yaml_key SHODAN_KEY '.api_keys.shodan'
  _export_yaml_key SECURITYTRAILS_KEY '.api_keys.securitytrails'
  _export_yaml_key CENSYS_ID '.api_keys.censys_id'
  _export_yaml_key CENSYS_SECRET '.api_keys.censys_secret'
  _export_yaml_key VIRUSTOTAL_KEY '.api_keys.virustotal'
  _export_yaml_key URLSCAN_KEY '.api_keys.urlscan'
  _export_yaml_key OTX_KEY '.api_keys.otx'
  _export_yaml_key NETLAS_KEY '.api_keys.netlas'
  _export_yaml_key C99_KEY '.api_keys.c99'
  _export_yaml_key FOFA_EMAIL '.api_keys.fofa_email'
  _export_yaml_key FOFA_KEY '.api_keys.fofa_key'
  _export_yaml_key ZOOMEYE_KEY '.api_keys.zoomeye'

  # ── Burp Suite
  _export_yaml_key BURP_ENABLED '.burp.enabled'
  _export_yaml_key BURP_PROXY '.burp.proxy'
  _export_yaml_key BURP_API_URL '.burp.api_url'
  _export_yaml_key BURP_API_KEY '.burp.api_key'
  _export_yaml_key BURP_AUTO_SCAN '.burp.auto_scan'
  _export_yaml_key BURP_SEND_INTERESTING '.burp.send_interesting'

  # Defaults
  [ -z "$BURP_ENABLED" ] && export BURP_ENABLED="false"
  [ -z "$BURP_PROXY" ] && export BURP_PROXY="http://127.0.0.1:8080"
  [ -z "$BURP_AUTO_SCAN" ] && export BURP_AUTO_SCAN="false"
  [ -z "$BURP_SEND_INTERESTING" ] && export BURP_SEND_INTERESTING="true"

  # ── Notifications
  _export_yaml_key TELEGRAM_BOT_TOKEN '.notifications.telegram_bot_token'
  _export_yaml_key TELEGRAM_CHAT_ID '.notifications.telegram_chat_id'
  _export_yaml_key DISCORD_WEBHOOK '.notifications.discord_webhook'
  _export_yaml_key SLACK_WEBHOOK '.notifications.slack_webhook'

  # ── Performance
  _export_yaml_key HTTPX_THREADS '.performance.httpx_threads'
  _export_yaml_key NUCLEI_RATE '.performance.nuclei_rate'
  _export_yaml_key FFUF_THREADS '.performance.ffuf_threads'
  _export_yaml_key NAABU_RATE '.performance.naabu_rate'
  _export_yaml_key GAU_THREADS '.performance.gau_threads'
  _export_yaml_key KATANA_DEPTH '.performance.katana_depth'
  _export_yaml_key KATANA_CONCURRENCY '.performance.katana_concurrency'
  _export_yaml_key ANALYZER_MAX_HOSTS '.performance.analyzer_max_hosts'
  _export_yaml_key CONTENT_MAX_HOSTS '.performance.content_max_hosts'
  _export_yaml_key VULNS_MAX_HOSTS '.performance.vulns_max_hosts'
  _export_yaml_key PARAMS_MAX_HOSTS '.performance.params_max_hosts'
  _export_yaml_key WAYMORE_FALLBACK_MAX_HOSTS '.performance.waymore_fallback_max_hosts'
  _export_yaml_key HYPOTHESIS_MAX_PER_PATTERN '.performance.hypothesis_max_per_pattern'
  _export_yaml_key SQLMAP_MAX_TARGETS '.performance.sqlmap_max_targets'
  _export_yaml_key SQLMAP_MAX_CONCURRENT '.performance.sqlmap_max_concurrent'

  # Defaults
  [ -z "$HTTPX_THREADS" ] && export HTTPX_THREADS=200
  [ -z "$NUCLEI_RATE" ] && export NUCLEI_RATE=150
  [ -z "$FFUF_THREADS" ] && export FFUF_THREADS=200
  [ -z "$NAABU_RATE" ] && export NAABU_RATE=2000
  [ -z "$GAU_THREADS" ] && export GAU_THREADS=200
  [ -z "$KATANA_DEPTH" ] && export KATANA_DEPTH=5
  [ -z "$KATANA_CONCURRENCY" ] && export KATANA_CONCURRENCY=50
  [ -z "$ANALYZER_MAX_HOSTS" ] && export ANALYZER_MAX_HOSTS=50
  [ -z "$CONTENT_MAX_HOSTS" ] && export CONTENT_MAX_HOSTS=20
  [ -z "$VULNS_MAX_HOSTS" ] && export VULNS_MAX_HOSTS=0
  [ -z "$PARAMS_MAX_HOSTS" ] && export PARAMS_MAX_HOSTS=20
  [ -z "$WAYMORE_FALLBACK_MAX_HOSTS" ] && export WAYMORE_FALLBACK_MAX_HOSTS=20
  [ -z "$HYPOTHESIS_MAX_PER_PATTERN" ] && export HYPOTHESIS_MAX_PER_PATTERN=20
  [ -z "$SQLMAP_MAX_TARGETS" ] && export SQLMAP_MAX_TARGETS=20
  [ -z "$SQLMAP_MAX_CONCURRENT" ] && export SQLMAP_MAX_CONCURRENT=4

  # ── Wordlists (relative to SCRIPT_DIR/data/wordlists/)
  local wl_base="${SCRIPT_DIR}/data/wordlists"
  local wl_dns_bruteforce wl_dns_best wl_dns_jhaddix wl_web_raft_large_dirs wl_web_raft_large_files wl_web_common wl_web_params
  wl_dns_bruteforce=$(_yaml_val '.wordlists.dns_bruteforce' "$config_file")
  wl_dns_best=$(_yaml_val '.wordlists.dns_best' "$config_file")
  wl_dns_jhaddix=$(_yaml_val '.wordlists.dns_jhaddix' "$config_file")
  wl_web_raft_large_dirs=$(_yaml_val '.wordlists.web_raft_large_dirs' "$config_file")
  wl_web_raft_large_files=$(_yaml_val '.wordlists.web_raft_large_files' "$config_file")
  wl_web_common=$(_yaml_val '.wordlists.web_common' "$config_file")
  wl_web_params=$(_yaml_val '.wordlists.web_params' "$config_file")

  WORDLIST_DNS_BRUTEFORCE="${wl_base}/${wl_dns_bruteforce}"
  WORDLIST_DNS_BEST="${wl_base}/${wl_dns_best}"
  WORDLIST_DNS_JHADDIX="${wl_base}/${wl_dns_jhaddix}"
  WORDLIST_WEB_RAFT_LARGE_DIRS="${wl_base}/${wl_web_raft_large_dirs}"
  WORDLIST_WEB_RAFT_LARGE_FILES="${wl_base}/${wl_web_raft_large_files}"
  WORDLIST_WEB_COMMON="${wl_base}/${wl_web_common}"
  WORDLIST_WEB_PARAMS="${wl_base}/${wl_web_params}"
  export WORDLIST_DNS_BRUTEFORCE WORDLIST_DNS_BEST WORDLIST_DNS_JHADDIX
  export WORDLIST_WEB_RAFT_LARGE_DIRS WORDLIST_WEB_RAFT_LARGE_FILES WORDLIST_WEB_COMMON WORDLIST_WEB_PARAMS
  export RESOLVERS="${SCRIPT_DIR}/data/resolvers/resolvers.txt"

  # ── Scope
  SCOPE_STRICT=$(_yaml_val '.scope.strict' "$config_file")
  export SCOPE_STRICT
  [ -z "$SCOPE_STRICT" ] && export SCOPE_STRICT="false"

  # ── Output
  OUTPUT_BASE=$(_yaml_val '.output.base_dir' "$config_file")
  export OUTPUT_BASE
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
  echo "$1" | sed 's/^\*\.//g' | sed 's/[^a-zA-Z0-9._-]/_/g'
}
