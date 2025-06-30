import os
import time
import random
import threading
import requests
import json
import logging

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger('load-generator')

# Configuration
API_GATEWAY_URL = os.environ.get('API_GATEWAY_URL', 'http://localhost:8080')
ENABLE_LOAD = os.environ.get('ENABLE_LOAD', 'true').lower() == 'true'
LOAD_INTENSITY = os.environ.get('LOAD_INTENSITY', 'medium')

# Intensity settings (requests per minute)
INTENSITY_SETTINGS = {
    'low': 60,     # 1 request per second
    'medium': 300,  # 5 requests per second
    'high': 600     # 10 requests per second
}

# User credentials for testing
TEST_USERS = [
    {"username": "john.doe", "password": "password123"},
    {"username": "jane.smith", "password": "password456"},
    {"username": "admin", "password": "admin123"}
]

# Account IDs for testing
ACCOUNT_IDS = [1, 2, 3]

# Transaction types
TRANSACTION_TYPES = ['DEPOSIT', 'WITHDRAWAL', 'PAYMENT', 'TRANSFER']

# Authentication tokens
auth_tokens = {}


def login_users():
    """Log in test users and store their tokens"""
    for user in TEST_USERS:
        try:
            response = requests.post(
                f"{API_GATEWAY_URL}/auth/login",
                json=user,
                timeout=5
            )
            if response.status_code == 200:
                data = response.json()
                auth_tokens[user['username']] = data['token']
                logger.info(f"Successfully logged in user: {user['username']}")
            else:
                logger.error(
                    f"Failed to log in user {user['username']}: {response.status_code}")
        except Exception as e:
            logger.error(f"Error logging in user {user['username']}: {e}")


def generate_random_transaction():
    """Generate a random transaction"""
    account_id = random.choice(ACCOUNT_IDS)
    transaction_type = random.choice(TRANSACTION_TYPES)

    # Amount based on transaction type
    if transaction_type == 'DEPOSIT':
        amount = random.uniform(10, 1000)
    elif transaction_type == 'WITHDRAWAL':
        amount = -random.uniform(10, 500)
    elif transaction_type == 'PAYMENT':
        amount = -random.uniform(20, 300)
    else:  # TRANSFER
        amount = -random.uniform(50, 1000)

    return {
        "accountId": account_id,
        "amount": round(amount, 2),
        "type": transaction_type
    }


def simulate_user_activity():
    """Simulate random user activity"""
    while ENABLE_LOAD:
        try:
            # Select random action
            action = random.choice([
                'get_accounts',
                'get_account_details',
                'create_transaction',
                'check_transaction_history',
                'check_fraud'
            ])

            # Select random user
            username = random.choice(list(auth_tokens.keys()))
            token = auth_tokens.get(username)

            if not token:
                continue

            # Perform action
            if action == 'get_accounts':
                response = requests.get(
                    f"{API_GATEWAY_URL}/accounts/accounts",
                    headers={"Authorization": f"Bearer {token}"},
                    timeout=5
                )
                logger.info(f"Get accounts: {response.status_code}")

            elif action == 'get_account_details':
                account_id = random.choice(ACCOUNT_IDS)
                response = requests.get(
                    f"{API_GATEWAY_URL}/accounts/accounts/{account_id}",
                    headers={"Authorization": f"Bearer {token}"},
                    timeout=5
                )
                logger.info(
                    f"Get account details for {account_id}: {response.status_code}")

            elif action == 'create_transaction':
                transaction = generate_random_transaction()
                response = requests.post(
                    f"{API_GATEWAY_URL}/transactions/transactions",
                    json=transaction,
                    headers={"Authorization": f"Bearer {token}"},
                    timeout=5
                )
                logger.info(f"Create transaction: {response.status_code}")

                # Check for fraud if transaction created successfully
                if response.status_code == 201:
                    transaction_data = response.json()
                    requests.post(
                        f"{API_GATEWAY_URL}/fraud/check",
                        json=transaction_data,
                        headers={"Authorization": f"Bearer {token}"},
                        timeout=5
                    )

            elif action == 'check_transaction_history':
                response = requests.get(
                    f"{API_GATEWAY_URL}/transactions/transactions",
                    headers={"Authorization": f"Bearer {token}"},
                    timeout=5
                )
                logger.info(
                    f"Check transaction history: {response.status_code}")

            elif action == 'check_fraud':
                response = requests.get(
                    f"{API_GATEWAY_URL}/fraud/alerts",
                    headers={"Authorization": f"Bearer {token}"},
                    timeout=5
                )
                logger.info(f"Check fraud alerts: {response.status_code}")

        except Exception as e:
            logger.error(f"Error during load testing: {e}")

        # Sleep based on load intensity
        sleep_time = 60 / INTENSITY_SETTINGS.get(LOAD_INTENSITY, 300)
        time.sleep(sleep_time)


def main():
    logger.info(f"Starting load generator with intensity: {LOAD_INTENSITY}")

    if not ENABLE_LOAD:
        logger.info(
            "Load generation is disabled. Set ENABLE_LOAD=true to enable.")
        while True:
            time.sleep(60)

    # Wait for API Gateway to be ready
    max_retries = 30
    retry_count = 0

    while retry_count < max_retries:
        try:
            response = requests.get(f"{API_GATEWAY_URL}/health", timeout=2)
            if response.status_code == 200:
                logger.info("API Gateway is ready")
                break
        except:
            pass

        logger.info(
            f"Waiting for API Gateway to be ready... ({retry_count}/{max_retries})")
        retry_count += 1
        time.sleep(5)

    if retry_count >= max_retries:
        logger.error("API Gateway did not become ready in time. Exiting.")
        return

    # Login users
    login_users()

    if not auth_tokens:
        logger.error("Failed to log in any users. Exiting.")
        return

    # Start load generation
    simulate_user_activity()


if __name__ == "__main__":
    main()
