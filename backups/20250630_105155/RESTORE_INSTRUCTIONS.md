# System Restoration Guide
### Backup Timestamp: 20250630_105155

This backup contains a complete snapshot of the AIOps platform, including all configurations, scripts, and live-exported Grafana dashboards with your manual edits preserved.

## Quick Restore
To restore the entire system to this state, simply run the updated restart script and select this backup when prompted:
```bash
./safe_restart6.sh
```

## Services Included
This backup includes the full configuration for all system components:
- Core Banking & ML Services
- Transaction Monitoring & Tracing
- Message Queues (RabbitMQ & Kafka)
- Database Monitoring (Postgres & MySQL)
- **Redis Cache Monitoring** (Redis, Exporter, Analyzer, Generator)
- **Container Resource Optimization** (Monitor & Anomaly Generator)
- Mock Windows IIS Monitoring
- **Anomaly Injector** (Port 5005)

## To Restore Dashboards Manually
If you only need to restore the Grafana dashboards:
1. Navigate to the `grafana_exports` directory inside this backup.
2. Run the included script: `./restore_dashboards.sh`
3. Alternatively, import each `*_complete.json` file manually via the Grafana UI.

## Backup Contents
- Complete Grafana dashboards (with all manual edits)
- All service configurations
- Message broker configurations
- Prometheus setup with all scrape jobs
- Docker compose files
- Shell scripts
- Final metrics state at shutdown

## Known Issues Resolved
- Docker compose volume definitions fixed
- Dashboard JSON format corrected
- Network configuration aligned
- All services properly included in startup/shutdown sequences
