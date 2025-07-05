#!/usr/bin/env python3
"""
Kubernetes Real-time Monitoring Dashboard
Provides live terminal dashboard for monitoring K8s metrics during demos
"""

import subprocess
import time
import json
import sys
import os
from datetime import datetime
import threading


class KubernetesMonitoringDashboard:
    def __init__(self):
        self.namespace = "banking-k8s-test"
        self.running = True
        self.refresh_interval = 5  # seconds

    def run_kubectl_command(self, command):
        """Execute kubectl command and return output"""
        try:
            result = subprocess.run(
                command, shell=True, capture_output=True, text=True)
            if result.returncode == 0:
                return result.stdout.strip()
            else:
                return f"Error: {result.stderr}"
        except Exception as e:
            return f"Exception: {e}"

    def clear_screen(self):
        """Clear terminal screen"""
        os.system('cls' if os.name == 'nt' else 'clear')

    def get_hpa_status(self):
        """Get HPA detailed status"""
        command = f"kubectl get hpa banking-service-hpa -n {self.namespace} -o json"
        result = self.run_kubectl_command(command)

        try:
            hpa_data = json.loads(result)
            status = hpa_data.get('status', {})
            return {
                'current_replicas': status.get('currentReplicas', 0),
                'desired_replicas': status.get('desiredReplicas', 0),
                'min_replicas': hpa_data.get('spec', {}).get('minReplicas', 0),
                'max_replicas': hpa_data.get('spec', {}).get('maxReplicas', 0),
                'cpu_utilization': status.get('currentMetrics', [{}])[0].get('resource', {}).get('current', {}).get('averageUtilization', 0),
                'target_cpu': hpa_data.get('spec', {}).get('metrics', [{}])[0].get('resource', {}).get('target', {}).get('averageUtilization', 0)
            }
        except (json.JSONDecodeError, KeyError, IndexError):
            return None

    def get_pod_status(self):
        """Get pod status for all deployments"""
        pods_info = {}

        # Get banking service pods
        command = f"kubectl get pods -n {self.namespace} -l app=banking-service -o json"
        result = self.run_kubectl_command(command)

        try:
            pods_data = json.loads(result)
            banking_pods = []
            for pod in pods_data.get('items', []):
                pod_info = {
                    'name': pod['metadata']['name'],
                    'status': pod['status']['phase'],
                    'ready': f"{sum(1 for c in pod['status'].get('containerStatuses', []) if c.get('ready', False))}/{len(pod['status'].get('containerStatuses', []))}"
                }
                banking_pods.append(pod_info)
            pods_info['banking_service'] = banking_pods
        except (json.JSONDecodeError, KeyError):
            pods_info['banking_service'] = []

        # Get load generator pods
        command = f"kubectl get pods -n {self.namespace} -l app=load-generator -o json"
        result = self.run_kubectl_command(command)

        try:
            pods_data = json.loads(result)
            load_gen_pods = []
            for pod in pods_data.get('items', []):
                pod_info = {
                    'name': pod['metadata']['name'],
                    'status': pod['status']['phase'],
                    'ready': f"{sum(1 for c in pod['status'].get('containerStatuses', []) if c.get('ready', False))}/{len(pod['status'].get('containerStatuses', []))}"
                }
                load_gen_pods.append(pod_info)
            pods_info['load_generator'] = load_gen_pods
        except (json.JSONDecodeError, KeyError):
            pods_info['load_generator'] = []

        return pods_info

    def get_node_resources(self):
        """Get node resource utilization"""
        # Get node metrics
        command = "kubectl top nodes"
        result = self.run_kubectl_command(command)

        node_info = {}
        if "Error" not in result:
            lines = result.split('\n')[1:]  # Skip header
            for line in lines:
                parts = line.split()
                if len(parts) >= 5:
                    node_info = {
                        'name': parts[0],
                        'cpu_usage': parts[1],
                        'cpu_percent': parts[2],
                        'memory_usage': parts[3],
                        'memory_percent': parts[4]
                    }
                    break

        return node_info

    def get_recent_events(self, limit=5):
        """Get recent events in the namespace"""
        command = f"kubectl get events -n {self.namespace} --sort-by='.lastTimestamp' --limit={limit}"
        result = self.run_kubectl_command(command)

        events = []
        if "Error" not in result:
            lines = result.split('\n')[1:]  # Skip header
            for line in lines:
                if line.strip():
                    events.append(line)

        return events

    def display_dashboard(self):
        """Display the monitoring dashboard"""
        while self.running:
            self.clear_screen()

            # Header
            print("🚀 Kubernetes Monitoring Dashboard - Banking K8s Test")
            print("=" * 70)
            print(
                f"📅 {datetime.now().strftime('%Y-%m-%d %H:%M:%S')} | Refresh: {self.refresh_interval}s | Press Ctrl+C to exit")
            print("=" * 70)

            # HPA Status
            hpa_status = self.get_hpa_status()
            if hpa_status:
                print("\n🎯 HPA AUTO-SCALING STATUS")
                print("-" * 30)
                print(f"📊 Current Replicas: {hpa_status['current_replicas']}")
                print(f"📈 Desired Replicas: {hpa_status['desired_replicas']}")
                print(f"📉 Min Replicas: {hpa_status['min_replicas']}")
                print(f"📊 Max Replicas: {hpa_status['max_replicas']}")
                print(
                    f"🔥 CPU Utilization: {hpa_status['cpu_utilization']}% (Target: {hpa_status['target_cpu']}%)")

                # Scaling status
                if hpa_status['current_replicas'] < hpa_status['desired_replicas']:
                    print("📈 STATUS: SCALING UP")
                elif hpa_status['current_replicas'] > hpa_status['desired_replicas']:
                    print("📉 STATUS: SCALING DOWN")
                else:
                    print("✅ STATUS: STABLE")
            else:
                print("\n❌ HPA STATUS: Unable to retrieve")

            # Pod Status
            pods_info = self.get_pod_status()
            print("\n🐳 POD STATUS")
            print("-" * 30)
            print(
                f"🏦 Banking Service Pods: {len(pods_info.get('banking_service', []))}")
            for pod in pods_info.get('banking_service', []):
                status_emoji = "✅" if pod['status'] == 'Running' else "⚠️"
                print(
                    f"  {status_emoji} {pod['name'][:20]}... | {pod['status']} | Ready: {pod['ready']}")

            print(
                f"\n⚡ Load Generator Pods: {len(pods_info.get('load_generator', []))}")
            for pod in pods_info.get('load_generator', []):
                status_emoji = "✅" if pod['status'] == 'Running' else "⚠️"
                print(
                    f"  {status_emoji} {pod['name'][:20]}... | {pod['status']} | Ready: {pod['ready']}")

            # Node Resources
            node_info = self.get_node_resources()
            print("\n🖥️ NODE RESOURCES")
            print("-" * 30)
            if node_info:
                print(f"📊 Node: {node_info.get('name', 'Unknown')}")
                print(
                    f"🔥 CPU Usage: {node_info.get('cpu_usage', 'N/A')} ({node_info.get('cpu_percent', 'N/A')})")
                print(
                    f"💾 Memory Usage: {node_info.get('memory_usage', 'N/A')} ({node_info.get('memory_percent', 'N/A')})")
            else:
                print("⚠️ Node metrics unavailable")

            # Recent Events
            events = self.get_recent_events(3)
            print("\n📅 RECENT EVENTS")
            print("-" * 30)
            for event in events:
                print(f"  📋 {event}")

            # Dashboard URLs
            print("\n🔗 GRAFANA DASHBOARDS")
            print("-" * 30)
            print(
                "📊 Dashboard 1: http://localhost:3000/d/k8s-cluster-overview-professional")
            print(
                "🚀 Dashboard 2: http://localhost:3000/d/k8s-pod-autoscaling-professional")
            print("🖥️ Dashboard 3: http://localhost:3000/d/k8s-node-resource-consumption")

            # Wait before next refresh
            time.sleep(self.refresh_interval)

    def stop(self):
        """Stop the monitoring dashboard"""
        self.running = False


def main():
    """Main execution function"""
    dashboard = KubernetesMonitoringDashboard()

    try:
        print("🚀 Starting Kubernetes Monitoring Dashboard...")
        print("📊 This will show real-time K8s metrics during your demo")
        print("⏳ Starting in 3 seconds...")
        time.sleep(3)

        dashboard.display_dashboard()

    except KeyboardInterrupt:
        print("\n🛑 Monitoring dashboard stopped by user")
        dashboard.stop()
    except Exception as e:
        print(f"❌ Dashboard failed: {e}")
        dashboard.stop()


if __name__ == "__main__":
    main()
