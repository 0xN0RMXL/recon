#!/bin/bash
# ============================================================
# RECON Framework — install.sh
# One-shot installer for all dependencies
# ============================================================

set -e

# ─── COLORS ──────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'


# Detect actual user context for installs (handles sudo)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ACTUAL_USER="${SUDO_USER:-$(whoami)}"
ACTUAL_HOME=$(getent passwd "$ACTUAL_USER" 2>/dev/null | cut -d: -f6)
[ -z "$ACTUAL_HOME" ] && ACTUAL_HOME="$HOME"
TOOLS_DIR="$ACTUAL_HOME/tools"
LOCAL_BIN="$ACTUAL_HOME/.local/bin"

# ─── HELPERS ─────────────────────────────────────────────────
info()    { echo -e "${CYAN}[*]${RESET} $1"; }
success() { echo -e "${GREEN}[+]${RESET} $1"; }
warn()    { echo -e "${YELLOW}[!]${RESET} $1"; }
error()   { echo -e "${RED}[-]${RESET} $1"; }

run_as_actual_user() {
  if [ "$(id -un)" = "$ACTUAL_USER" ]; then
    "$@"
  else
    sudo -H -u "$ACTUAL_USER" env \
      "HOME=$ACTUAL_HOME" \
      "PATH=/usr/local/go/bin:$ACTUAL_HOME/go/bin:$ACTUAL_HOME/.local/bin:$PATH" \
      "$@"
  fi
}

resolve_go_binary() {
  if command -v go &>/dev/null; then
    command -v go
  elif [ -x "/usr/local/go/bin/go" ]; then
    echo "/usr/local/go/bin/go"
  else
    echo ""
  fi
}

check_root() {
  if [ "$(id -u)" -ne 0 ]; then
    warn "Not running as root. Some system packages may fail to install."
    warn "Consider running: sudo bash install.sh"
  fi
}

# ─── DETECT OS ───────────────────────────────────────────────
detect_os() {
  if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS_ID="$ID"
    OS_VERSION="$VERSION_ID"
  else
    OS_ID="unknown"
  fi

  case "$OS_ID" in
    ubuntu|debian) info "Detected: $OS_ID $OS_VERSION" ;;
    kali)          info "Detected: Kali Linux" ;;
    *)             warn "Unsupported OS: $OS_ID. Attempting install anyway." ;;
  esac
}

# ─── 1. INSTALL SYSTEM PACKAGES ─────────────────────────────
install_system_packages() {
  info "Installing system packages..."
  
  local packages="git curl wget jq python3 python3-pip python3-venv unzip bc parallel nmap masscan chromium-browser libpcap-dev"
  
  if command -v apt-get &>/dev/null; then
    sudo apt-get update -qq 2>/dev/null
    sudo apt-get install -y -qq $packages 2>/dev/null && \
      success "System packages installed" || \
      warn "Some system packages failed to install"
  else
    error "apt-get not found. Install packages manually: $packages"
  fi
}

# ─── 2. INSTALL / VERIFY GO ─────────────────────────────────
install_go() {
  local GO_VERSION="1.22.0"
  local GO_TARBALL="go${GO_VERSION}.linux-amd64.tar.gz"
  local GO_URL="https://go.dev/dl/${GO_TARBALL}"
  local go_bin

  go_bin=$(resolve_go_binary)

  if [ -n "$go_bin" ]; then
    local current_ver
    current_ver=$($go_bin version | grep -oE 'go[0-9]+\.[0-9]+' | sed 's/go//')
    local major minor
    major=$(echo "$current_ver" | cut -d. -f1)
    minor=$(echo "$current_ver" | cut -d. -f2)
    if [ "$major" -ge 1 ] && [ "$minor" -ge 21 ]; then
      success "Go $($go_bin version | grep -oE 'go[0-9]+\.[0-9]+\.[0-9]+') already installed"
      return 0
    fi
  fi

  info "Installing Go $GO_VERSION..."
  wget -q "$GO_URL" -O "/tmp/$GO_TARBALL"
  sudo rm -rf /usr/local/go
  sudo tar -C /usr/local -xzf "/tmp/$GO_TARBALL"
  rm -f "/tmp/$GO_TARBALL"


  # Add to PATH
  export PATH=$PATH:/usr/local/go/bin:$ACTUAL_HOME/go/bin

  # Persist in actual user's shell configs
  USER_BASHRC="$ACTUAL_HOME/.bashrc"
  USER_ZSHRC="$ACTUAL_HOME/.zshrc"
  for rc in "$USER_BASHRC" "$USER_ZSHRC"; do
    if [ -f "$rc" ]; then
      grep -q '/usr/local/go/bin' "$rc" 2>/dev/null || \
        echo 'export PATH=$PATH:/usr/local/go/bin:'"$ACTUAL_HOME"'/go/bin' >> "$rc"
    fi
  done

  success "Go $GO_VERSION installed"
}

