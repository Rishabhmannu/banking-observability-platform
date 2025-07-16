"""
Chart Generation Engine for PDF Reports
Converts correlation data into professional charts for PDF embedding
"""

import plotly.graph_objects as go
import plotly.express as px
from plotly.subplots import make_subplots
import pandas as pd
import io
import base64
from typing import Dict, List, Optional, Tuple
import logging

logger = logging.getLogger(__name__)

class CorrelationChartGenerator:
    def __init__(self):
        # Professional color palette
        self.colors = {
            'primary': '#2C3E50',
            'secondary': '#3498DB', 
            'success': '#27AE60',
            'warning': '#F39C12',
            'danger': '#E74C3C',
            'light': '#ECF0F1',
            'dark': '#7F8C8D'
        }
        
        # Chart configuration
        self.chart_config = {
            'width': 800,
            'height': 500,
            'dpi': 300,  # High resolution for PDF
            'format': 'png'
        }
    
    def generate_all_charts(self, correlations_data: Dict, summary_data: Dict) -> Dict[str, bytes]:
        """Generate all charts for PDF report"""
        charts = {}
        
        try:
            # Chart 1: Correlation Confidence Distribution
            if correlations_data and correlations_data.get('correlations'):
                charts['confidence_distribution'] = self._create_confidence_distribution(correlations_data)
            
            # Chart 2: Top Correlations Bar Chart
            if correlations_data and correlations_data.get('correlations'):
                charts['top_correlations'] = self._create_top_correlations_chart(correlations_data)
            
            # Chart 3: Correlation Matrix Heatmap (if enough data)
            if correlations_data and len(correlations_data.get('correlations', [])) >= 5:
                charts['correlation_matrix'] = self._create_correlation_matrix(correlations_data)
            
            # Chart 4: Category Breakdown Pie Chart
            if summary_data and summary_data.get('by_category'):
                charts['category_breakdown'] = self._create_category_pie_chart(summary_data)
            
            logger.info(f"Generated {len(charts)} charts for PDF report")
            return charts
            
        except Exception as e:
            logger.error(f"Error generating charts: {e}")
            return {}
    
    def _create_confidence_distribution(self, correlations_data: Dict) -> bytes:
        """Create confidence level distribution bar chart"""
        correlations = correlations_data.get('correlations', [])
        
        # Group correlations by confidence ranges
        confidence_ranges = {
            '99%+': 0,
            '90-99%': 0, 
            '80-90%': 0,
            '70-80%': 0,
            '<70%': 0
        }
        
        for corr in correlations:
            confidence = corr.get('confidence', 0)
            if confidence >= 0.99:
                confidence_ranges['99%+'] += 1
            elif confidence >= 0.90:
                confidence_ranges['90-99%'] += 1
            elif confidence >= 0.80:
                confidence_ranges['80-90%'] += 1
            elif confidence >= 0.70:
                confidence_ranges['70-80%'] += 1
            else:
                confidence_ranges['<70%'] += 1
        
        # Create bar chart
        fig = go.Figure(data=[
            go.Bar(
                x=list(confidence_ranges.keys()),
                y=list(confidence_ranges.values()),
                marker_color=[self.colors['success'], self.colors['primary'], 
                             self.colors['secondary'], self.colors['warning'], self.colors['danger']],
                text=list(confidence_ranges.values()),
                textposition='auto',
            )
        ])
        
        fig.update_layout(
            title={
                'text': 'Correlation Confidence Distribution',
                'x': 0.5,
                'font': {'size': 16, 'color': self.colors['primary']}
            },
            xaxis_title='Confidence Level',
            yaxis_title='Number of Correlations',
            plot_bgcolor='white',
            paper_bgcolor='white',
            font={'color': self.colors['dark']},
            showlegend=False,
            width=self.chart_config['width'],
            height=self.chart_config['height']
        )
        
        return self._fig_to_bytes(fig)
    
    def _create_top_correlations_chart(self, correlations_data: Dict) -> bytes:
        """Create horizontal bar chart of top correlations"""
        correlations = correlations_data.get('correlations', [])
        
        # Get top 10 correlations
        top_correlations = sorted(correlations, key=lambda x: x.get('confidence', 0), reverse=True)[:10]
        
        # Prepare data
        labels = []
        confidences = []
        colors = []
        
        for corr in top_correlations:
            metric1 = corr.get('metric1', 'Unknown').replace('_', ' ').title()
            metric2 = corr.get('metric2', 'Unknown').replace('_', ' ').title()
            
            # Truncate long metric names
            if len(metric1) > 20:
                metric1 = metric1[:17] + '...'
            if len(metric2) > 20:
                metric2 = metric2[:17] + '...'
            
            labels.append(f"{metric1} ↔ {metric2}")
            confidence = corr.get('confidence', 0)
            confidences.append(confidence)
            
            # Color coding by confidence level
            if confidence >= 0.95:
                colors.append(self.colors['success'])
            elif confidence >= 0.85:
                colors.append(self.colors['primary'])
            elif confidence >= 0.75:
                colors.append(self.colors['warning'])
            else:
                colors.append(self.colors['danger'])
        
        # Create horizontal bar chart
        fig = go.Figure(data=[
            go.Bar(
                y=labels,
                x=confidences,
                orientation='h',
                marker_color=colors,
                text=[f"{conf:.1%}" for conf in confidences],
                textposition='auto',
            )
        ])
        
        fig.update_layout(
            title={
                'text': 'Top Correlations by Confidence',
                'x': 0.5,
                'font': {'size': 16, 'color': self.colors['primary']}
            },
            xaxis_title='Confidence Level',
            yaxis_title='Metric Pairs',
            plot_bgcolor='white',
            paper_bgcolor='white',
            font={'color': self.colors['dark']},
            showlegend=False,
            width=self.chart_config['width'],
            height=self.chart_config['height'],
            margin=dict(l=200)  # More space for labels
        )
        
        return self._fig_to_bytes(fig)
    
    def _create_correlation_matrix(self, correlations_data: Dict) -> bytes:
        """Create correlation matrix heatmap"""
        correlations = correlations_data.get('correlations', [])
        
        # Extract unique metrics
        metrics = set()
        for corr in correlations:
            metrics.add(corr.get('metric1', ''))
            metrics.add(corr.get('metric2', ''))
        
        metrics = sorted(list(metrics))[:15]  # Limit to 15 metrics for readability
        
        # Create correlation matrix
        matrix = [[0 for _ in metrics] for _ in metrics]
        
        for i, metric1 in enumerate(metrics):
            for j, metric2 in enumerate(metrics):
                if i == j:
                    matrix[i][j] = 1.0  # Perfect correlation with self
                else:
                    # Find correlation between these metrics
                    for corr in correlations:
                        if ((corr.get('metric1') == metric1 and corr.get('metric2') == metric2) or
                            (corr.get('metric1') == metric2 and corr.get('metric2') == metric1)):
                            matrix[i][j] = corr.get('correlation_coefficient', 0)
                            break
        
        # Clean metric names for display
        clean_metrics = [metric.replace('_', ' ').title()[:20] for metric in metrics]
        
        # Create heatmap
        fig = go.Figure(data=go.Heatmap(
            z=matrix,
            x=clean_metrics,
            y=clean_metrics,
            colorscale='RdBu',
            zmid=0,
            colorbar=dict(title='Correlation Coefficient'),
            text=[[f"{val:.2f}" for val in row] for row in matrix],
            texttemplate="%{text}",
            textfont={"size": 8}
        ))
        
        fig.update_layout(
            title={
                'text': 'Correlation Matrix Heatmap',
                'x': 0.5,
                'font': {'size': 16, 'color': self.colors['primary']}
            },
            width=self.chart_config['width'],
            height=self.chart_config['height'],
            font={'color': self.colors['dark']}
        )
        
        return self._fig_to_bytes(fig)
    
    def _create_category_pie_chart(self, summary_data: Dict) -> bytes:
        """Create pie chart of correlation categories"""
        categories = summary_data.get('by_category', {})
        
        if not categories:
            return b''
        
        labels = list(categories.keys())
        values = list(categories.values())
        
        # Professional color palette for categories
        category_colors = [
            self.colors['primary'],
            self.colors['secondary'], 
            self.colors['success'],
            self.colors['warning'],
            self.colors['danger'],
            self.colors['dark']
        ]
        
        fig = go.Figure(data=[go.Pie(
            labels=[label.replace('_', ' ').title() for label in labels],
            values=values,
            hole=0.3,  # Donut chart
            marker_colors=category_colors[:len(labels)],
            textinfo='label+percent',
            textposition='auto'
        )])
        
        fig.update_layout(
            title={
                'text': 'Correlations by Category',
                'x': 0.5,
                'font': {'size': 16, 'color': self.colors['primary']}
            },
            plot_bgcolor='white',
            paper_bgcolor='white',
            font={'color': self.colors['dark']},
            width=self.chart_config['width'],
            height=self.chart_config['height']
        )
        
        return self._fig_to_bytes(fig)
    
    def _fig_to_bytes(self, fig) -> bytes:
        """Convert plotly figure to bytes for PDF embedding"""
        try:
            # Convert to image bytes
            img_bytes = fig.to_image(
                format=self.chart_config['format'],
                width=self.chart_config['width'],
                height=self.chart_config['height'],
                scale=2  # High resolution
            )
            return img_bytes
            
        except Exception as e:
            logger.error(f"Error converting chart to bytes: {e}")
            return b''