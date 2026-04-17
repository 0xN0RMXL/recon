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
│   ├── test_core.sh      ← Tests run_phase retry + fail-fast integrity behavior
│   ├── test_recon_orchestration.sh ← Tests critical/non-critical phase policy
│   ├── test_recon_list_mode.sh ← Tests list-mode hard-stop behavior
│   ├── test_scoring.sh   ← Tests for scoring engine
│   ├── test_utils.sh     ← Tests for log(), notify(), banner()
│   └── test_config.sh    ← Tests for config loading
├── integration/
│   ├── test_install.sh   ← Verify tools/runtime readiness (Linux only; skips elsewhere)
│   ├── test_phase_01.sh  ← Subdomain enum against test target
│   ├── test_phase_03.sh  ← Probe against test target
│   ├── test_resume_integrity.sh ← Validate partial-checkpoint resume behavior
│   ├── test_urls_strategy.sh ← Wildcard URL root-first + fallback cap regression
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
- **test_core.sh** — Tests run_phase retry behavior, foundational artifact validation, and state transitions
- **test_recon_list_mode.sh** — Tests that list mode stops at the first critical domain failure
- **test_scoring.sh** — Tests URL scoring with known patterns, validates JSON output, sort order
- **test_utils.sh** — Tests log(), sanitize_target(), require_tool(), check_output()
- **test_config.sh** — Tests config.yaml loading, default values, and performance control settings

## Integration Tests

- **test_install.sh** — Checks required tools are present plus runtime readiness/interoperability checks
- **test_phase_01.sh** — Runs subdomain enumeration against scanme.nmap.org
- **test_phase_03.sh** — Runs httpx probe against scanme.nmap.org
- **test_resume_integrity.sh** — Verifies resume logic reruns phases when partial checkpoint markers exist
- **test_urls_strategy.sh** — Validates wildcard URL collection strategy (root-domain-first with bounded fallback)
- **test_reporting.sh** — Generates reports from fixture data and validates output

## Test Targets

All integration tests use **authorized test targets only**:
- `scanme.nmap.org` — Explicitly authorized by Nmap for testing
- Fixture files for offline testing
