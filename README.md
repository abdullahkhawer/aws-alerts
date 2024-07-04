# AWS Alerts

-   Founder: Abdullah Khawer (LinkedIn: https://www.linkedin.com/in/abdullah-khawer/)

## Introduction

AWS Alerts is a monitoring and alerting solution for AWS cloud to monitor resources for 30+ AWS services and send alerts related to failures, errors, warnings and terminations on Slack.

You can update provided variable values to enable or disable alerts for different AWS services.

By default, all AWS services are disabled and you have to choose which one to enable.

❓ Why did I develop this solution?

Because sometimes infrastructure level alerts can be missed which can be collected more efficiently using AWS CloudWatch events (AWS EventBridge), AWS CloudWatch alarms and AWS service specific event subscriptions but manually creating all the required resources to enable all those alerts can take a lot of time and effort.

Below you can find examples of AWS Alerts on Slack as notifications:
- AWS CloudWatch Event
<img width="482" alt="Screenshot Sample 1" src="https://github.com/abdullahkhawer/aws-alerts/assets/27900716/b5c6e43d-a465-4148-8011-5aa0addd83b6">

- AWS CloudWatch Alarm
<img width="542" alt="Screenshot Sample 2" src="https://github.com/abdullahkhawer/aws-alerts/assets/27900716/db4cb466-261f-48e3-b2ec-078d92639968">

## Supported IaC (Infrastructure as Code) Tools:

- Terraform
- AWS CloudFormation

## Supported AWS Services:

Following are the 30+ AWS services for which you can enable alerts for failures, errors, warnings and terminations notifications:

-   `AWS Batch`
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

## Components Used

Following are the components used in this solution:

-   Terraform template for all of the resources deployment in case you don't want to use AWS CloudFormation template.
-   AWS CloudFormation template for all of the resources deployment as stack in case you don't want to use Terraform template.
-   Python script developed in Python 3.12 having the logic to send formatted AWS Alerts to Slack.
-   Boto3 for AWS resources access in Python.
-   AWS Lambda function to execute the above mentioned Python script.
-   AWS IAM role used by the Lambda function with least privileges.
-   AWS Lambda Invoke Permission for AWS SNS topic.
-   AWS CloudWatch events for the failures, errors, warnings and terminations alerts of various AWS services triggered upon events.
-   AWS CloudWatch alarms for the failures of AWS Lambda functions.
-   AWS RDS and DMS event subscriptions for the failures, errors, warnings and terminations of AWS RDS and DMS resources respectively.
-   AWS SNS topic for receiving and sending alerts to Slack for failures, errors, warnings and terminations alerts of various AWS services.
-   AWS SNS topic policy for the above mentioned AWS SNS topic with sufficient permissions to allow publishing of messages on this AWS SNS topic.

## Prerequisites

Following are the prerequisites to be met once before you begin:

- Following tools should be installed on your system:
    - Git
    - AWS CLI
    - Terraform
    - Python 3.12 with `pip`
- A Slack Webhook URL is created for the channel where you want to receive the alerts either using general incoming webhook or app incoming webhook.
- A parameter should be created on AWS SSM Parameter Store with the name of your choice and it should have the Slack Webhook URL as its value.

## Deployment and Usage Notes

### Using Terraform:

Following are the steps to successfully deploy and use this solution:
-   Fork this repository from the master branch.
-   Use `terraform-usage-example.tf` file to create `main.tf` file for your infrastructure as needed.
-   Set the value for the `slack_webhook_url_aws_ssm_parameter_name` variable to the name of the AWS SSM Parameter name from the Parameter Store which is having Slack Webhook URL.
-   For any AWS service that you want to enable alerts for failures, errors, warnings and/or terminations notifications, set the value to `true` for its variable that is starting with the prefix `enable_...` (e.g., `enable_rds_failure_warning_alerts`). By default, all are set to `false`.
-   If `enable_lambda_failure_alerts` variable is set to to `true` for AWS Lambda functions' failure alerts, you can set a list of specific AWS Lambda functions to enable monitoring only for them by using `lambda_function_names` variable. Otherwise, it will fetch all the AWS Lambda function names.
-   Configure AWS CLI and then run `terraform init` and then `terraform apply`.
-   If the Terraform change plan looks good, enter `yes` to create the resources.
-   Wait for the Terraform to finish creating all the resources.

### Using AWS CloudFormation:

Following are the steps to successfully deploy and use this solution:
-   Fork this repository from the master branch.
-   Run the following command to install the Python libraries: `pip3 install -r ./function/requirements.txt -t ./function --no-cache-dir --upgrade`
-   Compress whatever is inside the `function` directory into a `.zip` file and put it on an AWS S3 bucket.
-   Login to AWS console with IAM user credentials having the required permissions to create resources via AWS CloudFormation.
-   Go to AWS CloudFormation and click on `Create Stack` button and then select `With new resources (standard)` option.
-   Under `Choose a template`, either upload `aws_alerts_cft.yaml` file from the `cloudformation` directory or upload it on an AWS S3 bucket and enter its AWS S3 object URL.
-   Enter any suitable value for `Stack Name`.
-   Enter value for `SlackWebhookURLAWSSSMParameterName` which is the name of the AWS SSM Parameter Name from the Parameter Store which is having Slack Webhook URL.
-   Enter value for `AWSAlertsLambdaCodeS3Bucket` which is an AWS S3 Bucket Name having AWS Alerts Lambda Function Code. (e.g., `my-bucket`).
-   Enter value for `AWSAlertsLambdaCodeS3ObjectKey` which is an AWS S3 Bucket Object Key having AWS Alerts Lambda Function Code (e.g., `lambda/code/aws_alerts.zip`).
-   For any AWS service that you want to enable alerts for failures, errors, warnings and/or terminations notifications, select `YES` for its variable that is starting with the prefix `Enable...` (e.g., `EnableCloudFormationFailureAlerts`). By default, all have `YES` selected.
-   Enter any suitable value for `Tags` if required.
-   Change extra configurations if required.
-   Under `Review`, select `I acknowledge that AWS CloudFormation might create IAM resources with custom names.` and click `Create`.
-   Wait for the stack to change its `Status` to `CREATE_COMPLETE`.

Note: You can subscribe other endpoints to the AWS SNS topic created for alerts if needed.

## Troubleshooting Notes

-   If no notifications are received or the AWS CloudWatch alarm isn't working, try resubscribing to the AWS SNS topic or updating the notification action in AWS CloudWatch alarm.
-   If some other issue occurs, kindly create an issue on this GitHub repository for its resolution or any help.

### Any contributions, improvements and suggestions will be highly appreciated.
