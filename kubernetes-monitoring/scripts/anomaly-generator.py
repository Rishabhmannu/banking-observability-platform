#!/usr/bin/env python3
"""
DISASTER-LEVEL Kubernetes Anomaly Generator
Creates extreme anomaly scenarios (40%+ CPU) for testing monitoring systems
"""

import subprocess
import time
import threading
import random
import sys
import logging
from datetime import datetime

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)


class DisasterAnomalyGenerator:
    def __init__(self):
        self.namespace = "banking-k8s-test"
        self.load_generator_deployment = "load-generator"
        self.banking_service_deployment = "banking-service"
        self.disaster_active = False

    def run_kubectl_command(self, command):
        """Execute kubectl command"""
        try:
            result = subprocess.run(
                command, shell=True, capture_output=True, text=True)
            return result.stdout.strip() if result.returncode == 0 else None
        except Exception as e:
            logger.error(f"Command failed: {e}")
            return None

    def create_cpu_bomb_anomaly(self, duration=180):
        """Create extreme CPU spike anomaly"""
        logger.info("💣 ANOMALY: CPU BOMB DETONATION")

        # Get all banking service pods
        pods_cmd = f"kubectl get pods -n {self.namespace} -l app=banking-service -o jsonpath='{{.items[*].metadata.name}}'"
        pods = self.run_kubectl_command(pods_cmd)

        if pods:
            pod_list = pods.split()
            for pod in pod_list:
                # Create intensive CPU load in each pod
                bomb_cmd = f"kubectl exec -n {self.namespace} {pod} -- sh -c 'for i in {{1..8}}; do yes > /dev/null & done; sleep {duration}; pkill yes' &"
                self.run_kubectl_command(bomb_cmd)
                logger.info(f"💥 CPU BOMB planted in {pod}")

        # Also scale load generators to maximum
        scale_cmd = f"kubectl scale deployment {self.load_generator_deployment} -n {self.namespace} --replicas=6"
        self.run_kubectl_command(scale_cmd)

        logger.info(f"⏳ CPU BOMB active for {duration} seconds...")
        time.sleep(duration)

        # Cleanup
        scale_cmd = f"kubectl scale deployment {self.load_generator_deployment} -n {self.namespace} --replicas=1"
        self.run_kubectl_command(scale_cmd)

        logger.info("✅ CPU BOMB anomaly completed")

    def create_cascading_failure_anomaly(self, duration=240):
        """Create cascading failure simulation"""
        logger.info("⚡ ANOMALY: CASCADING SYSTEM FAILURE")

        phases = [
            ("Phase 1: Initial Spike", 3, 60),
            ("Phase 2: System Overload", 5, 90),
            ("Phase 3: MAXIMUM CHAOS", 6, 90),
        ]

        for phase_name, replicas, phase_duration in phases:
            logger.info(f"🔥 {phase_name}")

            # Scale load generators
            scale_cmd = f"kubectl scale deployment {self.load_generator_deployment} -n {self.namespace} --replicas={replicas}"
            self.run_kubectl_command(scale_cmd)

            # Inject CPU stress
            if replicas >= 5:
                self.inject_random_cpu_stress(phase_duration)

            # Monitor during phase
            self.monitor_phase_response(phase_duration)

        # Recovery phase
        logger.info("🔄 RECOVERY: System restoration...")
        scale_cmd = f"kubectl scale deployment {self.load_generator_deployment} -n {self.namespace} --replicas=1"
        self.run_kubectl_command(scale_cmd)

        logger.info("✅ Cascading failure anomaly completed")

    def inject_random_cpu_stress(self, duration):
        """Inject random CPU stress in random pods"""
        pods_cmd = f"kubectl get pods -n {self.namespace} -l app=banking-service -o jsonpath='{{.items[*].metadata.name}}'"
        pods = self.run_kubectl_command(pods_cmd)

        if pods:
            pod_list = pods.split()
            # Randomly select pods for stress
            target_pods = random.sample(pod_list, min(3, len(pod_list)))

            for pod in target_pods:
                stress_cmd = f"kubectl exec -n {self.namespace} {pod} -- sh -c 'for i in {{1..6}}; do yes > /dev/null & done; sleep {duration//2}; pkill yes' &"
                self.run_kubectl_command(stress_cmd)
                logger.info(f"🎯 Random CPU stress injected in {pod}")

    def monitor_phase_response(self, duration):
        """Monitor system response during anomaly phase"""
        end_time = time.time() + duration

        while time.time() < end_time:
            hpa_cmd = f"kubectl get hpa -n {self.namespace} --no-headers"
            hpa_output = self.run_kubectl_command(hpa_cmd)

            if hpa_output:
                parts = hpa_output.split()
                if len(parts) >= 3:
                    logger.info(
                        f"📊 SYSTEM RESPONSE: {parts[2]} | Replicas: {parts[6]}/{parts[5]}")

            time.sleep(20)

    def run_disaster_anomalies(self):
        """Run all disaster-level anomaly scenarios"""
        logger.info("💥 STARTING DISASTER-LEVEL ANOMALY TESTING")
        logger.info("=" * 60)

        anomalies = [
            ("CPU BOMB", self.create_cpu_bomb_anomaly, [200]),
            ("CASCADING FAILURE",
             self.create_cascading_failure_anomaly, [300]),
        ]

        for name, func, args in anomalies:
            logger.info(f"\n🎯 === DISASTER ANOMALY: {name} ===")
            logger.info("⏳ Starting in 10 seconds... (Ctrl+C to skip)")

            try:
                time.sleep(10)
                func(*args)
                logger.info(f"✅ {name} completed successfully")

                logger.info("⏳ Waiting 60 seconds for system recovery...")
                time.sleep(60)

            except KeyboardInterrupt:
                logger.info(f"⏭️ {name} skipped by user")
                continue
            except Exception as e:
                logger.error(f"❌ {name} failed: {e}")
                continue

        logger.info("\n🎉 ALL DISASTER ANOMALIES COMPLETED!")


if __name__ == "__main__":
    generator = DisasterAnomalyGenerator()
    generator.run_disaster_anomalies()
