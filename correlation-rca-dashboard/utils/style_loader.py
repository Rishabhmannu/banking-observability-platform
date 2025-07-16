"""
Style Loader Utility
Handles loading of custom CSS styling for the dashboard
"""

import streamlit as st
import os


def load_custom_css():
    """Load custom CSS styling for the dashboard"""

    # Path to the CSS file
    css_file_path = os.path.join(os.path.dirname(
        os.path.dirname(__file__)), 'assets', 'styles.css')

    try:
        # Read the CSS file
        with open(css_file_path, 'r', encoding='utf-8') as css_file:
            css_content = css_file.read()

        # Apply the CSS
        st.markdown(f"""
        <style>
        {css_content}
        </style>
        """, unsafe_allow_html=True)

    except FileNotFoundError:
        # Fallback: basic styling if CSS file is not found
        st.markdown("""
        <style>
        .main-header {
            font-size: 3rem;
            text-align: center;
            color: #00d4aa;
            margin-bottom: 2rem;
        }
        .health-good { color: #00d4aa; font-weight: bold; }
        .health-bad { color: #ff6b6b; font-weight: bold; }
        </style>
        """, unsafe_allow_html=True)

        # Log the warning
        st.warning("⚠️ Custom CSS file not found. Using fallback styling.")

    except Exception as e:
        # Log error but don't break the app
        st.error(f"❌ Error loading custom CSS: {str(e)}")


def apply_dark_theme():
    """Apply additional dark theme styling for better visibility"""
    st.markdown("""
    <style>
    /* Additional dark theme enhancements */
    .stApp {
        background-color: #0e1117;
    }
    
    .stSelectbox > div > div {
        background-color: #262730;
        color: white;
    }
    
    .stTextInput > div > div > input {
        background-color: #262730;
        color: white;
    }
    
    .stButton > button {
        background-color: #00d4aa;
        color: white;
        border: none;
        border-radius: 5px;
        font-weight: bold;
    }
    
    .stButton > button:hover {
        background-color: #00b894;
        transform: translateY(-1px);
        box-shadow: 0 4px 8px rgba(0, 212, 170, 0.3);
    }
    </style>
    """, unsafe_allow_html=True)
