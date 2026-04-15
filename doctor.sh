#!/bin/bash
# ============================================================
# RECON Framework — doctor.sh
# Environment Health Check
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

GREEN='\033[0;32m'
RED='\033[0;31m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
RESET='\033[0m'

PASS=0
FAIL=0
WARN=0

check_tool() {
  local name="$1"
  local cmd="${2:-$1}"

  if command -v "$cmd" &>/dev/null; then
    local version
    version=$($cmd --version 2>/dev/null | head -1 | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?' | head -1 || echo "installed")
    [ -z "$version" ] && version="installed"
    printf "${CYAN}║${RESET}  %-16s ${GREEN}✅${RESET}  %-34s ${CYAN}║${RESET}\n" "$name" "v$version"
    ((PASS++))
  else
    printf "${CYAN}║${RESET}  %-16s ${RED}❌${RESET}  %-34s ${CYAN}║${RESET}\n" "$name" "MISSING — run install.sh"
    ((FAIL++))
  fi
}

check_file() {
  local name="$1"
  local path="$2"

  if [ -f "$path" ] || [ -d "$path" ]; then
    printf "${CYAN}║${RESET}  %-16s ${GREEN}✅${RESET}  %-34s ${CYAN}║${RESET}\n" "$name" "found"
    ((PASS++))
  else
    printf "${CYAN}║${RESET}  %-16s ${RED}❌${RESET}  %-34s ${CYAN}║${RESET}\n" "$name" "MISSING"
    ((FAIL++))
  fi
}

echo ""
echo -e "${CYAN}╔══════════════════════════════════════════════════════╗${RESET}"
echo -e "${CYAN}║${RESET}${BOLD}          RECON — Environment Health Check            ${RESET}${CYAN}║${RESET}"
echo -e "${CYAN}╠══════════════════════════════════════════════════════╣${RESET}"

# ── Go Tools
check_tool "subfinder"
check_tool "httpx"
check_tool "nuclei"
check_tool "naabu"
check_tool "dnsx"
check_tool "katana"
check_tool "asnmap"
check_tool "chaos"
check_tool "assetfinder"
check_tool "anew"
check_tool "waybackurls"
check_tool "gau"
check_tool "hakrawler"
check_tool "hakrevdns"
check_tool "puredns"
check_tool "ffuf"
check_tool "gobuster"
check_tool "amass"
check_tool "gowitness"
check_tool "gospider"
check_tool "dalfox"
check_tool "subjack"
check_tool "originiphunter"

echo -e "${CYAN}╠══════════════════════════════════════════════════════╣${RESET}"

# ── Binary Tools
check_tool "findomain"
check_tool "kiterunner" "kr"
check_tool "feroxbuster"
check_tool "gitleaks"
check_tool "nmap"
check_tool "jq"
check_tool "parallel"
check_tool "trufflehog"

echo -e "${CYAN}╠══════════════════════════════════════════════════════╣${RESET}"

# ── Cloned Tools
check_file "gitdorker" "$HOME/tools/GitDorker/GitDorker.py"
check_file "bfac" "$HOME/tools/bfac/bfac.py"
check_file "sqlmap" "$HOME/tools/sqlmap/sqlmap.py"

echo -e "${CYAN}╠══════════════════════════════════════════════════════╣${RESET}"

# ── Config & Data
check_file "config.yaml" "$SCRIPT_DIR/config.yaml"
check_file "wordlists" "$SCRIPT_DIR/data/wordlists/dns"
check_file "resolvers.txt" "$SCRIPT_DIR/data/resolvers/resolvers.txt"
check_file "github_dorks" "$SCRIPT_DIR/data/dorks/github_dorks.txt"

echo -e "${CYAN}╚══════════════════════════════════════════════════════╝${RESET}"

echo ""
echo -e "Results: ${GREEN}$PASS passed${RESET}, ${RED}$FAIL failed${RESET}"
echo ""

if [ "$FAIL" -gt 0 ]; then
  echo -e "${YELLOW}[!] $FAIL critical tools/files are missing.${RESET}"
  echo -e "${YELLOW}    Run: bash install.sh${RESET}"
  exit 1
else
  echo -e "${GREEN}[+] All tools and files are present. Ready to go!${RESET}"
  exit 0
fi
