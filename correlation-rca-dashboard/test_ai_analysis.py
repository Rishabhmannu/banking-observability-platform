#!/usr/bin/env python3
"""
Test AI Analysis Script
Standalone script to test AI RCA functionality
Can be run directly or tested via curl commands

Usage:
    python test_ai_analysis.py
    
    or via curl:
    curl -X GET http://localhost:5026/health
    curl -X GET http://localhost:5026/analyze
"""

import requests
import json
import time
from datetime import datetime


# API Configuration
CORRELATION_API = "http://localhost:5025"
RCA_API = "http://localhost:5026"


def test_service_health():
    """Test health of both correlation and RCA services"""
    print("🏥 Testing Service Health...")
    print("=" * 50)

    # Test Correlation Engine
    try:
        response = requests.get(f"{CORRELATION_API}/health", timeout=5)
        if response.status_code == 200:
            health_data = response.json()
            print(
                f"✅ Correlation Engine: {health_data.get('status', 'unknown')}")
            print(f"   Version: {health_data.get('version', 'unknown')}")
            print(
                f"   Analysis Running: {health_data.get('analysis_running', False)}")
        else:
            print(f"❌ Correlation Engine: HTTP {response.status_code}")
    except Exception as e:
        print(f"❌ Correlation Engine: {str(e)}")

    # Test RCA Engine
    try:
        response = requests.get(f"{RCA_API}/health", timeout=5)
        if response.status_code == 200:
            health_data = response.json()
            print(f"✅ RCA Engine: {health_data.get('status', 'unknown')}")
            print(
                f"   OpenAI Status: {health_data.get('openai_status', 'unknown')}")
        else:
            print(f"❌ RCA Engine: HTTP {response.status_code}")
    except Exception as e:
        print(f"❌ RCA Engine: {str(e)}")

    print()


def test_correlation_data():
    """Test correlation data retrieval"""
    print("🔗 Testing Correlation Data...")
    print("=" * 50)

    try:
        # Test latest correlations
        response = requests.get(
            f"{CORRELATION_API}/correlations/latest", timeout=10)
        if response.status_code == 200:
            data = response.json()
            correlations = data.get('correlations', [])
            print(f"✅ Latest Correlations: {len(correlations)} found")

            if correlations:
                latest = correlations[0]
                print(
                    f"   📊 Example: {latest['metric1']} ↔ {latest['metric2']}")
                print(f"   🎯 Confidence: {latest['confidence']:.1%}")
                print(f"   📈 Type: {latest['type']}")
                return True
            else:
                print("   ⚠️  No correlations available")
                return False
        else:
            print(
                f"❌ Failed to fetch correlations: HTTP {response.status_code}")
            return False
    except Exception as e:
        print(f"❌ Error fetching correlations: {str(e)}")
        return False


def test_ai_analysis():
    """Test AI analysis generation"""
    print("🤖 Testing AI Analysis...")
    print("=" * 50)

    try:
        print("🚀 Triggering AI analysis...")
        start_time = time.time()

        response = requests.get(f"{RCA_API}/analyze", timeout=30)

        duration = time.time() - start_time
        print(f"   ⏱️  Analysis took: {duration:.2f} seconds")

        if response.status_code == 200:
            data = response.json()
            print(f"✅ AI Analysis successful!")

            # Display analysis results
            if 'analyses' in data and data['analyses']:
                analyses = data['analyses']
                print(f"   📋 Generated {len(analyses)} analysis(es)")

                for i, analysis in enumerate(analyses[:3], 1):  # Show first 3
                    print(f"   \n   🔍 Analysis {i}:")
                    corr_event = analysis.get('correlation_event', {})
                    print(
                        f"      Metrics: {corr_event.get('metric1', 'N/A')} ↔ {corr_event.get('metric2', 'N/A')}")
                    print(
                        f"      Confidence: {corr_event.get('confidence', 0):.1%}")

                    if 'rca_explanation' in analysis:
                        # First 100 chars
                        explanation = analysis['rca_explanation'][:100]
                        print(f"      Explanation: {explanation}...")

                    if analysis.get('openai_used'):
                        print(f"      🤖 AI-Powered: Yes")
                    else:
                        print(f"      🤖 AI-Powered: No (Fallback)")

                return True
            else:
                print("   ⚠️  No analyses generated")
                return False
        else:
            print(f"❌ AI Analysis failed: HTTP {response.status_code}")
            if response.text:
                print(f"   Error: {response.text[:200]}")
            return False
    except Exception as e:
        print(f"❌ Error during AI analysis: {str(e)}")
        return False


def test_correlation_summary():
    """Test correlation summary data"""
    print("📊 Testing Correlation Summary...")
    print("=" * 50)

    try:
        response = requests.get(
            f"{CORRELATION_API}/correlations/summary", timeout=10)
        if response.status_code == 200:
            data = response.json()
            print(f"✅ Summary retrieved successfully!")

            total = data.get('total_correlations', 0)
            print(f"   📊 Total Correlations: {total}")

            by_confidence = data.get('by_confidence', {})
            high_conf = by_confidence.get('high_confidence_80_plus', 0)
            print(f"   ⭐ High Confidence: {high_conf}")

            by_category = data.get('by_category', {})
            business = by_category.get('business', 0)
            print(f"   🏢 Business Correlations: {business}")

            return True
        else:
            print(f"❌ Failed to fetch summary: HTTP {response.status_code}")
            return False
    except Exception as e:
        print(f"❌ Error fetching summary: {str(e)}")
        return False


def display_curl_commands():
    """Display equivalent curl commands for testing"""
    print("📡 Equivalent Curl Commands:")
    print("=" * 50)
    print(f"# Test Correlation Engine Health:")
    print(f"curl -s {CORRELATION_API}/health | jq '.'")
    print(f"\n# Test RCA Engine Health:")
    print(f"curl -s {RCA_API}/health | jq '.'")
    print(f"\n# Get Latest Correlations:")
    print(
        f"curl -s {CORRELATION_API}/correlations/latest | jq '.correlations[0:3]'")
    print(f"\n# Get Correlation Summary:")
    print(f"curl -s {CORRELATION_API}/correlations/summary | jq '.'")
    print(f"\n# Trigger AI Analysis:")
    print(f"curl -s {RCA_API}/analyze | jq '.analyses[0]'")
    print()


def main():
    """Main test function"""
    print("🧪 AI Analysis Test Suite")
    print("=" * 60)
    print(f"🕒 Started at: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    print()

    # Run all tests
    tests_passed = 0
    total_tests = 4

    test_service_health()

    if test_correlation_data():
        tests_passed += 1

    if test_correlation_summary():
        tests_passed += 1

    if test_ai_analysis():
        tests_passed += 1

    # Final results
    print()
    print("📋 Test Results Summary:")
    print("=" * 50)
    print(f"✅ Tests Passed: {tests_passed}/{total_tests}")

    if tests_passed == total_tests:
        print("🎉 All tests passed! AI system is working correctly.")
    elif tests_passed > 0:
        print("⚠️  Some tests failed. Check service status and configurations.")
    else:
        print("❌ All tests failed. Verify that both engines are running.")

    print()
    display_curl_commands()


if __name__ == "__main__":
    main()
