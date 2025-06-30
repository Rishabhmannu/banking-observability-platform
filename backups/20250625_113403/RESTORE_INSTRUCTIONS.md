# System Backup - 20250625_113403
Generated while system was RUNNING

## Quick Restore
Run: `./safe_restart5.sh` and select this backup when prompted

## Backup Contents
- Complete Grafana dashboards (including all manual edits)
- All service configurations
- Message broker configurations  
- Prometheus setup
- Docker compose files
- Shell scripts
- Live metrics snapshot
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
- PostgreSQL connection pool demo

## To Use This Backup
1. Run: ./safe_restart5.sh
2. When prompted for backup selection, choose: 20250625_113403
3. The system will restore all configurations and dashboards

## Notes
- This backup was created without stopping the system
- All dashboard edits and configurations are preserved
- The backup can be used to restore the system to this exact state
