"""
Data formatting utilities for the Banking Correlation Dashboard
Handles all data presentation and formatting logic
"""


def format_confidence(confidence: float) -> str:
    """Format confidence score with color coding"""
    percentage = f"{confidence:.1%}"
    if confidence >= 0.8:
        return f'<span class="confidence-high">{percentage} (High)</span>'
    elif confidence >= 0.6:
        return f'<span class="confidence-medium">{percentage} (Medium)</span>'
    else:
        return f'<span class="confidence-low">{percentage} (Low)</span>'


def format_p_value(p_value: float) -> str:
    """Format p-value in proper scientific notation with enhanced styling"""
    if p_value == 0:
        return '<span class="scientific-notation">< 10⁻¹⁵</span>'
    elif p_value >= 0.001:
        return f'<span class="scientific-notation">{p_value:.6f}</span>'
    else:
        # Convert to scientific notation
        exponent = int(f"{p_value:.1e}".split('e')[1])
        mantissa = p_value / (10 ** exponent)

        # Create superscript exponent
        superscript_map = {
            '0': '⁰', '1': '¹', '2': '²', '3': '³', '4': '⁴',
            '5': '⁵', '6': '⁶', '7': '⁷', '8': '⁸', '9': '⁹',
            '-': '⁻'
        }

        exponent_str = str(exponent)
        superscript_exp = ''.join(superscript_map.get(char, char)
                                  for char in exponent_str)

        return f'<span class="scientific-notation">{mantissa:.2f} × 10{superscript_exp}</span>'


def format_business_impact(impact: str) -> str:
    """Format business impact with appropriate styling and accent colors"""
    if impact.startswith("CRITICAL"):
        return f'🚨 <span class="impact-critical">{impact}</span>'
    elif impact.startswith("HIGH"):
        return f'⚠️ <span class="impact-high">{impact}</span>'
    elif impact.startswith("MEDIUM"):
        return f'📊 <span class="impact-medium">{impact}</span>'
    else:
        return f'ℹ️ <span class="impact-low">{impact}</span>'


def format_correlation_title(corr: dict, index: int) -> str:
    """Format correlation title for display"""
    return f"Correlation {index}: {corr['metric1']} ↔ {corr['metric2']}"


def format_metric_name(metric_name: str) -> str:
    """Format metric names for better readability"""
    # Remove common prefixes and suffixes
    formatted = metric_name.replace('_total', '').replace(
        'banking_', '').replace('_seconds', '')

    # Convert underscores to spaces and title case
    formatted = formatted.replace('_', ' ').title()

    return formatted


def get_clean_p_value(p_value: float) -> str:
    """Get clean p-value string without HTML tags for metrics display"""
    formatted = format_p_value(p_value)
    return formatted.replace('<span class="scientific-notation">', '').replace('</span>', '')
