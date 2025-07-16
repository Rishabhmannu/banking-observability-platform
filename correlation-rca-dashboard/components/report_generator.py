"""
Report Generator Component
Handles professional PDF report generation and preview
"""

import streamlit as st
from datetime import datetime
import logging

logger = logging.getLogger(__name__)

def display_professional_reports(correlations_data, summary_data):
    """Display professional report generation interface with full PDF functionality"""
    st.subheader("📋 Professional Report Generation")

    # Report configuration section
    col1, col2 = st.columns([1, 1])

    with col1:
        st.subheader("📄 Report Configuration")

        report_type = st.selectbox(
            "Report Type",
            ["Executive Summary", "Technical Analysis",
                "Security Assessment", "Performance Report"],
            help="Select the type of report to generate"
        )

        time_period = st.selectbox(
            "Time Period",
            ["Last Hour", "Last 4 Hours", "Last 24 Hours", "Last Week"],
            help="Time range for correlation analysis"
        )

        include_ai_insights = st.checkbox(
            "Include AI Insights", value=True, help="Include AI-powered analysis")
        include_visualizations = st.checkbox(
            "Include Charts", value=True, help="Include visualization charts")
        include_recommendations = st.checkbox(
            "Include Recommendations", value=True, help="Include action recommendations")

    with col2:
        st.subheader("📊 Report Preview")

        if correlations_data and summary_data:
            _display_report_preview(
                correlations_data, summary_data, report_type)
        else:
            st.info("📭 No data available for report preview.")

    st.markdown("---")

    # Report generation section
    st.subheader("🚀 Generate Report")

    # Add status info
    col1, col2, col3 = st.columns([1, 2, 1])
    
    with col1:
        # Show data availability
        if correlations_data:
            correlation_count = len(correlations_data.get('correlations', []))
            st.metric("Correlations Available", correlation_count)
        else:
            st.metric("Correlations Available", 0)
    
    with col3:
        # Show AI analysis availability
        ai_available = 'ai_analysis' in st.session_state and st.session_state.ai_analysis
        ai_count = len(st.session_state.get('ai_analysis', {}).get('analyses', [])) if ai_available else 0
        st.metric("AI Analyses Available", ai_count)

    with col2:
        # Main generation button
        if st.button("📄 Generate Professional PDF Report", type="primary", use_container_width=True):
            if correlations_data:
                _generate_pdf_report(
                    report_type=report_type,
                    time_period=time_period,
                    correlations_data=correlations_data,
                    summary_data=summary_data,
                    include_ai_insights=include_ai_insights,
                    include_visualizations=include_visualizations,
                    include_recommendations=include_recommendations
                )
            else:
                st.error("❌ No correlation data available for report generation.")

    # Report templates info
    _display_report_templates_info()


def _generate_pdf_report(report_type: str, time_period: str, correlations_data, summary_data, 
                        include_ai_insights: bool, include_visualizations: bool, include_recommendations: bool):
    """Generate and offer PDF report for download"""
    
    with st.spinner("📄 Generating professional PDF report... This may take up to 2 minutes."):
        try:
            # Import PDF generator
            from utils.pdf_generator import BankingReportGenerator
            
            # Get AI analysis if available and requested
            ai_analysis = None
            if include_ai_insights and 'ai_analysis' in st.session_state:
                ai_analysis = st.session_state['ai_analysis']
                st.info(f"✅ Including {len(ai_analysis.get('analyses', []))} AI analyses in report")
            elif include_ai_insights:
                st.warning("⚠️ AI insights requested but not available. Generate AI analysis first.")
            
            # Initialize PDF generator
            pdf_generator = BankingReportGenerator()
            
            # Generate PDF
            pdf_buffer = pdf_generator.generate_report(
                report_type=report_type,
                correlations_data=correlations_data,
                summary_data=summary_data,
                ai_analysis=ai_analysis,
                include_charts=include_visualizations,
                include_recommendations=include_recommendations,
                time_period=time_period
            )
            
            # Create filename with timestamp
            timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
            report_name = report_type.lower().replace(' ', '_')
            filename = f"banking_correlation_report_{report_name}_{timestamp}.pdf"
            
            # Success message with details
            st.success("✅ Report generated successfully!")
            
            # Show report details
            col1, col2, col3 = st.columns(3)
            with col1:
                st.metric("Report Type", report_type)
            with col2:
                st.metric("Time Period", time_period) 
            with col3:
                st.metric("File Size", f"{len(pdf_buffer.getvalue()) / 1024 / 1024:.1f} MB")
            
            # Download button
            st.download_button(
                label="⬇️ Download Professional PDF Report",
                data=pdf_buffer.getvalue(),
                file_name=filename,
                mime="application/pdf",
                use_container_width=True,
                help=f"Download {report_type} report as PDF"
            )
            
            # Show what was included
            included_features = []
            if ai_analysis:
                included_features.append(f"✅ AI Insights ({len(ai_analysis.get('analyses', []))} analyses)")
            if include_visualizations:
                included_features.append("✅ Charts and Visualizations")
            if include_recommendations:
                included_features.append("✅ Recommendations")
            
            if included_features:
                st.info("📋 **Report includes:** " + " • ".join(included_features))
            
        except ImportError as e:
            st.error("❌ PDF generation dependencies not installed.")
            st.code("pip install -r requirements-report.txt")
            logger.error(f"PDF generation import error: {e}")
            
        except Exception as e:
            st.error(f"❌ Error generating PDF report: {str(e)}")
            st.info("🔧 Please check the logs for detailed error information.")
            logger.error(f"PDF generation error: {e}")
            
            # Provide troubleshooting info
            with st.expander("🔧 Troubleshooting Information"):
                st.write("**Common issues:**")
                st.write("• Ensure all dependencies are installed: `pip install -r requirements-report.txt`")
                st.write("• Check that correlation data is available")
                st.write("• Verify AI analysis has been generated if including AI insights")
                st.write("• Try generating without charts if visualization errors occur")


