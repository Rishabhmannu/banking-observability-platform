# System Restoration Guide
Generated: 20250625_170719

## Quick Restore
Run: `./safe_restart5.sh` and select this backup

## Manual Dashboard Edits Preserved
- Transaction Tracing Analytics
- Message Queue Dashboard
- Database Connection Pool Dashboard
- All other manual panel modifications

## Services Included
- Core banking services
- DDoS detection and auto-baselining
- Transaction monitoring suite
- Windows IIS monitoring
- Transaction tracing with Jaeger
- RabbitMQ and Kafka messaging
- PostgreSQL connection pool demo

## Backup Contents
- Complete Grafana dashboards (with all manual edits)
- All service configurations
- Message broker configurations
- Prometheus setup
- Docker compose files
- Shell scripts
- Metrics state at shutdown

## To Restore Dashboards Manually
1. Go to grafana_exports directory
2. Run: ./restore_dashboards.sh
3. Or import each *_complete.json file via Grafana UI

## Known Issues Resolved
- Docker compose volume definitions fixed
- Dashboard JSON format corrected
- Network configuration aligned
