#!/bin/bash
# ============================================================
# RECON Framework — lib/cloud.sh
# Phase 10 — Cloud Asset Detection
# ============================================================

cloud_enum() {
  local OUT="$WORKDIR/10_cloud"
  local ERR_LOG="$OUT/cloud_errors.log"

  : > "$ERR_LOG"

  log info "Phase 10: Cloud asset detection starting"

  # Check for S3 bucket patterns based on target name
  local TARGET_CLEAN
  TARGET_CLEAN=$(echo "$TARGET" | sed 's/\./-/g')
  local BUCKET_PATTERNS=(
    "$TARGET_CLEAN"
    "www-$TARGET_CLEAN"
    "dev-$TARGET_CLEAN"
    "staging-$TARGET_CLEAN"
    "backup-$TARGET_CLEAN"
    "assets-$TARGET_CLEAN"
    "media-$TARGET_CLEAN"
    "static-$TARGET_CLEAN"
  )

  touch "$OUT/buckets.txt" "$OUT/accessible_buckets.txt"

  for bucket in "${BUCKET_PATTERNS[@]}"; do
    echo "$bucket" >> "$OUT/buckets.txt"
    # Test public access
    local response
    response=$(curl -sk -o /dev/null -w "%{http_code}" \
      "https://$bucket.s3.amazonaws.com/" 2>>"$ERR_LOG")
    if [[ "$response" =~ ^(200|301|403)$ ]]; then
      echo "$bucket.s3.amazonaws.com → HTTP $response" >> "$OUT/accessible_buckets.txt"
      log warn "Accessible S3 bucket found: $bucket (HTTP $response)"
    fi
  done

  # Check cloud leaks from URL categorization
  if [ -s "$WORKDIR/05_urls/categorized/cloud_leaks.txt" ]; then
    cat "$WORKDIR/05_urls/categorized/cloud_leaks.txt" >> "$OUT/buckets.txt"
    sort -u "$OUT/buckets.txt" -o "$OUT/buckets.txt" 2>>"$ERR_LOG"
  fi

  log success "Cloud asset detection complete"
}
