#!/usr/bin/env python3
"""
Test Cache Proxy Service
"""
import requests
import time
import json

def test_cache_proxy():
    """Test cache proxy functionality"""
    print("🧪 Testing Cache Proxy Service...")
    
    base_url = "http://localhost:8080"  # API Gateway
    cache_proxy_url = "http://localhost:5020"
    
    # Check if cache proxy is running
    try:
        health = requests.get(f"{cache_proxy_url}/health", timeout=2)
        print(f"✅ Cache Proxy Health: {health.json()}")
    except:
        print("❌ Cache Proxy not reachable on port 5020")
        return
    
    # Check cache stats
    try:
        stats = requests.get(f"{cache_proxy_url}/cache/stats", timeout=2)
        print(f"📊 Cache Stats: {json.dumps(stats.json(), indent=2)}")
    except:
        print("❌ Could not get cache stats")
    
    # Test caching with account endpoint
    print("\n🔄 Testing cache behavior...")
    
    # First request (cache miss)
    start = time.time()
    r1 = requests.get(f"{base_url}/accounts/1")
    time1 = time.time() - start
    cache_status1 = r1.headers.get('X-Cache-Status', 'UNKNOWN')
    print(f"Request 1: {r1.status_code} - {cache_status1} - {time1:.3f}s")
    
    # Second request (should be cache hit)
    start = time.time()
    r2 = requests.get(f"{base_url}/accounts/1")
    time2 = time.time() - start
    cache_status2 = r2.headers.get('X-Cache-Status', 'UNKNOWN')
    print(f"Request 2: {r2.status_code} - {cache_status2} - {time2:.3f}s")
    
    if cache_status2 == 'HIT' and time2 < time1:
        print("✅ Cache is working! Second request was faster")
    else:
        print("⚠️  Cache might not be working properly")
    
    # Check metrics
    try:
        metrics = requests.get(f"{cache_proxy_url}/metrics", timeout=2)
        if 'banking_cache_hits_total' in metrics.text:
            print("✅ Prometheus metrics are being exposed")
    except:
        print("❌ Could not fetch metrics")

if __name__ == "__main__":
    test_cache_proxy()