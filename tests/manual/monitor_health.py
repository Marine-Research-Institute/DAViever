#!/usr/bin/env python3
"""
Health Monitoring Script for MARBEFES BBT Database

This script monitors the application health endpoint and can be used for:
- Automated monitoring and alerting
- Integration with monitoring systems (Nagios, Prometheus, etc.)
- Scheduled health checks via cron

Usage:
    python monitor_health.py                          # Check localhost:5000
    python monitor_health.py --url http://host:port   # Custom URL
    python monitor_health.py --slack-webhook URL      # Send Slack alerts
    python monitor_health.py --email user@domain.com  # Send email alerts

Exit codes:
    0 - Healthy
    1 - Degraded (some services down)
    2 - Unhealthy (critical failure)
    3 - Connection error
"""

import argparse
import json
import sys
import time
from datetime import datetime
from typing import Dict, Any, Optional
import urllib.request
import urllib.error
import smtplib
from email.mime.text import MIMEText


class HealthMonitor:
    """Monitor application health and send alerts"""

    def __init__(self, base_url: str = "http://localhost:5000"):
        self.base_url = base_url.rstrip('/')
        self.health_url = f"{self.base_url}/health"

    def check_health(self) -> tuple[int, Dict[str, Any]]:
        """
        Check application health endpoint

        Returns:
            Tuple of (status_code, health_data)
        """
        try:
            req = urllib.request.Request(
                self.health_url,
                headers={'User-Agent': 'MARBEFES-Health-Monitor/1.0'}
            )

            with urllib.request.urlopen(req, timeout=10) as response:
                status_code = response.getcode()
                data = json.loads(response.read().decode('utf-8'))
                return status_code, data

        except urllib.error.HTTPError as e:
            # Server responded with error status
            try:
                data = json.loads(e.read().decode('utf-8'))
                return e.code, data
            except:
                return e.code, {"error": str(e)}

        except urllib.error.URLError as e:
            # Connection error
            return 3, {"error": f"Connection failed: {e.reason}"}

        except Exception as e:
            # Other error
            return 3, {"error": f"Unexpected error: {str(e)}"}

    def format_health_report(self, status_code: int, health_data: Dict[str, Any]) -> str:
        """Format health check results as human-readable report"""

        lines = []
        lines.append("=" * 60)
        lines.append("MARBEFES BBT Database - Health Check Report")
        lines.append("=" * 60)
        lines.append(f"Timestamp: {datetime.now().isoformat()}")
        lines.append(f"URL: {self.health_url}")
        lines.append("")

        if status_code == 3:
            lines.append("❌ STATUS: CONNECTION FAILED")
            lines.append(f"Error: {health_data.get('error', 'Unknown error')}")
            lines.append("=" * 60)
            return "\n".join(lines)

        # Overall status
        overall_status = health_data.get('status', 'unknown')
        status_emoji = {
            'healthy': '✅',
            'degraded': '⚠️',
            'unhealthy': '❌'
        }.get(overall_status, '❓')

        lines.append(f"{status_emoji} OVERALL STATUS: {overall_status.upper()}")
        lines.append(f"HTTP Status Code: {status_code}")
        lines.append(f"Version: {health_data.get('version', 'unknown')}")
        lines.append("")

        # Component status
        components = health_data.get('components', {})
        if components:
            lines.append("Component Status:")
            lines.append("-" * 60)

            for component_name, component_info in components.items():
                if isinstance(component_info, dict):
                    comp_status = component_info.get('status', 'unknown')
                    comp_emoji = {
                        'operational': '✅',
                        'degraded': '⚠️',
                        'error': '❌',
                        'disabled': '⚪',
                        'no_data': '⚪'
                    }.get(comp_status, '❓')

                    lines.append(f"  {comp_emoji} {component_name}: {comp_status}")

                    # Show additional details
                    if 'url' in component_info:
                        lines.append(f"      URL: {component_info['url']}")
                    if 'error' in component_info and component_info['error']:
                        lines.append(f"      Error: {component_info['error']}")
                    if 'layer_count' in component_info:
                        lines.append(f"      Layers: {component_info['layer_count']}")
                    if 'available' in component_info:
                        lines.append(f"      Available: {component_info['available']}")

        lines.append("=" * 60)
        return "\n".join(lines)

    def send_slack_alert(self, webhook_url: str, status_code: int, health_data: Dict[str, Any]):
        """Send alert to Slack webhook"""
        status = health_data.get('status', 'unknown')
        color_map = {
            'healthy': 'good',
            'degraded': 'warning',
            'unhealthy': 'danger'
        }

        message = {
            "text": f"MARBEFES BBT Database Health Alert",
            "attachments": [{
                "color": color_map.get(status, 'danger'),
                "title": f"Status: {status.upper()}",
                "text": f"HTTP Status: {status_code}\nURL: {self.health_url}",
                "fields": [],
                "footer": "MARBEFES Health Monitor",
                "ts": int(time.time())
            }]
        }

        # Add component details
        components = health_data.get('components', {})
        for comp_name, comp_info in components.items():
            if isinstance(comp_info, dict):
                comp_status = comp_info.get('status', 'unknown')
                message["attachments"][0]["fields"].append({
                    "title": comp_name,
                    "value": comp_status,
                    "short": True
                })

        # Send to Slack
        try:
            data = json.dumps(message).encode('utf-8')
            req = urllib.request.Request(
                webhook_url,
                data=data,
                headers={'Content-Type': 'application/json'}
            )
            urllib.request.urlopen(req)
            print("✅ Slack alert sent successfully")
        except Exception as e:
            print(f"❌ Failed to send Slack alert: {e}")

    def send_email_alert(self, to_email: str, status_code: int, health_data: Dict[str, Any],
                        smtp_host: str = 'localhost', smtp_port: int = 25):
        """Send alert via email"""
        status = health_data.get('status', 'unknown')

        subject = f"MARBEFES BBT Database Health Alert - {status.upper()}"
        body = self.format_health_report(status_code, health_data)

        msg = MIMEText(body)
        msg['Subject'] = subject
        msg['From'] = 'marbefes-monitor@localhost'
        msg['To'] = to_email

        try:
            with smtplib.SMTP(smtp_host, smtp_port) as server:
                server.send_message(msg)
            print(f"✅ Email alert sent to {to_email}")
        except Exception as e:
            print(f"❌ Failed to send email alert: {e}")


