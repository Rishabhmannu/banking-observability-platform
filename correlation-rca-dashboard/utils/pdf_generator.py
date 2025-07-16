"""
Professional PDF Report Generator
Creates comprehensive banking correlation reports with charts and AI analysis
"""

import io
from datetime import datetime
from typing import Dict, List, Optional
import logging
import re

from reportlab.lib.pagesizes import A4
from reportlab.lib.units import inch
from reportlab.platypus import (
    SimpleDocTemplate, Paragraph, Spacer, Table, TableStyle, 
    PageBreak, Image as RLImage, KeepTogether
)
from reportlab.lib import colors

from .pdf_styles import BankingPDFStyles
from .chart_generator import CorrelationChartGenerator

logger = logging.getLogger(__name__)

class BankingReportGenerator:
    def __init__(self):
        self.styles_engine = BankingPDFStyles()
        self.chart_generator = CorrelationChartGenerator()
        self.styles = self.styles_engine.styles
        
    def generate_report(self, 
                       report_type: str,
                       correlations_data: Dict,
                       summary_data: Dict,
                       ai_analysis: Optional[Dict] = None,
                       include_charts: bool = True,
                       include_recommendations: bool = True,
                       time_period: str = "Last 24 Hours") -> io.BytesIO:
        """Generate comprehensive PDF report"""
        
        buffer = io.BytesIO()
        doc = SimpleDocTemplate(
            buffer, 
            pagesize=A4,
            topMargin=1*inch,
            bottomMargin=1*inch,
            leftMargin=0.75*inch,
            rightMargin=0.75*inch
        )
        
        story = []
        
        try:
            # Generate charts first (needed for embedding)
            charts = {}
            if include_charts and correlations_data:
                charts = self.chart_generator.generate_all_charts(correlations_data, summary_data)
                logger.info(f"Generated {len(charts)} charts for report")
            
            # 1. Title Page
            story.extend(self._create_title_page(report_type, time_period))
            story.append(PageBreak())
            
            # 2. Executive Summary
            story.extend(self._create_executive_summary(correlations_data, summary_data, report_type))
            
            # 3. Correlation Analysis Section
            if correlations_data:
                story.extend(self._create_correlation_section(correlations_data, summary_data))
            
            # 4. Charts and Visualizations
            if include_charts and charts:
                story.extend(self._create_charts_section(charts))
            
            # 5. AI Insights Section
            if ai_analysis and ai_analysis.get('analyses'):
                story.extend(self._create_ai_insights_section(ai_analysis))
            
            # 6. Recommendations Section
            if include_recommendations:
                story.extend(self._create_recommendations_section(correlations_data, ai_analysis, report_type))
            
            # 7. Technical Appendix
            if report_type == "Technical Analysis":
                story.extend(self._create_technical_appendix(correlations_data, summary_data))
            
            # Build PDF
            doc.build(story)
            buffer.seek(0)
            logger.info(f"Successfully generated {report_type} PDF report")
            return buffer
            
        except Exception as e:
            logger.error(f"Error generating PDF report: {e}")
            raise e
    
    def _create_title_page(self, report_type: str, time_period: str) -> List:
        """Create professional title page"""
        elements = []
        
        # Title
        title_text = f"Banking System Correlation Analysis<br/>{report_type}"
        elements.append(Paragraph(title_text, self.styles['ReportTitle']))
        elements.append(Spacer(1, 0.5*inch))
        
        # Subtitle
        subtitle_text = f"Intelligent Monitoring & Root Cause Analysis<br/>Time Period: {time_period}"
        elements.append(Paragraph(subtitle_text, self.styles['ReportSubtitle']))
        elements.append(Spacer(1, 1*inch))
        
        # Report metadata
        current_time = datetime.now()
        metadata = [
            f"<b>Generated:</b> {current_time.strftime('%Y-%m-%d %H:%M:%S')}",
            f"<b>Report Type:</b> {report_type}",
            f"<b>Time Period:</b> {time_period}",
            f"<b>System:</b> DDoS Detection Banking System",
            f"<b>Analysis Engine:</b> Event Correlation + AI Insights"
        ]
        
        for item in metadata:
            elements.append(Paragraph(item, self.styles['BodyText']))
            elements.append(Spacer(1, 0.1*inch))
        
        elements.append(Spacer(1, 1*inch))
        
        # Disclaimer
        disclaimer = """
        <b>Confidential Report</b><br/>
        This report contains sensitive operational data and AI-powered analysis 
        of banking system correlations. Distribution should be limited to 
        authorized personnel only.
        """
        elements.append(Paragraph(disclaimer, self.styles['TechnicalNote']))
        
        return elements
    
    def _create_executive_summary(self, correlations_data: Dict, summary_data: Dict, report_type: str) -> List:
        """Create executive summary section"""
        elements = []
        
        elements.append(Paragraph("Executive Summary", self.styles['SectionHeader']))
        
        # Key statistics
        total_correlations = len(correlations_data.get('correlations', [])) if correlations_data else 0
        high_confidence = 0
        critical_correlations = 0
        
        if correlations_data and correlations_data.get('correlations'):
            for corr in correlations_data['correlations']:
                confidence = corr.get('confidence', 0)
                if confidence >= 0.8:
                    high_confidence += 1
                if confidence >= 0.95:
                    critical_correlations += 1
        
        # Summary content based on report type
        if report_type == "Executive Summary":
            summary_text = f"""
            This report analyzes {total_correlations} correlation events detected in the banking 
            system's monitoring infrastructure. Key findings include {high_confidence} high-confidence 
            correlations requiring attention and {critical_correlations} critical correlations 
            indicating potential system interdependencies.
            
            <b>Key Highlights:</b><br/>
            • Statistical correlation analysis across 18+ microservices<br/>
            • AI-powered root cause analysis with business impact assessment<br/>
            • Proactive monitoring insights for operational excellence<br/>
            • Performance optimization opportunities identified
            """
        elif report_type == "Security Assessment":
            summary_text = f"""
            Security-focused analysis of {total_correlations} correlation events with emphasis on 
            DDoS detection patterns, threat correlations, and system vulnerabilities. This assessment 
            provides actionable insights for strengthening security posture.
            
            <b>Security Focus Areas:</b><br/>
            • DDoS attack pattern correlations<br/>
            • Security metric interdependencies<br/>
            • Threat detection system performance<br/>
            • Infrastructure security correlations
            """
        elif report_type == "Performance Report":
            summary_text = f"""
            Comprehensive performance analysis covering {total_correlations} correlations related to 
            system performance, resource utilization, and operational efficiency. Focus on optimization 
            opportunities and capacity planning insights.
            
            <b>Performance Insights:</b><br/>
            • Transaction processing correlations<br/>
            • Resource utilization patterns<br/>
            • Cache and database performance<br/>
            • Response time optimization opportunities
            """
        else:  # Technical Analysis
            summary_text = f"""
            Detailed technical analysis of {total_correlations} correlation events with full statistical 
            context, methodology explanation, and comprehensive data analysis. Suitable for technical 
            teams and system administrators.
            
            <b>Technical Scope:</b><br/>
            • Statistical significance testing (p-values, confidence intervals)<br/>
            • Correlation methodology and algorithms<br/>
            • Raw data analysis and interpretation<br/>
            • System architecture impact assessment
            """
        
        elements.append(Paragraph(summary_text, self.styles['ExecutiveSummary']))
        elements.append(Spacer(1, 0.3*inch))
        
        return elements
    
    def _create_correlation_section(self, correlations_data: Dict, summary_data: Dict) -> List:
        """Create detailed correlation analysis section"""
        elements = []
        
        elements.append(Paragraph("Correlation Analysis", self.styles['SectionHeader']))
        
        correlations = correlations_data.get('correlations', [])
        if not correlations:
            elements.append(Paragraph("No correlation data available.", self.styles['BodyText']))
            return elements
        
        # Summary statistics
        elements.append(Paragraph("Statistical Overview", self.styles['SubSectionHeader']))
        
        stats_text = f"""
        Total correlations detected: <b>{len(correlations)}</b><br/>
        High confidence (>80%): <b>{sum(1 for c in correlations if c.get('confidence', 0) > 0.8)}</b><br/>
        Critical correlations (>95%): <b>{sum(1 for c in correlations if c.get('confidence', 0) > 0.95)}</b><br/>
        Average confidence level: <b>{sum(c.get('confidence', 0) for c in correlations) / len(correlations):.1%}</b>
        """
        elements.append(Paragraph(stats_text, self.styles['BodyText']))
        elements.append(Spacer(1, 0.2*inch))
        
        # Top correlations table
        elements.append(Paragraph("Top Correlations", self.styles['SubSectionHeader']))
        
        # Prepare table data
        table_data = [['Metric 1', 'Metric 2', 'Confidence', 'Type', 'P-Value']]
        
        # Sort by confidence and take top 10
        top_correlations = sorted(correlations, key=lambda x: x.get('confidence', 0), reverse=True)[:10]
        
        for corr in top_correlations:
            metric1 = corr.get('metric1', 'Unknown')[:25]
            metric2 = corr.get('metric2', 'Unknown')[:25]
            confidence = f"{corr.get('confidence', 0):.1%}"
            corr_type = corr.get('type', 'Unknown').title()
            p_value = f"{corr.get('p_value', 0):.2e}"
            
            table_data.append([metric1, metric2, confidence, corr_type, p_value])
        
        # Create table
        table = Table(table_data, colWidths=[2*inch, 2*inch, 0.8*inch, 0.8*inch, 0.8*inch])
        table.setStyle(self.styles_engine.get_table_style())
        
        elements.append(table)
        elements.append(Spacer(1, 0.3*inch))
        
        return elements
    
    def _create_charts_section(self, charts: Dict[str, bytes]) -> List:
        """Create charts and visualizations section"""
        elements = []
        
        elements.append(PageBreak())
        elements.append(Paragraph("Data Visualizations", self.styles['SectionHeader']))
        
        chart_titles = {
            'confidence_distribution': 'Correlation Confidence Distribution',
            'top_correlations': 'Top Correlations by Confidence Level', 
            'correlation_matrix': 'Correlation Matrix Heatmap',
            'category_breakdown': 'Correlations by Category'
        }
        
        for chart_key, chart_bytes in charts.items():
            if chart_bytes:
                try:
                    # Add chart title
                    title = chart_titles.get(chart_key, chart_key.replace('_', ' ').title())
                    elements.append(Paragraph(title, self.styles['SubSectionHeader']))
                    
                    # Create image from bytes
                    chart_buffer = io.BytesIO(chart_bytes)
                    chart_img = RLImage(chart_buffer, width=6*inch, height=3.75*inch)
                    elements.append(chart_img)
                    elements.append(Spacer(1, 0.3*inch))
                    
                except Exception as e:
                    logger.error(f"Error embedding chart {chart_key}: {e}")
                    elements.append(Paragraph(f"Chart generation error: {chart_key}", self.styles['TechnicalNote']))
        
        return elements
    
    def _create_ai_insights_section(self, ai_analysis: Dict) -> List:
        """Create AI insights and root cause analysis section"""
        elements = []
        
        elements.append(PageBreak())
        elements.append(Paragraph("AI-Powered Root Cause Analysis", self.styles['SectionHeader']))
        
        analyses = ai_analysis.get('analyses', [])
        
        for i, analysis in enumerate(analyses, 1):
            correlation_event = analysis.get('correlation_event', {})
            metric1 = correlation_event.get('metric1', 'Unknown')
            metric2 = correlation_event.get('metric2', 'Unknown')
            confidence = correlation_event.get('confidence', 0)
            
            # Analysis header
            header_text = f"Analysis {i}: {metric1} ↔ {metric2} (Confidence: {confidence:.1%})"
            elements.append(Paragraph(header_text, self.styles['SubSectionHeader']))
            
            # AI explanation
            explanation = analysis.get('rca_explanation', 'No explanation available.')
            
            # Clean and format the explanation
            explanation = explanation.replace('\\n', '<br/>')

            # Fix malformed HTML tags from AI: <b>Text:<b> becomes <b>Text:</b>
            explanation = re.sub(r'<b>([^<]*?):<b>', r'<b>\1:</b>', explanation)
            explanation = re.sub(r'<b>([^<]*?)<b>', r'<b>\1</b>', explanation)
            
            elements.append(Paragraph(explanation, self.styles['AIInsightBox']))
            elements.append(Spacer(1, 0.2*inch))
        
        return elements
    
    # ... (rest of the code remains the same)
    def _create_recommendations_section(self, correlations_data: Dict, ai_analysis: Optional[Dict], report_type: str) -> List:
        """Create recommendations section"""
        elements = []
        
        elements.append(PageBreak())
        elements.append(Paragraph("Recommendations & Action Items", self.styles['SectionHeader']))
        
        # Extract recommendations from AI analysis
        ai_recommendations = []
        if ai_analysis and ai_analysis.get('analyses'):
            for analysis in ai_analysis['analyses']:
                explanation = analysis.get('rca_explanation', '')
                if 'Remediation' in explanation or 'Prevention' in explanation:
                    ai_recommendations.append(explanation)
        
        # General recommendations based on report type
        if report_type == "Security Assessment":
            general_recs = [
                "Monitor DDoS detection score correlations for early threat identification",
                "Implement automated response for high-confidence security correlations",
                "Review security metric thresholds based on correlation patterns",
                "Establish correlation-based alerting for security incidents"
            ]
        elif report_type == "Performance Report":
            general_recs = [
                "Optimize cache hit ratios to improve transaction response times",
                "Scale container resources based on correlation patterns",
                "Implement proactive monitoring for resource utilization correlations",
                "Review database connection pool configurations"
            ]
        else:
            general_recs = [
                "Implement correlation-based alerting for critical system relationships",
                "Review and optimize highly correlated metric thresholds", 
                "Establish regular correlation analysis reports for trend monitoring",
                "Train operations teams on correlation pattern interpretation"
            ]
        
        # Add general recommendations
        elements.append(Paragraph("Strategic Recommendations", self.styles['SubSectionHeader']))
        for rec in general_recs:
            elements.append(Paragraph(f"• {rec}", self.styles['BulletPoint']))
        
        elements.append(Spacer(1, 0.2*inch))
        
        # Add AI-specific recommendations if available
        if ai_recommendations:
            elements.append(Paragraph("AI-Generated Insights", self.styles['SubSectionHeader']))
            elements.append(Paragraph("Based on the AI analysis of current correlations:", self.styles['BodyText']))
            
            for rec in ai_recommendations[:3]:  # Limit to top 3
                elements.append(Paragraph(rec[:200] + "...", self.styles['AIInsightBox']))
        
        return elements
    
    def _create_technical_appendix(self, correlations_data: Dict, summary_data: Dict) -> List:
        """Create technical appendix with detailed data"""
        elements = []
        
        elements.append(PageBreak())
        elements.append(Paragraph("Technical Appendix", self.styles['SectionHeader']))
        
        # Methodology
        elements.append(Paragraph("Correlation Analysis Methodology", self.styles['SubSectionHeader']))
        methodology_text = """
        The correlation analysis employs Pearson correlation coefficients with statistical 
        significance testing. Correlations are calculated using 15-minute time windows with 
        a minimum of 16 data points. Statistical significance is determined using p-values 
        with a threshold of 0.05. Only correlations meeting both confidence (>0.7) and 
        significance criteria are included in the analysis.
        """
        elements.append(Paragraph(methodology_text, self.styles['BodyText']))
        
        # System architecture
        elements.append(Paragraph("System Architecture", self.styles['SubSectionHeader']))
        architecture_text = """
        The banking system consists of 18+ microservices including API Gateway, Authentication, 
        Transaction Processing, Account Management, Fraud Detection, and Notification services. 
        The monitoring stack includes Prometheus for metrics collection, Grafana for visualization, 
        and custom correlation engines for pattern detection.
        """
        elements.append(Paragraph(architecture_text, self.styles['BodyText']))
        
        # Data sources
        elements.append(Paragraph("Data Sources", self.styles['SubSectionHeader']))
        data_sources = [
            "Container resource metrics (CPU, memory, network)",
            "Application performance metrics (response time, throughput)",
            "Database connection and query metrics",
            "Cache hit/miss ratios and efficiency scores",
            "Message queue processing rates and backlogs",
            "DDoS detection scores and security metrics"
        ]
        
        for source in data_sources:
            elements.append(Paragraph(f"• {source}", self.styles['BulletPoint']))
        
        return elements