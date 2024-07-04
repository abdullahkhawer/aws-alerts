#!/usr/bin/python

"""Python script to be used by an AWS Lambda function to send alerts to AWS SNS topic."""

# Required imports
import os
import sys
import json
import requests
import boto3
from botocore.config import Config

def lambda_handler(event, context):
    """AWS Lambda Function Handler"""

    print("Creating AWS SSM client...")
    ssm_client = boto3.client(
        'ssm',
        config=Config(
            connect_timeout=5,
            read_timeout=60,
            retries={'max_attempts': 5}
        )
    )

    print("Fetching Slack Webhook URL from AWS SSM Parameter Store...")
    slack_webhook_url = ssm_client.get_parameter(
        Name=os.getenv("SLACK_WEBHOOK_URL_AWS_SSM_PARAMETER_NAME"),
        WithDecryption=True
    )['Parameter']['Value']

    print("Extracting data from the event and formatting it...")
    event_subject = str(event['Records'][0]['Sns']['Subject'])
    event_message = str(event['Records'][0]['Sns']['Message'])
    event_message_json = json.loads(event_message)
    if event_subject == "None":
        if 'name' in event_message_json and 'region' in event_message_json:
            event_name = str(event_message_json['name'])
            event_region = str(event_message_json['region'])
            event_subject = f"EVENT: '{event_name}' in {event_region}"
        else:
            event_subject = "EVENT"
    keys_to_remove = [
        'AlarmActions',
        'AlarmConfigurationUpdatedTimestamp',
        'InsufficientDataActions',
        'NewStateReason',
        'NewStateValue',
        'OKActions',
        'OldStateValue',
        'StateChangeTime',
        'time'
    ]
    for key in keys_to_remove:
        if key in event_message_json:
            event_message_json.pop(key, None)
    keys_to_remove_from_trigger = [
        'ComparisonOperator',
        'EvaluateLowSampleCountPercentile',
        'EvaluationPeriods',
        'StatisticType',
        'Threshold',
        'TreatMissingData',
        'Unit'
    ]
    if 'Trigger' in event_message_json and isinstance(event_message_json['Trigger'], dict):
        for key in keys_to_remove_from_trigger:
            if key in event_message_json['Trigger']:
                event_message_json['Trigger'].pop(key, None)
    keys_to_remove_from_details = [
        'ActivityId',
        'additional-information',
        'current-phase-context',
        'current-phase',
        'EndTime',
        'RequestId',
        'StartTime',
        'version'
    ]
    if 'details' in event_message_json and isinstance(event_message_json['details'], dict):
        for key in keys_to_remove_from_details:
            if key in event_message_json['details']:
                event_message_json['details'].pop(key, None)
    event_message_formatted = f"```{json.dumps(event_message_json, indent=4)}```"

    print("Sending the alert to Slack...")
    slack_data = {
        "attachments": [
            {
                "pretext": "*AWS Alert*",
                "title": f":warning: Alert: {event_subject}",
                "text": f":exclamation: *Description:* {event_message_formatted}",
                "color": "#ff0000"
            }
        ]
    }
    try:
        response = requests.post(
            slack_webhook_url,
            data=json.dumps(slack_data),
            headers={'Content-Type': "application/json"},
            timeout=10)
        response.raise_for_status()
        print("The alert is sent to Slack successfully.")
    except Exception as err:
        print("ERROR: Failed to send the alert to Slack.")
        print(f'ERROR: {err}')
        sys.exit(1)
