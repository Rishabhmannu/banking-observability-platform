#!/usr/bin/env python3
"""
Test cAdvisor connection from both host and container perspective
"""
import requests
import subprocess
import json

def test_from_host():
    """Test cAdvisor connection from host"""
    print("🖥️  Testing from Host Machine:")
    
    # Test port 8086 (your mapped port)
    try:
        response = requests.get("http://localhost:8086/api/v1.0/machine", timeout=5)
        if response.status_code == 200:
            print("✅ SUCCESS: cAdvisor accessible at http://localhost:8086")
            print(f"   Machine info: {len(response.json())} fields")
            return True
        else:
            print(f"❌ FAILED: HTTP {response.status_code}")
    except Exception as e:
        print(f"❌ FAILED: {e}")
    
    return False

def test_from_container():
    """Test cAdvisor connection from within Docker network"""
    print("\n🐳 Testing from Container Network:")
    
    # Test using a temporary container in the same network
    cmd = [
        "docker", "run", "--rm",
        "--network", "ddos-detection-system_banking-network",
        "curlimages/curl:latest",
        "-s", "-o", "/dev/null", "-w", "%{http_code}",
        "http://cadvisor:8080/api/v1.0/machine"
    ]
    
    try:
        result = subprocess.run(cmd, capture_output=True, text=True)
        if result.stdout == "200":
            print("✅ SUCCESS: cAdvisor accessible at http://cadvisor:8080 from containers")
            return True
        else:
            print(f"❌ FAILED: HTTP {result.stdout}")
    except Exception as e:
        print(f"❌ FAILED: {e}")
    
    return False

def get_container_details():
    """Get cAdvisor container details"""
    print("\n📋 cAdvisor Container Details:")
    
    try:
        # Get container inspect data
        result = subprocess.run(
            ["docker", "inspect", "cadvisor"],
            capture_output=True,
            text=True
        )
        
        if result.returncode == 0:
            data = json.loads(result.stdout)[0]
            
            # Extract relevant info
            print(f"   State: {data['State']['Status']}")
            print(f"   Image: {data['Config']['Image']}")
            
            # Port mappings
            ports = data['NetworkSettings']['Ports']
            print("   Port Mappings:")
            for container_port, host_mappings in ports.items():
                if host_mappings:
                    for mapping in host_mappings:
                        print(f"      {mapping['HostPort']} -> {container_port}")
            
            # Networks
            networks = data['NetworkSettings']['Networks']
            print("   Networks:")
            for network_name in networks:
                print(f"      - {network_name}")
                
            return True
    except Exception as e:
        print(f"❌ Error getting container details: {e}")
    
    return False

def main():
    print("🔍 Testing cAdvisor Connectivity\n")
    
    # Get container details first
    get_container_details()
    
    # Test from host
    host_ok = test_from_host()
    
    # Test from container
    container_ok = test_from_container()
    
    # Summary
    print("\n📊 Summary:")
    if host_ok and container_ok:
        print("✅ cAdvisor is properly accessible")
        print("\n🔧 Configuration to use:")
        print("   From host: http://localhost:8086")
        print("   From containers: http://cadvisor:8080")
        print("   Environment variable: CADVISOR_URL=http://cadvisor:8080")
    else:
        print("❌ cAdvisor connectivity issues detected")
        if host_ok and not container_ok:
            print("   cAdvisor is accessible from host but not from containers")
            print("   This suggests a Docker network issue")
        elif not host_ok and container_ok:
            print("   cAdvisor is accessible from containers but not from host")
            print("   This suggests a port mapping issue")

if __name__ == "__main__":
    main()