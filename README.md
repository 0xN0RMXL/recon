<p align="center">
  <img src="https://img.shields.io/badge/version-1.0.0-blue?style=for-the-badge" alt="Version" />
  <img src="https://img.shields.io/badge/language-Bash-green?style=for-the-badge&logo=gnubash" alt="Language" />
  <img src="https://img.shields.io/badge/license-MIT-orange?style=for-the-badge" alt="License" />
  <img src="https://img.shields.io/badge/platform-Linux-lightgrey?style=for-the-badge&logo=linux" alt="Platform" />
</p>

<h1 align="center">⚡ RECON</h1>
<h3 align="center">Autonomous Bug Bounty Recon Framework</h3>

<p align="center">
  A production-grade, modular, intelligence-driven reconnaissance framework<br/>
  that automates your entire recon workflow — from subdomain discovery to vulnerability triage.
</p>

<p align="center">
  <a href="#-quick-start">Quick Start</a> •
  <a href="#-how-it-works">How It Works</a> •
  <a href="#-features">Features</a> •
  <a href="#-usage">Usage</a> •
  <a href="#-configuration">Configuration</a> •
  <a href="#-output">Output</a> •
  <a href="#-faq">FAQ</a>
</p>

---

## 🧠 What Is RECON?

**RECON** is a fully automated recon framework built for bug bounty hunters and penetration testers. Instead of manually chaining dozens of tools together, RECON orchestrates **30+ industry-standard tools** across **15 sequential phases** — then goes further by running an **intelligence engine** that analyzes results, generates vulnerability hypotheses, detects bug chains, and prioritizes what to hack first.

**In short:** You give it a target domain. It gives you a prioritized list of what to attack, with reports ready to submit.

### Who is this for?

- **Bug bounty hunters** who want to automate their recon and focus on manual exploitation
- **Penetration testers** who need comprehensive attack surface mapping
- **Security teams** who want continuous external asset monitoring
- **Researchers** learning offensive security methodology

---

## 🚀 Quick Start

### Prerequisites

- **OS**: Ubuntu 22.04+ or Kali Linux 2023+
- **RAM**: 4GB minimum (8GB+ recommended for large targets)
- **Disk**: 10GB free (wordlists + output)
- **Network**: Stable internet connection
- **Permissions**: `sudo` access for package installation

### Installation (< 15 minutes)

```bash
# 1. Clone the repository
git clone https://github.com/0xN0RMXL/recon.git
cd recon
cp config.yaml.example config.yaml

# 2. Run the one-shot installer (installs everything)
sudo bash install.sh

# 3. Add your API keys (optional but recommended)
nano config.yaml

# 4. Run your first scan
./recon.sh -d example.com
```

The installer handles **everything** automatically:

| Category | What Gets Installed |
|----------|-------------------|
| System packages | git, curl, jq, nmap, masscan, parallel, chromium |
| Go 1.22+ | Downloaded and configured if not present |
| Go tools (28) | subfinder, httpx, nuclei, naabu, ffuf, katana, amass, etc. |
| Python tools (7) | trufflehog, arjun, dirsearch, waymore, paramspider |
| Browser automation | Playwright + Chromium |
| Cloned tools | GitDorker, bfac, sqlmap |
| Binary releases | findomain, kiterunner, feroxbuster, gitleaks |
| Wordlists | SecLists DNS/Web, Assetnote best-dns, kiterunner API routes |
| Resolvers | Fresh resolver list from trickest/resolvers |
| GitHub dorks | Curated dork list from Proviesec |
| Nuclei templates | Latest templates auto-updated |

> **💡 Tip:** After installation, run `bash doctor.sh` to verify everything is working.

---

## 🔄 How It Works

RECON operates in three stages:

