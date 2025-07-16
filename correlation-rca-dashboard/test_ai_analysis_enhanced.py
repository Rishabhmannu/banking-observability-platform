#!/usr/bin/env python3
"""
Enhanced Test AI Analysis Script with Debug Information
Tests the optimized RCA functionality and analyzes the actual data structure

Usage:
    python test_ai_analysis_debug.py
"""

import requests
import json
import time
from datetime import datetime
from pprint import pprint


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
            print(f"✅ Correlation Engine: {health_data.get('status', 'unknown')}")
            print(f"   Version: {health_data.get('version', 'unknown')}")
            print(f"   Analysis Running: {health_data.get('analysis_running', False)}")
        else:
            print(f"❌ Correlation Engine: HTTP {response.status_code}")
    except Exception as e:
        print(f"❌ Correlation Engine: {str(e)}")

    # Test RCA Engine with enhanced status
    try:
        response = requests.get(f"{RCA_API}/health", timeout=5)
        if response.status_code == 200:
            health_data = response.json()
            print(f"✅ RCA Engine: {health_data.get('status', 'unknown')}")
            print(f"   Version: {health_data.get('version', 'unknown')}")
            print(f"   Model: {health_data.get('model', 'unknown')}")
            print(f"   OpenAI Status: {health_data.get('openai_status', 'unknown')}")

            # Show performance limits
            perf = health_data.get('performance', {})
            print(f"   Default Limit: {perf.get('default_correlation_limit', 'unknown')}")
            print(f"   Max Time: {perf.get('max_analysis_time_seconds', 'unknown')}s")
        else:
            print(f"❌ RCA Engine: HTTP {response.status_code}")
    except Exception as e:
        print(f"❌ RCA Engine: {str(e)}")

    print()


def test_openai_detailed_status():
    """Test detailed OpenAI status"""
    print("🤖 Testing Detailed OpenAI Status...")
    print("=" * 50)

    try:
        response = requests.get(f"{RCA_API}/openai-status", timeout=5)
        if response.status_code == 200:
            data = response.json()
            print(f"✅ OpenAI Status Retrieved:")
            print(f"   Configured: {data.get('configured', False)}")
            print(f"   Test Passed: {data.get('test_passed', False)}")
            print(f"   Model: {data.get('model', 'unknown')}")
            print(f"   Status: {data.get('status_message', 'unknown')}")

            recommendations = data.get('recommendations', [])
            if recommendations:
                print(f"   Recommendations: {', '.join(recommendations)}")
            return True
        else:
            print(f"❌ Failed to get OpenAI status: HTTP {response.status_code}")
            return False
    except Exception as e:
        print(f"❌ Error getting OpenAI status: {str(e)}")
        return False


def test_correlation_data():
    """Test correlation data retrieval"""
    print("🔗 Testing Correlation Data...")
    print("=" * 50)

    try:
        response = requests.get(f"{CORRELATION_API}/correlations/latest", timeout=10)
        if response.status_code == 200:
            data = response.json()
            correlations = data.get('correlations', [])
            print(f"✅ Latest Correlations: {len(correlations)} found")

            if correlations:
                latest = correlations[0]
                print(f"   📊 Example: {latest['metric1']} ↔ {latest['metric2']}")
                print(f"   🎯 Confidence: {latest['confidence']:.1%}")
                print(f"   📈 Type: {latest['type']}")
                return True
            else:
                print("   ⚠️  No correlations available")
                return False
        else:
            print(f"❌ Failed to fetch correlations: HTTP {response.status_code}")
            return False
    except Exception as e:
        print(f"❌ Error fetching correlations: {str(e)}")
        return False


