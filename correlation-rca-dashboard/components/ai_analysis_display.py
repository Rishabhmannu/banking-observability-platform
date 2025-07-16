"""
AI Analysis Display Component
Handles AI-powered root cause analysis interface and presentation
"""

import streamlit as st
import time
from utils.api_client import api_client
from utils.data_formatter import format_p_value, get_clean_p_value


def display_ai_insights_interface(correlation_healthy, rca_healthy):
    """Display AI-powered root cause analysis interface - SIMPLIFIED APPROACH"""
    st.subheader("🤖 AI-Powered Root Cause Analysis")

    if not rca_healthy:
        st.error("❌ RCA Engine is offline. Cannot generate AI insights.")
        st.info("💡 Ensure the RCA Insights Engine is running on port 5026.")
        return

    # Use the simplified combined approach
    _display_controls_and_results()


def _display_controls_and_results():
    """
    Manages the entire tab state: shows controls, handles form submission,
    and displays results or a getting started guide.
    """
    col1, col2, col3 = st.columns([1, 1, 1])

    with col1:
        st.subheader("🎯 Analysis Parameters")
        min_confidence = st.number_input(
            "🎯 Minimum confidence threshold:",
            min_value=0.0,
            max_value=1.0,
            value=0.82,
            step=0.01,
            format="%.2f",
            help="Lower bound - exclude correlations below this confidence"
        )
        max_confidence = st.number_input(
            "📊 Maximum confidence threshold:",
            min_value=0.0,
            max_value=1.0,
            value=0.98,
            step=0.01,
            format="%.2f",
            help="Upper bound - focus on correlations within specific range"
        )

        # Add validation
        if max_confidence <= min_confidence:
            st.error("⚠️ Maximum confidence must be greater than minimum confidence")
            max_confidence = min_confidence + 0.05

        # Estimated time info
        st.info(f"⏱️ Estimated time: 30 seconds - 2 minutes (depends on correlations found)")

    with col2:
        st.subheader("🚀 Generate Analysis")
        # estimated_time = limit * 8  # Removed since 'limit' is no longer used
        
        with st.form("ai_analysis_form"):
            generate_clicked = st.form_submit_button(
                "🤖 Generate AI Analysis", 
                type="primary", 
                use_container_width=True
            )
            if generate_clicked:
                if 'ai_analysis' in st.session_state:
                    del st.session_state['ai_analysis']
                _run_ai_analysis(min_confidence, max_confidence)

    with col3:
        st.subheader("🔄 Management")
        if st.button("📊 Check OpenAI Status", use_container_width=True):
            _check_openai_status()
        if st.button("🗑️ Clear Analysis", use_container_width=True):
            if 'ai_analysis' in st.session_state:
                del st.session_state['ai_analysis']
                st.success("✅ Analysis cleared!")
                st.rerun()

    st.markdown("---")

    # Display results or getting started guide
    if 'ai_analysis' in st.session_state and st.session_state.ai_analysis:
        _display_ai_results_final()
    else:
        _display_getting_started_guide()


def _run_ai_analysis(min_confidence: float, max_confidence: float):
    """
    Runs the AI analysis and stores the result in st.session_state.
    """
    with st.spinner(f"🤖 Analyzing correlations in range {min_confidence:.2f}-{max_confidence:.2f}... This may take up to 2 minutes for detailed AI analysis."):
        start_time = time.time()
        try:
            ai_analysis_result = api_client.trigger_ai_analysis(
                min_confidence=min_confidence,
                max_confidence=max_confidence
            )
            duration = time.time() - start_time
            
            if ai_analysis_result and ai_analysis_result.get('analyses'):
                st.session_state.ai_analysis = ai_analysis_result
                st.success(f"🎉 **Analysis Complete!** Generated {len(ai_analysis_result.get('analyses', []))} insights in {duration:.1f}s")
                time.sleep(1)
                st.rerun()  # Rerun to display results immediately
            else:
                st.session_state.ai_analysis = None
                st.error(f"❌ **Analysis Failed** ({duration:.1f}s). No insights generated.")
        
        except Exception as e:
            st.session_state.ai_analysis = None
            st.error(f"💥 **An unexpected error occurred:** {str(e)}")


