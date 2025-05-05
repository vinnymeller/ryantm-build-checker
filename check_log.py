import os
import re
import sys
from urllib.parse import urljoin

import requests
from bs4 import BeautifulSoup

# Exit Codes:
# 0: Success (Log found, no failure detected
# 1: Generic Error (Network, parsing, etc.)
# 2: Log Page Not Found (404) - Potential missing update script
# 3: Build Failure Detected ("nix build failed" in log)

def find_latest_log_url(base_url, html_content):
    """Parses HTML to find the URL of the latest log file."""
    soup = BeautifulSoup(html_content, 'html.parser')
    log_links = []
    # Simple regex to find links ending in YYYY-MM-DD.log
    log_pattern = re.compile(r"\d{4}-\d{2}-\d{2}\.log$")

    for link in soup.find_all('a', href=True):
        href = link['href']
        if log_pattern.search(href):
            log_links.append(urljoin(base_url, href)) # Handle relative URLs

    # Assume the last link found is the newest one
    if log_links:
        return log_links[-1]
    else:
        return None

def check_package_log(package_name):
    """Checks the r.ryantm log for a given package."""
    base_log_url = f"https://r.ryantm.com/log/{package_name}"
    print(f"Checking logs for: {package_name} at {base_log_url}")

    try:
        response = requests.get(base_log_url, timeout=30, allow_redirects=True)

        if response.status_code == 404:
            print(f"ERROR: Log page not found (404) for {package_name}. Possible missing update script?", file=sys.stderr)
            sys.exit(2)
        elif response.status_code != 200:
            print(f"ERROR: Failed to fetch log index page for {package_name}. Status: {response.status_code}", file=sys.stderr)
            sys.exit(1)

        # Find the latest log file URL from the index page
        latest_log_url = find_latest_log_url(base_log_url + "/", response.text)

        if not latest_log_url:
            print(f"ERROR: Could not find any valid YYYY-MM-DD.log links for {package_name} at {base_log_url}", file=sys.stderr)
            sys.exit(1)

        print(f"Fetching latest log: {latest_log_url}")
        log_response = requests.get(latest_log_url, timeout=60) # Longer timeout for log file

        if log_response.status_code != 200:
            print(f"ERROR: Failed to fetch log file {latest_log_url}. Status: {log_response.status_code}", file=sys.stderr)
            sys.exit(1)

        # Check for failure string
        log_content = log_response.text
        failure_string = "nix build failed" # The string we look for

        if failure_string in log_content:
            print(f"FAILURE DETECTED: '{failure_string}' found in log for {package_name}", file=sys.stderr)
            sys.exit(3)
        else:
            print(f"Success: No failure string detected for {package_name}.")
            sys.exit(0)

    except requests.exceptions.RequestException as e:
        print(f"ERROR: Network error checking {package_name}: {e}", file=sys.stderr)
        sys.exit(1)
    except Exception as e:
        print(f"ERROR: Unexpected error checking {package_name}: {e}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("Usage: python check_log.py <package_name>", file=sys.stderr)
        sys.exit(1)
    pkg_name = sys.argv[1]
    check_package_log(pkg_name)
