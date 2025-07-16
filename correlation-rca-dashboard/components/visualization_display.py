"""
Visualization Display Component
Handles interactive visualizations and summary analytics
"""

import streamlit as st
import plotly.express as px
import plotly.graph_objects as go


def display_interactive_visualizations(correlations_data, summary_data):
    """Display interactive visualizations - Priority Feature #4"""
    st.subheader("📈 Interactive Correlation Visualizations")

    if not correlations_data or not correlations_data.get('correlations'):
        st.info("📊 No correlation data available for visualization.")
        return

    # Show correlation summary charts
    display_correlation_summary(summary_data)

    # TODO: Add more interactive visualizations in future iterations
    st.info("🚧 Advanced interactive visualizations (network graphs, correlation matrices) coming soon...")


def display_correlation_summary(summary_data):
    """Display correlation summary with charts"""
    st.subheader("📊 Correlation Summary & Analytics")

    if not summary_data:
        st.info("📊 No summary data available.")
        return

    col1, col2 = st.columns(2)

    with col1:
        # Confidence distribution
        st.subheader("🎯 Confidence Distribution")
        confidence_data = summary_data.get('by_confidence', {})

        if confidence_data:
            labels = ['High (>80%)', 'Medium (60-80%)', 'Low (<60%)']
            values = [
                confidence_data.get('high_confidence_80_plus', 0),
                confidence_data.get('medium_confidence_60_80', 0),
                confidence_data.get('low_confidence_below_60', 0)
            ]

            fig_confidence = px.pie(
                values=values,
                names=labels,
                title="Correlation Confidence Levels",
                color_discrete_sequence=['#00d4aa', '#ffd93d', '#ff6b6b']
            )
            fig_confidence.update_layout(
                font=dict(color='white'),
                plot_bgcolor='rgba(0,0,0,0)',
                paper_bgcolor='rgba(0,0,0,0)'
            )
            st.plotly_chart(fig_confidence, use_container_width=True)

    with col2:
        # Category breakdown
        st.subheader("📈 Category Breakdown")
        category_data = summary_data.get('by_category', {})

        if category_data:
            categories = list(category_data.keys())
            counts = list(category_data.values())

            fig_category = px.bar(
                x=categories,
                y=counts,
                title="Correlations by Category",
                color=counts,
                color_continuous_scale='Viridis'
            )
            fig_category.update_layout(
                showlegend=False,
                font=dict(color='white'),
                plot_bgcolor='rgba(0,0,0,0)',
                paper_bgcolor='rgba(0,0,0,0)',
                xaxis=dict(gridcolor='#333'),
                yaxis=dict(gridcolor='#333')
            )
            st.plotly_chart(fig_category, use_container_width=True)

    # Additional analytics section
    _display_statistical_insights(summary_data)


def _display_statistical_insights(summary_data):
    """Display additional statistical insights"""
    if summary_data:
        st.subheader("📊 Statistical Insights")

        col1, col2, col3 = st.columns(3)

        with col1:
            total_correlations = summary_data.get('total_correlations', 0)
            st.metric("Total Correlations", total_correlations)

        with col2:
            high_significance = summary_data.get(
                'by_significance', {}).get('high_significance', 0)
            st.metric("High Significance", high_significance,
                      help="p-value < 0.01")

        with col3:
            business_correlations = summary_data.get(
                'by_category', {}).get('business', 0)
            st.metric("Business Correlations", business_correlations,
                      help="Business-critical metric correlations")