def _display_ai_results_final():
    """
    Display AI analysis using native Streamlit components - CLEAN APPROACH
    """
    ai_data = st.session_state.get('ai_analysis')
    if not ai_data or not ai_data.get('analyses'):
        return

    analyses = ai_data.get('analyses', [])
    
    # Use the scoped CSS class for styling
    st.markdown('<div class="ai-results-dashboard">', unsafe_allow_html=True)
    st.markdown("### 🔍 AI Analysis Results Dashboard")
    
    for i, analysis in enumerate(analyses, 1):
        correlation_event = analysis.get('correlation_event', {})
        metric1 = correlation_event.get('metric1', 'N/A')
        metric2 = correlation_event.get('metric2', 'N/A')
        confidence = correlation_event.get('confidence', 0)
        
        # Use native Streamlit container with border
        with st.container(border=True):
            st.markdown(f"#### 💡 Analysis {i}: {metric1} & {metric2}")
            
            # Use native Streamlit columns for metrics
            cols = st.columns(4)
            cols[0].metric(
                label="Metric 1", 
                value=metric1.replace('_', ' ').title()
            )
            cols[1].metric(
                label="Metric 2", 
                value=metric2.replace('_', ' ').title()
            )
            cols[2].metric(
                label="Confidence", 
                value=f"{confidence:.1%}"
            )
            cols[3].metric(
                label="Analysis Time", 
                value=f"{analysis.get('analysis_time_seconds', 0):.1f}s"
            )

            # Content area with native Streamlit styling
            with st.container():
                st.markdown('<div class="rca-content-box">', unsafe_allow_html=True)
                st.markdown("<h5>🤖 AI Root Cause Analysis & Recommendations</h5>", unsafe_allow_html=True)
                
                explanation = analysis.get('rca_explanation', 'No explanation available.')
                cleaned_explanation = explanation.replace('\\n', '\n')
                st.markdown(cleaned_explanation)
                
                st.markdown('</div>', unsafe_allow_html=True)
    
    st.markdown('</div>', unsafe_allow_html=True)


def _check_openai_status():
    """Check and display OpenAI status"""
    with st.spinner("🔍 Checking OpenAI status..."):
        openai_status = api_client.get_openai_status()
        
        if openai_status:
            if openai_status.get('configured') and openai_status.get('test_passed'):
                st.success(f"""
                ✅ **OpenAI Status: Healthy**
                
                - Model: {openai_status.get('model', 'Unknown')}
                - Status: {openai_status.get('status_message', 'Unknown')}
                - Last Test: {openai_status.get('last_test_time', 'Unknown')}
                """)
            else:
                st.warning(f"""
                ⚠️ **OpenAI Status: Issues Detected**
                
                - Configured: {openai_status.get('configured', False)}
                - Test Passed: {openai_status.get('test_passed', False)}
                - Status: {openai_status.get('status_message', 'Unknown')}
                
                **Recommendations:**
                {chr(10).join(['- ' + r for r in openai_status.get('recommendations', [])])}
                """)
        else:
            st.error("❌ Could not retrieve OpenAI status. Check RCA engine connection.")


def _display_getting_started_guide():
    """Display getting started guide when no AI analysis is available"""
    st.info("""
    ### 🤖 Welcome to AI-Powered Root Cause Analysis
    
    **What this does:**
    - Analyzes current correlations using advanced AI models (GPT-4)
    - Provides business context for technical metrics
    - Generates natural language explanations
    - Suggests root causes and remediation steps
    
    **How to use:**
    1. **Set Parameters**: Use the sidebar to choose correlations and confidence threshold
    2. **Generate Analysis**: Click "Generate AI Analysis" (takes 20-40 seconds)
    3. **Review Results**: Examine detailed insights and recommendations
    
    **Pro Tips:**
    - Start with fewer correlations (1-2) for faster results
    - Higher confidence threshold = more reliable but fewer correlations
    - Check OpenAI status if analysis fails
    
    **Current Status:** Ready to analyze correlations! 🚀
    """)
    
    # Add debug info in expander
    with st.expander("🔧 Debug Information"):
        st.write("**Session State Keys:**", list(st.session_state.keys()))
        if 'ai_analysis' in st.session_state:
            ai_data = st.session_state['ai_analysis']
            st.write("**AI Analysis Data Keys:**", list(ai_data.keys()) if ai_data else "None")
            if ai_data and 'analyses' in ai_data:
                st.write("**Number of Analyses:**", len(ai_data['analyses']))
        else:
            st.write("**AI Analysis Data:** Not found in session state")