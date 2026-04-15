# RECON Framework — Test Suite

## Overview

The test suite covers unit tests and integration tests for the RECON framework.

## Running Tests

```bash
cd tests/
bash run_tests.sh
```

## Test Structure

```
tests/
├── run_tests.sh          ← Master test runner
├── unit/
│   ├── test_state.sh     ← Tests for state machine functions
│   ├── test_scoring.sh   ← Tests for scoring engine
│   ├── test_utils.sh     ← Tests for log(), notify(), banner()
│   └── test_config.sh    ← Tests for config loading
├── integration/
│   ├── test_install.sh   ← Verify all tools are installed
│   ├── test_phase_01.sh  ← Subdomain enum against test target
│   ├── test_phase_03.sh  ← Probe against test target
│   └── test_reporting.sh ← Generate report from fixture data
├── fixtures/
│   ├── sample_subdomains.txt
│   ├── sample_live.txt
│   ├── sample_urls.txt
│   └── sample_state.json
└── README.md
```

## Unit Tests

- **test_state.sh** — Tests state_init, state_mark_done, state_mark_failed, state_should_skip, state_get_status
- **test_scoring.sh** — Tests URL scoring with known patterns, validates JSON output, sort order
- **test_utils.sh** — Tests log(), sanitize_target(), require_tool(), check_output()
- **test_config.sh** — Tests config.yaml loading, default values

## Integration Tests

- **test_install.sh** — Checks all required tools are in PATH
- **test_phase_01.sh** — Runs subdomain enumeration against scanme.nmap.org
- **test_phase_03.sh** — Runs httpx probe against scanme.nmap.org
- **test_reporting.sh** — Generates reports from fixture data and validates output

## Test Targets

All integration tests use **authorized test targets only**:
- `scanme.nmap.org` — Explicitly authorized by Nmap for testing
- Fixture files for offline testing
