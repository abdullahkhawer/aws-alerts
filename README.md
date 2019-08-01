# AWS Failure Error Warning Termination Notification Framework

-   Founder: Abdullah Khawer (LinkedIn: https://www.linkedin.com/in/abdullah-khawer/)
-   Version: v1.0

## Introduction

AWS Failure Error Warning Termination Notification Framework is an AWS based failure, error, warning and termination notification solution for various services under one AWS CloudFormation stack using AWS CloudWatch events for failures, errors, warnings and terminations of resources of various AWS services, AWS CloudWatch alarm for AWS Lambda function failures, AWS Lambda Function using a Python script that is using Boto3 to publish AWS CloudFormation failures on AWS SNS topic and AWS DMS and AWS RDS event subscriptions for failures, errors and terminations.

Following are the AWS services for which you can enable failures, errors, warnings and terminations notifications:
-   **AWS Batch**
-   **AWS CloudFormation (CF)**
-   **AWS CodeBuild (CB)**
-   **AWS CodeDeploy (CD)**
-   **AWS CodePipeline (CP)**
-   **AWS Config**
-   **AWS Data Lifecycle Manager (DLM)**
-   **AWS DataSync (DS)**
-   **AWS Database Migration Service (DMS)**
-   **AWS Elastic Block Store (EBS)**
-   **AWS Elastic Compute Cloud (EC2) Auto Scaling**
-   **AWS Elastic Compute Cloud (EC2)**
-   **AWS Elastic Container Service (ECS)**
-   **AWS Elemental**
-   **AWS Elastic Map Reduce (EMR)**
-   **AWS GameLift (GL)**
-   **AWS Glue**
-   **AWS Health**
-   **AWS Internet of Things (IoT)**
-   **AWS Key Management Service (KMS)**
-   **AWS Lambda**
-   **AWS Macie**
-   **AWS OpsWorks**
-   **AWS Relation Database Service (RDS)**
-   **AWS SageMaker**
-   **AWS Signer**
-   **AWS Server Migration Service (SMS)**
-   **AWS Systems Manager (SSM)**
-   **AWS Step Functions (SF)**
-   **AWS Transcribe**
-   **AWS Trusted Advisor (TA)**

You can even disable the created AWS CloudWatch events, AWS CloudWatch alarm, DMS and RDS subscriptions in a single click without deleting its AWS CloudFormation stack for different AWS services but that may create a stack drift. You can also update the stack to add or remove notification resources for different AWS services on the basis of the values of the stack parameters.

AWS Lambda function used for AWS CloudFormation failures management is using Python 3.7 as its runtime environment.

### Any contributions, improvements and suggestions will be highly appreciated.

## Components Used

Following are the components used in this framework:
-   AWS CloudFormation template (both in JSON and YAML) for stack deployment.
-   Python script having the logic to manage AWS CloudFormation failures developed in Python 3.7.
-   Boto3 for AWS resources access in Python.
-   AWS Lambda function to execute the above mentioned Python script.
-   AWS IAM role used by the Lambda function with least privileges.
-   AWS Lambda Invoke Permission for AWS SNS topic.
-   AWS CloudWatch events for the failures, errors, warnings and terminations notifications of various AWS services triggered upon events.
-   AWS CloudWatch alarm for the failures of AWS Lambda functions.
-   AWS RDS and DMS event subscriptions for the failures, errors, warnings and terminations of AWS RDS and DMS resources respectively.
-   AWS SNS topic for receiving and sending notifications to an email based subscribed endpoint for AWS CloudFormation notifications.
-   AWS SNS topic for receiving and sending notifications to an email based subscribed endpoint for failures, errors, warnings and terminations notifications of various AWS services.
-   AWS SNS topic policies for the above mentioned AWS SNS topics with sufficient permissions to allow publishing of messages on these AWS SNS topics.

## Deployment and Usage Notes

Following are the steps to successfully deploy and use this framework:
-   Clone this repository from the master branch.
-   Compress **aws_cloudformation_failure_notification.py** file in zip format and put it on AWS S3 bucket.
-   Login to AWS console with IAM user credentials having the required admin privileges to create resources via AWS CloudFormation.
-   Go to AWS CloudFormation and choose to **Create Stack**.
-   Under **Choose a template**, either upload **aws_failure_error_warning_termination_notification_framework_cft.json** or **aws_failure_error_warning_termination_notification_framework_cft.yaml** from here or put it on AWS S3 bucket and enter AWS S3 URL for that file.
-   Enter any suitable **Stack Name**.
-   Enter **FailureErrorWarningTerminationNotificationSNSTopicEmail** which is the email address where you receive all notifications from AWS SNS topic. (e.g., abcxyz@gmail.com).
-   If you want to enable AWS CloudFormation failures notifications, select yes for **EnableCloudFormationFailureNotification** and then specify the following:
    -   Enter **CloudFormationFailureLambdaCodeS3Bucket** which is an AWS S3 Bucket Name having AWS CloudFormation Failure Notification AWS Lambda Function Code. (e.g., my-bucket).
    -   Enter **CloudFormationFailureLambdaCodeS3Key** which is an AWS S3 Bucket Key having AWS CloudFormation Failure Notification AWS Lambda Function Code (e.g., lambda/code/aws_cloudformation_failure_notification.zip).
-   Similarly, for which ever AWS service you want to enable failures, errors, warnings and terminations notifications, select yes for that AWS service's parameter that is starting with **Enable...**
-   Enter suitable **Tags** if required.
-   Under **Review**, select **I acknowledge that AWS CloudFormation might create IAM resources with custom names.** and click create.
-   Wait for the stack to change its **Status** to **CREATE_COMPLETE**.
-   Confirm the subscription to the AWS SNS topic by either clicking on the URL received on the email address specified above during deployment or confirming the subscription from AWS SNS console.
-   Voila, you are done and everything is now up and running.

*NOTE: For AWS CloudFormation, AWS DataPipeline, AWS S3 for Object in RRS lost, any other AWS service that is not covered and supports failures notifications or any other custom notification solution that you have built, refer the following AWS SNS topic that is created for the sole purpose of the receival of failures, errors, warnings and terminations notifications and that is **failure-error-warning-termination-notification-sns-topic**.*

## Troubleshooting Notes

-   If the email is not receiving email or the AWS CloudWatch alarm isn't working, try resubscribing to the AWS SNS topic or updating the notification action in AWS CloudWatch alarm.
-   If some other issue occurs, kindly create an issue on this GitHub repository for its resolution or any help assistance.

### Warning: You will be billed for the AWS resources used if you create a stack for this framework.
