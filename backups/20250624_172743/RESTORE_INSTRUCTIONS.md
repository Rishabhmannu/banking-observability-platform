# System Restoration Guide
**Backup Created:** 20250624_172743

This backup is a **live snapshot** taken while the system was running.

## Services Included
- Core banking services
- DDoS detection and auto-baselining
- Transaction monitoring suite
- Windows IIS monitoring
- Transaction tracing with Jaeger
- RabbitMQ and Kafka messaging
- PostgreSQL connection pool demo

## Backup Contents
- **Complete Grafana Dashboards:** All dashboards as they appeared in the UI at the time of backup.
- **Service Configurations:** All local YAML/config files for services.
- **Message Broker Configs:** Configurations for RabbitMQ, Kafka, etc.
- **Source Code & Scripts:** A copy of the 'src' directory and helper scripts.
- **Metrics Snapshot:** A file named 'live_metrics_snapshot.txt' with the state of key metrics.

## To Restore Grafana Dashboards Manually
1.  Navigate into the 'grafana_exports' directory within this backup.
2.  Execute the restore script: `./restore_dashboards.sh`
3.  This will overwrite existing dashboards with the versions from this backup.
