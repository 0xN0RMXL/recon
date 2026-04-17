#!/bin/bash
# ============================================================
# RECON Framework — lib/reporting.sh
# Reporting Engine — JSON + Markdown + HTML Summary Reports
# ============================================================

reporting_error_log() {
  echo "$WORKDIR/reports/reporting_errors.log"
}

generate_report() {
  local REPORTS="$WORKDIR/reports"
  local ERR_LOG
  ERR_LOG=$(reporting_error_log)

  : > "$ERR_LOG"

  log info "Generating reports..."

  # ── JSON REPORT ──────────────────────────────────────────
  _generate_json_report

  # ── MARKDOWN REPORT ──────────────────────────────────────
  _generate_markdown_report

  # ── HTML REPORT ──────────────────────────────────────────
  _generate_html_report

  # ── HACKERONE TEMPLATE ───────────────────────────────────
  _generate_h1_template

  # ── BURP EXPORT ──────────────────────────────────────────
  burp_export_xml

  # ── FINDINGS JSON ────────────────────────────────────────
  _generate_findings_json

  log success "All reports generated in $REPORTS/"
}

_generate_json_report() {
  local ERR_LOG
  ERR_LOG=$(reporting_error_log)

  local subs live urls js params nuclei_crit nuclei_high secrets takeovers
  subs=$(wc -l < "$WORKDIR/01_subdomains/all_subdomains.txt" 2>>"$ERR_LOG" || echo 0)
  live=$(wc -l < "$WORKDIR/03_live_hosts/live.txt" 2>>"$ERR_LOG" || echo 0)
  urls=$(wc -l < "$WORKDIR/05_urls/all_urls.txt" 2>>"$ERR_LOG" || echo 0)
  js=$(wc -l < "$WORKDIR/07_js/js_urls.txt" 2>>"$ERR_LOG" || echo 0)
  params=$(wc -l < "$WORKDIR/08_params/all_params.txt" 2>>"$ERR_LOG" || echo 0)
  nuclei_crit=$(wc -l < "$WORKDIR/09_vulns/nuclei_critical.txt" 2>>"$ERR_LOG" || echo 0)
  nuclei_high=$(wc -l < "$WORKDIR/09_vulns/nuclei_high.txt" 2>>"$ERR_LOG" || echo 0)
  secrets=$(wc -l < "$WORKDIR/11_secrets/regex_secrets.txt" 2>>"$ERR_LOG" || echo 0)
  takeovers=$(wc -l < "$WORKDIR/09_vulns/takeovers_nuclei.txt" 2>>"$ERR_LOG" || echo 0)

  # Trim whitespace
  subs=$(echo "$subs" | tr -d ' ')
  live=$(echo "$live" | tr -d ' ')
  urls=$(echo "$urls" | tr -d ' ')
  js=$(echo "$js" | tr -d ' ')
  params=$(echo "$params" | tr -d ' ')
  nuclei_crit=$(echo "$nuclei_crit" | tr -d ' ')
  nuclei_high=$(echo "$nuclei_high" | tr -d ' ')
  secrets=$(echo "$secrets" | tr -d ' ')
  takeovers=$(echo "$takeovers" | tr -d ' ')

  if command -v jq &>/dev/null; then
    jq -n \
      --arg target "$TARGET" \
      --arg ts "$(date -Iseconds 2>>"$ERR_LOG" || date '+%Y-%m-%dT%H:%M:%S')" \
      --arg subs "$subs" \
      --arg live "$live" \
      --arg urls "$urls" \
      --arg js "$js" \
      --arg params "$params" \
      --arg nuclei_crit "$nuclei_crit" \
      --arg nuclei_high "$nuclei_high" \
      --arg secrets "$secrets" \
      --arg takeovers "$takeovers" \
      '{
        target: $target,
        timestamp: $ts,
        stats: {
          subdomains: ($subs | tonumber),
          live_hosts: ($live | tonumber),
          urls: ($urls | tonumber),
          js_files: ($js | tonumber),
          parameters: ($params | tonumber),
          nuclei_critical: ($nuclei_crit | tonumber),
          nuclei_high: ($nuclei_high | tonumber),
          secrets_found: ($secrets | tonumber),
          takeover_candidates: ($takeovers | tonumber)
        }
      }' > "$WORKDIR/reports/summary.json"
  else
    cat > "$WORKDIR/reports/summary.json" <<EOF
{
  "target": "$TARGET",
  "timestamp": "$(date)",
  "stats": {
    "subdomains": $subs,
    "live_hosts": $live,
    "urls": $urls,
    "js_files": $js,
    "parameters": $params,
    "nuclei_critical": $nuclei_crit,
    "nuclei_high": $nuclei_high,
    "secrets_found": $secrets,
    "takeover_candidates": $takeovers
  }
}
EOF
  fi

  log info "JSON report saved"
}

