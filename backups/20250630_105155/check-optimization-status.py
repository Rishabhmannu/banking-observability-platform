#!/usr/bin/env python3
"""
Check status of all optimization services
"""
import requests
import time
from datetime import datetime

services = [
    ("Redis", "http://localhost:9121/metrics", "Redis Exporter"),
    ("Redis Cache Analyzer", "http://localhost:5012/health", "Cache Analysis Service"),
    ("Cache Load Generator", "http://localhost:5013/health", "Load Testing Service"),
    ("Container Monitor", "http://localhost:5010/health", "Resource Optimization"),
    ("Resource Anomaly", "http://localhost:5011/health", "Anomaly Generator"),
]

def check_service(name, url, description):
    """Check if a service is healthy"""
    try:
        response = requests.get(url, timeout=3)
        if response.status_code == 200:
            if 'health' in url:
                data = response.json()
                status = data.get('status', 'unknown')
                return True, f"✅ {name}: {status}"
            else:
                return True, f"✅ {name}: responding"
        else:
            return False, f"❌ {name}: HTTP {response.status_code}"
    except requests.exceptions.ConnectionError:
        return False, f"❌ {name}: not running"
    except Exception as e:
        return False, f"❌ {name}: {type(e).__name__}"

def main():
    print("🔍 Optimization Services Status Check")
    print(f"📅 {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    print("=" * 50)
    
    all_healthy = True
    results = []
    
    for name, url, description in services:
        healthy, message = check_service(name, url, description)
        results.append((healthy, message, description))
        if not healthy:
            all_healthy = False
    
    # Display results
    print("\n📊 Service Status:")
    for healthy, message, description in results:
        print(f"  {message}")
        if healthy and description:
            print(f"     └─ {description}")
    
    # Quick tests if all services are up
    if all_healthy:
        print("\n🧪 Quick Functionality Tests:")
        
        # Test Redis cache stats
        try:
            response = requests.get("http://localhost:5012/cache-stats")
            if response.status_code == 200:
                stats = response.json()
                print(f"  📈 Cache Hit Ratio: {stats.get('hit_ratio', 0):.1%}")
                print(f"  💾 Memory Usage: {stats.get('memory_usage_mb', 0):.1f} MB")
                print(f"  ⭐ Efficiency Score: {stats.get('efficiency_score', 0):.0f}/100")
        except:
            pass
        
        # Test container recommendations
        try:
            response = requests.get("http://localhost:5010/recommendations")
            if response.status_code == 200:
                data = response.json()
                savings = data.get('total_potential_savings', 0)
                print(f"  💰 Total Potential Savings: ${savings:.2f}/month")
        except:
            pass
    
    # Summary
    print("\n📋 Summary:")
    if all_healthy:
        print("  ✅ All optimization services are running!")
        print("\n🚀 Next Steps:")
        print("  1. Generate some cache traffic:")
        print("     curl -X POST http://localhost:5013/start -H 'Content-Type: application/json' -d '{\"pattern\": \"normal\", \"ops_per_second\": 10}'")
        print("  2. View Grafana dashboards:")
        print("     http://localhost:3000")
        print("  3. Check optimization recommendations:")
        print("     curl http://localhost:5010/top-optimizations | jq")
    else:
        print("  ⚠️  Some services are not running")
        print("  Run: docker-compose logs [service-name] to check errors")

if __name__ == "__main__":
    main()