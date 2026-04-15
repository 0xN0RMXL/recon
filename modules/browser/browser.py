#!/usr/bin/env python3
"""
RECON Browser Automation Module
Uses Playwright to crawl authenticated sessions and capture
cookies, forms, hidden endpoints, and localStorage data.
"""

import sys
import json
import argparse
from pathlib import Path
from playwright.sync_api import sync_playwright, TimeoutError as PlaywrightTimeout


def crawl_target(target_url: str, output_dir: str, proxy: str = None) -> dict:
    results = {
        "url": target_url,
        "cookies": [],
        "forms": [],
        "endpoints": [],
        "local_storage": {},
        "js_files": [],
        "network_requests": []
    }

    launch_args = {"headless": True, "args": ["--no-sandbox"]}
    if proxy:
        launch_args["proxy"] = {"server": proxy}

    with sync_playwright() as p:
        browser = p.chromium.launch(**launch_args)
        context = browser.new_context(
            ignore_https_errors=True,
            user_agent="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36"
        )

        # Capture all network requests
        page = context.new_page()
        page.on("request", lambda req: results["network_requests"].append({
            "url": req.url,
            "method": req.method,
            "headers": dict(req.headers)
        }))

        try:
            page.goto(target_url, timeout=15000, wait_until="networkidle")

            # Cookies
            results["cookies"] = context.cookies()

            # Forms
            forms = page.query_selector_all("form")
            for form in forms:
                action = form.get_attribute("action") or ""
                method = form.get_attribute("method") or "GET"
                inputs = [
                    {"name": i.get_attribute("name"), "type": i.get_attribute("type")}
                    for i in form.query_selector_all("input")
                ]
                results["forms"].append({"action": action, "method": method, "inputs": inputs})

            # Extract all href links
            links = page.eval_on_selector_all("a[href]", "els => els.map(e => e.href)")
            results["endpoints"] = list(set(links))

            # JS file references
            js_srcs = page.eval_on_selector_all(
                "script[src]", "els => els.map(e => e.src)"
            )
            results["js_files"] = list(set(js_srcs))

            # LocalStorage (if accessible)
            try:
                ls = page.evaluate("() => JSON.stringify(window.localStorage)")
                results["local_storage"] = json.loads(ls) if ls else {}
            except Exception:
                pass

        except PlaywrightTimeout:
            results["error"] = f"Timeout loading {target_url}"
        except Exception as e:
            results["error"] = str(e)
        finally:
            browser.close()

    return results


def main():
    parser = argparse.ArgumentParser(description="RECON Browser Automation")
    parser.add_argument("-u", "--url", required=True, help="Target URL")
    parser.add_argument("-o", "--output", required=True, help="Output directory")
    parser.add_argument("--proxy", help="Proxy URL (e.g. http://127.0.0.1:8080)")
    args = parser.parse_args()

    Path(args.output).mkdir(parents=True, exist_ok=True)
    output_file = Path(args.output) / "browser_results.json"

    results = crawl_target(args.url, args.output, args.proxy)

    with open(output_file, "w") as f:
        json.dump(results, f, indent=2)

    # Print summary
    print(f"[+] Cookies: {len(results['cookies'])}")
    print(f"[+] Forms: {len(results['forms'])}")
    print(f"[+] Endpoints: {len(results['endpoints'])}")
    print(f"[+] JS Files: {len(results['js_files'])}")
    print(f"[+] Network requests: {len(results['network_requests'])}")
    print(f"[+] Results saved to: {output_file}")


if __name__ == "__main__":
    main()