_generate_markdown_report() {
  local ERR_LOG
  ERR_LOG=$(reporting_error_log)

  local subs live urls js params nuclei_crit nuclei_high secrets takeovers
  subs=$(wc -l < "$WORKDIR/01_subdomains/all_subdomains.txt" 2>>"$ERR_LOG" || echo 0)
  live=$(wc -l < "$WORKDIR/03_live_hosts/live.txt" 2>>"$ERR_LOG" || echo 0)
  urls=$(wc -l < "$WORKDIR/05_urls/all_urls.txt" 2>>"$ERR_LOG" || echo 0)
  js=$(wc -l < "$WORKDIR/07_js/js_urls.txt" 2>>"$ERR_LOG" || echo 0)
  params=$(wc -l < "$WORKDIR/08_params/all_params.txt" 2>>"$ERR_LOG" || echo 0)
  nuclei_crit=$(wc -l < "$WORKDIR/09_vulns/nuclei_critical.txt" 2>>"$ERR_LOG" || echo 0)
  nuclei_high=$(wc -l < "$WORKDIR/09_vulns/nuclei_high.txt" 2>>"$ERR_LOG" || echo 0)
  secrets=$(wc -l < "$WORKDIR/11_secrets/regex_secrets.txt" 2>>"$ERR_LOG" || echo 0)
  takeovers=$(wc -l < "$WORKDIR/09_vulns/takeovers_nuclei.txt" 2>>"$ERR_LOG" || echo 0)

  {
    echo "# Recon Report: $TARGET"
    echo "**Date**: $(date -Iseconds 2>>"$ERR_LOG" || date)"
    echo ""
    echo "## Executive Summary"
    echo "| Metric | Count |"
    echo "|--------|-------|"
    echo "| Total Subdomains | $(echo $subs | tr -d ' ') |"
    echo "| Live Hosts | $(echo $live | tr -d ' ') |"
    echo "| URLs Discovered | $(echo $urls | tr -d ' ') |"
    echo "| JS Files | $(echo $js | tr -d ' ') |"
    echo "| Parameters | $(echo $params | tr -d ' ') |"
    echo "| Critical Findings | $(echo $nuclei_crit | tr -d ' ') |"
    echo "| High Findings | $(echo $nuclei_high | tr -d ' ') |"
    echo "| Secrets Found | $(echo $secrets | tr -d ' ') |"
    echo "| Takeover Candidates | $(echo $takeovers | tr -d ' ') |"
    echo ""

    echo "## Priority Actions"
    if [ -s "$WORKDIR/intelligence/decision_report.txt" ]; then
      cat "$WORKDIR/intelligence/decision_report.txt"
    else
      echo "_No decision report generated._"
    fi
    echo ""

    echo "## Critical Findings"
    if [ -s "$WORKDIR/09_vulns/nuclei_critical.txt" ]; then
      echo '```'
      cat "$WORKDIR/09_vulns/nuclei_critical.txt"
      echo '```'
    else
      echo "_None detected._"
    fi
    echo ""

    echo "## High Findings"
    if [ -s "$WORKDIR/09_vulns/nuclei_high.txt" ]; then
      echo '```'
      cat "$WORKDIR/09_vulns/nuclei_high.txt"
      echo '```'
    else
      echo "_None detected._"
    fi
    echo ""

    echo "## Subdomain Takeovers"
    if [ -s "$WORKDIR/09_vulns/takeovers_nuclei.txt" ]; then
      echo '```'
      cat "$WORKDIR/09_vulns/takeovers_nuclei.txt"
      echo '```'
    else
      echo "_None detected._"
    fi
    echo ""

    echo "## Secrets Detected"
    if [ -s "$WORKDIR/11_secrets/regex_secrets.txt" ]; then
      echo '```'
      head -20 "$WORKDIR/11_secrets/regex_secrets.txt"
      echo '```'
    else
      echo "_None detected._"
    fi
    echo ""

    echo "## Bug Chains"
    if [ -s "$WORKDIR/intelligence/bug_chains.txt" ]; then
      cat "$WORKDIR/intelligence/bug_chains.txt"
    else
      echo "_No chains detected._"
    fi
    echo ""

    echo "## Vulnerability Hypotheses"
    if [ -s "$WORKDIR/intelligence/hypotheses.txt" ]; then
      cat "$WORKDIR/intelligence/hypotheses.txt"
    else
      echo "_No hypotheses generated._"
    fi
    echo ""

    echo "## All Subdomains (first 100)"
    if [ -s "$WORKDIR/01_subdomains/all_subdomains.txt" ]; then
      echo '```'
      head -100 "$WORKDIR/01_subdomains/all_subdomains.txt"
      echo '```'
    else
      echo "_None found._"
    fi

  } > "$WORKDIR/reports/summary.md"

  log info "Markdown report saved"
}

