#!/usr/bin/env python3
"""
AGGRESSIVE Load Testing and Scaling Demo for Kubernetes
Creates disaster-level load scenarios (40%+ CPU) to trigger rapid scaling
"""

import subprocess
import time
import threading
import requests
import sys
import logging
from datetime import datetime
import concurrent.futures

# Enhanced logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)


class AggressiveKubernetesLoadTester:
    def __init__(self):
        self.namespace = "banking-k8s-test"
        self.load_generator_deployment = "load-generator"
        self.banking_service_deployment = "banking-service"
        self.banking_service_url = "http://banking-service:80"
        self.stop_cpu_stress = False

    def run_kubectl_command(self, command):
        """Execute kubectl command"""
        try:
            result = subprocess.run(
                command, shell=True, capture_output=True, text=True)
            return result.stdout.strip() if result.returncode == 0 else None
        except Exception as e:
            logger.error(f"Command failed: {e}")
            return None

    def inject_cpu_stress_bomb(self, duration=180):
        """Inject CPU stress directly into banking service pods"""
        logger.info("💣 DEPLOYING CPU STRESS BOMB IN BANKING PODS...")

        # Get all banking service pods
        pods_cmd = f"kubectl get pods -n {self.namespace} -l app=banking-service -o jsonpath='{{.items[*].metadata.name}}'"
        pods = self.run_kubectl_command(pods_cmd)

        if not pods:
            logger.error("No banking service pods found!")
            return

        pod_list = pods.split()
        threads = []

        for pod in pod_list:
            # Create CPU stress in each pod
            stress_cmd = f"kubectl exec -n {self.namespace} {pod} -- sh -c 'for i in {{1..4}}; do yes > /dev/null & done; sleep {duration}; pkill yes'"
            thread = threading.Thread(
                target=self.run_kubectl_command, args=(stress_cmd,))
            threads.append(thread)
            thread.start()
            logger.info(f"🔥 CPU STRESS BOMB deployed in pod: {pod}")

        return threads

    def create_http_flood_attack(self, duration=180):
        """Create aggressive HTTP flood"""
        logger.info("🌊 LAUNCHING HTTP FLOOD ATTACK...")

        def flood_worker():
            end_time = time.time() + duration
            session = requests.Session()

            while time.time() < end_time and not self.stop_cpu_stress:
                try:
                    # Rapid-fire requests without delays
                    for _ in range(50):  # Burst of 50 requests
                        session.get(self.banking_service_url, timeout=1)
                    time.sleep(0.01)  # Minimal delay
                except:
                    continue

        # Launch multiple flood threads
        threads = []
        for i in range(20):  # 20 concurrent flood threads
            thread = threading.Thread(target=flood_worker)
            threads.append(thread)
            thread.start()

        logger.info("🌊 HTTP FLOOD ATTACK: 20 threads launched!")
        return threads

    def demonstrate_disaster_scenario(self, scenario_name, load_replicas, duration=300):
        """Demonstrate disaster-level scaling scenario"""
        logger.info(f"\n💥 === DISASTER SCENARIO: {scenario_name} ===")
        logger.info(
            f"🎯 Target: {load_replicas} load generators + CPU stress + HTTP flood")
        logger.info(f"⏱️ Duration: {duration} seconds")

        # Step 1: Scale load generators to maximum
        logger.info("🚀 PHASE 1: Maximum load generator deployment...")
        scale_cmd = f"kubectl scale deployment {self.load_generator_deployment} -n {self.namespace} --replicas={load_replicas}"
        self.run_kubectl_command(scale_cmd)
        time.sleep(10)

        # Step 2: Inject CPU stress bombs
        logger.info("💣 PHASE 2: CPU stress bomb injection...")
        cpu_threads = self.inject_cpu_stress_bomb(duration)
        time.sleep(5)

        # Step 3: Launch HTTP flood
        logger.info("🌊 PHASE 3: HTTP flood attack...")
        http_threads = self.create_http_flood_attack(duration)

        # Step 4: Monitor the carnage
        logger.info("📊 PHASE 4: Monitoring system response...")
        self.monitor_disaster_response(duration)

        # Step 5: Cleanup
        logger.info("🧹 PHASE 5: Cleanup and recovery...")
        self.stop_cpu_stress = True

        # Wait for threads to complete
        for thread in http_threads:
            thread.join()

        # Scale back down
        scale_cmd = f"kubectl scale deployment {self.load_generator_deployment} -n {self.namespace} --replicas=1"
        self.run_kubectl_command(scale_cmd)

        logger.info(f"✅ {scenario_name} completed!")

    def monitor_disaster_response(self, duration):
        """Monitor system response during disaster"""
        end_time = time.time() + duration

        while time.time() < end_time:
            # Get current HPA status
            hpa_cmd = f"kubectl get hpa -n {self.namespace} --no-headers"
            hpa_output = self.run_kubectl_command(hpa_cmd)

            if hpa_output:
                parts = hpa_output.split()
                if len(parts) >= 3:
                    logger.info(
                        f"🔥 DISASTER METRICS: {parts[2]} | Replicas: {parts[6]}/{parts[5]}")

            time.sleep(15)

    def run_disaster_demo(self):
        """Run complete disaster demonstration"""
        logger.info("💥 STARTING DISASTER-LEVEL LOAD TESTING DEMO")
        logger.info("=" * 60)

        scenarios = [
            ("Light Disaster", 4, 120),
            ("Medium Disaster", 6, 180),
            ("MAXIMUM DISASTER", 6, 300),
        ]

        for name, replicas, duration in scenarios:
            try:
                self.demonstrate_disaster_scenario(name, replicas, duration)
                logger.info("⏳ Waiting 60 seconds for system recovery...")
                time.sleep(60)
            except KeyboardInterrupt:
                logger.info("🛑 Demo interrupted by user")
                break
            except Exception as e:
                logger.error(f"❌ Scenario failed: {e}")

        logger.info("🎉 DISASTER DEMO COMPLETE!")


if __name__ == "__main__":
    tester = AggressiveKubernetesLoadTester()
    tester.run_disaster_demo()
