#!/usr/bin/env python3
import requests
import time

PROM = "http://localhost:9090"
OUT = "all_metrics_by_service.txt"


def list_jobs():
    # pull all activeTargets so we know every job name
    r = requests.get(f"{PROM}/api/v1/targets")
    r.raise_for_status()
    return sorted({
        t["labels"]["job"]
        for t in r.json()["data"]["activeTargets"]
        if t["health"] == "up"
    })


def fetch_metric_names_for_job(job):
    names = set()
    # Prometheus series API supports a job‐only selector:
    # series?match[]={job="<job>"}&limit=<big number>
    params = {
        "match[]": f'{{job="{job}"}}',
        "limit":   50000
    }
    r = requests.get(f"{PROM}/api/v1/series", params=params)
    r.raise_for_status()
    for series in r.json()["data"]:
        if "__name__" in series:
            names.add(series["__name__"])
    return sorted(names)


def main():
    jobs = list_jobs()
    if not jobs:
        print("No UP jobs found in Prometheus.")
        return

    with open(OUT, "w") as fw:
        for job in jobs:
            print(f"→ fetching metrics for job “{job}”…", end="", flush=True)
            try:
                names = fetch_metric_names_for_job(job)
                fw.write(f"=== {job} ({len(names)} metrics) ===\n")
                for n in names:
                    fw.write(n + "\n")
                fw.write("\n")
                print(f" {len(names)} metrics")
                # be kind to Prometheus
                time.sleep(0.1)
            except Exception as e:
                print(f" FAILED: {e}")
                fw.write(f"=== {job} ERROR: {e} ===\n\n")

    print(f"\n✅ Done. See “{OUT}”.")


if __name__ == "__main__":
    main()
