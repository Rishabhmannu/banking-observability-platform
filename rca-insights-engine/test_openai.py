#!/usr/bin/env python3
"""
OpenAI API Test Script for RCA Insights Engine
This script comprehensively tests OpenAI API key loading and connectivity
"""

import os
import sys
from pathlib import Path
from dotenv import load_dotenv
import openai
import json
from datetime import datetime


def print_section(title):
    """Print a formatted section header"""
    print(f"\n{'='*60}")
    print(f" {title}")
    print(f"{'='*60}")


def print_result(test_name, status, details=""):
    """Print test result with consistent formatting"""
    status_symbol = "✅" if status else "❌"
    print(f"{status_symbol} {test_name}")
    if details:
        print(f"   {details}")


def test_environment_loading():
    """Test .env file loading"""
    print_section("ENVIRONMENT LOADING TEST")

    # Test different .env file locations
    env_locations = [
        Path("../.env"),  # Parent directory (project root)
        Path(".env"),     # Current directory
        Path("../../.env"),  # Two levels up
    ]

    for env_path in env_locations:
        abs_path = env_path.resolve()
        exists = abs_path.exists()
        print_result(f"Checking {abs_path}", exists)

        if exists:
            print(f"   File size: {abs_path.stat().st_size} bytes")
            try:
                with open(abs_path, 'r') as f:
                    content = f.read()
                    has_openai_key = 'OPENAI_API_KEY' in content
                    print_result(f"Contains OPENAI_API_KEY", has_openai_key)
                    if has_openai_key:
                        # Show the line (without revealing the key)
                        lines = content.split('\n')
                        for line in lines:
                            if 'OPENAI_API_KEY' in line and not line.strip().startswith('#'):
                                key_part = line.split('=')[1].strip(
                                    ' "\'') if '=' in line else "NOT_FOUND"
                                masked_key = key_part[:8] + "***" + key_part[-4:] if len(
                                    key_part) > 12 else "INVALID_FORMAT"
                                print(
                                    f"   Found: OPENAI_API_KEY = {masked_key}")
                                break
            except Exception as e:
                print(f"   Error reading file: {e}")

    return any(env_path.resolve().exists() for env_path in env_locations)


def test_dotenv_loading():
    """Test python-dotenv loading"""
    print_section("DOTENV LOADING TEST")

    # Test loading from different locations
    test_locations = [
        "../.env",
        ".env",
        "../../.env"
    ]

    for location in test_locations:
        try:
            loaded = load_dotenv(dotenv_path=location)
            print_result(f"load_dotenv('{location}')", loaded)

            if loaded:
                api_key = os.getenv('OPENAI_API_KEY', '')
                has_key = bool(api_key)
                print_result(f"OPENAI_API_KEY loaded", has_key)

                if has_key:
                    valid_format = api_key.startswith('sk-')
                    print_result(
                        f"API key format valid (starts with 'sk-')", valid_format)

                    if valid_format:
                        masked_key = api_key[:8] + "***" + api_key[-4:]
                        print(f"   Loaded key: {masked_key}")
                        return api_key
                    else:
                        print(
                            f"   Invalid format. Key starts with: '{api_key[:5]}...'")

        except Exception as e:
            print_result(f"load_dotenv('{location}')", False, f"Error: {e}")

    return None


def test_openai_api_key_format(api_key):
    """Test OpenAI API key format"""
    print_section("API KEY FORMAT TEST")

    if not api_key:
        print_result("API key provided", False, "No API key found")
        return False

    print_result("API key provided", True)

    # Check length
    valid_length = len(api_key) >= 40
    print_result(f"API key length >= 40 chars",
                 valid_length, f"Length: {len(api_key)}")

    # Check format
    valid_format = api_key.startswith('sk-')
    print_result("API key starts with 'sk-'", valid_format)

    # Check for common issues
    has_quotes = api_key.startswith('"') or api_key.startswith("'")
    print_result("No surrounding quotes", not has_quotes)

    has_spaces = ' ' in api_key
    print_result("No spaces in key", not has_spaces)

    return valid_format and valid_length and not has_quotes and not has_spaces


