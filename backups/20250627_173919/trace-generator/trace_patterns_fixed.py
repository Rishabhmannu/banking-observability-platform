import random
import time
from opentelemetry import trace
from opentelemetry.trace import Status, StatusCode
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.resources import Resource
from opentelemetry.exporter.otlp.proto.http.trace_exporter import OTLPSpanExporter
from opentelemetry.sdk.trace.export import BatchSpanProcessor


class TracePatterns:
    def __init__(self, tracer):
        self.main_tracer = tracer
        self.tracers = self._create_service_tracers()

    def _create_service_tracers(self):
        """Create separate tracers for each service to ensure proper service naming"""
        services = [
            "api-gateway",
            "auth-service",
            "transaction-service",
            "account-service",
            "fraud-detection",
            "notification-service"
        ]

        tracers = {}

        # Get the global tracer provider's exporter settings
        global_provider = trace.get_tracer_provider()

        for service in services:
            # Create a resource for this specific service
            resource = Resource.create({
                "service.name": service,
                "service.version": "1.0.0",
                "deployment.environment": "development"
            })

            # Create a new provider for this service
            provider = TracerProvider(resource=resource)

            # Use the same OTLP exporter configuration
            otlp_exporter = OTLPSpanExporter(
                endpoint="http://jaeger:4318/v1/traces",
                headers={}
            )

            processor = BatchSpanProcessor(otlp_exporter)
            provider.add_span_processor(processor)

            # Get a tracer from this provider
            tracers[service] = provider.get_tracer(service)

        return tracers

    def generate_successful_transaction(self, transaction_type="transfer"):
        """Generate a successful banking transaction trace"""
        # Use the api-gateway tracer
        with self.tracers["api-gateway"].start_as_current_span("api-gateway",
                                                               attributes={
                                                                   "http.method": "POST",
                                                                   "http.url": f"/api/transaction/{transaction_type}",
                                                                   "http.status_code": 200
                                                               }) as api_span:
            # Simulate API Gateway processing
            time.sleep(random.uniform(0.01, 0.03))  # 10-30ms

            # Auth service call
            with self.tracers["auth-service"].start_as_current_span("auth-service",
                                                                    attributes={
                                                                        "auth.method": "jwt",
                                                                        "user.id": f"user_{random.randint(1000, 9999)}"
                                                                    }) as auth_span:
                time.sleep(random.uniform(0.01, 0.02))  # 10-20ms
                auth_span.set_attribute("auth.result", "authorized")

            # Transaction service call
            with self.tracers["transaction-service"].start_as_current_span("transaction-service",
                                                                           attributes={
                                                                               "transaction.type": transaction_type,
                                                                               "transaction.amount": random.uniform(10, 1000),
                                                                               "transaction.currency": "USD"
                                                                           }) as txn_span:
                time.sleep(random.uniform(0.02, 0.04))  # 20-40ms

                # Account service for debit
                with self.tracers["account-service"].start_as_current_span("account-service-debit",
                                                                           attributes={
                                                                               "account.operation": "debit",
                                                                               "account.id": f"acc_{random.randint(1000, 9999)}"
                                                                           }) as debit_span:
                    time.sleep(random.uniform(0.015, 0.025))  # 15-25ms

                # Account service for credit
                with self.tracers["account-service"].start_as_current_span("account-service-credit",
                                                                           attributes={
                                                                               "account.operation": "credit",
                                                                               "account.id": f"acc_{random.randint(1000, 9999)}"
                                                                           }) as credit_span:
                    time.sleep(random.uniform(0.015, 0.025))  # 15-25ms

                # Fraud detection
                with self.tracers["fraud-detection"].start_as_current_span("fraud-check",
                                                                           attributes={
                                                                               "risk.score": random.uniform(0, 0.3)
                                                                           }) as fraud_span:
                    time.sleep(random.uniform(0.02, 0.03))  # 20-30ms
                    fraud_span.set_attribute("fraud.detected", False)

                # Notification service
                with self.tracers["notification-service"].start_as_current_span("notification-service",
                                                                                attributes={
                                                                                    "notification.type": "email",
                                                                                    "notification.status": "sent"
                                                                                }) as notif_span:
                    time.sleep(random.uniform(0.01, 0.02))  # 10-20ms

    def generate_failed_auth_transaction(self):
        """Generate a transaction that fails at auth"""
        with self.tracers["api-gateway"].start_as_current_span("api-gateway",
                                                               attributes={
                                                                   "http.method": "POST",
                                                                   "http.url": "/api/transaction/withdrawal",
                                                                   "http.status_code": 401
                                                               }) as api_span:
            time.sleep(random.uniform(0.01, 0.02))

            # Auth service call that fails
            with self.tracers["auth-service"].start_as_current_span("auth-service",
                                                                    attributes={
                                                                        "auth.method": "jwt"
                                                                    }) as auth_span:
                time.sleep(random.uniform(0.01, 0.02))
                auth_span.set_status(Status(StatusCode.ERROR, "Invalid token"))
                auth_span.set_attribute("auth.result", "unauthorized")
                auth_span.set_attribute("error", True)
                auth_span.set_attribute("error.type", "AuthenticationError")

            api_span.set_status(
                Status(StatusCode.ERROR, "Authentication failed"))

    def generate_slow_transaction(self):
        """Generate a transaction with slow database query"""
        with self.tracers["api-gateway"].start_as_current_span("api-gateway",
                                                               attributes={
                                                                   "http.method": "POST",
                                                                   "http.url": "/api/transaction/balance",
                                                                   "http.status_code": 200
                                                               }) as api_span:
            time.sleep(random.uniform(0.01, 0.02))

            # Normal auth
            with self.tracers["auth-service"].start_as_current_span("auth-service") as auth_span:
                time.sleep(random.uniform(0.01, 0.02))

            # Slow account service
            with self.tracers["account-service"].start_as_current_span("account-service",
                                                                       attributes={
                                                                           "db.statement": "SELECT * FROM accounts WHERE user_id = ?",
                                                                           "db.type": "sql"
                                                                       }) as db_span:
                # Simulate slow query
                time.sleep(random.uniform(1.5, 2.5))  # 1.5-2.5 seconds
                db_span.set_attribute("db.slow_query", True)
                db_span.set_attribute("db.rows_examined",
                                      random.randint(10000, 50000))

    def generate_failed_insufficient_funds(self):
        """Generate a transaction that fails due to insufficient funds"""
        with self.tracers["api-gateway"].start_as_current_span("api-gateway",
                                                               attributes={
                                                                   "http.method": "POST",
                                                                   "http.url": "/api/transaction/withdrawal",
                                                                   "http.status_code": 400
                                                               }) as api_span:
            time.sleep(random.uniform(0.01, 0.02))

            # Auth passes
            with self.tracers["auth-service"].start_as_current_span("auth-service") as auth_span:
                time.sleep(random.uniform(0.01, 0.02))
                auth_span.set_attribute("auth.result", "authorized")

            # Transaction service detects insufficient funds
            with self.tracers["transaction-service"].start_as_current_span("transaction-service",
                                                                           attributes={
                                                                               "transaction.type": "withdrawal",
                                                                               "transaction.amount": random.uniform(1000, 5000),
                                                                               "transaction.currency": "USD"
                                                                           }) as txn_span:
                time.sleep(random.uniform(0.02, 0.04))

                # Account service check
                with self.tracers["account-service"].start_as_current_span("balance-check",
                                                                           attributes={
                                                                               "account.balance": random.uniform(0, 500),
                                                                               "account.operation": "check_balance"
                                                                           }) as balance_span:
                    time.sleep(random.uniform(0.015, 0.025))
                    balance_span.set_attribute("sufficient_funds", False)

                txn_span.set_status(
                    Status(StatusCode.ERROR, "Insufficient funds"))
                txn_span.set_attribute("error", True)
                txn_span.set_attribute("error.type", "InsufficientFundsError")

            api_span.set_status(
                Status(StatusCode.ERROR, "Bad request: Insufficient funds"))
