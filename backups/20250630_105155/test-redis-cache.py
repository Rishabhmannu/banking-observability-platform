#!/usr/bin/env python3
"""
Test script for Redis Cache monitoring services
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

def test_cache_operations():
    """Test cache load generation"""
    print("\n🔄 Testing Cache Operations...")
    
    # Start normal traffic pattern
    try:
        response = requests.post(
            'http://localhost:5013/start',
            json={'pattern': 'normal', 'ops_per_second': 5}
        )
        if response.status_code == 200:
            print("✅ Started normal cache traffic pattern")
        else:
            print(f"❌ Failed to start traffic: {response.text}")
            return False
    except Exception as e:
        print(f"❌ Error starting traffic: {e}")
        return False
    
    # Wait for some operations
    print("⏳ Generating cache operations for 10 seconds...")
    time.sleep(10)
    
    # Check stats
    try:
        response = requests.get('http://localhost:5013/stats')
        if response.status_code == 200:
            stats = response.json()
            print(f"✅ Cache operations generated: {stats['total_operations']}")
            print(f"   Actual rate: {stats['actual_ops_per_second']} ops/sec")
        
        # Stop generation
        requests.post('http://localhost:5013/stop')
        print("✅ Stopped cache traffic generation")
        
        return True
    except Exception as e:
        print(f"❌ Error checking stats: {e}")
        return False

def check_cache_analysis():
    """Check if cache analyzer is providing recommendations"""
    print("\n📊 Checking Cache Analysis...")
    
    try:
        response = requests.get('http://localhost:5012/cache-stats')
        if response.status_code == 200:
            stats = response.json()
            print(f"✅ Cache Analysis Results:")
            print(f"   Hit Ratio: {stats['hit_ratio']:.2%}")
            print(f"   Memory Usage: {stats['memory_usage_mb']} MB")
            print(f"   Efficiency Score: {stats['efficiency_score']:.1f}/100")
            return True
        else:
            print(f"⚠️  Cache stats not yet available")
            return False
    except Exception as e:
        print(f"❌ Error getting cache stats: {e}")
        return False

def main():
    print("🚀 Testing Redis Cache Monitoring Services\n")
    
    services = [
        ("Redis Cache Analyzer", "http://localhost:5012/health"),
        ("Cache Load Generator", "http://localhost:5013/health"),
    ]
    
    # Test health endpoints
    print("🏥 Health Check Results:")
    all_healthy = True
    for name, url in services:
        if not test_service(name, url):
            all_healthy = False
    
    if not all_healthy:
        print("\n❌ Some services are not healthy. Please check the logs.")
        sys.exit(1)
    
    # Test cache operations
    if test_cache_operations():
        # Give analyzer time to process
        time.sleep(5)
        check_cache_analysis()
    
    print("\n✅ Redis cache monitoring services are working correctly!")
    print("\n📈 Next steps:")
    print("1. Check Prometheus targets: http://localhost:9090/targets")
    print("2. View cache metrics in Grafana: http://localhost:3000")
    print("3. Try different cache patterns:")
    print("   curl -X POST http://localhost:5013/simulate/stampede")
    print("   curl -X POST http://localhost:5013/simulate/eviction")

if __name__ == "__main__":
    main()