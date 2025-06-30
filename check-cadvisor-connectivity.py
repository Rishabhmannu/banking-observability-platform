#!/usr/bin/env python3
"""
Check cAdvisor connectivity and determine the correct URL configuration
"""
import requests
import subprocess
import json

def check_url(url, description):
    """Check if a URL is accessible"""
    try:
        response = requests.get(f"{url}/api/v1.3/machine", timeout=5)
        if response.status_code == 200:
            print(f"✅ {description}: {url} - ACCESSIBLE")
            return True
        else:
            print(f"❌ {description}: {url} - HTTP {response.status_code}")
            return False
    except Exception as e:
        print(f"❌ {description}: {url} - {type(e).__name__}")
        return False

def get_cadvisor_container_info():
    """Get cAdvisor container information"""
    try:
        result = subprocess.run(
            ["docker", "ps", "--filter", "name=cadvisor", "--format", "json"],
            capture_output=True,
            text=True
        )
        if result.stdout:
            container = json.loads(result.stdout.split('\n')[0])
            print(f"\n📦 cAdvisor Container Info:")
            print(f"   Name: {container.get('Names', 'Unknown')}")
            print(f"   Image: {container.get('Image', 'Unknown')}")
            print(f"   Ports: {container.get('Ports', 'Unknown')}")
            print(f"   Networks: {container.get('Networks', 'Unknown')}")
            return container.get('Names', '').lower()
        else:
            print("\n⚠️  No cAdvisor container found")
            return None
    except Exception as e:
        print(f"\n❌ Error getting container info: {e}")
        return None

def main():
    print("🔍 Checking cAdvisor Connectivity\n")
    
    # Get container info
    container_name = get_cadvisor_container_info()
    
    # Test different connection methods
    print("\n🌐 Testing Connection Methods:")
    
    # Extract the actual port from container info if available
    actual_port = "8080"  # Default
    if container_name:
        try:
            result = subprocess.run(
                ["docker", "port", "cadvisor", "8080/tcp"],
                capture_output=True,
                text=True
            )
            if result.stdout:
                # Extract port from output like "0.0.0.0:8086"
                actual_port = result.stdout.strip().split(':')[-1]
                print(f"   📌 Detected cAdvisor is mapped to port: {actual_port}")
        except:
            pass
    
    urls_to_test = [
        (f"http://localhost:{actual_port}", f"Localhost port {actual_port} (from host)"),
        ("http://cadvisor:8080", "Container internal port 8080"),
        (f"http://host.docker.internal:{actual_port}", f"Docker host port {actual_port}"),
    ]
    
    # Add actual container name if found
    if container_name and container_name != 'cadvisor':
        urls_to_test.append((f"http://{container_name}:8080", f"Actual container name '{container_name}'"))
    
    working_urls = []
    for url, description in urls_to_test:
        if check_url(url, description):
            working_urls.append(url)
    
    # Check Docker network
    print("\n🔗 Checking Docker Networks:")
    try:
        # Check if banking-network exists
        result = subprocess.run(
            ["docker", "network", "inspect", "ddos-detection-system_banking-network"],
            capture_output=True,
            text=True
        )
        if result.returncode == 0:
            print("✅ Banking network exists")
            
            # Check if cAdvisor is in the network
            network_info = json.loads(result.stdout)[0]
            containers = network_info.get('Containers', {})
            cadvisor_in_network = any('cadvisor' in name.lower() for name in 
                                     [c.get('Name', '') for c in containers.values()])
            
            if cadvisor_in_network:
                print("✅ cAdvisor is in the banking network")
            else:
                print("⚠️  cAdvisor is NOT in the banking network")
                print("   This might require special configuration")
        else:
            print("❌ Banking network not found")
    except Exception as e:
        print(f"❌ Error checking network: {e}")
    
    # Provide recommendations
    print("\n📋 Recommendations:")
    if working_urls:
        if "http://cadvisor:8080" in working_urls:
            print("✅ Use default configuration - cAdvisor is accessible via container name")
        else:
            print(f"⚠️  Update CADVISOR_URL to: {working_urls[0]}")
            print(f"   Set environment variable: export CADVISOR_URL='{working_urls[0]}'")
    else:
        print("❌ cAdvisor is not accessible. Please ensure:")
        print("   1. cAdvisor container is running")
        print("   2. Port 8080 is properly exposed")
        print("   3. Container is in the correct network")
    
    # Show how to set the environment variable
    if working_urls and "http://cadvisor:8080" not in working_urls:
        print("\n🔧 To fix, run:")
        print(f"   export CADVISOR_URL='{working_urls[0]}'")
        print("   docker-compose -f docker-compose.optimization.yml up -d")

if __name__ == "__main__":
    main()