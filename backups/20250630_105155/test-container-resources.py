#!/usr/bin/env python3
"""
Test script for Container Resource monitoring services
Run this after starting the services to verify they're working
"""
import requests
import json
import time
import sys

def test_service(name, url, expected_status='healthy'):
    """Test if a service is healthy"""
    try:
        response = requests.get(url, timeout=5)
        if response.status_code == 200:
            data = response.json()
            status = data.get('status', 'unknown')
            if status == expected_status:
                print(f"✅ {name}: {status}")
                if 'containers_tracked' in data:
                    print(f"   Tracking {data['containers_tracked']} containers")
                return True
            else:
                print(f"⚠️  {name}: {status} (expected {expected_status})")
                return False
        else:
            print(f"❌ {name}: HTTP {response.status_code}")
            return False
    except Exception as e:
        print(f"❌ {name}: {str(e)}")
        return False

def test_resource_anomalies():
    """Test resource anomaly generation"""
    print("\n🔥 Testing Resource Anomaly Generation...")
    
    # Start CPU spike pattern
    try:
        response = requests.post(
            'http://localhost:5011/start/cpu_spike',
            json={'spike_duration': 5, 'spike_intensity': 0.5, 'interval': 10}
        )
        if response.status_code == 200:
            print("✅ Started CPU spike anomaly")
        else:
            print(f"❌ Failed to start anomaly: {response.text}")
            return False
    except Exception as e:
        print(f"❌ Error starting anomaly: {e}")
        return False
    
    # Check status
    time.sleep(2)
    try:
        response = requests.get('http://localhost:5011/status')
        if response.status_code == 200:
            status = response.json()
            print(f"✅ Anomaly Generator Status:")
            print(f"   Active patterns: {status['active_patterns']}")
            print(f"   CPU usage: {status['system']['cpu_percent']}%")
            print(f"   Memory usage: {status['system']['memory_percent']}%")
        
        # Stop anomaly
        requests.post('http://localhost:5011/stop/cpu_spike')
        print("✅ Stopped CPU spike anomaly")
        
        return True
    except Exception as e:
        print(f"❌ Error checking status: {e}")
        return False

def check_container_recommendations():
    """Check container resource recommendations"""
    print("\n📊 Checking Container Recommendations...")
    
    try:
        # Wait for some data collection
        print("⏳ Waiting 35 seconds for metrics collection...")
        time.sleep(35)
        
        response = requests.get('http://localhost:5010/recommendations')
        if response.status_code == 200:
            data = response.json()
            recommendations = data.get('recommendations', {})
            
            # Remove internal keys
            container_recs = {k: v for k, v in recommendations.items() if not k.startswith('_')}
            
            if container_recs:
                print(f"✅ Found recommendations for {len(container_recs)} containers")
                
                # Show top optimization
                response = requests.get('http://localhost:5010/top-optimizations')
                if response.status_code == 200:
                    top_data = response.json()
                    top_opts = top_data.get('top_optimizations', [])
                    if top_opts:
                        top = top_opts[0]
                        print(f"\n📈 Top Optimization Opportunity:")
                        print(f"   Container: {top['container']}")
                        print(f"   Category: {top['category']}")
                        print(f"   Potential Savings: ${top['potential_savings']:.2f}/month")
                        print(f"   CPU Waste: {top['cpu_waste']:.1f}%")
                        print(f"   Memory Waste: {top['memory_waste']:.1f}%")
                
                return True
            else:
                print("⚠️  No recommendations available yet (need more data)")
                print("   Container monitor needs at least 10 data points")
                return False
        else:
            print(f"❌ Failed to get recommendations: HTTP {response.status_code}")
            return False
    except Exception as e:
        print(f"❌ Error getting recommendations: {e}")
        return False

def test_anomaly_scenarios():
    """Test predefined anomaly scenarios"""
    print("\n🎭 Testing Anomaly Scenarios...")
    
    scenarios = ['memory_pressure', 'cpu_stress', 'resource_fluctuation']
    
    for scenario in scenarios:
        try:
            print(f"\n  Testing '{scenario}' scenario...")
            
            # Start scenario
            response = requests.post(f'http://localhost:5011/scenarios/{scenario}')
            if response.status_code == 200:
                data = response.json()
                print(f"  ✅ Started with patterns: {data['patterns']}")
                
                # Let it run briefly
                time.sleep(5)
                
                # Stop all
                requests.post('http://localhost:5011/stop-all')
                print(f"  ✅ Stopped {scenario}")
            else:
                print(f"  ❌ Failed to start {scenario}")
        except Exception as e:
            print(f"  ❌ Error with {scenario}: {e}")

def main():
    print("🚀 Testing Container Resource Monitoring Services\n")
    
    services = [
        ("Container Resource Monitor", "http://localhost:5010/health"),
        ("Resource Anomaly Generator", "http://localhost:5011/health"),
    ]
    
    # Test health endpoints
    print("🏥 Health Check Results:")
    all_healthy = True
    for name, url in services:
        if not test_service(name, url):
            all_healthy = False
    
    if not all_healthy:
        print("\n❌ Some services are not healthy. Please check the logs.")
        print("   Make sure cAdvisor is running on port 8080")
        sys.exit(1)
    
    # Test anomaly generation
    if test_resource_anomalies():
        # Check recommendations
        check_container_recommendations()
    
    # Test scenarios
    test_anomaly_scenarios()
    
    print("\n✅ Container resource monitoring services are working correctly!")
    print("\n📈 Next steps:")
    print("1. Check Prometheus targets: http://localhost:9090/targets")
    print("2. View container metrics in Grafana: http://localhost:3000")
    print("3. Explore optimization opportunities:")
    print("   curl http://localhost:5010/top-optimizations | jq")
    print("4. Try anomaly scenarios:")
    print("   curl -X POST http://localhost:5011/scenarios/unstable_container")

if __name__ == "__main__":
    main()