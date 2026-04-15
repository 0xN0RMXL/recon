#!/bin/bash
# ============================================================
# RECON Framework — update.sh
# Updates all tools, templates, wordlists, and resolvers
# ============================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
RESET='\033[0m'

info()    { echo -e "${CYAN}[*]${RESET} $1"; }
success() { echo -e "${GREEN}[+]${RESET} $1"; }
warn()    { echo -e "${YELLOW}[!]${RESET} $1"; }

echo ""
echo -e "${CYAN}RECON Framework — Update Tool${RESET}"
echo -e "${CYAN}═══════════════════════════════${RESET}"
echo ""

# Update Go tools
info "Updating Go tools..."
export PATH=$PATH:/usr/local/go/bin:$HOME/go/bin
while IFS= read -r tool; do
  [ -z "$tool" ] && continue
  [[ "$tool" =~ ^# ]] && continue
  local_name=$(basename "$tool" | cut -d@ -f1)
  go install "$tool" 2>/dev/null && \
    success "Updated: $local_name" || \
    warn "Failed: $local_name"
done < "$SCRIPT_DIR/go-tools.txt"

# Update nuclei templates
info "Updating nuclei templates..."
nuclei -update-templates 2>/dev/null && \
  success "Nuclei templates updated" || \
  warn "Nuclei template update failed"

# Update resolvers
info "Updating resolvers..."
wget -q -O "$SCRIPT_DIR/data/resolvers/resolvers.txt" \
  https://raw.githubusercontent.com/trickest/resolvers/main/resolvers.txt 2>/dev/null && \
  success "Resolvers updated" || \
  warn "Resolvers update failed"

# Update GitHub dorks
info "Updating GitHub dorks..."
wget -q -O "$SCRIPT_DIR/data/dorks/github_dorks.txt" \
  https://raw.githubusercontent.com/Proviesec/github-dorks/main/dorks.txt 2>/dev/null && \
  success "GitHub dorks updated" || \
  warn "GitHub dorks update failed"

# Update cloned tools
info "Updating cloned tools..."
for dir in "$HOME/tools/GitDorker" "$HOME/tools/bfac" "$HOME/tools/sqlmap"; do
  if [ -d "$dir" ]; then
    (cd "$dir" && git pull -q 2>/dev/null) && \
      success "Updated: $(basename "$dir")" || \
      warn "Failed: $(basename "$dir")"
  fi
done

# Update Python tools
info "Updating Python tools..."
pip3 install --break-system-packages --upgrade -r "$SCRIPT_DIR/requirements.txt" 2>/dev/null && \
  success "Python tools updated" || \
  warn "Python tools update failed"

echo ""
success "All updates complete."
echo ""