def _display_report_preview(correlations_data, summary_data, report_type):
    """Display a preview of what the report will contain"""
    st.write(f"**Report Type:** {report_type}")
    st.write(f"**Generated:** {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")

    # Summary stats
    total_correlations = len(correlations_data.get('correlations', [])) if correlations_data else 0
    high_confidence = 0
    if correlations_data:
        high_confidence = sum(1 for c in correlations_data.get('correlations', []) 
                            if c.get('confidence', 0) > 0.8)

    st.write(f"**Total Correlations:** {total_correlations}")
    st.write(f"**High Confidence:** {high_confidence}")

    if correlations_data and correlations_data.get('correlations'):
        latest_corr = correlations_data['correlations'][0]
        metric1 = latest_corr['metric1'].replace('_', ' ').title()
        metric2 = latest_corr['metric2'].replace('_', ' ').title()
        st.write(f"**Latest Correlation:** {metric1} ↔ {metric2}")
        st.write(f"**Confidence:** {latest_corr['confidence']:.1%}")
    
    # AI analysis preview
    if 'ai_analysis' in st.session_state:
        ai_count = len(st.session_state['ai_analysis'].get('analyses', []))
        st.write(f"**AI Analyses Available:** {ai_count}")
    else:
        st.write(f"**AI Analyses Available:** 0 (Generate AI analysis first)")


def _display_report_templates_info():
    """Display information about available report templates"""
    st.subheader("📋 Available Report Templates")

    with st.expander("📊 Report Template Details", expanded=False):

        col1, col2 = st.columns(2)

        with col1:
            st.write("**Executive Summary:**")
            st.write("- High-level correlation overview")
            st.write("- Key business insights")
            st.write("- Strategic recommendations")
            st.write("- Executive-friendly formatting")

            st.write("**Technical Analysis:**")
            st.write("- Detailed statistical analysis")
            st.write("- P-values and confidence intervals")
            st.write("- Correlation methodologies")
            st.write("- Technical appendices")

        with col2:
            st.write("**Security Assessment:**")
            st.write("- Security-related correlations")
            st.write("- DDoS impact analysis")
            st.write("- Threat correlation patterns")
            st.write("- Security recommendations")

            st.write("**Performance Report:**")
            st.write("- Performance metric correlations")
            st.write("- System health insights")
            st.write("- Optimization opportunities")
            st.write("- Capacity planning guidance")

    # Updated info about PDF generation
    st.success("✅ **PDF Generation Ready:** Full functionality with charts, AI analysis, and professional formatting.")
    
    # Sample report info
    with st.expander("📄 Sample Report Features"):
        st.write("**Professional Features:**")
        st.write("• Banking-style professional formatting")
        st.write("• Embedded high-resolution charts and visualizations")
        st.write("• Complete AI-powered root cause analysis")
        st.write("• Executive summary with key metrics")
        st.write("• Detailed correlation analysis tables")
        st.write("• Strategic and technical recommendations")
        st.write("• Technical appendix with methodology")
        st.write("")
        st.write("**File Format:** PDF with embedded images")
        st.write("**Typical Size:** 2-5 MB depending on charts and content")
        st.write("**Generation Time:** 30 seconds - 2 minutes")