```
┌──────────────────────────────────────────────────────────────────┐
│                        TARGET INPUT                              │
│   Single domain · Wildcard · Domain list · Company OSINT         │
└──────────────────────┬───────────────────────────────────────────┘
                       │
                       ▼
┌──────────────────────────────────────────────────────────────────┐
│                   15 RECON PHASES                                │
│                                                                  │
│  ┌─────────┐ ┌─────┐ ┌───────┐ ┌───────┐ ┌──────┐             │
│  │Subdomains│→│ DNS │→│ Probe │→│ Ports │→│ URLs │→ ...        │
│  └─────────┘ └─────┘ └───────┘ └───────┘ └──────┘             │
│                                                                  │
│  → Content → JS → Params → Vulns → Cloud → Secrets             │
│  → Screenshots → API → GitHub → Origins                         │
│                                                                  │
│  Each phase: ✓ Checkpoint · ✓ Resume · ✓ 3 Retries             │
└──────────────────────┬───────────────────────────────────────────┘
                       │
                       ▼
┌──────────────────────────────────────────────────────────────────┐
│                 INTELLIGENCE ENGINE                              │
│                                                                  │
│  🔍 Anomaly Detection    — Find debug pages, SQL errors, JWTs   │
│  💡 Hypothesis Generator — Map URLs to specific vuln tests       │
│  🔗 Bug Chain Detector   — Find multi-step attack paths          │
│  📊 Priority Scorer      — Rank endpoints by exploitability      │
│  🧭 Decision Engine      — Tell you exactly what to do next      │
└──────────────────────┬───────────────────────────────────────────┘
                       │
                       ▼
┌──────────────────────────────────────────────────────────────────┐
│                      REPORTS                                     │
│                                                                  │
│  📄 summary.json         — Machine-readable full results         │
│  📝 summary.md           — Human-readable markdown report        │
│  🌐 summary.html         — Self-contained dark-theme dashboard   │
│  🎯 findings.json        — Critical/high findings extracted      │
│  📊 prioritized.json     — Scored endpoints ranked by priority   │
│  📋 h1_template.md       — HackerOne copy-paste report template  │
│  📥 burp_export.xml      — Import directly into Burp Suite       │
└──────────────────────────────────────────────────────────────────┘
```

---

## ✨ Features

### 🎯 Reconnaissance (15 Phases)

| Phase | Name | Tools Used | What It Finds |
|-------|------|-----------|---------------|
| 01 | **Subdomains** | subfinder, assetfinder, amass, findomain, chaos, crt.sh, puredns, ffuf | Every subdomain — passive, active, and brute-force |
| 02 | **DNS** | dnsx, asnmap, hakrevdns | IP resolution, PTR records, ASN mapping |
| 03 | **Probe** | httpx | Live hosts, status codes, technologies, web servers |
| 04 | **Ports** | naabu, nmap | Open ports, running services, versions |
| 05 | **URLs** | waybackurls, waymore, gau, hakrawler, katana, gospider | Every URL from archives, crawlers, and JS parsing |
| 06 | **Content** | ffuf, feroxbuster, gobuster, dirsearch, bfac | Hidden dirs, vhosts, backup files, 403 bypasses |
| 07 | **JS Analysis** | subjs, mantra, custom regex | Endpoints, API keys, tokens, secrets in JavaScript |
| 08 | **Params** | arjun, paramspider, ffuf | Hidden parameters on every endpoint |
| 09 | **Vulns** | nuclei, subjack, dalfox, sqlmap | CVEs, misconfigs, XSS, SQLi, subdomain takeovers |
| 10 | **Cloud** | Custom S3/GCP/Azure checks | Exposed buckets, cloud misconfigurations |
| 11 | **Secrets** | trufflehog, gitleaks, regex | Leaked credentials, API keys, private keys |
| 12 | **Screenshots** | gowitness | Visual screenshots of every live host |
| 13 | **API** | kiterunner | Hidden API routes and parameters |
| 14 | **GitHub** | GitDorker | Leaked code, credentials, internal URLs on GitHub |
| 15 | **Origins** | originiphunter | Real origin IPs behind CDN/WAF |

### 🧠 Intelligence Engine

- **Anomaly Detection** — Probes live hosts and flags debug pages, SQL errors, exposed tokens, JWTs, LFI indicators
- **Hypothesis Generator** — Maps discovered URLs to specific vulnerability tests (IDOR, SSRF, file upload bypass, etc.)
- **Bug Chain Correlator** — Detects multi-step attack chains (e.g., SSRF → cloud metadata → RCE)
- **Priority Scorer** — Scores every URL using 13+ patterns (API, admin, upload, auth, graphql, etc.)
- **Decision Engine** — Generates a prioritized action list telling you exactly what to test first

### 🔧 Operational Features

- **Smart Resume** — Checkpoint-based state machine; crash mid-scan and pick up where you left off
- **Smart Nuclei** — Automatically selects nuclei template tags based on detected technology stack
- **Burp Suite Integration** — Route traffic through Burp proxy (Community) or auto-scan via REST API (Pro)
- **Real-time Notifications** — Get alerts on Telegram, Discord, or Slack as phases complete
- **Distributed Scanning** — Split targets across multiple VPS nodes via SSH
- **Differential Recon** — Compare runs to find new assets added since your last scan

