# AWS Failure Error Warning Termination Notification Framework

-   Founder: Abdullah Khawer (LinkedIn: https://www.linkedin.com/in/abdullah-khawer/)

## Introduction

AWS Failure Error Warning Termination Notification Framework is a framework for AWS cloud to monitor resources for various AWS services and alert for failures, errors, warnings and terminations.

You can update provided variable values to enable or disable notification resources for different AWS services.

By default, all AWS services are disabled and you have to choose which one to enable.

## Supported IaC (Infrastructure as Code) Tools:

- Terraform
- AWS CloudFormation

## Supported AWS Services:

Following are the AWS services for which you can enable notifications for failures, errors, warnings and terminations:

-   `AWS Batch`
-   `AWS CloudFormation (CF)`
-   `AWS CodeBuild (CB)`
-   `AWS CodeDeploy (CD)`
-   `AWS CodePipeline (CP)`
-   `AWS Config`
-   `AWS Data Lifecycle Manager (DLM)`
-   `AWS Database Migration Service (DMS)`
-   `AWS DataSync (DS)`
-   `AWS Elastic Block Store (EBS)`
-   `AWS Elastic Compute Cloud (EC2) Auto Scaling`
-   `AWS Elastic Compute Cloud (EC2)`
-   `AWS Elastic Container Service (ECS)`
-   `AWS Elastic Map Reduce (EMR)`
-   `AWS Elemental`
-   `AWS GameLift (GL)`
-   `AWS Glue`
-   `AWS Health`
-   `AWS Internet of Things (IoT)`
-   `AWS Key Management Service (KMS)`
-   `AWS Lambda`
-   `AWS Macie`
-   `AWS OpsWorks`
-   `AWS Redshift`
-   `AWS Relation Database Service (RDS)`
-   `AWS SageMaker`
-   `AWS Server Migration Service (SMS)`
-   `AWS Signer`
-   `AWS Step Functions (SF)`
-   `AWS Systems Manager (SSM)`
-   `AWS Transcribe`
-   `AWS Trusted Advisor (TA)`

### Any contributions, improvements and suggestions will be highly appreciated.

## Components Used

Following are the components used in this framework:

-   Terraform templates for all of the resources deployment in case you don't want to use AWS CloudFormation templates.
-   AWS CloudFormation templates (both in JSON and YAML) for all of the resources deployment as stack in case you don't want to use Terraform templates.
-   Python script having the logic to manage AWS CloudFormation failures developed in Python 3.9.
-   Boto3 for AWS resources access in Python.
-   AWS Lambda function to execute the above mentioned Python script.
-   AWS IAM role used by the Lambda function with least privileges.
-   AWS Lambda Invoke Permission for AWS SNS topic.
-   AWS CloudWatch events for the failures, errors, warnings and terminations notifications of various AWS services triggered upon events.
-   AWS CloudWatch alarms for the failures of AWS Lambda functions.
-   AWS RDS and DMS event subscriptions for the failures, errors, warnings and terminations of AWS RDS and DMS resources respectively.
-   AWS SNS topic for receiving and sending notifications to the subscribed endpoint for AWS CloudFormation notifications.
-   AWS SNS topic for receiving and sending notifications to the subscribed endpoint for failures, errors, warnings and terminations notifications of various AWS services.
-   AWS SNS topic policies for the above mentioned AWS SNS topics with sufficient permissions to allow publishing of messages on these AWS SNS topics.

## Deployment and Usage Notes

### Using Terraform:

Following are the steps to successfully deploy and use this framework:
-   Fork this repository from the master branch.
-   If you want to enable AWS CloudFormation failures notifications, change default value to `true` for `enable_cloudformation_failure_notification` variable.
-   Similarly, for any AWS service you want to enable failures, errors, warnings and terminations notifications, change default value to `true` for that AWS service's variable that is starting with `enable_...`
-   If `enable_lambda_failure_notification` variable is set to to `true` for AWS Lambda functions failure notifications, you can set a list of specific AWS Lambda functions to enable monitoring only for those using `lambda_function_names` variable. Otherwise, it will fetch all AWS Lambda function names.
-   Configure AWS CLI and then run `terraform init` and then `terraform apply` within the `/terraform` directory and provide protocol (e.g., `email` or `https`) and endpoint (e.g., `abcxyz@gmail.com`) by providing values for `failure_error_warning_termination_notification_sns_topic_protocol` and `failure_error_warning_termination_notification_sns_topic_endpoint` respectively.
-   If the Terraform change plan looks good, enter `yes` to create the resources.
-   Wait for the Terraform to finish creating all the resources.
-   Confirm the subscription of the endpoint to the AWS SNS topic. The method depends on the protocol selected.

### Using AWS CloudFormation:

Following are the steps to successfully deploy and use this framework:
-   Fork this repository from the master branch.
-   Compress `/function/aws_cloudformation_failure_notification.py` file in zip format and put it on AWS S3 bucket.
-   Login to AWS console with IAM user credentials having the required admin privileges to create resources via AWS CloudFormation.
-   Go to AWS CloudFormation and choose to `Create Stack`.
-   Under `Choose a template`, either upload `aws_failure_error_warning_termination_notification_framework_cft.json` or `aws_failure_error_warning_termination_notification_framework_cft.yaml` from here or put it on AWS S3 bucket and enter AWS S3 URL for that file.
-   Enter any suitable `Stack Name`.
-   Enter `FailureErrorWarningTerminationNotificationSNSTopicEndpoint` which is the endpoint where you receive all notifications from AWS SNS topic. (e.g., `abcxyz@gmail.com`).
-   Enter `FailureErrorWarningTerminationNotificationSNSTopicProtocol` which is the protocol used by the endpoint where you receive all notifications from AWS SNS topic. (e.g., `email` or `https`).
-   If you want to enable AWS CloudFormation failures notifications, select `YES` for `EnableCloudFormationFailureNotification` and then specify the following:
    -   Enter `CloudFormationFailureLambdaCodeS3Bucket` which is an AWS S3 Bucket Name having AWS CloudFormation Failure Notification AWS Lambda Function Code. (e.g., my-bucket).
    -   Enter `CloudFormationFailureLambdaCodeS3Key` which is an AWS S3 Bucket Key having AWS CloudFormation Failure Notification AWS Lambda Function Code (e.g., lambda/code/aws_cloudformation_failure_notification.zip).
-   Similarly, for any AWS service you want to enable failures, errors, warnings and terminations notifications, select `YES` for that AWS service's variable that is starting with `Enable...`
-   Enter suitable `Tags` if required.
-   Under `Review`, select `I acknowledge that AWS CloudFormation might create IAM resources with custom names.` and click create.
-   Wait for the stack to change its `Status` to `CREATE_COMPLETE`.
-   Confirm the subscription of the endpoint to the AWS SNS topic. The method depends on the protocol selected.

Voila, you are done and everything is now up and running.

## Troubleshooting Notes

-   In case of no notifications are received or the AWS CloudWatch alarm isn't working, try resubscribing to the AWS SNS topic or updating the notification action in AWS CloudWatch alarm.
-   If some other issue occurs, kindly create an issue on this GitHub repository for its resolution or any help.

### Warning: You will be billed for the AWS resources created by this framework.
