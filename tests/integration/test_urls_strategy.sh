#!/bin/bash
# ============================================================
# RECON Framework — Integration Test: Wildcard URL strategy
# Validates root-domain-first waymore + bounded fallback behavior
# ============================================================

cd "$(dirname "${BASH_SOURCE[0]}")/../.." || exit 1

source lib/utils.sh
source lib/state.sh
source lib/core.sh
source lib/urls.sh

ERRORS=0
TARGET="example.com"
TARGET_MODE="wildcard"
OUTPUT_BASE="/tmp/recon_test_urls_strategy_$$"
VERSION="1.0.0"
FORCE="false"
NO_NOTIFY="true"
GAU_THREADS=10
WAYMORE_FALLBACK_MAX_HOSTS=3
LOG_FILE="/tmp/test_urls_strategy_log_$$.txt"

MOCK_BIN="/tmp/recon_mock_bin_$$"
WAYMORE_CALLS_FILE="/tmp/recon_waymore_calls_$$.txt"
mkdir -p "$MOCK_BIN"
: > "$WAYMORE_CALLS_FILE"
export WAYMORE_CALLS_FILE

cat > "$MOCK_BIN/waymore" << 'EOF'
#!/bin/bash
input=""
out=""
while [ $# -gt 0 ]; do
  case "$1" in
    -i)
      input="$2"
      shift 2
      ;;
    -oU)
      out="$2"
      shift 2
      ;;
    *)
      shift
      ;;
  esac
done

echo "$input" >> "$WAYMORE_CALLS_FILE"

[ -n "$out" ] || exit 0
if [ "$input" = "example.com" ]; then
  : > "$out"
  exit 0
fi

if [[ "$input" =~ ^https?:// ]]; then
  printf "%s/test?x=1\n" "$input" > "$out"
else
  printf "https://%s/test?x=1\n" "$input" > "$out"
fi
EOF

cat > "$MOCK_BIN/waybackurls" << 'EOF'
#!/bin/bash
cat >/dev/null
exit 0
EOF

cat > "$MOCK_BIN/gau" << 'EOF'
#!/bin/bash
cat >/dev/null
exit 0
EOF

cat > "$MOCK_BIN/hakrawler" << 'EOF'
#!/bin/bash
cat >/dev/null
exit 0
EOF

cat > "$MOCK_BIN/katana" << 'EOF'
#!/bin/bash
exit 0
EOF

cat > "$MOCK_BIN/gospider" << 'EOF'
#!/bin/bash
out_dir=""
while [ $# -gt 0 ]; do
  case "$1" in
    -o)
      out_dir="$2"
      shift 2
      ;;
    *)
      shift
      ;;
  esac
done
[ -n "$out_dir" ] && mkdir -p "$out_dir"
exit 0
EOF

cat > "$MOCK_BIN/httpx" << 'EOF'
#!/bin/bash
input_file=""
while [ $# -gt 0 ]; do
  case "$1" in
    -l)
      input_file="$2"
      shift 2
      ;;
    *)
      shift
      ;;
  esac
done
[ -n "$input_file" ] && cat "$input_file"
exit 0
EOF

chmod +x "$MOCK_BIN"/*
export PATH="$MOCK_BIN:$PATH"

init_workspace

for i in $(seq 1 10); do
  echo "https://sub${i}.example.com" >> "$WORKDIR/03_live_hosts/live.txt"
done

if collect_urls; then
  echo "PASS: collect_urls completed"
else
  echo "FAIL: collect_urls failed"
  ((ERRORS++))
fi

first_call=$(head -n 1 "$WAYMORE_CALLS_FILE" 2>/dev/null)
if [ "$first_call" = "example.com" ]; then
  echo "PASS: waymore root-domain-first call verified"
else
  echo "FAIL: first waymore call mismatch (got: $first_call)"
  ((ERRORS++))
fi

call_count=$(wc -l < "$WAYMORE_CALLS_FILE" | tr -d ' ')
if [ "$call_count" -eq 4 ]; then
  echo "PASS: waymore fallback host cap enforced"
else
  echo "FAIL: unexpected waymore call count (got: $call_count, expected: 4)"
  ((ERRORS++))
fi

if [ -s "$WORKDIR/05_urls/all_urls.txt" ]; then
  url_count=$(wc -l < "$WORKDIR/05_urls/all_urls.txt" | tr -d ' ')
  echo "PASS: URL output produced ($url_count URLs)"
else
  echo "FAIL: no URL output produced"
  ((ERRORS++))
fi

rm -rf "$OUTPUT_BASE" "$MOCK_BIN"
rm -f "$WAYMORE_CALLS_FILE" "$LOG_FILE"

exit $ERRORS
