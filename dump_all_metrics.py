#!/usr/bin/env python3
import requests

# ▶️ change if Prometheus isn’t on localhost:9090
PROM_URL = "http://localhost:9090"
OUTPUT = "all_metrics_by_service.txt"

def fetch_active_targets(prom_url):
    resp = requests.get(f"{prom_url}/api/v1/targets")
    resp.raise_for_status()
    active = resp.json()["data"]["activeTargets"]
    return [
        {
            "job": t["labels"].get("job", t["scrapeUrl"]),
            "url": t["scrapeUrl"]
        }
        for t in active
        if t["health"] == "up"
    ]

def scrape_names(url):
    r = requests.get(url)
    r.raise_for_status()
    names = set()
    for line in r.text.splitlines():
        if not line or line.startswith("#"):
            continue
        names.add(line.split("{", 1)[0].split()[0])
    return sorted(names)

def main():
    targets = fetch_active_targets(PROM_URL)
    if not targets:
        print("No active targets found.")
        return

    with open(OUTPUT, "w") as out:
        for t in targets:
            out.write(f"=== {t['job']} ===\n")
            try:
                metrics = scrape_names(t["url"])
                for m in metrics:
                    out.write(m + "\n")
                out.write("\n")
                print(f"✓ {t['job']}: {len(metrics)} metrics")
            except Exception as e:
                out.write(f"# ERROR scraping {t['url']}: {e}\n\n")
                print(f"! {t['job']}: error ({e})")

    print(f"\nAll done—see {OUTPUT}")

if __name__ == "__main__":
    main()
