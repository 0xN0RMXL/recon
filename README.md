# RECON — Autonomous Bug Bounty Recon Framework

> A production-grade, modular, intelligence-driven recon framework for authorized bug bounty hunting.

## Features

- **15-phase automated pipeline** — subdomain enum → origin IP hunting
- **30+ integrated tools** — subfinder, httpx, nuclei, naabu, ffuf, and more
- **Smart Nuclei template selection** — based on detected technology stack
- **JS analysis + secret extraction** — subjs, mantra, regex patterns
- **API endpoint discovery** — kiterunner route/parameter scanning
- **Bug chain correlation engine** — detects multi-step attack chains
- **Vulnerability hypothesis generation** — automated test case mapping
- **Priority scoring system** — additive URL scoring with 13+ patterns
- **Burp Suite Community + Pro integration** — proxy routing + REST API
- **Telegram / Discord / Slack notifications** — real-time alerts
- **Distributed VPS scanning** — split targets across SSH nodes
- **Resume/checkpoint system** — full state machine with smart skip logic
- **JSON + Markdown + HTML reporting** — self-contained dark-theme HTML
- **HackerOne-ready report templates** — copy-paste ready
- **Differential recon** — detects new assets between runs

## Installation

```bash
git clone https://github.com/0xN0RMXL/recon recon
cd recon
bash install.sh
```

The installer automatically handles:
- System packages (git, curl, jq, nmap, parallel, etc.)
- Go 1.22+ installation
- 28 Go tools from ProjectDiscovery, tomnomnom, and more
- Python tools (trufflehog, arjun, dirsearch, waymore, paramspider)
- Playwright + Chromium for browser automation
- Cloned tools (GitDorker, bfac, sqlmap)
- Binary releases (findomain, kiterunner, feroxbuster, gitleaks)
- Wordlists (SecLists DNS/Web, Assetnote)
- Fresh resolvers from trickest/resolvers
- GitHub dorks from Proviesec
- Nuclei template updates

## Configuration

```bash
cp config.yaml.example config.yaml
nano config.yaml   # Add your API keys
```

## Usage

### Interactive Mode
```bash
./recon.sh
```

### CLI Mode
```bash
# Single domain
./recon.sh -d example.com

# Wildcard
./recon.sh -w "*.example.com"

# Domain list
./recon.sh -l domains.txt

# Company OSINT
./recon.sh -c "Company Name"

# Resume previous run
./recon.sh -d example.com --resume

# Force re-scan
./recon.sh -d example.com --force

# Run specific phase only
./recon.sh -d example.com --only subdomains

# Skip a phase
./recon.sh -d example.com --skip screenshots

# Disable Burp proxy
./recon.sh -d example.com --no-burp

# Custom threads
./recon.sh -d example.com --threads 100
```

### Full CLI Reference
```
./recon.sh [--domain|-d TARGET] [--list|-l FILE] [--wildcard|-w WILDCARD]
           [--company|-c COMPANY] [--phase PHASE_NAME] [--skip PHASE_NAME]
           [--resume] [--force] [--only PHASE] [--no-burp] [--no-notify]
           [--threads N] [--rate N] [--config PATH] [--output DIR]
```

## API Keys (all optional, improve coverage)

| Service | Free | URL |
|---------|------|-----|
| ProjectDiscovery Chaos | ✅ | https://cloud.projectdiscovery.io |
| GitHub Token | ✅ | https://github.com/settings/tokens |
| Shodan | Freemium | https://account.shodan.io |
| SecurityTrails | Limited | https://securitytrails.com |
| Censys | ✅ | https://search.censys.io/account |
| VirusTotal | ✅ | https://www.virustotal.com/gui/my-apikey |
| URLScan.io | ✅ | https://urlscan.io/user/profile |
| AlienVault OTX | ✅ | https://otx.alienvault.com/api |
| Netlas.io | Limited | https://app.netlas.io/profile/ |
| c99.nl | Paid | https://api.c99.nl |
| FOFA | Paid | https://en.fofa.info/userInfo |
| ZoomEye | Freemium | https://www.zoomeye.org/profile |

## Phase Execution Order

```
Phase 01: subdomains    — subdomain enumeration (passive + active + bruteforce)
Phase 02: dns           — DNS resolution, PTR records, ASN mapping
Phase 03: probe         — live host detection, tech fingerprinting
Phase 04: ports         — port scanning and service detection
Phase 05: urls          — URL collection from all sources
Phase 06: content       — directory/content fuzzing, vhost, backup files
Phase 07: js            — JavaScript analysis and secret extraction
Phase 08: params        — parameter discovery
Phase 09: vulns         — nuclei smart scan + subdomain takeover
Phase 10: cloud         — cloud asset detection
Phase 11: secrets       — trufflehog + gitleaks + regex scanning
Phase 12: screenshots   — gowitness screenshots of all live hosts
Phase 13: api           — API endpoint discovery (kiterunner)
Phase 14: github        — GitHub dorking
Phase 15: origins       — origin IP hunting

[Intelligence phases run after Phase 05]
Phase I1: analyzer      — response anomaly analysis
Phase I2: hypothesis    — vulnerability hypothesis generation
Phase I3: chaining      — bug chain correlation
Phase I4: scoring       — endpoint priority scoring

[Final]
Phase R:  reporting     — generate all reports + send notifications
```

## Output Structure

```
output/<target>/
├── 01_subdomains/    ← All discovered subdomains
├── 02_dns/           ← DNS resolution data
├── 03_live_hosts/    ← Probed live hosts
├── 04_ports/         ← Port scan results
├── 05_urls/          ← URL collection + categorization
├── 06_content/       ← Directory fuzzing results
├── 07_js/            ← JavaScript analysis
├── 08_params/        ← Parameter discovery
├── 09_vulns/         ← Vulnerability scan results
├── 10_cloud/         ← Cloud asset detection
├── 11_secrets/       ← Secret/credential detection
├── 12_screenshots/   ← gowitness screenshots
├── 13_api/           ← API endpoint discovery
├── 14_github/        ← GitHub dorking results
├── 15_origins/       ← Origin IP hunting
├── intelligence/     ← Hypotheses, chains, anomalies
└── reports/          ← JSON + MD + HTML reports
```

## Burp Suite Integration

### Community Edition
Set `burp.enabled: true` in config.yaml to route all compatible tool traffic through Burp proxy.

### Pro Edition
Configure `burp.api_url` and `burp.api_key` to enable:
- Auto-send live hosts to Burp active scanner
- Auto-send interesting endpoints (admin, API, upload, login)
- Burp XML export for import into Burp Suite

## Environment Check

```bash
bash doctor.sh
```

## Update Tools

```bash
bash update.sh
```

## Testing

```bash
cd tests/
bash run_tests.sh
```

## Legal

⚠️ **This tool is for authorized security testing and bug bounty programs only.**

Unauthorized use against systems you do not own or have written permission to test is **illegal**. The authors accept **no liability** for misuse.

## License

MIT License — see [LICENSE](LICENSE) for details.