def main():
    parser = argparse.ArgumentParser(
        description='Monitor MARBEFES BBT Database health endpoint'
    )
    parser.add_argument(
        '--url',
        default='http://localhost:5000',
        help='Base URL of the application (default: http://localhost:5000)'
    )
    parser.add_argument(
        '--slack-webhook',
        help='Slack webhook URL for alerts'
    )
    parser.add_argument(
        '--email',
        help='Email address for alerts'
    )
    parser.add_argument(
        '--smtp-host',
        default='localhost',
        help='SMTP server host (default: localhost)'
    )
    parser.add_argument(
        '--smtp-port',
        type=int,
        default=25,
        help='SMTP server port (default: 25)'
    )
    parser.add_argument(
        '--quiet',
        action='store_true',
        help='Suppress output (only return exit code)'
    )
    parser.add_argument(
        '--json',
        action='store_true',
        help='Output results as JSON'
    )

    args = parser.parse_args()

    # Create monitor
    monitor = HealthMonitor(args.url)

    # Check health
    status_code, health_data = monitor.check_health()

    # Determine exit code based on status
    exit_code = 0
    overall_status = health_data.get('status', 'unknown')

    if status_code == 3:
        exit_code = 3  # Connection error
    elif overall_status == 'degraded':
        exit_code = 1  # Degraded
    elif overall_status == 'unhealthy' or status_code >= 500:
        exit_code = 2  # Unhealthy
    elif status_code == 200:
        exit_code = 0  # Healthy
    else:
        exit_code = 2  # Unknown/error

    # Output results
    if not args.quiet:
        if args.json:
            output = {
                'status_code': status_code,
                'exit_code': exit_code,
                'health_data': health_data,
                'timestamp': datetime.now().isoformat()
            }
            print(json.dumps(output, indent=2))
        else:
            print(monitor.format_health_report(status_code, health_data))

    # Send alerts if configured
    if args.slack_webhook and exit_code > 0:
        monitor.send_slack_alert(args.slack_webhook, status_code, health_data)

    if args.email and exit_code > 0:
        monitor.send_email_alert(args.email, status_code, health_data,
                                args.smtp_host, args.smtp_port)

    sys.exit(exit_code)


if __name__ == '__main__':
    main()
