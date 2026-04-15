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

file_has_min_lines() {
  local file_path="$1"
  local min_lines="$2"

  if [ ! -s "$file_path" ]; then
    return 1
  fi

  local lines
  lines=$(wc -l < "$file_path" 2>/dev/null | tr -d ' ')
  [ -n "$lines" ] && [ "$lines" -ge "$min_lines" ]
}

download_validated_text_file() {
  local output_file="$1"
  local min_lines="$2"
  local label="$3"
  shift 3
  local urls=("$@")

  mkdir -p "$(dirname "$output_file")"

  if file_has_min_lines "$output_file" "$min_lines"; then
    local existing_lines
    existing_lines=$(wc -l < "$output_file" 2>/dev/null | tr -d ' ')
    success "$label already present ($existing_lines lines)"
    return 0
  fi

  warn "$label missing or invalid. Downloading..."

  local url tmp_file lines
  tmp_file="${output_file}.tmp.$$"

  for url in "${urls[@]}"; do
    [ -z "$url" ] && continue

    if wget -q "$url" -O "$tmp_file" 2>/dev/null; then
      lines=$(wc -l < "$tmp_file" 2>/dev/null | tr -d ' ')
      lines="${lines:-0}"
      if [ "$lines" -ge "$min_lines" ]; then
        mv "$tmp_file" "$output_file"
        success "$label downloaded ($lines lines)"
        return 0
      fi
      warn "$label from $url is too small ($lines lines)"
    else
      warn "Failed downloading $label from $url"
    fi

    rm -f "$tmp_file"
  done

  rm -f "$tmp_file"
  error "Unable to install valid $label"
  return 1
}

install_trufflehog_binary() {
  info "Trying trufflehog binary fallback..."

  local tg_tag tg_ver tg_url tg_bin
  tg_tag=$(curl -s https://api.github.com/repos/trufflesecurity/trufflehog/releases/latest \
    | jq -r '.tag_name' 2>/dev/null)

  if [ -z "$tg_tag" ] || [ "$tg_tag" = "null" ]; then
    warn "Could not resolve trufflehog latest release tag"
    return 1
  fi

  tg_ver="${tg_tag#v}"
  tg_url="https://github.com/trufflesecurity/trufflehog/releases/download/${tg_tag}/trufflehog_${tg_ver}_linux_amd64.tar.gz"

  rm -rf /tmp/recon_trufflehog /tmp/recon_trufflehog.tar.gz
  mkdir -p /tmp/recon_trufflehog

  if wget -q "$tg_url" -O /tmp/recon_trufflehog.tar.gz 2>/dev/null && \
     tar xzf /tmp/recon_trufflehog.tar.gz -C /tmp/recon_trufflehog 2>/dev/null; then
    tg_bin=$(find /tmp/recon_trufflehog -type f -name trufflehog 2>/dev/null | head -1)
    if [ -n "$tg_bin" ]; then
      install -m 0755 "$tg_bin" "$LOCAL_BIN/trufflehog" 2>/dev/null && {
        success "trufflehog installed via binary fallback"
        rm -rf /tmp/recon_trufflehog /tmp/recon_trufflehog.tar.gz
        return 0
      }
    fi
  fi

  rm -rf /tmp/recon_trufflehog /tmp/recon_trufflehog.tar.gz
  warn "trufflehog binary fallback failed"
  return 1
}