# ─── 3. INSTALL GO TOOLS ────────────────────────────────────
install_go_tools() {
  info "Installing Go tools (this may take a while)..."


  export PATH=$PATH:/usr/local/go/bin:$ACTUAL_HOME/go/bin
  local go_bin
  go_bin=$(resolve_go_binary)

  if [ -z "$go_bin" ]; then
    error "Go binary not found. Install Go first, then rerun install.sh"
    return 1
  fi

  if [ ! -f "$SCRIPT_DIR/go-tools.txt" ]; then
    error "go-tools.txt not found!"
    return 1
  fi

  local total
  total=$(wc -l < "$SCRIPT_DIR/go-tools.txt" | tr -d ' ')
  local count=0
  local installed_count=0
  local failed_count=0
  local failed_list=()

  while IFS= read -r tool; do
    [ -z "$tool" ] && continue
    [[ "$tool" =~ ^# ]] && continue
    count=$((count + 1))
    # Extract a human-readable tool name from module path
    # Priority: /cmd/<name> → last non-version segment → fallback
    local tool_name
    tool_name=$(echo "$tool" | grep -oE '/cmd/[^/@]+' | sed 's|/cmd/||')
    if [ -z "$tool_name" ]; then
      # Strip version tag, then get last path segment, skip vN segments
      tool_name=$(echo "$tool" | sed 's/@.*//' | tr '/' '\n' \
        | grep -v -E '^v[0-9]+$' | grep -v '^\.\.\.$' | tail -1)
    fi
    [ -z "$tool_name" ] && tool_name="$tool"
    info "[$count/$total] Installing $tool_name..."
    if output=$(run_as_actual_user "$go_bin" install "$tool" 2>&1); then
      if [ -x "$ACTUAL_HOME/go/bin/$tool_name" ] || command -v "$tool_name" &>/dev/null; then
        success "  $tool_name installed"
        installed_count=$((installed_count + 1))
      else
        warn "  $tool_name: install reported success but binary not in PATH"
        failed_count=$((failed_count + 1))
        failed_list+=("$tool_name (not found in PATH)")
      fi
    else
      warn "  $tool_name failed: $output"
      failed_count=$((failed_count + 1))
      failed_list+=("$tool_name")
    fi
  done < "$SCRIPT_DIR/go-tools.txt"

  if [ "$failed_count" -eq 0 ]; then
    success "Go tools summary: $installed_count installed, 0 failed"
  else
    warn "Go tools summary: $installed_count installed, $failed_count failed"
    for failed_tool in "${failed_list[@]}"; do
      warn "  - $failed_tool"
    done
  fi
}

# ─── 4. INSTALL PYTHON TOOLS ────────────────────────────────
install_python_tools() {
  info "Installing Python tools..."
  local py_bin
  py_bin=$(command -v python3 || true)

  if [ -z "$py_bin" ]; then
    warn "python3 not found; skipping Python tools"
    return 0
  fi

  local pip_flags=(--user --break-system-packages)

  if [ -f "$SCRIPT_DIR/requirements.txt" ]; then
    if run_as_actual_user "$py_bin" -m pip install "${pip_flags[@]}" -r "$SCRIPT_DIR/requirements.txt"; then
      success "Python tools installed"
    else
      warn "Bulk Python install failed. Retrying package-by-package to show exact failures..."
      local failed_packages=()
      while IFS= read -r package; do
        [ -z "$package" ] && continue
        [[ "$package" =~ ^# ]] && continue
        info "Installing Python package: $package"
        if run_as_actual_user "$py_bin" -m pip install "${pip_flags[@]}" "$package"; then
          success "  $package installed"
        else
          warn "  $package failed"
          failed_packages+=("$package")
        fi
      done < "$SCRIPT_DIR/requirements.txt"

      if [ "${#failed_packages[@]}" -eq 0 ]; then
        success "Python tools installed after retries"
      else
        warn "Some Python tools failed to install: ${failed_packages[*]}"
      fi
    fi
  fi

  # Install Playwright and Chromium
  info "Installing Playwright + Chromium..."
  if run_as_actual_user "$py_bin" -m pip install "${pip_flags[@]}" playwright; then
    if run_as_actual_user "$py_bin" -m playwright install chromium; then
      success "Playwright + Chromium installed"
    else
      warn "Playwright browser install failed"
    fi
  else
    warn "Playwright package install failed"
  fi
}

# ─── 5. CLONE BINARY TOOLS ──────────────────────────────────
clone_tools() {
  mkdir -p "$TOOLS_DIR"

  info "Cloning GitDorker..."
  if [ ! -d "$TOOLS_DIR/GitDorker" ]; then
    git clone -q https://github.com/obheda12/GitDorker "$TOOLS_DIR/GitDorker" 2>/dev/null && \
      success "GitDorker cloned" || warn "GitDorker clone failed"
  else
    success "GitDorker already exists"
  fi

  info "Cloning bfac..."
  if [ ! -d "$TOOLS_DIR/bfac" ]; then
    git clone -q https://github.com/mazen160/bfac "$TOOLS_DIR/bfac" 2>/dev/null && \
      success "bfac cloned" || warn "bfac clone failed"
  else
    success "bfac already exists"
  fi

  info "Cloning sqlmap..."
  if [ ! -d "$TOOLS_DIR/sqlmap" ]; then
    git clone -q https://github.com/sqlmapproject/sqlmap "$TOOLS_DIR/sqlmap" 2>/dev/null && \
      success "sqlmap cloned" || warn "sqlmap clone failed"
  else
    success "sqlmap already exists"
  fi
}

# ─── 6. DOWNLOAD BINARY RELEASES ────────────────────────────
download_binaries() {
  mkdir -p "$LOCAL_BIN"
  export PATH=$PATH:$LOCAL_BIN

  # Ensure .local/bin is in PATH permanently
  for rc in "$ACTUAL_HOME/.bashrc" "$ACTUAL_HOME/.zshrc"; do
    [ -f "$rc" ] && grep -q '.local/bin' "$rc" 2>/dev/null || \
      echo 'export PATH=$PATH:'"$ACTUAL_HOME"'/.local/bin' >> "$rc" 2>/dev/null
  done

  # findomain
  if ! command -v findomain &>/dev/null; then
    info "Downloading findomain..."
    local fd_installed=false

    # Strategy 1: GitHub API (asset name is 'findomain-linux', plain binary, no zip)
    local fd_url
    fd_url=$(curl -s "https://api.github.com/repos/Findomain/Findomain/releases/latest" \
      | jq -r '.assets[] | select(.name == "findomain-linux") | .browser_download_url' \
      2>/dev/null | head -1)

    if [ -n "$fd_url" ]; then
      wget -q "$fd_url" -O "$LOCAL_BIN/findomain" 2>/dev/null && \
        chmod +x "$LOCAL_BIN/findomain" && fd_installed=true
    fi

    # Strategy 2: pinned direct URL (fallback if API rate-limited)
    if [ "$fd_installed" = false ]; then
      warn "GitHub API failed, trying direct URL fallback..."
      wget -q "https://github.com/Findomain/Findomain/releases/download/9.0.4/findomain-linux" \
        -O "$LOCAL_BIN/findomain" 2>/dev/null && \
        chmod +x "$LOCAL_BIN/findomain" && fd_installed=true
    fi

    # Strategy 3: apt install
    if [ "$fd_installed" = false ]; then
      warn "Direct download failed, trying apt..."
      sudo apt-get install -y -qq findomain 2>/dev/null && fd_installed=true
    fi

    if [ "$fd_installed" = true ]; then
      success "findomain installed"
    else
      warn "findomain could not be installed automatically. Install manually: https://github.com/Findomain/Findomain/releases"
    fi
  else
    success "findomain already installed"
  fi


  # kiterunner
  if ! command -v kr &>/dev/null; then
    info "Downloading kiterunner..."
    local kr_url
    kr_url=$(curl -s https://api.github.com/repos/assetnote/kiterunner/releases/latest \
      | jq -r '.assets[] | select(.name | test("linux_amd64")) | .browser_download_url' 2>/dev/null | head -1)
    if [ -n "$kr_url" ]; then
      wget -q "$kr_url" -O /tmp/kr.tar.gz 2>/dev/null
      tar xzf /tmp/kr.tar.gz -C /tmp/ 2>/dev/null
      chmod +x /tmp/kr 2>/dev/null
      mv /tmp/kr "$LOCAL_BIN/" 2>/dev/null
      rm -f /tmp/kr.tar.gz
      success "kiterunner installed"
    else
      warn "kiterunner download failed"
    fi
  else
    success "kiterunner already installed"
  fi

  # feroxbuster
  if ! command -v feroxbuster &>/dev/null; then
    info "Downloading feroxbuster..."
    local fb_url
    fb_url=$(curl -s https://api.github.com/repos/epi052/feroxbuster/releases/latest \
      | jq -r '.assets[] | select(.name | test("x86_64-linux")) | .browser_download_url' 2>/dev/null | head -1)
    if [ -n "$fb_url" ]; then
      wget -q "$fb_url" -O /tmp/feroxbuster.zip 2>/dev/null
      unzip -oq /tmp/feroxbuster.zip -d /tmp/ 2>/dev/null
      chmod +x /tmp/feroxbuster 2>/dev/null
      mv /tmp/feroxbuster "$LOCAL_BIN/" 2>/dev/null
      rm -f /tmp/feroxbuster.zip
      success "feroxbuster installed"
    else
      warn "feroxbuster download failed"
    fi
  else
    success "feroxbuster already installed"
  fi

  # gitleaks
  if ! command -v gitleaks &>/dev/null; then
    info "Downloading gitleaks..."
    local gl_url
    gl_url=$(curl -s https://api.github.com/repos/gitleaks/gitleaks/releases/latest \
      | jq -r '.assets[] | select(.name | test("linux_x64")) | .browser_download_url' 2>/dev/null | head -1)
    if [ -n "$gl_url" ]; then
      wget -q "$gl_url" -O /tmp/gitleaks.tar.gz 2>/dev/null
      tar xzf /tmp/gitleaks.tar.gz -C /tmp/ 2>/dev/null
      chmod +x /tmp/gitleaks 2>/dev/null
      mv /tmp/gitleaks "$LOCAL_BIN/" 2>/dev/null
      rm -f /tmp/gitleaks.tar.gz
      success "gitleaks installed"
    else
      warn "gitleaks download failed"
    fi
  else
    success "gitleaks already installed"
  fi
}

# ─── 7. DOWNLOAD WORDLISTS ──────────────────────────────────
download_wordlists() {
  local wl_dir="$SCRIPT_DIR/data/wordlists"
  mkdir -p "$wl_dir/dns" "$wl_dir/web"

  info "Downloading wordlists..."

  # SecLists DNS wordlists (sparse clone)
  if [ ! -f "$wl_dir/dns/subdomains-top1million-110000.txt" ]; then
    info "Downloading SecLists DNS wordlists..."
    local seclists_dns="https://raw.githubusercontent.com/danielmiessler/SecLists/master/Discovery/DNS"
    wget -q "$seclists_dns/subdomains-top1million-110000.txt" -O "$wl_dir/dns/subdomains-top1million-110000.txt" 2>/dev/null && \
      success "DNS wordlist downloaded" || warn "DNS wordlist download failed"
    wget -q "$seclists_dns/dns-Jhaddix.txt" -O "$wl_dir/dns/dns-Jhaddix.txt" 2>/dev/null
  else
    success "DNS wordlists already exist"
  fi

  # SecLists Web wordlists
  if [ ! -f "$wl_dir/web/common.txt" ]; then
    info "Downloading SecLists Web wordlists..."
    local seclists_web="https://raw.githubusercontent.com/danielmiessler/SecLists/master/Discovery/Web-Content"
    wget -q "$seclists_web/common.txt" -O "$wl_dir/web/common.txt" 2>/dev/null
    wget -q "$seclists_web/raft-large-directories.txt" -O "$wl_dir/web/raft-large-directories.txt" 2>/dev/null
    wget -q "$seclists_web/raft-large-files.txt" -O "$wl_dir/web/raft-large-files.txt" 2>/dev/null
    wget -q "$seclists_web/burp-parameter-names.txt" -O "$wl_dir/web/burp-parameter-names.txt" 2>/dev/null
    success "Web wordlists downloaded"
  else
    success "Web wordlists already exist"
  fi

  # best-dns-wordlist from Assetnote
  if [ ! -f "$wl_dir/dns/best-dns-wordlist.txt" ]; then
    info "Downloading Assetnote best-dns-wordlist..."
    wget -q "https://wordlists-cdn.assetnote.io/data/manual/best-dns-wordlist.txt" \
      -O "$wl_dir/dns/best-dns-wordlist.txt" 2>/dev/null && \
      success "best-dns-wordlist downloaded" || warn "best-dns-wordlist download failed"
  else
    success "best-dns-wordlist already exists"
  fi
}

# ─── 8. DOWNLOAD RESOLVERS ──────────────────────────────────
download_resolvers() {
  local res_dir="$SCRIPT_DIR/data/resolvers"
  mkdir -p "$res_dir"

  if [ ! -f "$res_dir/resolvers.txt" ] || [ "$(find "$res_dir/resolvers.txt" -mtime +7 2>/dev/null)" ]; then
    info "Downloading fresh resolvers..."
    wget -q "https://raw.githubusercontent.com/trickest/resolvers/main/resolvers.txt" \
      -O "$res_dir/resolvers.txt" 2>/dev/null && \
      success "Resolvers downloaded ($(wc -l < "$res_dir/resolvers.txt" | tr -d ' ') entries)" || \
      warn "Resolvers download failed"
  else
    success "Resolvers are up to date"
  fi
}

# ─── 9. DOWNLOAD GITHUB DORKS ───────────────────────────────
download_dorks() {
  local dorks_dir="$SCRIPT_DIR/data/dorks"
  mkdir -p "$dorks_dir"

  info "Downloading GitHub dorks..."
  wget -q "https://raw.githubusercontent.com/Proviesec/github-dorks/main/dorks.txt" \
    -O "$dorks_dir/github_dorks.txt" 2>/dev/null && \
    success "GitHub dorks downloaded" || warn "GitHub dorks download failed"
}

# ─── 10. DOWNLOAD KITERUNNER WORDLISTS ───────────────────────
download_kiterunner_wordlists() {
  if command -v kr &>/dev/null; then
    info "Downloading kiterunner API wordlists..."
    kr wordlist save apiroutes-260227 2>/dev/null && \
      success "apiroutes wordlist saved" || warn "Failed to save apiroutes wordlist"
    kr wordlist save parameters-260227 2>/dev/null && \
      success "parameters wordlist saved" || warn "Failed to save parameters wordlist"
    kr wordlist save directories-260227 2>/dev/null && \
      success "directories wordlist saved" || warn "Failed to save directories wordlist"
  else
    warn "kiterunner not found, skipping wordlist download"
  fi
}

# ─── 11. UPDATE NUCLEI TEMPLATES ─────────────────────────────
update_nuclei() {
  if command -v nuclei &>/dev/null; then
    info "Updating nuclei templates..."
    nuclei -update-templates 2>/dev/null && \
      success "Nuclei templates updated" || warn "Nuclei template update failed"
  fi
}

# ─── 11. CREATE CONFIG ──────────────────────────────────────
create_config() {
  if [ ! -f "$SCRIPT_DIR/config.yaml" ]; then
    info "Creating config.yaml from template..."
    cp "$SCRIPT_DIR/config.yaml.example" "$SCRIPT_DIR/config.yaml"
    success "config.yaml created"
  else
    success "config.yaml already exists"
  fi
}

# ─── 12. FIX USER OWNERSHIP (SUDO RUNS) ─────────────────────
fix_user_ownership() {
  if [ "$(id -u)" -eq 0 ] && [ -n "${SUDO_USER:-}" ]; then
    info "Ensuring user ownership for installed tools..."
    [ -d "$ACTUAL_HOME/go" ] && chown -R "$ACTUAL_USER:$ACTUAL_USER" "$ACTUAL_HOME/go" 2>/dev/null || true
    [ -d "$ACTUAL_HOME/.local" ] && chown -R "$ACTUAL_USER:$ACTUAL_USER" "$ACTUAL_HOME/.local" 2>/dev/null || true
    [ -d "$TOOLS_DIR" ] && chown -R "$ACTUAL_USER:$ACTUAL_USER" "$TOOLS_DIR" 2>/dev/null || true
  fi
}

# ─── 12. VERIFY INSTALLATION ────────────────────────────────
verify_install() {
  info "Running doctor.sh to verify installation..."
  if [ -f "$SCRIPT_DIR/doctor.sh" ]; then
    run_as_actual_user bash "$SCRIPT_DIR/doctor.sh"
  fi
}

# ─── API KEY REMINDER ───────────────────────────────────────
api_key_reminder() {
  echo ""
  echo -e "${CYAN}╔══════════════════════════════════════════════════════╗${RESET}"
  echo -e "${CYAN}║${RESET}${BOLD}          API Key Setup Required                      ${RESET}${CYAN}║${RESET}"
  echo -e "${CYAN}╠══════════════════════════════════════════════════════╣${RESET}"
  echo -e "${CYAN}║${RESET}  Edit ${BOLD}config.yaml${RESET} and add your API keys:             ${CYAN}║${RESET}"
  echo -e "${CYAN}║${RESET}                                                      ${CYAN}║${RESET}"
  echo -e "${CYAN}║${RESET}  ${GREEN}nano config.yaml${RESET}                                   ${CYAN}║${RESET}"
  echo -e "${CYAN}║${RESET}                                                      ${CYAN}║${RESET}"
  echo -e "${CYAN}║${RESET}  All keys are optional but improve coverage.         ${CYAN}║${RESET}"
  echo -e "${CYAN}║${RESET}  Free tiers: Chaos, GitHub, Censys, VT, OTX         ${CYAN}║${RESET}"
  echo -e "${CYAN}╚══════════════════════════════════════════════════════╝${RESET}"
  echo ""
}

# ─── MAIN INSTALLER ─────────────────────────────────────────
main() {
  echo ""
  echo -e "${CYAN}${BOLD}  RECON Framework — Installer${RESET}"
  echo -e "${CYAN}  ════════════════════════════${RESET}"
  echo ""

  check_root
  detect_os

  install_system_packages
  install_go
  install_go_tools
  install_python_tools
  clone_tools
  download_binaries
  download_wordlists
  download_resolvers
  download_dorks
  download_kiterunner_wordlists
  update_nuclei
  create_config
  fix_user_ownership
  verify_install
  api_key_reminder

  echo ""
  # Ensure main scripts are executable
  chmod +x "$SCRIPT_DIR/recon.sh" "$SCRIPT_DIR/doctor.sh" "$SCRIPT_DIR/update.sh" 2>/dev/null && \
    success "Framework scripts are now executable" || warn "Could not set executable bit"

  success "Installation complete! Run: ./recon.sh"
  echo ""
}

main "$@"
