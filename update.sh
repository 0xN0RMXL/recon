#!/bin/bash
# ============================================================
# RECON Framework — update.sh
# Updates all tools, templates, wordlists, and resolvers
# ============================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ACTUAL_USER="${SUDO_USER:-$(whoami)}"
ACTUAL_HOME=$(getent passwd "$ACTUAL_USER" 2>/dev/null | cut -d: -f6)
[ -z "$ACTUAL_HOME" ] && ACTUAL_HOME="$HOME"
TOOLS_DIR="$ACTUAL_HOME/tools"

GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
RESET='\033[0m'

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

update_go_tools() {
  if [ ! -f "$SCRIPT_DIR/go-tools.txt" ]; then
    warn "go-tools.txt not found; skipping Go tools update"
    return 0
  fi

  local go_bin
  go_bin=$(resolve_go_binary)
  if [ -z "$go_bin" ]; then
    warn "Go is not installed; skipping Go tools update"
    return 0
  fi

  info "Updating Go tools..."
  while IFS= read -r tool; do
    [ -z "$tool" ] && continue
    [[ "$tool" =~ ^# ]] && continue

    local local_name
    local_name=$(basename "$tool" | cut -d@ -f1)
    if run_as_actual_user "$go_bin" install "$tool" >/dev/null 2>&1; then
      success "Updated: $local_name"
    else
      warn "Failed: $local_name"
    fi
  done < "$SCRIPT_DIR/go-tools.txt"
}

update_nuclei_templates() {
  info "Updating nuclei templates..."
  nuclei -update-templates >/dev/null 2>&1 && \
    success "Nuclei templates updated" || \
    warn "Nuclei template update failed"
}

update_resolvers() {
  info "Updating resolvers..."
  wget -q -O "$SCRIPT_DIR/data/resolvers/resolvers.txt" \
    https://raw.githubusercontent.com/trickest/resolvers/main/resolvers.txt 2>/dev/null && \
    success "Resolvers updated" || \
    warn "Resolvers update failed"
}

update_dorks() {
  info "Updating GitHub dorks..."
  wget -q -O "$SCRIPT_DIR/data/dorks/github_dorks.txt" \
    https://raw.githubusercontent.com/Proviesec/github-dorks/main/github-dorks.txt 2>/dev/null && \
    success "GitHub dorks updated" || \
    warn "GitHub dorks update failed"
}

update_cloned_tools() {
  info "Updating cloned tools..."
  for dir in "$TOOLS_DIR/GitDorker" "$TOOLS_DIR/bfac" "$TOOLS_DIR/sqlmap" "$TOOLS_DIR/paramspider"; do
    if [ -d "$dir/.git" ]; then
      run_as_actual_user git -C "$dir" pull --ff-only >/dev/null 2>&1 && \
        success "Updated: $(basename "$dir")" || \
        warn "Failed: $(basename "$dir")"
    fi
  done
}

update_massdns() {
  if command -v massdns &>/dev/null && massdns -h >/dev/null 2>&1; then
    success "massdns runtime is healthy"
    return 0
  fi

  warn "massdns missing or unhealthy; attempting source rebuild"
  local build_dir="/tmp/recon_massdns_update"
  rm -rf "$build_dir"

  if ! git clone -q https://github.com/blechschmidt/massdns "$build_dir" 2>/dev/null; then
    warn "Failed to clone massdns source"
    return 0
  fi

  if ! (cd "$build_dir" && make -s) 2>/dev/null; then
    warn "Failed to build massdns"
    rm -rf "$build_dir"
    return 0
  fi

  if [ -w "/usr/local/bin" ] || [ "$(id -u)" -eq 0 ]; then
    install -m 0755 "$build_dir/bin/massdns" /usr/local/bin/massdns 2>/dev/null || true
  elif command -v sudo &>/dev/null; then
    sudo install -m 0755 "$build_dir/bin/massdns" /usr/local/bin/massdns 2>/dev/null || true
  fi

  rm -rf "$build_dir"

  if command -v massdns &>/dev/null && massdns -h >/dev/null 2>&1; then
    success "massdns repaired/updated"
  else
    warn "massdns update skipped (permission/runtime issue)"
  fi
}

update_python_tools() {
  local py_bin
  py_bin=$(command -v python3 || true)

  if [ -z "$py_bin" ]; then
    warn "python3 not found; skipping Python tools update"
    return 0
  fi

  info "Updating Python tools..."
  run_as_actual_user "$py_bin" -m pip install --user --break-system-packages --upgrade -r "$SCRIPT_DIR/requirements.txt" >/dev/null 2>&1 && \
    success "Python tools updated" || \
    warn "Python tools update failed"
}

echo ""
echo -e "${CYAN}RECON Framework — Update Tool${RESET}"
echo -e "${CYAN}═══════════════════════════════${RESET}"
echo ""

update_go_tools
update_nuclei_templates
update_resolvers
update_dorks
update_cloned_tools
update_massdns
update_python_tools

echo ""
success "All updates complete."
echo ""
