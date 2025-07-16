from flask import Flask, jsonify, request
import requests
import json
import time
import logging
from datetime import datetime, timedelta
from typing import Dict, List, Optional
import os
from prometheus_client import Counter, Histogram, Gauge, generate_latest
from openai import OpenAI
from dotenv import load_dotenv
import signal
import threading

# Configure logging FIRST
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Load environment variables from .env file in project root (for local testing)
# In Docker, environment variables are passed directly
if os.path.exists('../.env'):
    load_dotenv(dotenv_path='../.env')
    logger.info("Loaded .env file from parent directory")
elif os.path.exists('.env'):
    load_dotenv(dotenv_path='.env')
    logger.info("Loaded .env file from current directory")
else:
    logger.info("No .env file found, using environment variables from system")

app = Flask(__name__)

# Prometheus metrics for self-monitoring
llm_api_requests_total = Counter(
    'llm_api_requests_total',
    'Total LLM API requests',
    ['status']
)
rca_analysis_duration = Histogram(
    'rca_analysis_duration_seconds',
    'Time spent on RCA analysis'
)
rca_explanations_generated = Counter(
    'rca_explanations_generated_total',
    'Total RCA explanations generated',
    ['explanation_type']
)
openai_api_errors = Counter(
    'openai_api_errors_total',
    'Total OpenAI API errors',
    ['error_type']
)


