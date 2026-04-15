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

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOOLS_DIR="$HOME/tools"
LOCAL_BIN="$HOME/.local/bin"

# ─── HELPERS ─────────────────────────────────────────────────
info()    { echo -e "${CYAN}[*]${RESET} $1"; }
success() { echo -e "${GREEN}[+]${RESET} $1"; }
warn()    { echo -e "${YELLOW}[!]${RESET} $1"; }
error()   { echo -e "${RED}[-]${RESET} $1"; }

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
  
  local packages="git curl wget jq python3 python3-pip python3-venv unzip bc parallel nmap masscan chromium-browser"
  
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

  if command -v go &>/dev/null; then
    local current_ver
    current_ver=$(go version | grep -oE 'go[0-9]+\.[0-9]+' | sed 's/go//')
    local major minor
    major=$(echo "$current_ver" | cut -d. -f1)
    minor=$(echo "$current_ver" | cut -d. -f2)
    if [ "$major" -ge 1 ] && [ "$minor" -ge 21 ]; then
      success "Go $(go version | grep -oE 'go[0-9]+\.[0-9]+\.[0-9]+') already installed"
      return 0
    fi
  fi

  info "Installing Go $GO_VERSION..."
  wget -q "$GO_URL" -O "/tmp/$GO_TARBALL"
  sudo rm -rf /usr/local/go
  sudo tar -C /usr/local -xzf "/tmp/$GO_TARBALL"
  rm -f "/tmp/$GO_TARBALL"

  # Add to PATH
  export PATH=$PATH:/usr/local/go/bin:$HOME/go/bin

  # Persist in shell configs
  for rc in "$HOME/.bashrc" "$HOME/.zshrc"; do
    if [ -f "$rc" ]; then
      grep -q '/usr/local/go/bin' "$rc" 2>/dev/null || \
        echo 'export PATH=$PATH:/usr/local/go/bin:$HOME/go/bin' >> "$rc"
    fi
  done

  if [ -f "$HOME/.bashrc" ]; then
    # shellcheck source=/dev/null
    source "$HOME/.bashrc" 2>/dev/null || true
  fi

  success "Go $GO_VERSION installed"
}

# ─── 3. INSTALL GO TOOLS ────────────────────────────────────
install_go_tools() {
  info "Installing Go tools (this may take a while)..."

  export PATH=$PATH:/usr/local/go/bin:$HOME/go/bin

  if [ ! -f "$SCRIPT_DIR/go-tools.txt" ]; then
    error "go-tools.txt not found!"
    return 1
  fi

  local total
  total=$(wc -l < "$SCRIPT_DIR/go-tools.txt" | tr -d ' ')
  local count=0

  while IFS= read -r tool; do
    [ -z "$tool" ] && continue
    [[ "$tool" =~ ^# ]] && continue
    count=$((count + 1))
    local tool_name
    tool_name=$(basename "$tool" | cut -d@ -f1)
    info "[$count/$total] Installing $tool_name..."
    go install "$tool" 2>/dev/null && \
      success "  $tool_name installed" || \
      warn "  $tool_name failed to install"
  done < "$SCRIPT_DIR/go-tools.txt"
}

# ─── 4. INSTALL PYTHON TOOLS ────────────────────────────────
install_python_tools() {
  info "Installing Python tools..."

  if [ -f "$SCRIPT_DIR/requirements.txt" ]; then
    pip3 install --break-system-packages -r "$SCRIPT_DIR/requirements.txt" 2>/dev/null && \
      success "Python tools installed" || \
      warn "Some Python tools failed to install"
  fi

  # Install Playwright and Chromium
  info "Installing Playwright + Chromium..."
  pip3 install --break-system-packages playwright 2>/dev/null
  playwright install chromium 2>/dev/null && \
    success "Playwright + Chromium installed" || \
    warn "Playwright install failed"
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
  for rc in "$HOME/.bashrc" "$HOME/.zshrc"; do
    [ -f "$rc" ] && grep -q '.local/bin' "$rc" 2>/dev/null || \
      echo 'export PATH=$PATH:$HOME/.local/bin' >> "$rc" 2>/dev/null
  done

  # findomain
  if ! command -v findomain &>/dev/null; then
    info "Downloading findomain..."
    local fd_url
    fd_url=$(curl -s https://api.github.com/repos/Findomain/Findomain/releases/latest \
      | jq -r '.assets[] | select(.name | test("linux-amd64")) | .browser_download_url' 2>/dev/null | head -1)
    if [ -n "$fd_url" ]; then
      wget -q "$fd_url" -O /tmp/findomain.zip 2>/dev/null
      unzip -oq /tmp/findomain.zip -d /tmp/ 2>/dev/null
      chmod +x /tmp/findomain 2>/dev/null
      mv /tmp/findomain "$LOCAL_BIN/" 2>/dev/null
      rm -f /tmp/findomain.zip
      success "findomain installed"
    else
      warn "findomain download failed — installing manually may be needed"
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

# ─── 12. VERIFY INSTALLATION ────────────────────────────────
verify_install() {
  info "Running doctor.sh to verify installation..."
  if [ -f "$SCRIPT_DIR/doctor.sh" ]; then
    bash "$SCRIPT_DIR/doctor.sh"
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
  verify_install
  api_key_reminder

  echo ""
  success "Installation complete! Run: ./recon.sh"
  echo ""
}

main "$@"
