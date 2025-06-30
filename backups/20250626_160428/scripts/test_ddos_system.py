# scripts/test_ddos_system.py
import requests
import time
import threading
import random
import json
from datetime import datetime
from concurrent.futures import ThreadPoolExecutor
import argparse

class DDoSSystemTester:
    def __init__(self, 
                 banking_url="http://localhost:8080",
                 ml_service_url="http://localhost:5000",
                 prometheus_url="http://localhost:9090",
                 grafana_url="http://localhost:3000"):
        
        self.banking_url = banking_url
        self.ml_service_url = ml_service_url
        self.prometheus_url = prometheus_url
        self.grafana_url = grafana_url
        
        self.attack_active = False
        self.test_results = {
            'normal_traffic': {'requests': 0, 'errors': 0},
            'attack_traffic': {'requests': 0, 'errors': 0},
            'ml_detections': {'normal': [], 'attack': []}
        }
    
    def check_system_health(self):
        """Check if all system components are healthy"""
        print("🔍 Checking system health...")
        
        services = {
            'Banking API': f"{self.banking_url}/health",
            'ML Detection Service': f"{self.ml_service_url}/health",
            'Prometheus': f"{self.prometheus_url}/-/healthy",
            'Grafana': f"{self.grafana_url}/api/health"
        }
        
        all_healthy = True
        for service, url in services.items():
            try:
                response = requests.get(url, timeout=5)
                if response.status_code == 200:
                    print(f"  ✅ {service}: Healthy")
                else:
                    print(f"  ❌ {service}: Unhealthy (HTTP {response.status_code})")
                    all_healthy = False
            except Exception as e:
                print(f"  ❌ {service}: Connection failed ({e})")
                all_healthy = False
        
        return all_healthy
    
    def get_ml_detection_status(self):
        """Get current ML detection status"""
        try:
            response = requests.get(f"{self.ml_service_url}/status", timeout=5)
            if response.status_code == 200:
                return response.json()
            return None
        except:
            return None
    
    def generate_normal_traffic(self, duration_seconds=300, rate_per_second=2):
        """Generate normal banking traffic"""
        print(f"📊 Generating normal traffic for {duration_seconds} seconds at {rate_per_second} req/s...")
        
        endpoints = [
            "/accounts/accounts",
            "/transactions/transactions",
            "/auth/login",
            "/health"
        ]
        
        end_time = time.time() + duration_seconds
        
        while time.time() < end_time and not self.attack_active:
            try:
                endpoint = random.choice(endpoints)
                url = f"{self.banking_url}{endpoint}"
                
                response = requests.get(url, timeout=5)
                
                self.test_results['normal_traffic']['requests'] += 1
                if response.status_code >= 400:
                    self.test_results['normal_traffic']['errors'] += 1
                
                # Check ML detection
                ml_status = self.get_ml_detection_status()
                if ml_status and 'ml_service' in ml_status:
                    detection_score = self._get_prometheus_metric('ddos_detection_score')
                    if detection_score is not None:
                        self.test_results['ml_detections']['normal'].append({
                            'timestamp': datetime.now().isoformat(),
                            'score': detection_score,
                            'prediction': self._get_prometheus_metric('ddos_binary_prediction')
                        })
                
                time.sleep(1 / rate_per_second)
                
            except Exception as e:
                self.test_results['normal_traffic']['errors'] += 1
                print(f"Normal traffic error: {e}")
    
    def generate_ddos_attack(self, duration_seconds=120, intensity="medium"):
        """Simulate DDoS attack"""
        print(f"🚨 Starting {intensity} intensity DDoS attack for {duration_seconds} seconds...")
        
        self.attack_active = True
        
        intensities = {
            "low": {"threads": 10, "delay": 0.1},
            "medium": {"threads": 50, "delay": 0.05},
            "high": {"threads": 100, "delay": 0.01}
        }
        
        config = intensities.get(intensity, intensities["medium"])
        
        def attack_worker():
            end_time = time.time() + duration_seconds
            while time.time() < end_time:
                try:
                    # Rapid requests to banking services
                    endpoints = ["/accounts/accounts", "/health", "/transactions/transactions"]
                    endpoint = random.choice(endpoints)
                    
                    response = requests.get(f"{self.banking_url}{endpoint}", timeout=1)
                    
                    self.test_results['attack_traffic']['requests'] += 1
                    if response.status_code >= 400:
                        self.test_results['attack_traffic']['errors'] += 1
                        
                    time.sleep(config["delay"])
                except:
                    self.test_results['attack_traffic']['errors'] += 1
        
        # Launch attack threads
        with ThreadPoolExecutor(max_workers=config["threads"]) as executor:
            futures = [executor.submit(attack_worker) for _ in range(config["threads"])]
            
            # Monitor ML detection during attack
            monitor_end_time = time.time() + duration_seconds
            while time.time() < monitor_end_time:
                try:
                    detection_score = self._get_prometheus_metric('ddos_detection_score')
                    binary_prediction = self._get_prometheus_metric('ddos_binary_prediction')
                    
                    if detection_score is not None:
                        detection_data = {
                            'timestamp': datetime.now().isoformat(),
                            'score': detection_score,
                            'prediction': binary_prediction
                        }
                        self.test_results['ml_detections']['attack'].append(detection_data)
                        
                        if binary_prediction == 1:
                            print(f"  🎯 ML DETECTED ATTACK! Score: {detection_score:.3f}")
                    
                    time.sleep(10)  # Check every 10 seconds
                except Exception as e:
                    print(f"  Monitoring error: {e}")
                    
            # Wait for all threads to complete
            for future in futures:
                future.result()
        
        self.attack_active = False
        print("🔄 DDoS attack simulation completed")
        
        # Give ML service time to process
        time.sleep(30)
    
    def _get_prometheus_metric(self, metric_name):
        """Get current value of a Prometheus metric"""
        try:
            url = f"{self.prometheus_url}/api/v1/query"
            params = {'query': metric_name}
            
            response = requests.get(url, params=params, timeout=5)
            data = response.json()
            
            if (data['status'] == 'success' and 
                data['data']['result'] and 
                len(data['data']['result']) > 0):
                return float(data['data']['result'][0]['value'][1])
            
            return None
        except:
            return None
    
    def run_comprehensive_test(self):
        """Run a comprehensive test of the DDoS detection system"""
        print("🧪 Starting Comprehensive DDoS Detection System Test")
        print("=" * 60)
        
        # Health check
        if not self.check_system_health():
            print("❌ System health check failed. Please ensure all services are running.")
            return False
        
        print("\n🔄 Test Plan:")
        print("1. Baseline normal traffic (5 minutes)")
        print("2. DDoS attack simulation (2 minutes)")
        print("3. Recovery period (3 minutes)")
        print("4. Analysis and reporting")
        
        start_time = datetime.now()
        
        # Phase 1: Normal traffic baseline
        print(f"\n📊 Phase 1: Generating baseline normal traffic...")
        self.generate_normal_traffic(duration_seconds=300, rate_per_second=2)
        
        # Phase 2: DDoS attack
        print(f"\n🚨 Phase 2: DDoS attack simulation...")
        attack_thread = threading.Thread(
            target=self.generate_ddos_attack, 
            args=(120, "medium")
        )
        attack_thread.start()
        attack_thread.join()
        
        # Phase 3: Recovery
        print(f"\n🔄 Phase 3: Recovery period...")
        self.generate_normal_traffic(duration_seconds=180, rate_per_second=1)
        
        # Analysis
        print(f"\n📈 Test Analysis:")
        self.analyze_results()
        
        end_time = datetime.now()
        print(f"\n✅ Comprehensive test completed in {end_time - start_time}")
        
        return True
    
    def analyze_results(self):
        """Analyze test results and provide insights"""
        print("=" * 40)
        
        # Traffic statistics
        normal_total = self.test_results['normal_traffic']['requests']
        normal_errors = self.test_results['normal_traffic']['errors']
        attack_total = self.test_results['attack_traffic']['requests']
        attack_errors = self.test_results['attack_traffic']['errors']
        
        print(f"📊 Traffic Statistics:")
        print(f"  Normal Traffic:  {normal_total:,} requests, {normal_errors:,} errors ({normal_errors/normal_total*100:.1f}% error rate)")
        print(f"  Attack Traffic:  {attack_total:,} requests, {attack_errors:,} errors ({attack_errors/attack_total*100:.1f}% error rate)")
        
        # ML Detection Analysis
        normal_detections = self.test_results['ml_detections']['normal']
        attack_detections = self.test_results['ml_detections']['attack']
        
        print(f"\n🤖 ML Detection Analysis:")
        print(f"  Normal Period Samples: {len(normal_detections)}")
        print(f"  Attack Period Samples: {len(attack_detections)}")
        
        if normal_detections:
            normal_predictions = [d['prediction'] for d in normal_detections]
            false_positives = sum(normal_predictions)
            false_positive_rate = false_positives / len(normal_predictions) * 100
            print(f"  False Positive Rate: {false_positive_rate:.1f}% ({false_positives}/{len(normal_predictions)})")
        
        if attack_detections:
            attack_predictions = [d['prediction'] for d in attack_detections]
            true_positives = sum(attack_predictions)
            detection_rate = true_positives / len(attack_predictions) * 100
            print(f"  Attack Detection Rate: {detection_rate:.1f}% ({true_positives}/{len(attack_predictions)})")
            
            # Average scores during attack
            attack_scores = [d['score'] for d in attack_detections if d['score'] is not None]
            if attack_scores:
                avg_attack_score = sum(attack_scores) / len(attack_scores)
                print(f"  Average Attack Score: {avg_attack_score:.3f}")
        
        # Performance assessment
        print(f"\n🎯 Performance Assessment:")
        
        if attack_detections and normal_detections:
            # Check if system detected the attack
            detected_attack = any(d['prediction'] == 1 for d in attack_detections)
            if detected_attack:
                print(f"  ✅ ML Model Successfully Detected DDoS Attack")
                
                # Time to detection
                first_detection = next((d for d in attack_detections if d['prediction'] == 1), None)
                if first_detection:
                    print(f"  ⏱️  First Detection: {first_detection['timestamp']}")
            else:
                print(f"  ❌ ML Model Failed to Detect DDoS Attack")
            
            # False alarm check
            false_alarms = any(d['prediction'] == 1 for d in normal_detections)
            if not false_alarms:
                print(f"  ✅ No False Alarms During Normal Traffic")
            else:
                print(f"  ⚠️  False Alarms Detected During Normal Traffic")
        
        print(f"\n📋 Recommendations:")
        if len(attack_detections) == 0:
            print(f"  - Increase ML service monitoring frequency")
        if attack_total > 0 and attack_total < 1000:
            print(f"  - Consider more intensive attack simulation")
        
        print(f"\n🔗 View Real-time Results:")
        print(f"  Grafana Dashboard: {self.grafana_url}")
        print(f"  Prometheus Queries: {self.prometheus_url}")
        print(f"  ML Service Status: {self.ml_service_url}/status")

def main():
    parser = argparse.ArgumentParser(description='Test DDoS Detection System')
    parser.add_argument('--mode', choices=['health', 'normal', 'attack', 'comprehensive'], 
                       default='comprehensive', help='Test mode to run')
    parser.add_argument('--duration', type=int, default=120, 
                       help='Duration for attack simulation (seconds)')
    parser.add_argument('--intensity', choices=['low', 'medium', 'high'], 
                       default='medium', help='Attack intensity')
    
    args = parser.parse_args()
    
    tester = DDoSSystemTester()
    
    if args.mode == 'health':
        tester.check_system_health()
    elif args.mode == 'normal':
        tester.generate_normal_traffic(duration_seconds=300)
    elif args.mode == 'attack':
        tester.generate_ddos_attack(duration_seconds=args.duration, intensity=args.intensity)
    elif args.mode == 'comprehensive':
        tester.run_comprehensive_test()

if __name__ == "__main__":
    main()