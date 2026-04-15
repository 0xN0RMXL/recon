#!/bin/bash
# ============================================================
# RECON Framework — lib/parallel.sh
# GNU parallel wrappers for tool parallelization
# ============================================================

# ─── RUN COMMAND IN PARALLEL ACROSS FILE LINES ──────────────
# Usage: parallel_exec <input_file> <concurrency> <command_template>
# The placeholder {} in command_template is replaced with each line
parallel_exec() {
  local input_file="$1"
  local concurrency="$2"
  shift 2
  local cmd_template="$*"

  if ! command -v parallel &>/dev/null; then
    log warn "GNU parallel not found. Running sequentially."
    while IFS= read -r line; do
      eval "${cmd_template//\{\}/$line}"
    done < "$input_file"
    return
  fi

  parallel -j "$concurrency" --bar --halt soon,fail=20% \
    "$cmd_template" :::: "$input_file"
}

# ─── RUN MULTIPLE TOOLS IN PARALLEL ─────────────────────────
# Usage: parallel_tools <func1> <func2> ...
# Each function runs in background, all are waited on
parallel_tools() {
  local pids=()
  for func in "$@"; do
    $func &
    pids+=($!)
  done

  # Wait for all and collect exit codes
  local failed=0
  for pid in "${pids[@]}"; do
    if ! wait "$pid"; then
      ((failed++))
    fi
  done

  return $failed
}

# ─── BATCH PROCESS WITH RATE LIMITING ────────────────────────
# Usage: batch_process <input_file> <batch_size> <delay_seconds> <command>
batch_process() {
  local input_file="$1"
  local batch_size="$2"
  local delay="$3"
  shift 3
  local cmd="$*"

  local count=0
  while IFS= read -r line; do
    eval "${cmd//\{\}/$line}" &
    ((count++))
    if [ $((count % batch_size)) -eq 0 ]; then
      wait
      sleep "$delay"
    fi
  done < "$input_file"
  wait
}
