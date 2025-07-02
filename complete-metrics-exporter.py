#!/usr/bin/env python3
"""
Complete Multi-Service Metrics Exporter
Exports all Prometheus metrics from your banking microservices platform
"""
import requests
import json
import time
import os
import csv
from datetime import datetime
from concurrent.futures import ThreadPoolExecutor, as_completed


class ComprehensiveMetricsExporter:
    def __init__(self):
        self.prometheus_url = "http://localhost:9090"
        self.output_dir = "metrics_export"

        # All services based on your Prometheus targets
        self.services = {
            # Core Banking Services
            'api-gateway': 'banking-services',
            'account-service': 'banking-services',
            'transaction-service': 'banking-services',
            'auth-service': 'banking-services',
            'notification-service': 'banking-services',
            'fraud-detection': 'banking-services',

            # ML & Detection Services
            'ddos-ml-detection': 'ddos-ml-detection',
            'auto-baselining': 'auto-baselining',
            'anomaly-injector': 'anomaly-injector',

            # Monitoring Services
            'container-resource-monitor': 'container-resource-monitor',
            'transaction-monitor': 'transaction-monitor',
            'performance-aggregator': 'performance-aggregator',
            'node-exporter': 'node-exporter',
            'cadvisor': 'cadvisor',
            'windows-exporter': 'windows-exporter',

            # Cache Services
            'cache-pattern-analyzer': 'cache-pattern-analyzer',
            'cache-load-generator': 'cache-load-generator',
            'cache-proxy': 'cache-proxy',
            'redis-exporter': 'redis-exporter',

            # Database Services
            'banking-postgresql': 'banking-postgresql',
            'banking-db-demo': 'banking-db-demo',

            # Message Queue Services
            'banking-rabbitmq': 'banking-rabbitmq',
            'rabbitmq-queue-monitor': 'rabbitmq-queue-monitor',
            'banking-message-consumer': 'banking-message-consumer',
            'banking-message-producer': 'banking-message-producer',
            'banking-kafka': 'banking-kafka',

            # Testing & Utilities
            'resource-anomaly-generator': 'resource-anomaly-generator',
            'trace-generator': 'trace-generator',

            # Infrastructure
            'prometheus': 'prometheus'
        }

        # Service categories for better organization
        self.service_categories = {
            'banking': ['api-gateway', 'account-service', 'transaction-service', 'auth-service', 'notification-service', 'fraud-detection'],
            'ml_detection': ['ddos-ml-detection', 'auto-baselining', 'anomaly-injector'],
            'monitoring': ['container-resource-monitor', 'transaction-monitor', 'performance-aggregator', 'node-exporter', 'cadvisor', 'windows-exporter'],
            'cache': ['cache-pattern-analyzer', 'cache-load-generator', 'cache-proxy', 'redis-exporter'],
            'database': ['banking-postgresql', 'banking-db-demo'],
            'messaging': ['banking-rabbitmq', 'rabbitmq-queue-monitor', 'banking-message-consumer', 'banking-message-producer', 'banking-kafka'],
            'testing': ['resource-anomaly-generator', 'trace-generator'],
            'infrastructure': ['prometheus']
        }

    def create_output_structure(self):
        """Create organized output directory structure"""
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        self.export_path = os.path.join(
            self.output_dir, f"complete_export_{timestamp}")

        # Create main directory
        os.makedirs(self.export_path, exist_ok=True)

        # Create category subdirectories
        for category in self.service_categories.keys():
            os.makedirs(os.path.join(
                self.export_path, category), exist_ok=True)

        # Create summary directory
        os.makedirs(os.path.join(self.export_path, "summary"), exist_ok=True)

        return self.export_path

    def get_all_metrics_for_service(self, service_name, job_name):
        """Get all metrics for a specific service"""
        try:
            # Query all metrics for this service
            query = f'{{job="{job_name}"}}'
            response = requests.get(
                f"{self.prometheus_url}/api/v1/query",
                params={'query': query},
                timeout=10
            )

            if response.status_code == 200:
                data = response.json()
                return data.get('data', {}).get('result', [])
            else:
                print(
                    f"❌ Failed to get metrics for {service_name}: HTTP {response.status_code}")
                return []

        except Exception as e:
            print(f"❌ Error getting metrics for {service_name}: {e}")
            return []

    def export_service_metrics(self, service_name, job_name, category):
        """Export metrics for a specific service"""
        print(f"📊 Exporting {service_name}...")

        metrics = self.get_all_metrics_for_service(service_name, job_name)

        if not metrics:
            print(f"⚠️  No metrics found for {service_name}")
            return 0

        # Organize metrics by type
        metrics_by_type = {}
        for metric in metrics:
            metric_name = metric['metric']['__name__']
            if metric_name not in metrics_by_type:
                metrics_by_type[metric_name] = []
            metrics_by_type[metric_name].append(metric)

        # Save to category directory
        category_dir = os.path.join(self.export_path, category)
        filename = os.path.join(category_dir, f"{service_name}_metrics.txt")

        with open(filename, 'w') as f:
            f.write(f"# Metrics for {service_name}\n")
            f.write(f"# Job: {job_name}\n")
            f.write(f"# Category: {category}\n")
            f.write(f"# Exported at: {datetime.now().isoformat()}\n")
            f.write(f"# Total metrics: {len(metrics)}\n")
            f.write(f"# Unique metric types: {len(metrics_by_type)}\n\n")

            # Write metrics grouped by type
            for metric_type, type_metrics in sorted(metrics_by_type.items()):
                f.write(f"## {metric_type}\n")
                for metric in type_metrics:
                    labels = {k: v for k,
                              v in metric['metric'].items() if k != '__name__'}
                    value = metric['value'][1]

                    f.write(f"{metric_type}")
                    if labels:
                        labels_str = ','.join(
                            [f'{k}="{v}"' for k, v in labels.items()])
                        f.write(f"{{{labels_str}}}")
                    f.write(f" {value}\n")
                f.write("\n")

        print(
            f"✅ Exported {len(metrics)} metrics for {service_name} ({len(metrics_by_type)} types)")
        return len(metrics)

    def export_all_services(self):
        """Export metrics for all services using parallel processing"""
        print("🚀 Starting comprehensive metrics export...")
        export_path = self.create_output_structure()

        total_metrics = 0
        export_results = {}

        # Use ThreadPoolExecutor for parallel processing
        with ThreadPoolExecutor(max_workers=5) as executor:
            future_to_service = {}

            # Submit all export tasks
            for service_name, job_name in self.services.items():
                # Find category for this service
                category = 'other'
                for cat, services in self.service_categories.items():
                    if service_name in services:
                        category = cat
                        break

                future = executor.submit(
                    self.export_service_metrics, service_name, job_name, category)
                future_to_service[future] = (service_name, category)

            # Collect results
            for future in as_completed(future_to_service):
                service_name, category = future_to_service[future]
                try:
                    metrics_count = future.result()
                    total_metrics += metrics_count
                    export_results[service_name] = {
                        'category': category,
                        'metrics_count': metrics_count,
                        'status': 'success'
                    }
                except Exception as e:
                    print(f"❌ Error exporting {service_name}: {e}")
                    export_results[service_name] = {
                        'category': category,
                        'metrics_count': 0,
                        'status': 'failed',
                        'error': str(e)
                    }

        # Generate summary report
        self.generate_summary_report(export_results, total_metrics)

        print(f"\n🎉 Export completed!")
        print(f"📁 Output directory: {export_path}")
        print(f"📊 Total metrics exported: {total_metrics}")
        print(f"🔧 Services processed: {len(export_results)}")

        return export_path, export_results

    def generate_summary_report(self, export_results, total_metrics):
        """Generate comprehensive summary report"""
        summary_dir = os.path.join(self.export_path, "summary")

        # 1. Text summary
        with open(os.path.join(summary_dir, "export_summary.txt"), 'w') as f:
            f.write("COMPREHENSIVE METRICS EXPORT SUMMARY\n")
            f.write("=" * 50 + "\n")
            f.write(f"Export Date: {datetime.now().isoformat()}\n")
            f.write(f"Total Services: {len(export_results)}\n")
            f.write(f"Total Metrics: {total_metrics}\n\n")

            # By category
            f.write("METRICS BY CATEGORY:\n")
            f.write("-" * 30 + "\n")
            category_totals = {}
            for service, data in export_results.items():
                category = data['category']
                if category not in category_totals:
                    category_totals[category] = {'services': 0, 'metrics': 0}
                category_totals[category]['services'] += 1
                category_totals[category]['metrics'] += data['metrics_count']

            for category, totals in sorted(category_totals.items()):
                f.write(
                    f"{category.upper()}: {totals['services']} services, {totals['metrics']} metrics\n")

            f.write("\nDETAILED RESULTS:\n")
            f.write("-" * 30 + "\n")
            for service, data in sorted(export_results.items()):
                status_icon = "✅" if data['status'] == 'success' else "❌"
                f.write(
                    f"{status_icon} {service}: {data['metrics_count']} metrics ({data['category']})\n")

        # 2. CSV summary for analysis
        with open(os.path.join(summary_dir, "export_summary.csv"), 'w', newline='') as f:
            writer = csv.writer(f)
            writer.writerow(
                ['Service', 'Category', 'Metrics_Count', 'Status', 'Error'])

            for service, data in sorted(export_results.items()):
                writer.writerow([
                    service,
                    data['category'],
                    data['metrics_count'],
                    data['status'],
                    data.get('error', '')
                ])

        # 3. JSON summary for programmatic access
        with open(os.path.join(summary_dir, "export_summary.json"), 'w') as f:
            summary_data = {
                'export_timestamp': datetime.now().isoformat(),
                'total_services': len(export_results),
                'total_metrics': total_metrics,
                'services': export_results,
                'category_totals': category_totals
            }
            json.dump(summary_data, f, indent=2)

    def export_time_series_data(self, hours_back=24):
        """Export time series data for key metrics"""
        print(f"📈 Exporting time series data for last {hours_back} hours...")

        # Key metrics to export time series for
        key_metrics = [
            'container_cpu_usage_cores',
            'container_memory_usage_mb',
            'up',
            'http_requests_total',
            'transaction_duration_seconds',
            'cache_hit_ratio',
            'queue_depth'
        ]

        time_series_dir = os.path.join(self.export_path, "time_series")
        os.makedirs(time_series_dir, exist_ok=True)

        for metric in key_metrics:
            try:
                # Query time series data
                query = f'{metric}[{hours_back}h]'
                response = requests.get(
                    f"{self.prometheus_url}/api/v1/query",
                    params={'query': query}
                )

                if response.status_code == 200:
                    data = response.json()
                    if data['data']['result']:
                        filename = os.path.join(
                            time_series_dir, f"{metric}_timeseries.json")
                        with open(filename, 'w') as f:
                            json.dump(data['data']['result'], f, indent=2)
                        print(f"✅ Exported time series for {metric}")
            except Exception as e:
                print(f"❌ Error exporting time series for {metric}: {e}")


def main():
    """Main execution function"""
    print("🎯 COMPREHENSIVE METRICS EXPORTER")
    print("=" * 50)

    exporter = ComprehensiveMetricsExporter()

    # Export all current metrics
    export_path, results = exporter.export_all_services()

    # Export time series data
    exporter.export_time_series_data()

    print(f"\n📋 EXPORT COMPLETED!")
    print(f"📁 All files saved to: {export_path}")
    print(f"📊 Check summary/ directory for overview")
    print(f"📈 Check time_series/ directory for historical data")

    # Quick stats
    successful = sum(1 for r in results.values() if r['status'] == 'success')
    failed = len(results) - successful

    print(f"\n📈 QUICK STATS:")
    print(f"✅ Successful exports: {successful}")
    print(f"❌ Failed exports: {failed}")
    print(
        f"📊 Total metrics: {sum(r['metrics_count'] for r in results.values())}")


if __name__ == "__main__":
    main()
