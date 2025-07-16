"""
🔍 Banking Service Correlation & AI Insights Dashboard
Main entry point - imports from modular components
"""

import streamlit as st
import time
import pandas as pd
import plotly.express as px
from datetime import datetime

# Import modular components
from utils.api_client import api_client, check_service_health, get_cached_correlations, get_cached_summary
from components.correlations_display import display_correlation_analysis
from components.ai_analysis_display import display_ai_insights_interface
from components.visualization_display import display_interactive_visualizations
from components.report_generator import display_professional_reports
from utils.data_formatter import format_confidence, format_business_impact

# FIXED: Import CSS loader from the correct location
from utils.style_loader import load_custom_css, apply_dark_theme

# Page configuration
st.set_page_config(
    page_title="🔍 Banking Correlation Dashboard",
    page_icon="🔍",
    layout="wide",
    initial_sidebar_state="expanded"
)

# FIXED: Load custom CSS properly
load_custom_css()
apply_dark_theme()


def display_service_health():
    """Display service health status in sidebar with enhanced styling"""
    st.sidebar.subheader("🏥 Service Health")

    correlation_healthy, rca_healthy = check_service_health()

    if correlation_healthy:
        st.sidebar.markdown(
            '<p class="health-good">✅ Correlation Engine: Healthy</p>', unsafe_allow_html=True)
    else:
        st.sidebar.markdown(
            '<p class="health-bad">❌ Correlation Engine: Offline</p>', unsafe_allow_html=True)

    if rca_healthy:
        st.sidebar.markdown(
            '<p class="health-good">✅ RCA Engine: Healthy</p>', unsafe_allow_html=True)
    else:
        st.sidebar.markdown(
            '<p class="health-bad">❌ RCA Engine: Offline</p>', unsafe_allow_html=True)

    # Add overall system status
    overall_status = "🟢 All Systems Operational" if (correlation_healthy and rca_healthy) else "🟡 Partial System Availability" if (
        correlation_healthy or rca_healthy) else "🔴 System Offline"
    status_color = "#00d4aa" if (correlation_healthy and rca_healthy) else "#ffd93d" if (
        correlation_healthy or rca_healthy) else "#ff6b6b"

    st.sidebar.markdown(
        f'<div style="background: {status_color}20; color: {status_color}; padding: 0.8rem; border-radius: 8px; margin: 1rem 0; font-weight: bold; text-align: center;">{overall_status}</div>', unsafe_allow_html=True)

    return correlation_healthy, rca_healthy


def display_key_metrics(correlations_data, summary_data):
    """Display key metrics in the top row"""
    col1, col2, col3, col4 = st.columns(4)

    with col1:
        total_correlations = 0
        if summary_data and 'total_correlations' in summary_data:
            total_correlations = summary_data['total_correlations']

        st.markdown(f'''
        <div class="metric-card">
            <h3>📊 Total Correlations</h3>
            <h2>{total_correlations}</h2>
        </div>
        ''', unsafe_allow_html=True)

    with col2:
        latest_confidence = "N/A"
        if correlations_data and correlations_data.get('correlations'):
            latest_confidence = f"{correlations_data['correlations'][0]['confidence']:.1%}"

        st.markdown(f'''
        <div class="metric-card">
            <h3>🎯 Latest Confidence</h3>
            <h2>{latest_confidence}</h2>
        </div>
        ''', unsafe_allow_html=True)

    with col3:
        high_confidence_count = 0
        if summary_data and 'by_confidence' in summary_data:
            high_confidence_count = summary_data['by_confidence'].get(
                'high_confidence_80_plus', 0)

        st.markdown(f'''
        <div class="metric-card">
            <h3>⭐ High Confidence</h3>
            <h2>{high_confidence_count}</h2>
        </div>
        ''', unsafe_allow_html=True)

    with col4:
        current_time = datetime.now().strftime("%H:%M:%S")
        st.markdown(f'''
        <div class="metric-card">
            <h3>🕒 Last Update</h3>
            <h2>{current_time}</h2>
        </div>
        ''', unsafe_allow_html=True)


