# scripts/simulate_ddos.py
import requests
import threading
import time
import random
from concurrent.futures import ThreadPoolExecutor


class DDoSSimulator:
    def __init__(self, target_url="http://localhost:8080"):
        self.target_url = target_url
        self.attack_active = False

    def normal_traffic(self, duration_seconds=300):
        """Generate normal banking traffic"""
        end_time = time.time() + duration_seconds

        while time.time() < end_time and not self.attack_active:
            try:
                # Simulate normal banking operations
                endpoints = [
                    "/accounts/accounts",
                    "/transactions/transactions",
                    "/auth/login",
                    "/health"
                ]

                endpoint = random.choice(endpoints)
                response = requests.get(
                    f"{self.target_url}{endpoint}", timeout=5)

                # Random delay between requests (normal user behavior)
                time.sleep(random.uniform(1, 3))

            except Exception as e:
                print(f"Normal traffic error: {e}")

    def ddos_attack(self, duration_seconds=120, intensity="medium"):
        """Simulate DDoS attack"""
        self.attack_active = True

        intensities = {
            "low": {"threads": 10, "delay": 0.1},
            "medium": {"threads": 50, "delay": 0.05},
            "high": {"threads": 100, "delay": 0.01}
        }

        config = intensities.get(intensity, intensities["medium"])

        print(
            f"Starting {intensity} intensity DDoS attack for {duration_seconds} seconds...")

        def attack_worker():
            end_time = time.time() + duration_seconds
            while time.time() < end_time:
                try:
                    # Rapid requests to overwhelm the server
                    requests.get(
                        f"{self.target_url}/accounts/accounts", timeout=1)
                    time.sleep(config["delay"])
                except:
                    pass  # Ignore errors during attack

        # Launch attack threads
        with ThreadPoolExecutor(max_workers=config["threads"]) as executor:
            futures = [executor.submit(attack_worker)
                       for _ in range(config["threads"])]

            # Wait for attack to complete
            time.sleep(duration_seconds)

        self.attack_active = False
        print("DDoS attack simulation completed!")

    def run_simulation(self):
        """Run complete simulation: normal -> attack -> normal"""
        print("Starting DDoS simulation...")

        # Phase 1: Normal traffic (5 minutes)
        print("Phase 1: Normal traffic (5 minutes)")
        normal_thread = threading.Thread(
            target=self.normal_traffic, args=(300,))
        normal_thread.start()
        time.sleep(300)

        # Phase 2: DDoS attack (2 minutes)
        print("Phase 2: DDoS attack (2 minutes)")
        self.ddos_attack(120, "medium")

        # Phase 3: Recovery (3 minutes)
        print("Phase 3: Recovery period (3 minutes)")
        self.attack_active = False
        recovery_thread = threading.Thread(
            target=self.normal_traffic, args=(180,))
        recovery_thread.start()
        recovery_thread.join()

        print("Simulation completed!")


if __name__ == "__main__":
    simulator = DDoSSimulator()
    simulator.run_simulation()
