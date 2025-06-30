#!/usr/bin/env python3

from flask import Flask, request, jsonify
import json
from datetime import datetime
import os

app = Flask(__name__)

# Create alerts directory
os.makedirs('alerts', exist_ok=True)


@app.route('/webhook', methods=['POST'])
def webhook():
    """Log alerts to file"""
    try:
        data = request.get_json()
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")

        # Write to file
        filename = f"alerts/alert_{timestamp}.json"
        with open(filename, 'w') as f:
            json.dump(data, f, indent=2)

        # Also write human-readable summary
        summary_file = "alerts/alerts_summary.txt"
        with open(summary_file, 'a') as f:
            f.write(f"\n{'='*50}\n")
            f.write(f"ALERT at {datetime.now()}\n")
            f.write(f"{'='*50}\n")

            if data and 'alerts' in data:
                for alert in data['alerts']:
                    alert_name = alert.get('labels', {}).get(
                        'alertname', 'Unknown')
                    status = alert.get('status', 'unknown')
                    f.write(f"Alert: {alert_name}\n")
                    f.write(f"Status: {status}\n")

                    if 'annotations' in alert:
                        summary = alert['annotations'].get(
                            'summary', 'No summary')
                        f.write(f"Summary: {summary}\n")

            f.write(f"Raw data saved to: {filename}\n")

        print(f"📝 Alert logged to {filename}")
        return jsonify({"status": "success"}), 200

    except Exception as e:
        print(f"❌ Error: {e}")
        return jsonify({"status": "error"}), 500


@app.route('/health', methods=['GET'])
def health():
    return jsonify({"status": "healthy"}), 200


if __name__ == '__main__':
    print("📁 File-based webhook receiver starting...")
    print("📂 Alerts will be saved to: ./alerts/")
    app.run(host='0.0.0.0', port=5002)