---

## 📖 Usage

### Interactive Mode (Recommended for First Use)

Just run the script with no arguments — it will guide you through target selection and execution mode:

```bash
./recon.sh
```

You'll see:
```
╔══════════════════════════════════════════╗
║          RECON — Target Selection        ║
╠══════════════════════════════════════════╣
║  1) Single Domain    (e.g. example.com)  ║
║  2) Wildcard         (e.g. *.example.com)║
║  3) Domain List      (path to file)      ║
║  4) Company OSINT    (company name)      ║
╚══════════════════════════════════════════╝
```

### CLI Mode (For Automation & Scripting)

```bash
# ─── Basic Scans ────────────────────────────
./recon.sh -d example.com                    # Single domain
./recon.sh -w "*.example.com"                # Wildcard scope
./recon.sh -l targets.txt                    # Multiple domains from file
./recon.sh -c "Acme Corp"                    # Company name → auto-expand

# ─── Resume & Control ──────────────────────
./recon.sh -d example.com --resume           # Resume interrupted scan
./recon.sh -d example.com --force            # Re-run everything from scratch
./recon.sh -d example.com --only subdomains  # Run one specific phase
./recon.sh -d example.com --skip screenshots # Skip a phase

# ─── Performance Tuning ────────────────────
./recon.sh -d example.com --threads 100      # Lower threads for shared VPS
./recon.sh -d example.com --rate 50          # Lower rate limit for WAF evasion

# ─── Integration Control ───────────────────
./recon.sh -d example.com --no-burp          # Disable Burp proxy routing
./recon.sh -d example.com --no-notify        # Disable notifications

# ─── Custom Config & Output ────────────────
./recon.sh -d example.com --config my.yaml   # Use alternate config file
./recon.sh -d example.com --output /data/out # Custom output directory
```

### Full Flag Reference

```
TARGET MODES:
  -d, --domain TARGET       Single domain (e.g. example.com)
  -w, --wildcard TARGET     Wildcard domain (e.g. *.example.com)
  -l, --list FILE           File with one domain per line
  -c, --company NAME        Company name for OSINT expansion

EXECUTION CONTROL:
  --phase PHASE             Run a specific phase
  --skip PHASE              Skip a specific phase
  --only PHASE              Run ONLY this phase (skip all others)
  --resume                  Resume from last checkpoint
  --force                   Ignore checkpoints, re-run everything

PERFORMANCE:
  --threads N               Override thread count for httpx/ffuf
  --rate N                  Override rate limit for nuclei/naabu

INTEGRATIONS:
  --no-burp                 Disable Burp Suite proxy routing
  --no-notify               Disable Telegram/Discord/Slack notifications

PATHS:
  --config PATH             Path to config.yaml (default: ./config.yaml)
  --output DIR              Output directory (default: ./output)

OTHER:
  -h, --help                Show help message
```

---

## ⚙️ Configuration

### Step 1: Create Your Config

```bash
cp config.yaml.example config.yaml
nano config.yaml
```

### Step 2: Add API Keys

API keys are **all optional** — the framework works without them but discovers significantly more with them.