def test_openai_api_connection(api_key):
    """Test OpenAI API connectivity"""
    print_section("OPENAI API CONNECTION TEST")

    if not api_key:
        print_result("API key available", False, "Cannot test without API key")
        return False

    try:
        # Import the new OpenAI client
        from openai import OpenAI

        # Initialize the client with just the API key
        client = OpenAI(api_key=api_key)
        print_result("OpenAI client initialized", True)

        # Test with a simple request
        print("Testing API connection...")
        response = client.chat.completions.create(
            model="gpt-3.5-turbo",
            messages=[
                {"role": "system", "content": "You are a helpful assistant."},
                {"role": "user", "content": "Respond with exactly: 'API test successful'"}
            ],
            max_tokens=10,
            temperature=0
        )

        if response.choices and response.choices[0].message.content:
            content = response.choices[0].message.content.strip()
            print_result("API request successful",
                         True, f"Response: '{content}'")

            # Check usage information
            if hasattr(response, 'usage'):
                print(f"   Tokens used: {response.usage.total_tokens}")
                print(f"   Model: {response.model}")

            return True
        else:
            print_result("API request successful", False, "Empty response")
            return False

    except ImportError as e:
        print_result("OpenAI library import", False, f"Import error: {e}")
        return False

    except Exception as e:
        # Handle different types of OpenAI errors
        error_msg = str(e)

        if "authentication" in error_msg.lower() or "unauthorized" in error_msg.lower():
            print_result("API authentication", False,
                         f"Authentication failed: {e}")
        elif "rate limit" in error_msg.lower():
            print_result("API rate limit", False, f"Rate limit exceeded: {e}")
        elif "invalid request" in error_msg.lower():
            print_result("API request format", False, f"Invalid request: {e}")
        elif "quota" in error_msg.lower():
            print_result("API quota", False, f"Quota exceeded: {e}")
        else:
            print_result("API connection", False, f"Error: {e}")

        return False
      
def test_environment_variables():
    """Test current environment variables"""
    print_section("CURRENT ENVIRONMENT VARIABLES")

    env_vars = ['OPENAI_API_KEY', 'CORRELATION_ENGINE_URL', 'PROMETHEUS_URL']

    for var in env_vars:
        value = os.getenv(var, '')
        has_value = bool(value)
        print_result(f"{var} set", has_value)

        if has_value:
            if var == 'OPENAI_API_KEY':
                masked = value[:8] + "***" + \
                    value[-4:] if len(value) > 12 else "INVALID_FORMAT"
                print(f"   Value: {masked}")
            else:
                print(f"   Value: {value}")


def main():
    """Main test function"""
    print("🔍 OpenAI API Comprehensive Test")
    print(f"⏰ Test started at: {datetime.now()}")
    print(f"📂 Working directory: {os.getcwd()}")
    print(f"🐍 Python version: {sys.version}")

    # Test 1: Environment file loading
    env_file_exists = test_environment_loading()

    # Test 2: dotenv loading
    api_key = test_dotenv_loading()

    # Test 3: Current environment variables
    test_environment_variables()

    # Test 4: API key format
    if api_key:
        format_valid = test_openai_api_key_format(api_key)

        # Test 5: API connectivity
        if format_valid:
            connection_success = test_openai_api_connection(api_key)
        else:
            connection_success = False
    else:
        format_valid = False
        connection_success = False

    # Summary
    print_section("TEST SUMMARY")
    print_result("Environment file found", env_file_exists)
    print_result("API key loaded", bool(api_key))
    print_result("API key format valid", format_valid)
    print_result("API connection successful", connection_success)

    if connection_success:
        print("\n🎉 All tests passed! Your OpenAI API key is working correctly.")
        return 0
    else:
        print("\n❌ Some tests failed. Please check the issues above.")
        return 1


if __name__ == "__main__":
    exit_code = main()
    sys.exit(exit_code)