class RCAInsightsEngine:
    def __init__(self):
        self.correlation_engine_url = os.getenv(
            'CORRELATION_ENGINE_URL', 'http://event-correlation-engine:5025')
        self.prometheus_url = os.getenv(
            'PROMETHEUS_URL', 'http://prometheus:9090')
        self.openai_api_key = os.getenv('OPENAI_API_KEY', '')
        self.openai_configured = False
        self.openai_test_passed = False
        self.openai_client = None

        # Initialize OpenAI client with proper error handling
        self._initialize_openai()

        # System context for banking domain
        self.system_context = """You are an expert system administrator and data analyst specializing in banking microservices architecture. 
        You analyze metric correlations and provide clear, actionable root cause explanations.
        
        Banking System Context:
        - 18+ microservices: API Gateway, Auth, Transaction, Account, Fraud Detection, Notification
        - Infrastructure: Redis cache, MySQL/PostgreSQL databases, RabbitMQ/Kafka messaging
        - Monitoring: Prometheus metrics, container resource monitoring, DDoS detection
        - Performance targets: <300ms response time, >99% uptime, >80% cache hit ratio
        
        Always provide:
        1. Root cause explanation in simple terms
        2. Business impact assessment
        3. Specific remediation steps
        4. Prevention recommendations"""

    def _initialize_openai(self):
        """Initialize OpenAI client with comprehensive error handling"""
        try:
            if not self.openai_api_key:
                logger.warning(
                    "OpenAI API key not found in environment variables")
                return

            if not self.openai_api_key.startswith('sk-'):
                logger.error(
                    "Invalid OpenAI API key format (should start with 'sk-')")
                openai_api_errors.labels(error_type='invalid_key_format').inc()
                return

            # Initialize the OpenAI client
            self.openai_client = OpenAI(api_key=self.openai_api_key)
            self.openai_configured = True
            logger.info("OpenAI client initialized successfully")

            # Test the API key with a simple request
            self._test_openai_api()

        except Exception as e:
            logger.error(f"Error initializing OpenAI client: {e}")
            openai_api_errors.labels(error_type='initialization_error').inc()

    def _test_openai_api(self):
        """Test OpenAI API connectivity and validity"""
        try:
            logger.info("Testing OpenAI API connectivity...")

            response = self.openai_client.chat.completions.create(
                model="gpt-4o",
                messages=[
                    {"role": "system", "content": "You are a helpful assistant."},
                    {"role": "user", "content": "Test message - respond with 'API test successful'"}
                ],
                max_tokens=10,
                temperature=0
            )

            if response.choices[0].message.content:
                self.openai_test_passed = True
                logger.info("OpenAI API test successful")
                llm_api_requests_total.labels(status='success').inc()
            else:
                logger.error("OpenAI API test failed - empty response")
                openai_api_errors.labels(error_type='empty_response').inc()

        except Exception as e:
            error_msg = str(e)

            if "authentication" in error_msg.lower() or "unauthorized" in error_msg.lower():
                logger.error(
                    "OpenAI API authentication failed - invalid API key")
                openai_api_errors.labels(
                    error_type='authentication_error').inc()
                self.openai_configured = False
            elif "rate limit" in error_msg.lower():
                logger.warning("OpenAI API rate limit reached during test")
                openai_api_errors.labels(error_type='rate_limit').inc()
                self.openai_test_passed = True  # Still consider configured
            else:
                logger.error(f"OpenAI API test error: {e}")
                openai_api_errors.labels(error_type='api_error').inc()

    def get_correlation_events(self) -> List[Dict]:
        """Get recent correlation events from the Event Correlation Engine"""
        try:
            response = requests.get(
                f"{self.correlation_engine_url}/correlations/latest", timeout=10)
            if response.status_code == 200:
                data = response.json()
                return data.get('correlations', [])
            return []
        except Exception as e:
            logger.error(f"Error fetching correlation events: {e}")
            return []

    def get_metric_context(self, metric_name: str) -> Dict:
        """Get current context for a specific metric"""
        try:
            # Get current value
            query = f"query?query={metric_name}"
            response = requests.get(
                f"{self.prometheus_url}/api/v1/{query}", timeout=5)

            current_value = "unknown"
            if response.status_code == 200:
                data = response.json()
                if data['status'] == 'success' and data['data']['result']:
                    current_value = data['data']['result'][0]['value'][1]

            # Get metric interpretation
            interpretation = self._interpret_metric(metric_name, current_value)

            return {
                'metric': metric_name,
                'current_value': current_value,
                'interpretation': interpretation,
                'timestamp': datetime.now().isoformat()
            }

        except Exception as e:
            logger.error(f"Error getting context for {metric_name}: {e}")
            return {'metric': metric_name, 'error': str(e)}

    def _interpret_metric(self, metric_name: str, value: str) -> str:
        """Interpret metric values in banking context"""
        try:
            val = float(value)

            if 'cpu_usage' in metric_name:
                if val > 0.8:
                    return f"HIGH CPU usage at {val:.1%} (Critical: >80%)"
                elif val > 0.6:
                    return f"ELEVATED CPU usage at {val:.1%} (Warning: >60%)"
                else:
                    return f"NORMAL CPU usage at {val:.1%}"

            elif 'memory_usage' in metric_name:
                if val > 0.85:
                    return f"HIGH memory usage at {val:.1%} (Critical: >85%)"
                elif val > 0.7:
                    return f"ELEVATED memory usage at {val:.1%} (Warning: >70%)"
                else:
                    return f"NORMAL memory usage at {val:.1%}"

            elif 'cache_hit_ratio' in metric_name:
                if val < 0.6:
                    return f"POOR cache performance at {val:.1%} hit ratio (Target: >80%)"
                elif val < 0.8:
                    return f"DEGRADED cache performance at {val:.1%} hit ratio"
                else:
                    return f"GOOD cache performance at {val:.1%} hit ratio"

            elif 'up' in metric_name:
                return "SERVICE UP" if val == 1 else "SERVICE DOWN"

            elif 'response_time' in metric_name or 'duration' in metric_name:
                if val > 2.0:
                    return f"SLOW response time at {val:.2f}s (Target: <0.3s)"
                elif val > 0.5:
                    return f"DEGRADED response time at {val:.2f}s"
                else:
                    return f"GOOD response time at {val:.2f}s"

            else:
                return f"Current value: {value}"

        except:
            return f"Current value: {value}"

    def generate_rca_explanation(self, correlation_event: Dict) -> Dict:
        """Generate RCA explanation using LLM - FIXED VERSION"""
        try:
            with rca_analysis_duration.time():
                start_time = time.time()

                # Get context for both metrics
                metric1_context = self.get_metric_context(correlation_event['metric1'])
                metric2_context = self.get_metric_context(correlation_event['metric2'])

                # Build context for LLM
                context = self._build_llm_context(correlation_event, metric1_context, metric2_context)

                # Generate explanation
                if self.openai_configured and self.openai_test_passed:
                    explanation = self._call_openai_api(context)
                    openai_used = True
                else:
                    explanation = self._generate_mock_explanation(correlation_event, metric1_context, metric2_context)
                    openai_used = False

                rca_explanations_generated.labels(explanation_type='correlation').inc()

                total_time = time.time() - start_time
                logger.info(f"RCA explanation generated in {total_time:.2f}s")

                return {
                    'correlation_event': correlation_event,
                    'metric1_context': metric1_context,
                    'metric2_context': metric2_context,
                    'rca_explanation': explanation,
                    'openai_used': openai_used,
                    'analysis_time_seconds': round(total_time, 2),
                    'timestamp': datetime.now().isoformat()
                }

        except Exception as e:
            logger.error(f"Error generating RCA explanation: {e}")
            return {
                'error': str(e),
                'correlation_event': correlation_event,
                'timestamp': datetime.now().isoformat()
            }

    def _build_llm_context(self, correlation_event: Dict, metric1_context: Dict, metric2_context: Dict) -> str:
        """Build enhanced context string for LLM with metric names and values"""
        correlation_type = correlation_event['type']
        confidence = correlation_event['confidence']
        
        # Extract metric names and current values for better AI understanding
        metric1_name = metric1_context['metric']
        metric1_value = metric1_context.get('current_value', 'unknown')
        metric2_name = metric2_context['metric']
        metric2_value = metric2_context.get('current_value', 'unknown')
        
        # Format metric context with names and values
        metric1_display = f"{metric1_name}: {metric1_value}"
        metric2_display = f"{metric2_name}: {metric2_value}"
        
        # Add unit context for better AI understanding
        if 'memory_usage_mb' in metric1_name and metric1_value != 'unknown':
            try:
                metric1_display = f"{metric1_name}: {float(metric1_value):.1f} MB"
            except:
                pass
        elif 'cpu_usage_percent' in metric1_name and metric1_value != 'unknown':
            try:
                metric1_display = f"{metric1_name}: {float(metric1_value):.1f}%"
            except:
                pass
        elif 'cache_hit_ratio' in metric1_name and metric1_value != 'unknown':
            try:
                metric1_display = f"{metric1_name}: {float(metric1_value):.1%}"
            except:
                pass
        
        if 'memory_usage_mb' in metric2_name and metric2_value != 'unknown':
            try:
                metric2_display = f"{metric2_name}: {float(metric2_value):.1f} MB"
            except:
                pass
        elif 'cpu_usage_percent' in metric2_name and metric2_value != 'unknown':
            try:
                metric2_display = f"{metric2_name}: {float(metric2_value):.1f}%"
            except:
                pass
        elif 'cache_hit_ratio' in metric2_name and metric2_value != 'unknown':
            try:
                metric2_display = f"{metric2_name}: {float(metric2_value):.1%}"
            except:
                pass

        context = f"""
CORRELATION ANALYSIS REPORT
===========================

Correlation Detected: {correlation_type.upper()} correlation (confidence: {confidence:.2f})

METRIC ANALYSIS:
Primary Metric: {metric1_display}
- Context: {metric1_context['interpretation']}
- Description: {metric1_name.replace('_', ' ').title()}

Secondary Metric: {metric2_display}  
- Context: {metric2_context['interpretation']}
- Description: {metric2_name.replace('_', ' ').title()}

CORRELATION DETAILS:
- Correlation coefficient: {correlation_event['correlation_coefficient']:.3f}
- Statistical significance: p-value = {correlation_event['p_value']:.4f}
- Sample size: {correlation_event['sample_size']} data points

BUSINESS CONTEXT:
This correlation was detected in our banking microservices monitoring system. The metrics represent:
- {metric1_name}: {self._get_metric_business_context(metric1_name)}
- {metric2_name}: {self._get_metric_business_context(metric2_name)}

ANALYSIS REQUEST:
Based on this correlation between {metric1_display} and {metric2_display}, provide:
1. **Root Cause Analysis:** Why are these metrics correlated?
2. **Business Impact Assessment:** How does this affect banking operations?
3. **Specific Remediation Steps:** Immediate actions to take
4. **Prevention Recommendations:** Long-term measures to prevent issues
"""
        return context

    def _get_metric_business_context(self, metric_name: str) -> str:
        """Get business context description for metrics"""
        if 'transaction' in metric_name:
            return "Banking transaction processing performance and volume"
        elif 'memory_usage' in metric_name:
            return "Container memory consumption affecting service performance"
        elif 'cpu_usage' in metric_name:
            return "Container CPU utilization impacting processing capacity"
        elif 'cache_hit_ratio' in metric_name:
            return "Redis cache efficiency affecting response times"
        elif 'db_' in metric_name:
            return "Database performance and connection utilization"
        elif 'ddos' in metric_name:
            return "DDoS detection and security threat assessment"
        elif 'messages' in metric_name:
            return "Message queue processing and workflow coordination"
        elif 'response_time' in metric_name or 'duration' in metric_name:
            return "Service response time and user experience"
        else:
            return "System monitoring metric"

    def _call_openai_api(self, context: str) -> str:
        """Call OpenAI API for RCA explanation - FIXED VERSION"""
        try:
            logger.info("Calling OpenAI API for RCA analysis...")

            # FIXED: Removed invalid timeout parameter
            response = self.openai_client.chat.completions.create(
                model="gpt-4o",
                messages=[
                    {"role": "system", "content": self.system_context},
                    {"role": "user", "content": context}
                ],
                max_tokens=800,
                temperature=0.3
            )

            if response.choices and response.choices[0].message.content:
                llm_api_requests_total.labels(status='success').inc()
                logger.info("OpenAI API call successful")
                return response.choices[0].message.content.strip()
            else:
                logger.error("OpenAI API returned empty response")
                llm_api_requests_total.labels(status='error').inc()
                openai_api_errors.labels(error_type='empty_response').inc()
                return "Error: OpenAI API returned empty response"

        except Exception as e:
            error_msg = str(e)
            llm_api_requests_total.labels(status='error').inc()

            if "authentication" in error_msg.lower() or "unauthorized" in error_msg.lower():
                logger.error("OpenAI API authentication failed")
                openai_api_errors.labels(error_type='authentication_error').inc()
                return "Error: OpenAI API authentication failed - please check your API key"
            elif "rate limit" in error_msg.lower():
                logger.warning("OpenAI API rate limit exceeded")
                openai_api_errors.labels(error_type='rate_limit').inc()
                return "Error: OpenAI API rate limit exceeded - please try again later"
            else:
                logger.error(f"OpenAI API error: {e}")
                openai_api_errors.labels(error_type='api_error').inc()
                return f"Error: OpenAI API error - {e}"

    def _generate_mock_explanation(self, correlation_event: Dict, metric1_context: Dict, metric2_context: Dict) -> str:
        """Generate mock explanation when OpenAI API is not available"""
        correlation_type = correlation_event['type']
        confidence = correlation_event['confidence']

        return f"""
ROOT CAUSE ANALYSIS (Mock Response - OpenAI API not available)
============================================================

CORRELATION SUMMARY:
A {correlation_type} correlation (confidence: {confidence:.2f}) was detected between:
- {metric1_context['metric']}: {metric1_context['interpretation']}
- {metric2_context['metric']}: {metric2_context['interpretation']}

LIKELY ROOT CAUSE:
Resource contention or cascading performance impact between related system components.

BUSINESS IMPACT:
- Potential customer experience degradation
- Risk of service performance issues
- Possible transaction processing delays

RECOMMENDED ACTIONS:
1. Monitor both metrics closely for continued correlation
2. Check resource allocation for affected services
3. Review recent deployments or configuration changes
4. Scale resources if performance thresholds are exceeded

PREVENTION:
- Implement proactive monitoring alerts
- Review service resource limits
- Consider implementing circuit breakers
- Schedule regular performance reviews

Note: Configure valid OPENAI_API_KEY in .env file for detailed AI-powered analysis.
"""


