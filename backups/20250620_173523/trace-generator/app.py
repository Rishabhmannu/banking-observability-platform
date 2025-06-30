from flask import Flask, jsonify, Response
from prometheus_client import Counter, Gauge, Histogram, generate_latest, REGISTRY
import threading
import time
import logging
import random
from datetime import datetime

# OpenTelemetry imports
from opentelemetry import trace
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor
from opentelemetry.exporter.otlp.proto.http.trace_exporter import OTLPSpanExporter
from opentelemetry.sdk.resources import Resource
from opentelemetry.instrumentation.flask import FlaskInstrumentor

# Import our trace patterns
from trace_patterns import TracePatterns

# Initialize Flask app
app = Flask(__name__)
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Prometheus metrics for monitoring the trace generator itself
traces_generated_total = Counter(
    'traces_generated_total',
    'Total number of traces generated',
    ['trace_type', 'service']
)

trace_generation_errors = Counter(
    'trace_generation_errors_total',
    'Total number of errors during trace generation',
    ['error_type']
)

active_trace_generation = Gauge(
    'active_trace_generation',
    'Whether trace generation is currently active'
)

trace_patterns_per_minute = Gauge(
    'trace_patterns_per_minute',
    'Number of trace patterns generated per minute',
    ['pattern_type']
)

# Initialize OpenTelemetry


def init_telemetry():
    """Initialize OpenTelemetry with Jaeger exporter"""
    # Create a resource to identify this service
    resource = Resource.create({
        "service.name": "trace-generator",
        "service.version": "1.0.0",
        "deployment.environment": "development"
    })

    # Create tracer provider
    provider = TracerProvider(resource=resource)

    # Configure OTLP exporter to send to Jaeger
    otlp_exporter = OTLPSpanExporter(
        endpoint="http://jaeger:4318/v1/traces",
        headers={}
    )

    # Add the exporter to the tracer provider
    processor = BatchSpanProcessor(otlp_exporter)
    provider.add_span_processor(processor)

    # Set the global tracer provider
    trace.set_tracer_provider(provider)

    # Instrument Flask
    FlaskInstrumentor().instrument_app(app)

    # Return a tracer for our use
    return trace.get_tracer(__name__)


# Initialize tracer
tracer = init_telemetry()
trace_patterns = TracePatterns(tracer)


class TraceGenerator:
    def __init__(self):
        self.is_running = False
        self.generation_thread = None
        self.patterns_per_minute = {
            'successful': 30,
            'failed_auth': 5,
            'slow': 3,
            'insufficient_funds': 5
        }

    def start(self):
        """Start generating traces"""
        if not self.is_running:
            self.is_running = True
            self.generation_thread = threading.Thread(
                target=self._generate_traces, daemon=True)
            self.generation_thread.start()
            active_trace_generation.set(1)
            logger.info("Trace generation started")

    def stop(self):
        """Stop generating traces"""
        self.is_running = False
        active_trace_generation.set(0)
        logger.info("Trace generation stopped")

    def _generate_traces(self):
        """Background thread that generates traces"""
        while self.is_running:
            try:
                # Generate different types of traces based on configured rates

                # Successful transactions (most common)
                if random.random() < (self.patterns_per_minute['successful'] / 60):
                    transaction_type = random.choice(
                        ['transfer', 'withdrawal', 'deposit', 'query'])
                    trace_patterns.generate_successful_transaction(
                        transaction_type)
                    traces_generated_total.labels(
                        trace_type='successful', service='banking').inc()

                # Failed auth (occasional)
                if random.random() < (self.patterns_per_minute['failed_auth'] / 60):
                    trace_patterns.generate_failed_auth_transaction()
                    traces_generated_total.labels(
                        trace_type='failed_auth', service='banking').inc()

                # Slow transactions (rare)
                if random.random() < (self.patterns_per_minute['slow'] / 60):
                    trace_patterns.generate_slow_transaction()
                    traces_generated_total.labels(
                        trace_type='slow', service='banking').inc()

                # Insufficient funds (occasional)
                if random.random() < (self.patterns_per_minute['insufficient_funds'] / 60):
                    trace_patterns.generate_failed_insufficient_funds()
                    traces_generated_total.labels(
                        trace_type='insufficient_funds', service='banking').inc()

                # Update metrics
                for pattern_type, rate in self.patterns_per_minute.items():
                    trace_patterns_per_minute.labels(
                        pattern_type=pattern_type).set(rate)

                # Sleep for a bit
                time.sleep(1)

            except Exception as e:
                logger.error(f"Error generating trace: {e}")
                trace_generation_errors.labels(
                    error_type=type(e).__name__).inc()


# Initialize generator
generator = TraceGenerator()


@app.route('/health', methods=['GET'])
def health():
    """Health check endpoint"""
    return jsonify({
        'status': 'healthy',
        'service': 'trace-generator',
        'timestamp': datetime.now().isoformat(),
        'trace_generation_active': generator.is_running
    })


@app.route('/metrics', methods=['GET'])
def metrics():
    """Prometheus metrics endpoint"""
    return Response(generate_latest(REGISTRY), mimetype='text/plain; version=0.0.4; charset=utf-8')


@app.route('/start', methods=['POST'])
def start_generation():
    """Start trace generation"""
    generator.start()
    return jsonify({
        'status': 'started',
        'message': 'Trace generation started'
    })


@app.route('/stop', methods=['POST'])
def stop_generation():
    """Stop trace generation"""
    generator.stop()
    return jsonify({
        'status': 'stopped',
        'message': 'Trace generation stopped'
    })


@app.route('/status', methods=['GET'])
def status():
    """Get current generation status"""
    return jsonify({
        'is_running': generator.is_running,
        'patterns_per_minute': generator.patterns_per_minute,
        'timestamp': datetime.now().isoformat()
    })


@app.route('/configure', methods=['POST'])
def configure():
    """Configure trace generation rates"""
    from flask import request
    data = request.json

    if 'patterns_per_minute' in data:
        generator.patterns_per_minute.update(data['patterns_per_minute'])

    return jsonify({
        'status': 'configured',
        'patterns_per_minute': generator.patterns_per_minute
    })


if __name__ == '__main__':
    logger.info("Starting Trace Generator Service on port 9414")
    # Start generating traces automatically
    generator.start()
    app.run(host='0.0.0.0', port=9414, debug=False)
