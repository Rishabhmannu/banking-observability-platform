"""
PDF Styling Engine for Banking Reports
Professional formatting and color schemes
"""

from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.lib.colors import HexColor, black, white
from reportlab.lib.enums import TA_CENTER, TA_LEFT, TA_RIGHT, TA_JUSTIFY
from reportlab.lib.units import inch

class BankingPDFStyles:
    def __init__(self):
        self.base_styles = getSampleStyleSheet()
        self.setup_colors()
        self.setup_custom_styles()
    
    def setup_colors(self):
        """Define professional color palette"""
        # Professional color scheme
        self.primary_blue = HexColor('#2C3E50')      # Dark blue-gray
        self.secondary_blue = HexColor('#3498DB')     # Bright blue  
        self.success_green = HexColor('#27AE60')      # Success green
        self.warning_orange = HexColor('#F39C12')     # Warning orange
        self.danger_red = HexColor('#E74C3C')         # Error red
        self.light_gray = HexColor('#ECF0F1')         # Light background
        self.dark_gray = HexColor('#7F8C8D')          # Secondary text
        
    def setup_custom_styles(self):
        """Create custom paragraph styles"""
        self.styles = {}
        
        # Title Page Styles
        self.styles['ReportTitle'] = ParagraphStyle(
            name='ReportTitle',
            parent=self.base_styles['Title'],
            fontSize=28,
            textColor=self.primary_blue,
            spaceAfter=30,
            alignment=TA_CENTER,
            fontName='Helvetica-Bold'
        )
        
        self.styles['ReportSubtitle'] = ParagraphStyle(
            name='ReportSubtitle',
            parent=self.base_styles['Normal'],
            fontSize=16,
            textColor=self.dark_gray,
            spaceAfter=20,
            alignment=TA_CENTER,
            fontName='Helvetica'
        )
        
        # Section Headers
        self.styles['SectionHeader'] = ParagraphStyle(
            name='SectionHeader',
            parent=self.base_styles['Heading1'],
            fontSize=18,
            textColor=self.primary_blue,
            spaceBefore=25,
            spaceAfter=15,
            fontName='Helvetica-Bold'
        )
        
        self.styles['SubSectionHeader'] = ParagraphStyle(
            name='SubSectionHeader',
            parent=self.base_styles['Heading2'],
            fontSize=14,
            textColor=self.secondary_blue,
            spaceBefore=15,
            spaceAfter=10,
            fontName='Helvetica-Bold'
        )
        
        # Content Styles
        self.styles['BodyText'] = ParagraphStyle(
            name='BodyText',
            parent=self.base_styles['Normal'],
            fontSize=11,
            spaceBefore=6,
            spaceAfter=6,
            alignment=TA_JUSTIFY,
            fontName='Helvetica'
        )
        
        self.styles['BulletPoint'] = ParagraphStyle(
            name='BulletPoint',
            parent=self.base_styles['Normal'],
            fontSize=11,
            leftIndent=20,
            spaceBefore=3,
            spaceAfter=3,
            fontName='Helvetica'
        )
        
        # Special Content Boxes
        self.styles['ExecutiveSummary'] = ParagraphStyle(
            name='ExecutiveSummary',
            parent=self.base_styles['Normal'],
            fontSize=12,
            leftIndent=15,
            rightIndent=15,
            spaceBefore=10,
            spaceAfter=10,
            borderColor=self.secondary_blue,
            borderWidth=1,
            borderPadding=15,
            fontName='Helvetica'
        )
        
        self.styles['AIInsightBox'] = ParagraphStyle(
            name='AIInsightBox',
            parent=self.base_styles['Normal'],
            fontSize=10,
            leftIndent=20,
            rightIndent=20,
            spaceBefore=8,
            spaceAfter=8,
            borderColor=self.success_green,
            borderWidth=1,
            borderPadding=12,
            fontName='Helvetica'
        )
        
        self.styles['TechnicalNote'] = ParagraphStyle(
            name='TechnicalNote',
            parent=self.base_styles['Normal'],
            fontSize=9,
            textColor=self.dark_gray,
            leftIndent=10,
            spaceBefore=5,
            spaceAfter=5,
            fontName='Helvetica-Oblique'
        )
        
        # Table Styles
        self.styles['TableHeader'] = ParagraphStyle(
            name='TableHeader',
            parent=self.base_styles['Normal'],
            fontSize=10,
            textColor=white,
            alignment=TA_CENTER,
            fontName='Helvetica-Bold'
        )
        
        self.styles['TableCell'] = ParagraphStyle(
            name='TableCell',
            parent=self.base_styles['Normal'],
            fontSize=9,
            alignment=TA_LEFT,
            fontName='Helvetica'
        )
        
        # Footer Style
        self.styles['Footer'] = ParagraphStyle(
            name='Footer',
            parent=self.base_styles['Normal'],
            fontSize=8,
            textColor=self.dark_gray,
            alignment=TA_CENTER,
            fontName='Helvetica'
        )

    def get_table_style(self, header_color=None):
        """Get standard table formatting"""
        from reportlab.platypus import TableStyle
        
        if header_color is None:
            header_color = self.primary_blue
            
        return TableStyle([
            # Header styling
            ('BACKGROUND', (0, 0), (-1, 0), header_color),
            ('TEXTCOLOR', (0, 0), (-1, 0), white),
            ('FONTNAME', (0, 0), (-1, 0), 'Helvetica-Bold'),
            ('FONTSIZE', (0, 0), (-1, 0), 10),
            ('ALIGN', (0, 0), (-1, 0), 'CENTER'),
            
            # Data rows styling
            ('BACKGROUND', (0, 1), (-1, -1), white),
            ('TEXTCOLOR', (0, 1), (-1, -1), black),
            ('FONTNAME', (0, 1), (-1, -1), 'Helvetica'),
            ('FONTSIZE', (0, 1), (-1, -1), 9),
            ('ALIGN', (0, 1), (-1, -1), 'LEFT'),
            
            # Grid and borders
            ('GRID', (0, 0), (-1, -1), 1, self.dark_gray),
            ('VALIGN', (0, 0), (-1, -1), 'MIDDLE'),
            
            # Alternating row colors
            ('ROWBACKGROUNDS', (0, 1), (-1, -1), [white, self.light_gray]),
        ])