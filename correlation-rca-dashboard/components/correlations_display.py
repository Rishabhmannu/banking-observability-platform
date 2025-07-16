"""
Correlation Display Component
Handles all correlation analysis visualization and presentation
"""

import streamlit as st
from utils.data_formatter import (
    format_confidence,
    format_business_impact,
    format_p_value,
    get_clean_p_value,
    format_correlation_title
)


def display_correlation_analysis(correlations_data):
    """Display correlation analysis with improved styling and bigger headers"""
    st.subheader("🔗 Real-Time Correlation Analysis")

    if not correlations_data or not correlations_data.get('correlations'):
        st.info(
            "📭 No correlation data available. The correlation engine may be starting up.")
        return

    correlations = correlations_data['correlations']

    # Display correlations with enhanced styling
    for i, corr in enumerate(correlations[:10]):  # Show top 10 correlations
        # Create bigger, bolder header for each correlation
        correlation_title = format_correlation_title(corr, i + 1)

        with st.expander(correlation_title, expanded=(i < 3)):

            # Bigger, bolder correlation header inside expander
            st.markdown(f'''
            <div class="correlation-header">
                🔗 {corr['metric1']} ↔ {corr['metric2']}
            </div>
            ''', unsafe_allow_html=True)

            # Main correlation info with dark theme
            col1, col2 = st.columns([2, 1])

            with col1:
                st.markdown(f'''
                <div class="correlation-card">
                    <p><strong>Confidence:</strong> {format_confidence(corr['confidence'])}</p>
                    <p><strong>Correlation Type:</strong> <span style="color: #70a1ff; font-weight: bold;">{corr['type'].title()}</span> correlation</p>
                    <p><strong>Business Impact:</strong> {format_business_impact(corr.get('business_impact', 'Unknown'))}</p>
                    <p><strong>Statistical Significance:</strong> <span style="color: #ffd93d;">p-value = {format_p_value(corr['p_value'])}</span></p>
                </div>
                ''', unsafe_allow_html=True)

            with col2:
                # Statistical details with accent colors
                st.metric("P-Value", get_clean_p_value(
                    corr['p_value']), help="Lower values indicate stronger statistical significance")
                st.metric("Sample Size", corr['sample_size'],
                          help="Number of data points used in analysis")
                st.metric("Confidence", f"{corr['confidence']:.1%}",
                          help="Statistical confidence in correlation")

                # Category and group info with better styling
                if 'category' in corr:
                    category_color = "#00d4aa" if corr['category'] == 'business' else "#70a1ff"
                    st.markdown(
                        f'<div style="background: {category_color}20; color: {category_color}; padding: 0.5rem; border-radius: 5px; margin: 0.5rem 0; font-weight: bold;">📂 Category: {corr["category"].title()}</div>', unsafe_allow_html=True)

                if 'correlation_group' in corr:
                    group_display = corr['correlation_group'].replace(
                        '_', ' → ').title()
                    st.markdown(
                        f'<div style="background: #ffd93d20; color: #ffd93d; padding: 0.5rem; border-radius: 5px; margin: 0.5rem 0; font-weight: bold;">🔄 Group: {group_display}</div>', unsafe_allow_html=True)
