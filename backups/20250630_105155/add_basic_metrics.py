#!/usr/bin/env python3
# This script adds basic metrics to a Flask service

import sys
import re

def add_metrics_to_flask_app(app_file):
    with open(app_file, 'r') as f:
        content = f.read()
    
    # Check if already has metrics
    if '/metrics' in content:
        print(f"✅ {app_file} already has metrics endpoint")
        return
    
    # Add prometheus import
    if 'from prometheus_client import' not in content:
        content = content.replace(
            'from flask import', 
            'from flask import Flask, jsonify, request\nfrom prometheus_client import generate_latest, CONTENT_TYPE_LATEST\n# Original imports:\nfrom flask import'
        )
    
    # Add metrics endpoint
    metrics_code = '''
@app.route('/metrics')
def metrics():
    """Basic Prometheus metrics endpoint"""
    return generate_latest(), 200, {'Content-Type': CONTENT_TYPE_LATEST}
'''
    
    # Insert before the final if __name__ == '__main__'
    content = content.replace(
        "if __name__ == '__main__':",
        metrics_code + "\nif __name__ == '__main__':"
    )
    
    with open(app_file, 'w') as f:
        f.write(content)
    
    print(f"✅ Added metrics endpoint to {app_file}")

# Find and update Flask apps
import os
import glob

flask_apps = glob.glob('*/app.py')
for app in flask_apps:
    if os.path.exists(app):
        add_metrics_to_flask_app(app)

print("🔄 Now rebuild services: docker compose up -d --build")
