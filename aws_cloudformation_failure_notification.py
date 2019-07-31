#!/usr/bin/python

"""Python Script to be used by a Lambda Function to Send Notification on SNS
regarding CloudFormation Stacks Failures"""

# Required Imports
import os
import time
import boto3
from botocore.exceptions import ClientError

def get_sns_client(tries=1):
    """Get SNS Client Routine"""

    try:
        return boto3.client('sns')
    except ClientError as exception_obj:
        if exception_obj.response['Error']['Code'] == 'ThrottlingException':
            if tries <= 3:
                print("Throttling Exception Occured.")
                print("Retrying.....")
                print("Attempt No.: " + str(tries))
                time.sleep(3)
                return get_sns_client(tries + 1)
            else:
                print("Attempted 3 Times But No Success.")
                print("Raising Exception.....")
                raise
        else:
            raise

def publish_message_on_sns(sns_client, subject, message, sns_topic_arn, tries=1):
    """Publish Message on SNS Routine"""

    try:
        return sns_client.publish(Subject=subject, Message=message, TopicArn=sns_topic_arn)
    except ClientError as exception_obj:
        if exception_obj.response['Error']['Code'] == 'ThrottlingException':
            if tries <= 3:
                print("Throttling Exception Occured.")
                print("Retrying.....")
                print("Attempt No.: " + str(tries))
                time.sleep(3)
                return publish_message_on_sns(
                    sns_client, subject, message,
                    sns_topic_arn, tries + 1)
            else:
                print("Attempted 3 Times But No Success.")
                print("Raising Exception.....")
                raise
        else:
            raise

def send_cf_failure_notification(event, failure_sns_topic_arn):
    """Send CloudFormation Stack Failure Notification on SNS Routine"""

    print("Creating SNS Client.....")
    sns_client = get_sns_client()

    print("Extracting Out SNS Message from Event.....")
    sns_message = str(event["Records"][0]["Sns"]["Message"])

    print("Extracting Out Event Message.....")
    failure_stack_states = [
        "CREATE_FAILED", "DELETE_FAILED",
        "ROLLBACK_IN_PROGRESS", "UPDATE_ROLLBACK_IN_PROGRESS"]
    for failure_stack_state in failure_stack_states:
        if failure_stack_state in sns_message:
            print("Publishing Message on SNS.....")
            sns_subject = "CloudFormation Stack is in " + failure_stack_state
            publish_message_on_sns(sns_client, sns_subject, sns_message, failure_sns_topic_arn)
            break

    return

def lambda_handler(event, context):
    """Lambda Handler"""

    try:
        print("FUNCTION START")

        send_cf_failure_notification(event, os.getenv("FAILURE_SNS_TOPIC_ARN"))

        print("FUNCTION END")
    except Exception as exception_obj:
        print("ERROR: " + str(exception_obj))

    return None