install_paramspider_tool() {
  local py_bin="$1"
  local pip_flags=(--user --break-system-packages)
  local ps_dir="$TOOLS_DIR/paramspider"
  local backup_dir=""
  local clone_output=""

  info "Installing ParamSpider from GitHub (non-PyPI)..."

  run_as_actual_user mkdir -p "$TOOLS_DIR" "$LOCAL_BIN"

  if ! run_as_actual_user test -w "$TOOLS_DIR"; then
    warn "Tools directory is not writable by $ACTUAL_USER. Fixing ownership..."
    sudo chown -R "$ACTUAL_USER:$ACTUAL_USER" "$TOOLS_DIR" 2>/dev/null || true
  fi

  if ! run_as_actual_user test -w "$LOCAL_BIN"; then
    warn "$LOCAL_BIN is not writable by $ACTUAL_USER. Fixing ownership..."
    sudo chown -R "$ACTUAL_USER:$ACTUAL_USER" "$LOCAL_BIN" 2>/dev/null || true
  fi

  if [ -d "$ps_dir/.git" ]; then
    run_as_actual_user git -C "$ps_dir" pull --ff-only >/dev/null 2>&1 || \
      warn "ParamSpider update failed; using existing clone"
  else
    if [ -d "$ps_dir" ]; then
      backup_dir="${ps_dir}.backup.$(date +%s)"
      warn "Existing ParamSpider directory is not a git clone. Preserving it at: $backup_dir"
      if ! run_as_actual_user mv "$ps_dir" "$backup_dir" 2>/dev/null; then
        warn "Could not preserve existing ParamSpider directory: $ps_dir"
        return 1
      fi
    fi

    if clone_output=$(run_as_actual_user git clone -q https://github.com/devanshbatham/ParamSpider "$ps_dir" 2>&1); then
      :
    elif clone_output=$(run_as_actual_user git clone -q https://github.com/devanshbatham/paramspider "$ps_dir" 2>&1); then
      :
    else
      warn "ParamSpider clone failed: ${clone_output:-unknown error}"
      if [ -n "$backup_dir" ] && [ -d "$backup_dir" ] && [ ! -e "$ps_dir" ]; then
        run_as_actual_user mv "$backup_dir" "$ps_dir" 2>/dev/null || true
      fi
      return 1
    fi

    if [ -n "$backup_dir" ] && [ -d "$backup_dir" ]; then
      warn "Previous ParamSpider directory kept at: $backup_dir"
    fi
  fi

  if [ -n "$py_bin" ]; then
    run_as_actual_user "$py_bin" -m pip install "${pip_flags[@]}" requests colorama >/dev/null 2>&1 || true
  fi

  cat > "$LOCAL_BIN/paramspider" << 'EOF'
#!/usr/bin/env bash
if [ -f "$HOME/tools/paramspider/paramspider.py" ]; then
  python3 "$HOME/tools/paramspider/paramspider.py" "$@"
elif [ -f "$HOME/tools/paramspider/paramspider/main.py" ]; then
  python3 "$HOME/tools/paramspider/paramspider/main.py" "$@"
else
  echo "paramspider source not found under $HOME/tools/paramspider" >&2
  exit 1
fi
EOF

  chmod +x "$LOCAL_BIN/paramspider" 2>/dev/null

  if [ -x "$LOCAL_BIN/paramspider" ]; then
    success "ParamSpider installed"
    return 0
  fi

  warn "ParamSpider wrapper install failed"
  return 1
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
      if [ "$tool_name" = "trufflehog" ] && install_trufflehog_binary; then
        installed_count=$((installed_count + 1))
        continue
      fi
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

  install_paramspider_tool "$py_bin" || warn "ParamSpider install failed"

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

    # Strategy 1: zip release asset (current default)
    local fd_url fd_bin
    fd_url=$(curl -s "https://api.github.com/repos/findomain/findomain/releases/latest" \
      | jq -r '.assets[] | select(.name == "findomain-linux.zip") | .browser_download_url' \
      2>/dev/null | head -1)

    if [ -n "$fd_url" ]; then
      rm -rf /tmp/recon_findomain /tmp/recon_findomain.zip
      mkdir -p /tmp/recon_findomain
      if wget -q "$fd_url" -O /tmp/recon_findomain.zip 2>/dev/null && \
         unzip -oq /tmp/recon_findomain.zip -d /tmp/recon_findomain 2>/dev/null; then
        fd_bin=$(find /tmp/recon_findomain -type f -name findomain 2>/dev/null | head -1)
        if [ -n "$fd_bin" ] && install -m 0755 "$fd_bin" "$LOCAL_BIN/findomain" 2>/dev/null; then
          fd_installed=true
        fi
      fi
      rm -rf /tmp/recon_findomain /tmp/recon_findomain.zip
    fi

    # Strategy 2: legacy plain-binary asset
    if [ "$fd_installed" = false ]; then
      fd_url=$(curl -s "https://api.github.com/repos/findomain/findomain/releases/latest" \
        | jq -r '.assets[] | select(.name == "findomain-linux") | .browser_download_url' \
        2>/dev/null | head -1)
      if [ -n "$fd_url" ] && wget -q "$fd_url" -O "$LOCAL_BIN/findomain" 2>/dev/null && \
         chmod +x "$LOCAL_BIN/findomain"; then
        fd_installed=true
      fi
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
    local kr_url kr_bin
    kr_url=$(curl -s https://api.github.com/repos/assetnote/kiterunner/releases/latest \
      | jq -r '.assets[] | select(.name | test("linux_amd64")) | .browser_download_url' 2>/dev/null | head -1)
    if [ -n "$kr_url" ]; then
      rm -rf /tmp/recon_kr /tmp/recon_kr.tar.gz
      mkdir -p /tmp/recon_kr
      if wget -q "$kr_url" -O /tmp/recon_kr.tar.gz 2>/dev/null && \
         tar xzf /tmp/recon_kr.tar.gz -C /tmp/recon_kr 2>/dev/null; then
        kr_bin=$(find /tmp/recon_kr -type f -name kr 2>/dev/null | head -1)
        if [ -n "$kr_bin" ] && install -m 0755 "$kr_bin" "$LOCAL_BIN/kr" 2>/dev/null; then
          success "kiterunner installed"
        else
          warn "kiterunner extraction succeeded but binary install failed"
        fi
      else
        warn "kiterunner download/extract failed"
      fi
      rm -rf /tmp/recon_kr /tmp/recon_kr.tar.gz
    else
      warn "kiterunner download URL not found"
    fi
  else
    success "kiterunner already installed"
  fi

  # feroxbuster
  if ! command -v feroxbuster &>/dev/null; then
    info "Downloading feroxbuster..."
    local fb_url fb_bin
    fb_url=$(curl -s https://api.github.com/repos/epi052/feroxbuster/releases/latest \
      | jq -r '.assets[] | select(.name | test("x86_64-linux")) | .browser_download_url' 2>/dev/null | head -1)
    if [ -n "$fb_url" ]; then
      rm -rf /tmp/recon_feroxbuster /tmp/recon_feroxbuster.zip /tmp/recon_feroxbuster.tar.gz
      mkdir -p /tmp/recon_feroxbuster

      if [[ "$fb_url" == *.zip ]]; then
        if wget -q "$fb_url" -O /tmp/recon_feroxbuster.zip 2>/dev/null && \
           unzip -oq /tmp/recon_feroxbuster.zip -d /tmp/recon_feroxbuster 2>/dev/null; then
          :
        else
          warn "feroxbuster zip download/extract failed"
        fi
      elif [[ "$fb_url" == *.tar.gz ]] || [[ "$fb_url" == *.tgz ]]; then
        if wget -q "$fb_url" -O /tmp/recon_feroxbuster.tar.gz 2>/dev/null && \
           tar xzf /tmp/recon_feroxbuster.tar.gz -C /tmp/recon_feroxbuster 2>/dev/null; then
          :
        else
          warn "feroxbuster tar download/extract failed"
        fi
      else
        if wget -q "$fb_url" -O /tmp/recon_feroxbuster/feroxbuster 2>/dev/null; then
          :
        else
          warn "feroxbuster direct binary download failed"
        fi
      fi

      fb_bin=$(find /tmp/recon_feroxbuster -type f -name feroxbuster 2>/dev/null | head -1)
      if [ -n "$fb_bin" ] && install -m 0755 "$fb_bin" "$LOCAL_BIN/feroxbuster" 2>/dev/null; then
        success "feroxbuster installed"
      else
        warn "feroxbuster binary not found after download"
      fi
      rm -rf /tmp/recon_feroxbuster /tmp/recon_feroxbuster.zip /tmp/recon_feroxbuster.tar.gz
    else
      warn "feroxbuster download URL not found"
    fi
  else
    success "feroxbuster already installed"
  fi

  # gitleaks
  if ! command -v gitleaks &>/dev/null; then
    info "Downloading gitleaks..."
    local gl_url gl_bin
    gl_url=$(curl -s https://api.github.com/repos/gitleaks/gitleaks/releases/latest \
      | jq -r '.assets[] | select(.name | test("linux_x64")) | .browser_download_url' 2>/dev/null | head -1)
    if [ -n "$gl_url" ]; then
      rm -rf /tmp/recon_gitleaks /tmp/recon_gitleaks.tar.gz /tmp/recon_gitleaks.zip
      mkdir -p /tmp/recon_gitleaks

      if [[ "$gl_url" == *.tar.gz ]] || [[ "$gl_url" == *.tgz ]]; then
        if wget -q "$gl_url" -O /tmp/recon_gitleaks.tar.gz 2>/dev/null && \
           tar xzf /tmp/recon_gitleaks.tar.gz -C /tmp/recon_gitleaks 2>/dev/null; then
          :
        else
          warn "gitleaks tar download/extract failed"
        fi
      elif [[ "$gl_url" == *.zip ]]; then
        if wget -q "$gl_url" -O /tmp/recon_gitleaks.zip 2>/dev/null && \
           unzip -oq /tmp/recon_gitleaks.zip -d /tmp/recon_gitleaks 2>/dev/null; then
          :
        else
          warn "gitleaks zip download/extract failed"
        fi
      else
        if wget -q "$gl_url" -O /tmp/recon_gitleaks/gitleaks 2>/dev/null; then
          :
        else
          warn "gitleaks direct binary download failed"
        fi
      fi

      gl_bin=$(find /tmp/recon_gitleaks -type f -name gitleaks 2>/dev/null | head -1)
      if [ -n "$gl_bin" ] && install -m 0755 "$gl_bin" "$LOCAL_BIN/gitleaks" 2>/dev/null; then
        success "gitleaks installed"
      else
        warn "gitleaks binary not found after download"
      fi
      rm -rf /tmp/recon_gitleaks /tmp/recon_gitleaks.tar.gz /tmp/recon_gitleaks.zip
    else
      warn "gitleaks download URL not found"
    fi
  else
    success "gitleaks already installed"
  fi

  # trufflehog sanity fallback (in case Go install path failed earlier)
  if ! command -v trufflehog &>/dev/null; then
    info "Attempting trufflehog fallback install..."
    install_trufflehog_binary || true
  else
    success "trufflehog already installed"
  fi
}

# ─── 7. DOWNLOAD WORDLISTS ──────────────────────────────────
download_wordlists() {
  local wl_dir="$SCRIPT_DIR/data/wordlists"
  mkdir -p "$wl_dir/dns" "$wl_dir/web"

  info "Downloading wordlists..."

  local failures=0

  download_validated_text_file \
    "$wl_dir/dns/subdomains-top1million-110000.txt" \
    1000 \
    "DNS wordlist: subdomains-top1million-110000" \
    "https://raw.githubusercontent.com/danielmiessler/SecLists/master/Discovery/DNS/subdomains-top1million-110000.txt" \
    "https://raw.githubusercontent.com/danielmiessler/SecLists/main/Discovery/DNS/subdomains-top1million-110000.txt" || failures=$((failures + 1))

  download_validated_text_file \
    "$wl_dir/dns/dns-Jhaddix.txt" \
    100 \
    "DNS wordlist: dns-Jhaddix" \
    "https://raw.githubusercontent.com/danielmiessler/SecLists/master/Discovery/DNS/dns-Jhaddix.txt" \
    "https://raw.githubusercontent.com/danielmiessler/SecLists/main/Discovery/DNS/dns-Jhaddix.txt" || failures=$((failures + 1))

  download_validated_text_file \
    "$wl_dir/dns/best-dns-wordlist.txt" \
    100 \
    "DNS wordlist: best-dns-wordlist" \
    "https://wordlists-cdn.assetnote.io/data/manual/best-dns-wordlist.txt" || failures=$((failures + 1))

  download_validated_text_file \
    "$wl_dir/web/common.txt" \
    100 \
    "Web wordlist: common.txt" \
    "https://raw.githubusercontent.com/danielmiessler/SecLists/master/Discovery/Web-Content/common.txt" \
    "https://raw.githubusercontent.com/danielmiessler/SecLists/main/Discovery/Web-Content/common.txt" || failures=$((failures + 1))

  download_validated_text_file \
    "$wl_dir/web/raft-large-directories.txt" \
    100 \
    "Web wordlist: raft-large-directories" \
    "https://raw.githubusercontent.com/danielmiessler/SecLists/master/Discovery/Web-Content/raft-large-directories.txt" \
    "https://raw.githubusercontent.com/danielmiessler/SecLists/main/Discovery/Web-Content/raft-large-directories.txt" || failures=$((failures + 1))

  download_validated_text_file \
    "$wl_dir/web/raft-large-files.txt" \
    100 \
    "Web wordlist: raft-large-files" \
    "https://raw.githubusercontent.com/danielmiessler/SecLists/master/Discovery/Web-Content/raft-large-files.txt" \
    "https://raw.githubusercontent.com/danielmiessler/SecLists/main/Discovery/Web-Content/raft-large-files.txt" || failures=$((failures + 1))

  download_validated_text_file \
    "$wl_dir/web/burp-parameter-names.txt" \
    20 \
    "Web wordlist: burp-parameter-names" \
    "https://raw.githubusercontent.com/danielmiessler/SecLists/master/Discovery/Web-Content/burp-parameter-names.txt" \
    "https://raw.githubusercontent.com/danielmiessler/SecLists/main/Discovery/Web-Content/burp-parameter-names.txt" || failures=$((failures + 1))

  if [ "$failures" -gt 0 ]; then
    error "Wordlist installation failed for $failures required files"
    return 1
  fi

  success "All required wordlists are installed"
}

# ─── 8. DOWNLOAD RESOLVERS ──────────────────────────────────
download_resolvers() {
  local res_dir="$SCRIPT_DIR/data/resolvers"
  local res_file="$res_dir/resolvers.txt"
  mkdir -p "$res_dir"

  if file_has_min_lines "$res_file" 50 && [ -z "$(find "$res_file" -mtime +7 2>/dev/null)" ]; then
    success "Resolvers are up to date ($(wc -l < "$res_file" | tr -d ' ') entries)"
    return 0
  fi

  if [ -f "$res_file" ]; then
    warn "Resolvers file is stale or invalid. Refreshing..."
  else
    info "Downloading fresh resolvers..."
  fi

  if ! download_validated_text_file \
    "$res_file" \
    50 \
    "Resolvers list" \
    "https://raw.githubusercontent.com/trickest/resolvers/main/resolvers.txt" \
    "https://raw.githubusercontent.com/blechschmidt/massdns/master/lists/resolvers.txt"; then
    error "Resolvers installation failed"
    return 1
  fi

  success "Resolvers downloaded ($(wc -l < "$res_file" | tr -d ' ') entries)"
}

# ─── 9. DOWNLOAD GITHUB DORKS ───────────────────────────────
download_dorks() {
  local dorks_dir="$SCRIPT_DIR/data/dorks"
  local dorks_file="$dorks_dir/github_dorks.txt"
  mkdir -p "$dorks_dir"

  info "Downloading GitHub dorks..."
  if ! download_validated_text_file \
    "$dorks_file" \
    5 \
    "GitHub dorks" \
    "https://raw.githubusercontent.com/Proviesec/github-dorks/main/github-dorks.txt" \
    "https://raw.githubusercontent.com/Proviesec/github-dorks/main/best-github-dorks.txt"; then
    error "GitHub dorks installation failed"
    return 1
  fi

  success "GitHub dorks are installed ($(wc -l < "$dorks_file" | tr -d ' ') lines)"
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