def display_correlation_summary(summary_data):
    """Display correlation summary with charts - ADDED MISSING FUNCTION"""
    if not summary_data:
        st.info("📊 No summary data available.")
        return

    st.subheader("📊 Correlation Summary & Analytics")

    col1, col2 = st.columns(2)

    with col1:
        # Total correlations metric
        total = summary_data.get('total_correlations', 0)
        st.metric("Total Correlations Detected", total)

        # Confidence breakdown
        confidence_data = summary_data.get('by_confidence', {})
        if confidence_data:
            high_conf = confidence_data.get('high_confidence_80_plus', 0)
            medium_conf = confidence_data.get('medium_confidence_60_80', 0)
            low_conf = confidence_data.get('low_confidence_below_60', 0)

            st.metric("High Confidence (>80%)", high_conf)
            st.metric("Medium Confidence (60-80%)", medium_conf)
            st.metric("Low Confidence (<60%)", low_conf)

    with col2:
        # Category breakdown
        category_data = summary_data.get('by_category', {})
        if category_data:
            for category, count in category_data.items():
                st.metric(f"{category.title()} Correlations", count)


def main():
    """Main application function"""

    # Header
    st.markdown('<h1 class="main-header">🔍 Banking Service Correlation & AI Insights</h1>',
                unsafe_allow_html=True)

    # Sidebar controls
    st.sidebar.title("🎛️ Control Panel")

    # Service health check
    correlation_healthy, rca_healthy = display_service_health()

    st.sidebar.markdown("---")

    # Auto-refresh option
    auto_refresh = st.sidebar.checkbox("🔄 Auto-refresh (30s)", value=False)

    # Manual refresh button
    if st.sidebar.button("🔄 Refresh Data"):
        st.cache_data.clear()
        st.rerun()

    # ENHANCED: Add more sidebar controls
    st.sidebar.markdown("---")
    st.sidebar.subheader("📋 Quick Info")

    if correlation_healthy:
        st.sidebar.info(
            "💡 **Tip**: Use the tabs below to explore different aspects of the correlation analysis.")
    else:
        st.sidebar.error(
            "⚠️ **Issue**: Correlation engine is offline. Please check the service status.")

    # Data fetching with better error handling
    correlations_data = None
    summary_data = None

    if correlation_healthy:
        try:
            correlations_data = get_cached_correlations()
            summary_data = get_cached_summary()

            if not correlations_data:
                st.warning(
                    "⚠️ No correlation data available. The engines may be starting up.")

        except Exception as e:
            st.error(f"❌ Error fetching data: {str(e)}")
    else:
        st.error("❌ Cannot fetch data - Correlation engine is offline")

    # Key metrics display
    display_key_metrics(correlations_data, summary_data)

    st.markdown("---")

    # Main content tabs
    tab1, tab2, tab3, tab4 = st.tabs([
        "📊 Correlation Analysis",
        "🤖 AI Insights",
        "📈 Interactive Visualizations",
        "📋 Professional Reports"
    ])

    with tab1:
        st.markdown("### 🔗 Real-Time Correlation Detection")
        display_correlation_analysis(correlations_data)

        # Add summary section
        if summary_data:
            st.markdown("---")
            display_correlation_summary(summary_data)

    with tab2:
        st.markdown("### 🤖 AI-Powered Root Cause Analysis")
        display_ai_insights_interface(correlation_healthy, rca_healthy)

    with tab3:
        st.markdown("### 📈 Interactive Data Visualizations")
        display_interactive_visualizations(correlations_data, summary_data)

    with tab4:
        st.markdown("### 📋 Professional Report Generation")
        display_professional_reports(correlations_data, summary_data)

    # Footer with system info
    st.markdown("---")
    st.markdown(f"""
    <div style="text-align: center; color: #666; font-size: 0.8rem; padding: 1rem;">
        🏦 Banking Service Correlation Dashboard | 
        Last Updated: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')} | 
        Correlation Engine: {'🟢 Online' if correlation_healthy else '🔴 Offline'} | 
        RCA Engine: {'🟢 Online' if rca_healthy else '🔴 Offline'}
    </div>
    """, unsafe_allow_html=True)

    # Auto-refresh logic (keep this at the end)
    if auto_refresh:
        time.sleep(30)
        st.rerun()


if __name__ == "__main__":
    main()
