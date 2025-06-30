# System Restoration Guide
**Backup Created:** 20250618_150603

This backup is a **live snapshot** taken while the system was running.

## Backup Contents
- **Complete Grafana Dashboards:** All dashboards as they appeared in the UI at the time of backup, including any manual edits.
- **Service Configurations:** All local YAML/config files for services like Prometheus, Grafana, etc.
- **Source Code:** A copy of the 'src' directory.
- **Docker & Scripts:** All 'docker-compose.yml' files and helper scripts.
- **Metrics Snapshot:** A file named 'live_metrics_snapshot.txt' with the state of key metrics at the time of backup.

## To Restore Grafana Dashboards Manually
1.  Navigate into the 'grafana_exports' directory within this backup.
2.  Execute the restore script: `./restore_dashboards.sh`
3.  Alternatively, you can manually import the '\*_complete.json' files through the Grafana UI ('Create' -> 'Import').

This will overwrite existing dashboards with the versions from this backup.