def analyze_ai_response_structure(data, test_name):
    """Analyze the structure of AI analysis response in detail"""
    print(f"\n🔍 **DETAILED ANALYSIS: {test_name}**")
    print("=" * 60)
    
    # Top-level structure
    print("📋 **Top-level Response Structure:**")
    for key in data.keys():
        value = data[key]
        if isinstance(value, list):
            print(f"   {key}: List with {len(value)} items")
        elif isinstance(value, dict):
            print(f"   {key}: Dict with {len(value)} keys")
        else:
            print(f"   {key}: {type(value).__name__} = {value}")
    
    # Analyses structure
    analyses = data.get('analyses', [])
    print(f"\n📊 **Analyses Array: {len(analyses)} items**")
    
    for i, analysis in enumerate(analyses, 1):
        print(f"\n   📝 **Analysis {i}:**")
        print(f"      Keys: {list(analysis.keys())}")
        
        # Correlation event details
        if 'correlation_event' in analysis:
            corr_event = analysis['correlation_event']
            print(f"      📈 Correlation Event:")
            print(f"         Metric1: {corr_event.get('metric1', 'N/A')}")
            print(f"         Metric2: {corr_event.get('metric2', 'N/A')}")
            print(f"         Confidence: {corr_event.get('confidence', 0):.1%}")
            print(f"         Type: {corr_event.get('type', 'N/A')}")
            print(f"         P-Value: {corr_event.get('p_value', 'N/A')}")
        
        # RCA explanation details
        if 'rca_explanation' in analysis:
            explanation = analysis['rca_explanation']
            print(f"      🤖 RCA Explanation:")
            print(f"         Type: {type(explanation)}")
            print(f"         Length: {len(explanation) if explanation else 0} characters")
            if explanation:
                # Show first 100 characters
                preview = explanation[:100].replace('\n', ' ')
                print(f"         Preview: '{preview}...'")
            else:
                print(f"         Content: EMPTY or None")
        else:
            print(f"      🤖 RCA Explanation: MISSING from response")
        
        # Additional analysis fields
        other_fields = {k: v for k, v in analysis.items() 
                       if k not in ['correlation_event', 'rca_explanation']}
        if other_fields:
            print(f"      🔧 Other Fields:")
            for field, value in other_fields.items():
                if isinstance(value, dict):
                    print(f"         {field}: Dict with keys {list(value.keys())}")
                else:
                    print(f"         {field}: {value}")
    
    # Performance analysis
    if 'performance' in data:
        perf = data['performance']
        print(f"\n⚡ **Performance Metrics:**")
        for key, value in perf.items():
            print(f"   {key}: {value}")


def test_ai_analysis_optimized():
    """Test AI analysis with new optimized parameters - FIXED VERSION"""
    print("🚀 Testing Optimized AI Analysis...")
    print("=" * 50)

    test_cases = [
        {"limit": 1, "min_confidence": 0.9, "name": "Single High-Confidence"},
        {"limit": 2, "min_confidence": 0.8, "name": "Two High-Confidence"},
        {"limit": 3, "min_confidence": 0.7, "name": "Three Medium-Confidence"},
    ]

    successful_tests = 0
    total_tests = len(test_cases)

    for i, test_case in enumerate(test_cases, 1):
        limit = test_case["limit"]
        min_conf = test_case["min_confidence"]
        name = test_case["name"]

        print(f"\n🧪 Test {i}/{total_tests}: {name} (limit={limit}, min_confidence={min_conf})")
        print("-" * 50)

        try:
            start_time = time.time()

            # Build URL with parameters
            url = f"{RCA_API}/analyze?limit={limit}&min_confidence={min_conf}"
            print(f"   📡 Calling: {url}")

            # Request with timeout
            response = requests.get(url, timeout=35)
            duration = time.time() - start_time

            print(f"   ⏱️  Request took: {duration:.2f} seconds")

            if response.status_code == 200:
                data = response.json()
                print(f"   ✅ Analysis successful!")

                # Basic metrics
                total_corr = data.get('total_correlations', 0)
                filtered_corr = data.get('filtered_correlations', 0)
                analyses_gen = data.get('analyses_generated', 0)

                print(f"   📊 Total correlations: {total_corr}")
                print(f"   🔍 Filtered correlations: {filtered_corr}")
                print(f"   📋 Analyses generated: {analyses_gen}")

                # Performance data
                perf = data.get('performance', {})
                total_time = perf.get('total_time_seconds', 0)
                avg_time = perf.get('average_time_per_analysis', 0)
                timeout_occurred = perf.get('timeout_occurred', False)

                print(f"   ⚡ Total analysis time: {total_time:.2f}s")
                print(f"   📈 Average per analysis: {avg_time:.2f}s")
                print(f"   ⏰ Timeout occurred: {timeout_occurred}")

                # DETAILED ANALYSIS OF RESPONSE STRUCTURE
                analyze_ai_response_structure(data, name)

                successful_tests += 1

            else:
                print(f"   ❌ Analysis failed: HTTP {response.status_code}")
                try:
                    error_data = response.json()
                    print(f"   Error: {error_data.get('error', response.text[:100])}")
                except:
                    print(f"   Error: {response.text[:100]}")

        except requests.exceptions.Timeout:
            duration = time.time() - start_time
            print(f"   ❌ Analysis timed out after {duration:.2f} seconds")
        except Exception as e:
            duration = time.time() - start_time
            print(f"   ❌ Error after {duration:.2f} seconds: {str(e)}")

    print(f"\n🎯 **Optimized Tests Summary: {successful_tests}/{total_tests} passed**")
    return successful_tests > 0


