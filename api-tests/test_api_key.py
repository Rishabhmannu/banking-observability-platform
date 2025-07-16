#!/usr/bin/env python3
"""
Comprehensive test script to verify OpenAI API key functionality
"""

import os
import sys
import asyncio
from dotenv import load_dotenv
from openai import OpenAI

# Add parent directory to path to import our modules
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))


def test_environment_variables():
    """Test 1: Check if environment variables are loaded"""
    print("=" * 50)
    print("TEST 1: Environment Variables")
    print("=" * 50)

    # Load .env file
    load_dotenv()

    # Check API key
    api_key = os.getenv("OPENAI_API_KEY")
    print(f"API Key present: {'✅ Yes' if api_key else '❌ No'}")
    if api_key:
        print(f"API Key length: {len(api_key)} characters")
        print(f"API Key starts with: {api_key[:7]}...")

    # Check model
    model = os.getenv("OPENAI_MODEL", "gpt-4")
    print(f"Model configured: {model}")

    return api_key is not None and len(api_key) > 20


def test_openai_client_creation():
    """Test 2: Test OpenAI client creation"""
    print("\n" + "=" * 50)
    print("TEST 2: OpenAI Client Creation")
    print("=" * 50)

    try:
        api_key = os.getenv("OPENAI_API_KEY")
        client = OpenAI(api_key=api_key)
        print("✅ OpenAI client created successfully")
        return client
    except Exception as e:
        print(f"❌ Failed to create OpenAI client: {e}")
        return None


def test_simple_chat_completion(client):
    """Test 3: Simple chat completion"""
    print("\n" + "=" * 50)
    print("TEST 3: Simple Chat Completion")
    print("=" * 50)

    if not client:
        print("❌ Cannot test - no client available")
        return False

    try:
        response = client.chat.completions.create(
            model=os.getenv("OPENAI_MODEL", "gpt-4"),
            messages=[
                {"role": "user", "content": "Hello, please respond with 'API key working'"}
            ],
            max_tokens=20
        )

        result = response.choices[0].message.content
        print(f"✅ Chat completion successful")
        print(f"Response: {result}")
        return True

    except Exception as e:
        print(f"❌ Chat completion failed: {e}")
        return False


def test_promql_conversion(client):
    """Test 4: PromQL conversion functionality"""
    print("\n" + "=" * 50)
    print("TEST 4: PromQL Conversion")
    print("=" * 50)

    if not client:
        print("❌ Cannot test - no client available")
        return False

    try:
        system_prompt = """You are an expert at converting natural language queries about banking systems to PromQL queries.
        
Available banking metrics:
- up{job="banking-services"} - Health status of banking services
- redis_connected_clients - Number of Redis connections

Convert the user query to a PromQL query. Return ONLY the PromQL query, nothing else."""

        response = client.chat.completions.create(
            model=os.getenv("OPENAI_MODEL", "gpt-4"),
            messages=[
                {"role": "system", "content": system_prompt},
                {"role": "user", "content": "How are the banking services?"}
            ],
            max_tokens=50,
            temperature=0.1
        )

        promql_query = response.choices[0].message.content.strip()
        print(f"✅ PromQL conversion successful")
        print(f"Query: How are the banking services?")
        print(f"PromQL: {promql_query}")
        return True

    except Exception as e:
        print(f"❌ PromQL conversion failed: {e}")
        return False


def test_our_openai_client():
    """Test 5: Test our custom OpenAI client"""
    print("\n" + "=" * 50)
    print("TEST 5: Custom OpenAI Client")
    print("=" * 50)

    try:
        from llm.openai_client import OpenAIClient

        # Create our client
        openai_client = OpenAIClient()
        print("✅ Custom OpenAI client created")

        # Test connection
        is_connected = openai_client.test_connection()
        print(
            f"Connection test: {'✅ Success' if is_connected else '❌ Failed'}")

        return is_connected

    except Exception as e:
        print(f"❌ Custom client test failed: {e}")
        return False


async def test_async_functions():
    """Test 6: Test async functions"""
    print("\n" + "=" * 50)
    print("TEST 6: Async Functions")
    print("=" * 50)

    try:
        from llm.openai_client import OpenAIClient

        openai_client = OpenAIClient()

        # Test async PromQL conversion
        promql_query = await openai_client.natural_language_to_promql("How are the banking services?")
        print(f"✅ Async PromQL conversion successful")
        print(f"Result: {promql_query}")

        # Test async explanation
        sample_data = {"status": "success", "data": {
            "result": [{"value": [1751948643, "1"]}]}}
        explanation = await openai_client.explain_metrics("How are the banking services?", sample_data)
        print(f"✅ Async explanation successful")
        print(f"Explanation: {explanation[:100]}...")

        return True

    except Exception as e:
        print(f"❌ Async functions failed: {e}")
        return False


def main():
    """Run all tests"""
    print("🔍 WATCHTOWER AI - OpenAI API Key Test Suite")
    print("=" * 50)

    # Test results
    results = {}

    # Test 1: Environment Variables
    results['env'] = test_environment_variables()

    # Test 2: Client Creation
    client = test_openai_client_creation()
    results['client'] = client is not None

    # Test 3: Simple Chat
    results['chat'] = test_simple_chat_completion(client)

    # Test 4: PromQL Conversion
    results['promql'] = test_promql_conversion(client)

    # Test 5: Custom Client
    results['custom'] = test_our_openai_client()

    # Test 6: Async Functions
    results['async'] = asyncio.run(test_async_functions())

    # Summary
    print("\n" + "=" * 50)
    print("SUMMARY")
    print("=" * 50)

    for test_name, passed in results.items():
        status = "✅ PASS" if passed else "❌ FAIL"
        print(f"{test_name.upper()}: {status}")

    all_passed = all(results.values())
    print(
        f"\nOverall: {'✅ ALL TESTS PASSED' if all_passed else '❌ SOME TESTS FAILED'}")

    if not all_passed:
        print("\n💡 TROUBLESHOOTING:")
        if not results['env']:
            print("- Check your .env file has OPENAI_API_KEY set")
        if not results['client']:
            print("- Verify your API key is valid")
        if not results['chat']:
            print("- Check your OpenAI account has credits")
        if not results['custom']:
            print("- Check if all Python packages are installed")


if __name__ == "__main__":
    main()