# Initialize the RCA engine
rca_engine = RCAInsightsEngine()


@app.route('/health')
def health_check():
    """Health check endpoint with enhanced OpenAI status reporting"""

    # Determine OpenAI status
    openai_status = "not_configured"
    if rca_engine.openai_configured:
        if rca_engine.openai_test_passed:
            openai_status = "configured_and_tested"
        else:
            openai_status = "configured_but_failed_test"

    # Get API key status
    api_key_status = "not_provided"
    if rca_engine.openai_api_key:
        if rca_engine.openai_api_key.startswith('sk-'):
            api_key_status = "valid_format"
        else:
            api_key_status = "invalid_format"

    return jsonify({
        'status': 'healthy',
        'service': 'rca-insights-engine',
        'version': '2.0.0',  # Updated version
        'model': 'gpt-4o',   # Current AI model
        'correlation_engine_connected': _check_correlation_engine_connection(),
        'prometheus_connected': _check_prometheus_connection(),

        # Enhanced OpenAI status
        'openai_status': openai_status,
        'openai_details': {
            'configured': rca_engine.openai_configured,
            'test_passed': rca_engine.openai_test_passed,
            'api_key_status': api_key_status,
            'model': 'gpt-4o'
        },

        # Performance info
        'performance': {
            'max_correlations_per_request': 20,
            'default_correlation_limit': 5,
            'max_analysis_time_seconds': 25,
            'individual_timeout_seconds': 10
        },

        'timestamp': datetime.now().isoformat()
    })


