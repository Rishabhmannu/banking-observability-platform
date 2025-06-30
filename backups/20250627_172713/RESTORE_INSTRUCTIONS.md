# System Backup - 20250627_172713
Generated while system was RUNNING

## Quick Restore
Run: `./safe_restart5.sh` and select this backup when prompted

## Backup Contents
- Complete Grafana dashboards (including all manual edits)
- All service configurations including RabbitMQ Monitor
- NEW: Redis Cache and Container Optimization configs
- Message broker configurations  
- Prometheus setup with monitor scrape job
- Docker compose files
- Shell scripts including message-queue-tester-v2.sh
- Live metrics snapshot with cache & container status
- Running services list

## Manual Dashboard Restoration
If dashboards need to be restored manually:
1. Navigate to grafana_exports directory
2. Run: ./restore_dashboards.sh
3. Or import each *_complete.json file via Grafana UI

## Services Included in Backup
- Core banking services
- DDoS detection and auto-baselining
- Transaction monitoring suite
- Windows IIS monitoring
- Transaction tracing with Jaeger
- RabbitMQ and Kafka messaging
- RabbitMQ Queue Monitor (port 9418)
- PostgreSQL connection pool demo
- NEW: Redis Cache Monitoring (6379, 9121, 5012, 5013)
- NEW: Container Resource Optimization (5010, 5011)

## To Use This Backup
1. Run: ./safe_restart5.sh
2. When prompted for backup selection, choose: 20250627_172713
3. The system will restore all configurations and dashboards

## Notes
- This backup was created without stopping the system
- All dashboard edits and configurations are preserved
- The backup can be used to restore the system to this exact state
- Redis Cache & Container monitor configurations are included.