def test_ai_analysis_original():
    """Test original AI analysis (no parameters) for comparison"""
    print("\n🤖 Testing Original AI Analysis (No Parameters)...")
    print("=" * 50)

    try:
        print("🚀 Triggering analysis without parameters...")
        start_time = time.time()

        response = requests.get(f"{RCA_API}/analyze", timeout=35)
        duration = time.time() - start_time

        print(f"   ⏱️  Analysis took: {duration:.2f} seconds")

        if response.status_code == 200:
            data = response.json()
            print(f"✅ Original analysis successful!")

            analyses = data.get('analyses', [])
            print(f"   📋 Generated {len(analyses)} analysis(es)")
            
            # DETAILED ANALYSIS OF ORIGINAL RESPONSE
            analyze_ai_response_structure(data, "Original Analysis")
            
            return True
        else:
            print(f"❌ Original analysis failed: HTTP {response.status_code}")
            return False

    except requests.exceptions.Timeout:
        duration = time.time() - start_time
        print(f"❌ Original analysis timed out after {duration:.2f} seconds")
        return False
    except Exception as e:
        print(f"❌ Error in original analysis: {str(e)}")
        return False


def test_specific_analysis_content():
    """Test specific analysis to understand content structure"""
    print("\n🔬 Testing Specific Analysis Content...")
    print("=" * 50)
    
    # Test with very specific parameters
    url = f"{RCA_API}/analyze?limit=1&min_confidence=0.8"
    
    try:
        response = requests.get(url, timeout=35)
        if response.status_code == 200:
            data = response.json()
            
            print("📊 **RAW RESPONSE STRUCTURE:**")
            print(json.dumps(data, indent=2, default=str))
            
            return True
        else:
            print(f"❌ Failed: HTTP {response.status_code}")
            return False
    except Exception as e:
        print(f"❌ Error: {str(e)}")
        return False


def main():
    """Main test function"""
    print("🧪 Enhanced AI Analysis Test Suite with Debug Information")
    print("=" * 70)
    print(f"🕒 Started at: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    print()

    # Run all tests
    tests_passed = 0
    total_tests = 6

    # Basic health and data tests
    test_service_health()

    if test_openai_detailed_status():
        tests_passed += 1

    if test_correlation_data():
        tests_passed += 1

    # AI Analysis tests
    if test_ai_analysis_optimized():
        tests_passed += 1

    # Test original for comparison
    if test_ai_analysis_original():
        tests_passed += 1

    # Test specific content structure
    if test_specific_analysis_content():
        tests_passed += 1

    # Final results
    print()
    print("📋 Test Results Summary:")
    print("=" * 50)
    print(f"✅ Tests Passed: {tests_passed}/{total_tests}")

    if tests_passed >= 5:
        print("🎉 All core functionality is working! System is ready.")
    elif tests_passed >= 3:
        print("⚠️  Most tests passed. Some issues may need attention.")
    else:
        print("❌ Multiple tests failed. System needs debugging.")

    print()
    print("🔍 **KEY FINDINGS:**")
    print("=" * 50)
    print("1. Check the detailed analysis sections above for AI response structure")
    print("2. Look for 'rca_explanation' content - this is what should display in Streamlit")
    print("3. If RCA explanations are empty/missing, that's the root cause")
    print("4. Performance metrics show if OpenAI API is actually being called")
    
    print()
    print("📡 Manual Verification Commands:")
    print("=" * 50)
    print("# Test with debug output:")
    print("curl 'http://localhost:5026/analyze?limit=1&min_confidence=0.8' | jq '.analyses[0].rca_explanation'")
    print("# Test OpenAI status:")
    print("curl 'http://localhost:5026/openai-status' | jq '.'")


if __name__ == "__main__":
    main()