@app.route('/openai-status')
def openai_status():
    """Get detailed OpenAI API status"""

    # Determine detailed status
    if not rca_engine.openai_api_key:
        status_message = "No OpenAI API key provided. Set OPENAI_API_KEY environment variable."
        recommendations = [
            "Add OPENAI_API_KEY to your .env file", "Restart the RCA service"]
    elif not rca_engine.openai_api_key.startswith('sk-'):
        status_message = "Invalid OpenAI API key format. Keys should start with 'sk-'"
        recommendations = ["Check your API key format",
                           "Ensure no extra spaces or characters"]
    elif not rca_engine.openai_configured:
        status_message = "OpenAI client initialization failed"
        recommendations = ["Check API key validity",
                           "Check network connectivity", "Review service logs"]
    elif not rca_engine.openai_test_passed:
        status_message = "OpenAI API test call failed"
        recommendations = ["Verify API key permissions",
                           "Check OpenAI service status", "Review rate limits"]
    else:
        status_message = "OpenAI API is properly configured and tested"
        recommendations = ["System ready for AI-powered analysis"]

    return jsonify({
        'configured': rca_engine.openai_configured,
        'test_passed': rca_engine.openai_test_passed,
        'api_key_format_valid': rca_engine.openai_api_key.startswith('sk-') if rca_engine.openai_api_key else False,
        'model': 'gpt-4o',
        'status_message': status_message,
        'recommendations': recommendations,
        'last_test_time': datetime.now().isoformat()
    })


