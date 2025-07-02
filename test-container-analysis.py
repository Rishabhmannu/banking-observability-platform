#!/usr/bin/env python3
import requests
import time
import json

print("🔍 Testing Container Resource Monitor...")

# Check health
try:
    health = requests.get("http://localhost:5010/health")
    print(f"Health: {health.json()}")
except Exception as e:
    print(f"❌ Error: {e}")

# Get recommendations
try:
    print("\n📊 Fetching recommendations...")
    rec = requests.get("http://localhost:5010/recommendations")
    print(json.dumps(rec.json(), indent=2))
except Exception as e:
    print(f"❌ Error: {e}")

# Check metrics
try:
    print("\n📈 Checking for optimization metrics...")
    metrics = requests.get("http://localhost:5010/metrics")
    for line in metrics.text.split('\n'):
        if 'container_' in line and not line.startswith('#'):
            print(line)
except Exception as e:
    print(f"❌ Error: {e}")

# Trigger immediate analysis
print("\n🔄 Triggering analysis...")
try:
    analyze = requests.post("http://localhost:5010/analyze")
    print(f"Analysis result: {analyze.status_code}")
except:
    print("Analysis endpoint might not exist")