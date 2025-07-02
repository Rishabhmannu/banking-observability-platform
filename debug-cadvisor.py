#!/usr/bin/env python3
"""
Debug cAdvisor connection and find containers
"""
import requests
import json

def test_cadvisor():
    """Test different cAdvisor endpoints"""
    base_url = "http://localhost:8086"
    
    endpoints = [
        "/api/v1.3/containers",
        "/api/v1.3/containers/",
        "/api/v1.3/docker",
        "/api/v1.2/containers",
        "/api/v1.2/docker",
        "/containers/docker",
        "/"
    ]
    
    print("🔍 Testing cAdvisor endpoints...\n")
    
    for endpoint in endpoints:
        try:
            url = f"{base_url}{endpoint}"
            print(f"Testing: {url}")
            response = requests.get(url, timeout=5)
            
            if response.status_code == 200:
                print(f"✅ Success! Status: {response.status_code}")
                
                # Try to parse as JSON
                try:
                    data = response.json()
                    if isinstance(data, dict):
                        # Check for subcontainers
                        if 'subcontainers' in data:
                            containers = data.get('subcontainers', [])
                            print(f"   Found {len(containers)} subcontainers")
                            for i, container in enumerate(containers[:5]):  # Show first 5
                                print(f"   - {container}")
                        else:
                            print(f"   Keys: {list(data.keys())[:10]}")
                except:
                    print("   Response is not JSON")
            else:
                print(f"❌ Failed. Status: {response.status_code}")
                
        except Exception as e:
            print(f"❌ Error: {e}")
        
        print("-" * 50)

if __name__ == "__main__":
    test_cadvisor()