_generate_html_report() {
  local ERR_LOG
  ERR_LOG=$(reporting_error_log)

  local subs live urls js params nuclei_crit nuclei_high secrets takeovers
  subs=$(wc -l < "$WORKDIR/01_subdomains/all_subdomains.txt" 2>>"$ERR_LOG" || echo 0)
  live=$(wc -l < "$WORKDIR/03_live_hosts/live.txt" 2>>"$ERR_LOG" || echo 0)
  urls=$(wc -l < "$WORKDIR/05_urls/all_urls.txt" 2>>"$ERR_LOG" || echo 0)
  js=$(wc -l < "$WORKDIR/07_js/js_urls.txt" 2>>"$ERR_LOG" || echo 0)
  params=$(wc -l < "$WORKDIR/08_params/all_params.txt" 2>>"$ERR_LOG" || echo 0)
  nuclei_crit=$(wc -l < "$WORKDIR/09_vulns/nuclei_critical.txt" 2>>"$ERR_LOG" || echo 0)
  nuclei_high=$(wc -l < "$WORKDIR/09_vulns/nuclei_high.txt" 2>>"$ERR_LOG" || echo 0)
  secrets=$(wc -l < "$WORKDIR/11_secrets/regex_secrets.txt" 2>>"$ERR_LOG" || echo 0)
  takeovers=$(wc -l < "$WORKDIR/09_vulns/takeovers_nuclei.txt" 2>>"$ERR_LOG" || echo 0)

  # Trim whitespace
  subs=$(echo "$subs" | tr -d ' ')
  live=$(echo "$live" | tr -d ' ')
  urls=$(echo "$urls" | tr -d ' ')
  js=$(echo "$js" | tr -d ' ')
  params=$(echo "$params" | tr -d ' ')
  nuclei_crit=$(echo "$nuclei_crit" | tr -d ' ')
  nuclei_high=$(echo "$nuclei_high" | tr -d ' ')
  secrets=$(echo "$secrets" | tr -d ' ')
  takeovers=$(echo "$takeovers" | tr -d ' ')

  # Build contents for sections
  local critical_content high_content takeover_content secrets_content chains_content hypotheses_content
  critical_content=$(cat "$WORKDIR/09_vulns/nuclei_critical.txt" 2>>"$ERR_LOG" | head -50 | sed 's/</\&lt;/g;s/>/\&gt;/g' || echo "None detected.")
  high_content=$(cat "$WORKDIR/09_vulns/nuclei_high.txt" 2>>"$ERR_LOG" | head -50 | sed 's/</\&lt;/g;s/>/\&gt;/g' || echo "None detected.")
  takeover_content=$(cat "$WORKDIR/09_vulns/takeovers_nuclei.txt" 2>>"$ERR_LOG" | sed 's/</\&lt;/g;s/>/\&gt;/g' || echo "None detected.")
  secrets_content=$(head -20 "$WORKDIR/11_secrets/regex_secrets.txt" 2>>"$ERR_LOG" | sed 's/</\&lt;/g;s/>/\&gt;/g' || echo "None detected.")
  chains_content=$(cat "$WORKDIR/intelligence/bug_chains.txt" 2>>"$ERR_LOG" | sed 's/</\&lt;/g;s/>/\&gt;/g' || echo "No chains detected.")
  hypotheses_content=$(cat "$WORKDIR/intelligence/hypotheses.txt" 2>>"$ERR_LOG" | head -100 | sed 's/</\&lt;/g;s/>/\&gt;/g' || echo "No hypotheses generated.")

  cat > "$WORKDIR/reports/summary.html" <<'HTMLEOF'
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>RECON Report</title>
<style>
*{margin:0;padding:0;box-sizing:border-box}
body{background:#0d1117;color:#c9d1d9;font-family:'Segoe UI',system-ui,-apple-system,sans-serif;line-height:1.6;padding:20px}
.container{max-width:1200px;margin:0 auto}
h1{color:#58a6ff;font-size:2rem;margin-bottom:5px}
h2{color:#58a6ff;font-size:1.3rem;margin:20px 0 10px;cursor:pointer;user-select:none}
h2:hover{color:#79c0ff}
h2::before{content:'▸ ';transition:transform 0.2s}
h2.open::before{content:'▾ '}
.subtitle{color:#8b949e;font-size:0.9rem;margin-bottom:30px}
.stats{display:grid;grid-template-columns:repeat(auto-fit,minmax(200px,1fr));gap:15px;margin-bottom:30px}
.stat-card{background:#161b22;border:1px solid #30363d;border-radius:8px;padding:20px;text-align:center;transition:border-color 0.2s}
.stat-card:hover{border-color:#58a6ff}
.stat-value{font-size:2rem;font-weight:700;margin-bottom:5px}
.stat-label{color:#8b949e;font-size:0.85rem;text-transform:uppercase;letter-spacing:1px}
.critical .stat-value{color:#f85149}
.high .stat-value{color:#d29922}
.medium .stat-value{color:#e3b341}
.info .stat-value{color:#58a6ff}
.section{background:#161b22;border:1px solid #30363d;border-radius:8px;margin-bottom:15px;overflow:hidden}
.section-header{padding:15px 20px;cursor:pointer;display:flex;align-items:center;gap:10px}
.section-content{padding:0 20px 15px;display:none}
.section-content.show{display:block}
.section-content pre{background:#0d1117;border:1px solid #30363d;border-radius:6px;padding:15px;overflow-x:auto;font-size:0.85rem;color:#c9d1d9;white-space:pre-wrap;word-break:break-all}
.sev-critical{color:#f85149}
.sev-high{color:#d29922}
.sev-medium{color:#e3b341}
.sev-low{color:#58a6ff}
.sev-info{color:#8b949e}
.search-box{width:100%;padding:12px 16px;background:#0d1117;border:1px solid #30363d;border-radius:8px;color:#c9d1d9;font-size:1rem;margin-bottom:20px;outline:none}
.search-box:focus{border-color:#58a6ff}
.badge{display:inline-block;padding:2px 8px;border-radius:12px;font-size:0.75rem;font-weight:600;margin-left:8px}
.badge-critical{background:rgba(248,81,73,0.2);color:#f85149}
.badge-high{background:rgba(210,153,34,0.2);color:#d29922}
.badge-info{background:rgba(88,166,255,0.2);color:#58a6ff}
</style>
</head>
<body>
<div class="container">
<h1>⚡ RECON Report</h1>
HTMLEOF

  # Inject dynamic content
  cat >> "$WORKDIR/reports/summary.html" <<EOF
<p class="subtitle">Target: <strong>$TARGET</strong> &middot; Generated: $(date)</p>
<input type="text" class="search-box" id="searchBox" placeholder="🔍 Search findings, URLs, subdomains..." onkeyup="filterSections()">
<div class="stats">
<div class="stat-card info"><div class="stat-value">$subs</div><div class="stat-label">Subdomains</div></div>
<div class="stat-card info"><div class="stat-value">$live</div><div class="stat-label">Live Hosts</div></div>
<div class="stat-card info"><div class="stat-value">$urls</div><div class="stat-label">URLs</div></div>
<div class="stat-card info"><div class="stat-value">$js</div><div class="stat-label">JS Files</div></div>
<div class="stat-card info"><div class="stat-value">$params</div><div class="stat-label">Parameters</div></div>
<div class="stat-card critical"><div class="stat-value">$nuclei_crit</div><div class="stat-label">Critical</div></div>
<div class="stat-card high"><div class="stat-value">$nuclei_high</div><div class="stat-label">High</div></div>
<div class="stat-card high"><div class="stat-value">$secrets</div><div class="stat-label">Secrets</div></div>
<div class="stat-card critical"><div class="stat-value">$takeovers</div><div class="stat-label">Takeovers</div></div>
</div>
<div class="section" data-section="critical">
<div class="section-header" onclick="toggleSection(this)"><h2>Critical Findings</h2><span class="badge badge-critical">$nuclei_crit</span></div>
<div class="section-content"><pre>$critical_content</pre></div>
</div>
<div class="section" data-section="high">
<div class="section-header" onclick="toggleSection(this)"><h2>High Findings</h2><span class="badge badge-high">$nuclei_high</span></div>
<div class="section-content"><pre>$high_content</pre></div>
</div>
<div class="section" data-section="takeovers">
<div class="section-header" onclick="toggleSection(this)"><h2>Subdomain Takeovers</h2></div>
<div class="section-content"><pre>$takeover_content</pre></div>
</div>
<div class="section" data-section="secrets">
<div class="section-header" onclick="toggleSection(this)"><h2>Secrets Detected</h2></div>
<div class="section-content"><pre>$secrets_content</pre></div>
</div>
<div class="section" data-section="chains">
<div class="section-header" onclick="toggleSection(this)"><h2>Bug Chains</h2></div>
<div class="section-content"><pre>$chains_content</pre></div>
</div>
<div class="section" data-section="hypotheses">
<div class="section-header" onclick="toggleSection(this)"><h2>Vulnerability Hypotheses</h2></div>
<div class="section-content"><pre>$hypotheses_content</pre></div>
</div>
</div>
EOF

  cat >> "$WORKDIR/reports/summary.html" <<'HTMLEOF2'
<script>
function toggleSection(el){
  const content=el.nextElementSibling;
  const h2=el.querySelector('h2');
  content.classList.toggle('show');
  h2.classList.toggle('open');
}
function filterSections(){
  const q=document.getElementById('searchBox').value.toLowerCase();
  document.querySelectorAll('.section').forEach(s=>{
    const text=s.textContent.toLowerCase();
    s.style.display=text.includes(q)?'block':'none';
  });
}
// Auto-expand critical sections
document.querySelectorAll('[data-section="critical"] .section-header, [data-section="high"] .section-header').forEach(el=>toggleSection(el));
</script>
</body>
</html>
HTMLEOF2

  log info "HTML report saved"
}

_generate_h1_template() {
  cat > "$WORKDIR/reports/h1_report_template.md" <<'EOF'
## Summary
[Brief 1-2 sentence description of the vulnerability]

## Severity
[Critical / High / Medium / Low]

## Steps To Reproduce
1. 
2. 
3. 

## Impact
[What can an attacker do with this?]

## Supporting Material / References
- Screenshot: 
- Request/Response:
- Tool output:

## Remediation
[Brief fix recommendation]
EOF

  log info "HackerOne report template saved"
}

_generate_findings_json() {
  local findings_file="$WORKDIR/reports/findings.json"

  {
    echo "["
    local first=true

    # Critical nuclei findings
    if [ -s "$WORKDIR/09_vulns/nuclei_critical.json" ]; then
      while IFS= read -r line; do
        [ "$first" = true ] && first=false || echo ","
        echo "$line"
      done < "$WORKDIR/09_vulns/nuclei_critical.json"
    fi

    # High nuclei findings
    if [ -s "$WORKDIR/09_vulns/nuclei_high.json" ]; then
      while IFS= read -r line; do
        [ "$first" = true ] && first=false || echo ","
        echo "$line"
      done < "$WORKDIR/09_vulns/nuclei_high.json"
    fi

    echo "]"
  } > "$findings_file"

  log info "Findings JSON saved"
}
