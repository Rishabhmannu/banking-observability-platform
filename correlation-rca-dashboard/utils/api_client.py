"""
Clean API client for Event Correlation and RCA engines.
Handles all API communication with proper error handling.
"""

import requests
import logging
from typing import Optional, Dict, Any
import streamlit as st

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# API endpoints
CORRELATION_API = "http://localhost:5025"
RCA_API = "http://localhost:5026"


class APIClient:
    """Clean API client with robust error handling"""

    def __init__(self):
        self.correlation_base = CORRELATION_API
        self.rca_base = RCA_API
        # FIXED: Increased default timeout from 10 to 15 seconds
        self.timeout = 15
        # ENHANCED: Increased timeout for processing multiple correlations
        self.ai_timeout = 120  # AI analysis can take up to 2 minutes for detailed analysis

    def _make_request(self, url: str, timeout: int = None) -> Optional[Dict[Any, Any]]:
        """Make HTTP request with error handling"""
        try:
            timeout = timeout or self.timeout
            response = requests.get(url, timeout=timeout)
            response.raise_for_status()
            return response.json()
        except requests.exceptions.Timeout:
            logger.error(f"Timeout accessing {url} after {timeout} seconds")
            return None
        except requests.exceptions.ConnectionError:
            logger.error(f"Connection error accessing {url}")
            return None
        except requests.exceptions.HTTPError as e:
            logger.error(f"HTTP error accessing {url}: {e}")
            return None
        except Exception as e:
            logger.error(f"Unexpected error accessing {url}: {e}")
            return None

    def get_correlation_health(self) -> Optional[Dict[str, Any]]:
        """Get correlation engine health status"""
        url = f"{self.correlation_base}/health"
        return self._make_request(url, timeout=5)  # Health checks are quick

    def get_rca_health(self) -> Optional[Dict[str, Any]]:
        """Get RCA engine health status"""
        url = f"{self.rca_base}/health"
        return self._make_request(url, timeout=5)  # Health checks are quick

    def get_latest_correlations(self) -> Optional[Dict[str, Any]]:
        """Get latest correlation analysis"""
        url = f"{self.correlation_base}/correlations/latest"
        return self._make_request(url, timeout=12)  # Slightly longer for data retrieval

    def get_correlation_summary(self) -> Optional[Dict[str, Any]]:
        """Get correlation analysis summary"""
        url = f"{self.correlation_base}/correlations/summary"
        return self._make_request(url, timeout=12)  # Slightly longer for data retrieval

    def get_all_correlations(self, limit: int = 10) -> Optional[Dict[str, Any]]:
        """Get recent correlation analyses"""
        url = f"{self.correlation_base}/correlations?limit={limit}"
        return self._make_request(url, timeout=15)  # May take longer for multiple records

    def get_business_correlations(self) -> Optional[Dict[str, Any]]:
        """Get business-category correlations only"""
        url = f"{self.correlation_base}/correlations/business"
        return self._make_request(url, timeout=15)  # May take longer for filtered data

    def trigger_ai_analysis(self, min_confidence: float = None, max_confidence: float = None) -> Optional[Dict[str, Any]]:
        """Trigger AI-powered RCA analysis with confidence range parameters (up to 2 minutes)"""
        # Build URL with optional parameters
        url = f"{self.rca_base}/analyze"
        params = []
        
        if min_confidence is not None:
            params.append(f"min_confidence={min_confidence}")
        if max_confidence is not None:
            params.append(f"max_confidence={max_confidence}")
        
        if params:
            url += "?" + "&".join(params)
        
        # FIXED: Use longer timeout for AI analysis (40 seconds)
        return self._make_request(url, timeout=self.ai_timeout)

    def get_openai_status(self) -> Optional[Dict[str, Any]]:
        """Get detailed OpenAI status"""
        url = f"{self.rca_base}/openai-status"
        return self._make_request(url, timeout=8)  # Quick status check


# Singleton instance
api_client = APIClient()


def check_service_health() -> tuple[bool, bool]:
    """Check health of both services - returns (correlation_healthy, rca_healthy)"""
    correlation_health = api_client.get_correlation_health()
    rca_health = api_client.get_rca_health()

    correlation_healthy = correlation_health is not None and correlation_health.get(
        'status') == 'healthy'
    rca_healthy = rca_health is not None and rca_health.get(
        'status') == 'healthy'

    return correlation_healthy, rca_healthy


@st.cache_data(ttl=30)
def get_cached_correlations():
    """Get correlations with 30-second caching"""
    return api_client.get_latest_correlations()


@st.cache_data(ttl=60)
def get_cached_summary():
    """Get correlation summary with 60-second caching"""
    return api_client.get_correlation_summary()


@st.cache_data(ttl=120)
def get_cached_openai_status():
    """Get OpenAI status with 2-minute caching"""
    return api_client.get_openai_status()