@app.route('/analyze')
def analyze_correlations():
    """Analyze recent correlations and generate RCA explanations - ENHANCED VERSION"""
    try:
        # Get request parameters for confidence range filtering
        min_confidence = float(request.args.get('min_confidence', 0.7))
        max_confidence = float(request.args.get('max_confidence', 0.95))

        # Validate confidence range
        min_confidence = max(0.0, min(min_confidence, 1.0))  # Enforce range: 0.0-1.0
        max_confidence = max(0.0, min(max_confidence, 1.0))  # Enforce range: 0.0-1.0
        
        # Ensure max >= min
        if max_confidence < min_confidence:
            max_confidence = min_confidence + 0.1
            max_confidence = min(max_confidence, 1.0)

        logger.info(f"Starting RCA analysis with confidence range: {min_confidence:.2f} - {max_confidence:.2f}")

        # Get recent correlation events
        correlation_events = rca_engine.get_correlation_events()

        if not correlation_events:
            return jsonify({'message': 'No correlation events to analyze'})

        # Filter correlations by confidence range
        filtered_events = []
        for event in correlation_events:
            confidence = event.get('confidence', 0)
            if min_confidence <= confidence <= max_confidence:
                filtered_events.append(event)

        # Sort by confidence (highest first) - no limit, use all in range
        filtered_events.sort(key=lambda x: x.get('confidence', 0), reverse=True)
        events_to_analyze = filtered_events

        logger.info(f"Filtered {len(correlation_events)} events to {len(events_to_analyze)} within confidence range {min_confidence:.2f}-{max_confidence:.2f}")

        if not events_to_analyze:
            return jsonify({
                'message': f'No correlations found in confidence range {min_confidence:.2f}-{max_confidence:.2f}',
                'suggestion': f'Try expanding range: most correlations are 0.82-0.85 or 0.99+',
                'total_correlations': len(correlation_events),
                'filtered_correlations': 0,
                'criteria': {
                    'min_confidence': min_confidence,
                    'max_confidence': max_confidence
                }
            })

        # Generate RCA explanations for filtered events
        analyses = []
        start_time = time.time()

        for i, event in enumerate(events_to_analyze, 1):
            logger.info(f"Analyzing correlation {i}/{len(events_to_analyze)}: {event.get('metric1', 'unknown')} ↔ {event.get('metric2', 'unknown')}")

            try:
                analysis = rca_engine.generate_rca_explanation(event)
                if analysis:
                    analyses.append(analysis)
                else:
                    logger.warning(f"Failed to generate analysis for correlation {i}")

            except Exception as e:
                logger.error(f"Error analyzing correlation {i}: {e}")
                continue

        total_time = time.time() - start_time
        logger.info(f"RCA analysis completed: {len(analyses)} analyses generated in {total_time:.1f}s")

        return jsonify({
            'total_correlations': len(correlation_events),
            'filtered_correlations': len(events_to_analyze),
            'analyses_generated': len(analyses),
            'analyses': analyses,
            'performance': {
                'total_time_seconds': round(total_time, 2),
                'average_time_per_analysis': round(total_time / max(1, len(analyses)), 2),
                'timeout_occurred': False
            },
            'criteria': {
                'min_confidence': min_confidence,
                'max_confidence': max_confidence
            },
            'openai_status': {
                'configured': rca_engine.openai_configured,
                'test_passed': rca_engine.openai_test_passed
            },
            'timestamp': datetime.now().isoformat()
        })

    except Exception as e:
        logger.error(f"Error in analyze endpoint: {e}")
        return jsonify({'error': str(e)}), 500


@app.route('/metrics')
def metrics():
    """Prometheus metrics endpoint"""
    return generate_latest(), 200, {'Content-Type': 'text/plain'}


def _check_correlation_engine_connection():
    """Check if Event Correlation Engine is accessible"""
    try:
        response = requests.get(
            f"{rca_engine.correlation_engine_url}/health", timeout=5)
        return response.status_code == 200
    except:
        return False


def _check_prometheus_connection():
    """Check if Prometheus is accessible"""
    try:
        response = requests.get(
            f"{rca_engine.prometheus_url}/api/v1/targets", timeout=5)
        return response.status_code == 200
    except:
        return False


if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5026, debug=False)