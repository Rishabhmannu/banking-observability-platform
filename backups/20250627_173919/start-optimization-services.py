#!/usr/bin/env python3
"""
Startup script for Redis Cache and Container Resource Optimization services
This script helps start the new monitoring services and verify they're working
"""
import subprocess
import time
import sys
import requests

def run_command(command, description):
    """Run a shell command and report status"""
    print(f"\n🔄 {description}...")
    try:
        result = subprocess.run(command, shell=True, capture_output=True, text=True)
        if result.returncode == 0:
            print(f"✅ {description} - Success")
            if result.stdout:
                print(f"   {result.stdout.strip()}")
            return True
        else:
            print(f"❌ {description} - Failed")
            if result.stderr:
                print(f"   Error: {result.stderr.strip()}")
            return False
    except Exception as e:
        print(f"❌ {description} - Exception: {e}")
        return False

def check_service_health(service_name, url, max_retries=10, retry_delay=3):
    """Check if a service is healthy with retries"""
    print(f"\n🏥 Checking {service_name} health...")
    
    for attempt in range(max_retries):
        try:
            response = requests.get(url, timeout=5)
            if response.status_code == 200:
                data = response.json()
                if data.get('status') == 'healthy':
                    print(f"✅ {service_name} is healthy")
                    return True
                else:
                    print(f"⚠️  {service_name} status: {data.get('status', 'unknown')}")
            else:
                print(f"⚠️  {service_name} returned HTTP {response.status_code}")
        except requests.exceptions.ConnectionError:
            print(f"⏳ Waiting for {service_name} to start... (attempt {attempt + 1}/{max_retries})")
        except Exception as e:
            print(f"⚠️  Error checking {service_name}: {e}")
        
        if attempt < max_retries - 1:
            time.sleep(retry_delay)
    
    print(f"❌ {service_name} failed to become healthy")
    return False

def main():
    print("🚀 Starting Redis Cache & Container Resource Optimization Services")
    print("=" * 60)
    
    # Step 1: Check if main services are running
    print("\n📋 Step 1: Checking prerequisites...")
    
    # Check if Prometheus is running
    try:
        response = requests.get('http://localhost:9090/-/ready', timeout=2)
        if response.status_code == 200:
            print("✅ Prometheus is running")
        else:
            print("⚠️  Prometheus might not be ready")
    except:
        print("❌ Prometheus is not accessible on port 9090")
        print("   Please ensure Prometheus is running first")
        sys.exit(1)
    
    # Check if cAdvisor is running
    try:
        response = requests.get('http://localhost:8080/containers/', timeout=2)
        if response.status_code == 200:
            print("✅ cAdvisor is running")
        else:
            print("⚠️  cAdvisor might not be ready")
    except:
        print("⚠️  cAdvisor is not accessible on port 8080")
        print("   Container resource monitoring will have limited functionality")
    
    # Step 2: Build Docker images
    print("\n📦 Step 2: Building Docker images...")
    
    services_to_build = [
        ("Redis Cache Analyzer", "docker-compose -f docker-compose.optimization.yml build cache-pattern-analyzer"),
        ("Cache Load Generator", "docker-compose -f docker-compose.optimization.yml build cache-load-generator"),
        ("Container Resource Monitor", "docker-compose -f docker-compose.optimization.yml build container-resource-monitor"),
        ("Resource Anomaly Generator", "docker-compose -f docker-compose.optimization.yml build resource-anomaly-generator")
    ]
    
    all_built = True
    for service_name, build_command in services_to_build:
        if not run_command(build_command, f"Building {service_name}"):
            all_built = False
    
    if not all_built:
        print("\n❌ Some services failed to build. Please check the errors above.")
        sys.exit(1)
    
    # Step 3: Start services
    print("\n🚀 Step 3: Starting optimization services...")
    
    if not run_command(
        "docker-compose -f docker-compose.optimization.yml up -d",
        "Starting all optimization services"
    ):
        print("\n❌ Failed to start services. Please check Docker logs.")
        sys.exit(1)
    
    # Step 4: Wait for services to be ready
    print("\n⏳ Step 4: Waiting for services to be ready...")
    time.sleep(5)  # Initial wait
    
    services_to_check = [
        ("Redis", "http://localhost:9121/metrics"),  # Redis exporter
        ("Redis Cache Analyzer", "http://localhost:5012/health"),
        ("Cache Load Generator", "http://localhost:5013/health"),
        ("Container Resource Monitor", "http://localhost:5010/health"),
        ("Resource Anomaly Generator", "http://localhost:5011/health")
    ]
    
    all_healthy = True
    for service_name, health_url in services_to_check:
        if not check_service_health(service_name, health_url):
            all_healthy = False
    
    if not all_healthy:
        print("\n⚠️  Some services are not healthy. Checking logs...")
        run_command(
            "docker-compose -f docker-compose.optimization.yml logs --tail=20",
            "Recent logs from all services"
        )
    
    # Step 5: Initialize some test data
    print("\n🎯 Step 5: Initializing test data...")
    
    try:
        # Start normal cache traffic
        response = requests.post(
            'http://localhost:5013/start',
            json={'pattern': 'normal', 'ops_per_second': 5}
        )
        if response.status_code == 200:
            print("✅ Started normal cache traffic pattern")
        
        # Wait a bit for data to accumulate
        print("⏳ Generating initial data for 15 seconds...")
        time.sleep(15)
        
        # Stop the traffic
        requests.post('http://localhost:5013/stop')
        print("✅ Initial data generation complete")
        
    except Exception as e:
        print(f"⚠️  Could not initialize test data: {e}")
    
    # Step 6: Summary
    print("\n" + "=" * 60)
    print("📊 SUMMARY")
    print("=" * 60)
    
    print("\n✅ All optimization services have been started!")
    
    print("\n🔗 Service URLs:")
    print("   Redis Cache Analyzer:        http://localhost:5012")
    print("   Cache Load Generator:        http://localhost:5013")
    print("   Container Resource Monitor:  http://localhost:5010")
    print("   Resource Anomaly Generator:  http://localhost:5011")
    print("   Redis (direct):             localhost:6379")
    
    print("\n📈 Monitoring URLs:")
    print("   Prometheus Targets:  http://localhost:9090/targets")
    print("   Grafana Dashboards:  http://localhost:3000")
    
    print("\n🧪 Quick Tests:")
    print("   1. Test cache patterns:")
    print("      python test-redis-cache.py")
    print("   2. Test container monitoring:")
    print("      python test-container-resources.py")
    
    print("\n🛑 To stop all services:")
    print("   docker-compose -f docker-compose.optimization.yml down")
    
    print("\n📚 Next Steps:")
    print("   1. Create Grafana dashboards for the new metrics")
    print("   2. Configure alerts in Prometheus for optimization opportunities")
    print("   3. Integrate cache with your banking services")
    print("   4. Review container recommendations at http://localhost:5010/top-optimizations")

if __name__ == "__main__":
    main()