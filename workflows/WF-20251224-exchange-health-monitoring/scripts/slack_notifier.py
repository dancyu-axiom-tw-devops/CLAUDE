#!/usr/bin/env python3
"""
Slack Notifier for Exchange Service Health Check
"""

import requests
import logging
from typing import Dict, Any, Optional

logger = logging.getLogger(__name__)


class SlackNotifier:
    """Send notifications to Slack"""

    def __init__(self, bot_token: Optional[str] = None, webhook_url: Optional[str] = None):
        """Initialize Slack notifier"""
        self.bot_token = bot_token
        self.webhook_url = webhook_url

    def send_report(self, markdown_report: str, channel: str = '#sre-alerts') -> bool:
        """Send health check report to Slack"""
        if self.webhook_url:
            return self._send_webhook(markdown_report)
        elif self.bot_token:
            return self._send_api(markdown_report, channel)
        else:
            logger.error("No Slack credentials configured")
            return False

    def _send_webhook(self, text: str) -> bool:
        """Send via Slack webhook"""
        try:
            payload = {'text': text}
            response = requests.post(self.webhook_url, json=payload, timeout=10)
            response.raise_for_status()
            logger.info("Sent report via Slack webhook")
            return True
        except Exception as e:
            logger.error(f"Failed to send Slack webhook: {e}")
            return False

    def _send_api(self, text: str, channel: str) -> bool:
        """Send via Slack API"""
        try:
            url = 'https://slack.com/api/chat.postMessage'
            headers = {
                'Authorization': f'Bearer {self.bot_token}',
                'Content-Type': 'application/json',
            }
            payload = {
                'channel': channel,
                'text': text,
                'mrkdwn': True,
            }
            response = requests.post(url, headers=headers, json=payload, timeout=10)
            response.raise_for_status()
            data = response.json()
            if data.get('ok'):
                logger.info(f"Sent report to Slack channel {channel}")
                return True
            else:
                logger.error(f"Slack API error: {data.get('error')}")
                return False
        except Exception as e:
            logger.error(f"Failed to send Slack API message: {e}")
            return False