| Service | Free Tier? | What It Adds | Get Key |
|---------|-----------|-------------|---------|
| GitHub Token | ✅ Free | GitHub subdomain discovery + dorking | [github.com/settings/tokens](https://github.com/settings/tokens) |
| ProjectDiscovery Chaos | ✅ Free | Passive subdomain database | [cloud.projectdiscovery.io](https://cloud.projectdiscovery.io) |
| Censys | ✅ Free | Certificate-based discovery | [search.censys.io/account](https://search.censys.io/account) |
| VirusTotal | ✅ Free | Passive DNS intelligence | [virustotal.com/gui/my-apikey](https://www.virustotal.com/gui/my-apikey) |
| AlienVault OTX | ✅ Free | Passive DNS + threat intel | [otx.alienvault.com/api](https://otx.alienvault.com/api) |
| URLScan.io | ✅ Free | Subdomain + URL discovery | [urlscan.io/user/profile](https://urlscan.io/user/profile) |
| Shodan | 💰 Freemium | Port/service intelligence | [account.shodan.io](https://account.shodan.io) |
| SecurityTrails | 💰 Limited | Historical DNS data | [securitytrails.com](https://securitytrails.com) |
| Netlas.io | 💰 Limited | Certificate search engine | [app.netlas.io/profile](https://app.netlas.io/profile/) |
| ZoomEye | 💰 Freemium | IP/domain intelligence | [zoomeye.org/profile](https://www.zoomeye.org/profile) |
| c99.nl | 💰 Paid | Subdomain finder API | [api.c99.nl](https://api.c99.nl) |
| FOFA | 💰 Paid | Chinese internet search engine | [en.fofa.info](https://en.fofa.info/userInfo) |

> **💡 Recommended minimum:** GitHub token + Chaos key + free accounts. This covers ~80% of discovery capability.

### Step 3: Configure Notifications (Optional)

```yaml
notifications:
  telegram_bot_token: "YOUR_BOT_TOKEN"    # Create at @BotFather
  telegram_chat_id: "YOUR_CHAT_ID"        # Get from @userinfobot
  discord_webhook: "https://discord..."    # Server Settings → Integrations
  slack_webhook: "https://hooks.slack..."  # api.slack.com/apps
```

### Step 4: Configure Burp Suite (Optional)

```yaml
burp:
  enabled: true                            # Route traffic through Burp
  proxy: "http://127.0.0.1:8080"          # Burp proxy listener
  api_url: "http://127.0.0.1:1337"        # Pro REST API (Pro only)
  api_key: ""                              # Pro API key (Pro only)
  auto_scan: false                         # Auto-send to active scanner
  send_interesting: true                   # Send admin/api/upload URLs
```

---

## 📂 Output

Every scan creates an organized directory tree:

```
output/example.com/
│
├── meta/                          ← Run metadata
│   ├── state.json                    Checkpoint state machine
│   ├── execution.log                 Full execution log
│   ├── config_snapshot.yaml          Config used for this run
│   └── run_info.json                 Target, mode, start time
│
├── 01_subdomains/                 ← Subdomain discovery
│   ├── passive/                      Individual tool outputs
│   │   ├── subfinder.txt
│   │   ├── amass.txt
│   │   ├── crtsh.txt
│   │   └── ... (11 sources)
│   ├── active/                       Brute-force results
│   ├── fuzzing/                      Subdomain fuzzing
│   └── all_subdomains.txt           ★ Merged + deduplicated
│
├── 02_dns/                        ← DNS intelligence
├── 03_live_hosts/                 ← Live host probing
├── 04_ports/                      ← Port scanning
├── 05_urls/                       ← URL collection
│   ├── raw/                          6 tool outputs
│   ├── categorized/                  15 categorized lists
│   │   ├── api_endpoints.txt
│   │   ├── admin_panels.txt
│   │   ├── login_flows.txt
│   │   ├── upload_endpoints.txt
│   │   ├── idor_candidates.txt
│   │   └── ... (10 more)
│   ├── all_urls.txt                 ★ All URLs merged
│   └── live_urls.txt                ★ Verified live URLs
│
├── 06_content/                    ← Content discovery
├── 07_js/                         ← JavaScript analysis
├── 08_params/                     ← Parameter discovery
├── 09_vulns/                      ← Vulnerability scanning
│   ├── nuclei_critical.txt          ★ Critical findings
│   ├── nuclei_high.txt              ★ High findings
│   ├── takeovers_nuclei.txt         ★ Subdomain takeovers
│   ├── dalfox_xss.txt               ★ XSS findings
│   └── sqlmap/                       SQLi results
│
├── 10_cloud/ → 15_origins/       ← Remaining phases
│
├── intelligence/                  ← AI-driven analysis
│   ├── response_anomalies.txt       Debug pages, SQL errors, tokens
│   ├── hypotheses.txt               What to test and how
│   ├── bug_chains.txt               Multi-step attack paths
│   ├── decision_report.txt          ★ Prioritized action list
│   └── diff_new_assets.txt          New assets since last scan
│
└── reports/                       ← Final reports
    ├── summary.json                  Machine-readable results
    ├── summary.md                    Human-readable report
    ├── summary.html                  ★ Self-contained HTML dashboard
    ├── findings.json                 Critical + high findings
    ├── prioritized_targets.json      Scored priority targets
    ├── h1_report_template.md         HackerOne report template
    └── burp_export.xml               Burp Suite importable XML
```

### Understanding the HTML Report

The HTML report (`summary.html`) is a **self-contained, dark-themed dashboard** that opens in any browser — no server needed. It includes:
- Statistics cards for all metrics
- Collapsible sections for each finding category
- Search box to filter across all findings
- Critical and high sections auto-expanded
- Copy-paste ready for triage

---

## 🔌 Burp Suite Integration

### Community Edition (Free)

Set `burp.enabled: true` in config.yaml. All compatible tools (httpx, ffuf, etc.) will route their traffic through Burp's proxy, populating your site map and history automatically.

### Professional Edition

Configure `burp.api_url` and `burp.api_key` to unlock:
- **Auto-send live hosts** to Burp's active scanner
- **Auto-send interesting endpoints** (admin panels, API routes, upload forms, login pages)
- **Burp XML export** — import findings directly into Burp Suite

---

## 🛠️ Maintenance

### Health Check

Verify all tools are installed and working:

```bash
bash doctor.sh
```

### Update Everything

Keep tools, templates, wordlists, and resolvers up to date:

```bash
bash update.sh
```

### Run Tests

Validate the framework is functioning correctly:

```bash
cd tests/
bash run_tests.sh
```

---

## ❓ FAQ

### Q: How long does a full scan take?

Depends on target size. A single domain with ~500 subdomains typically takes **30-60 minutes**. Large wildcard scopes can take several hours.

### Q: Can I run this on a VPS?

Absolutely — it's designed for it. A $10/month VPS (2 CPU, 4GB RAM) handles most targets comfortably. Use `--threads` and `--rate` to tune for your hardware.

### Q: What if a scan gets interrupted?

Just rerun with `--resume`. The state machine tracks every phase's completion status and will skip already-completed phases (unless the output file is missing or empty).

### Q: Will this get me banned/blocked?

RECON is designed for **authorized testing only**. That said, it generates significant traffic. Some tips:
- Lower `--threads` and `--rate` for sensitive targets
- Use `--skip ports` if you don't need aggressive port scanning
- Route through Burp to monitor your traffic in real-time

### Q: Do I need all API keys?

No. The framework works with zero API keys. But adding free-tier keys (GitHub, Chaos, Censys, VT, OTX) significantly increases subdomain discovery. We recommend at minimum a **GitHub token** and **Chaos API key**.

### Q: Can I run just one phase?

Yes: `./recon.sh -d target.com --only subdomains` runs only subdomain enumeration.

### Q: How do I add custom Nuclei templates?

Drop them in `~/nuclei-templates/` and they'll be picked up automatically. RECON runs `nuclei -update-templates` during installation and via `update.sh`.

### Q: Can I add my own recon phases?

Yes. Create a new file in `lib/` with a function, then add a `run_phase "name" "function_name"` call in `recon.sh` → `run_all_phases()`. The state machine will automatically track it.

---

## 🏗️ Architecture

```
recon/
├── recon.sh                   Main orchestrator — CLI, menu, phase execution
├── install.sh                 One-shot installer (17-step automated setup)
├── update.sh                  Tool/template/wordlist updater
├── doctor.sh                  Environment health checker
├── config.yaml.example        Configuration template
│
├── lib/                       Core library (27 modules)
│   ├── utils.sh                  Logging, notifications, config loader
│   ├── state.sh                  Checkpoint state machine
│   ├── core.sh                   Workspace init, run_phase() with retry
│   ├── parallel.sh               GNU parallel wrappers
│   ├── burp.sh                   Burp Suite proxy + API integration
│   ├── subdomains.sh → origins.sh    15 recon phase modules
│   ├── analyzer.sh → scoring.sh      Intelligence engine (5 modules)
│   ├── reporting.sh              Report generator (7 output formats)
│   └── diff.sh                   Differential recon engine
│
├── modules/
│   ├── browser/browser.py     Playwright-based browser automation
│   └── distributed/           VPS cluster scan distribution
│
├── data/                      Wordlists, resolvers, dorks (auto-populated)
├── output/                    Scan results (per-target directories)
├── tests/                     Unit + integration test suite
└── logs/                      Runtime logs
```

---

## ⚠️ Legal Disclaimer

**This tool is designed exclusively for authorized security testing and bug bounty programs.**

Unauthorized use against systems you do not own or have explicit written permission to test is **illegal** and may violate computer fraud laws in your jurisdiction (CFAA, CMA, etc.).

By using this tool, you acknowledge that:
- You have **written authorization** to test the target
- You accept **full responsibility** for your actions
- The authors accept **no liability** for misuse

**Always verify scope before scanning. When in doubt — don't scan.**

---

## 📄 License

MIT License — see [LICENSE](LICENSE) for details.

---

<p align="center">
  <strong>Built for hunters, by hunters.</strong><br/>
  <sub>If RECON helps you find a bug, we'd love to hear about it.</sub>
</p>
