data "aws_caller_identity" "current" {}

data "aws_lambda_functions" "all" {}

data "aws_region" "current" {}

locals {
  lambda_function_names         = length(var.lambda_function_names) == 0 ? data.aws_lambda_functions.all.function_names : var.lambda_function_names
  lambda_function_build_command = "pip3 install -r ${path.module}/../function/requirements.txt -t ${path.module}/../function --no-cache-dir --upgrade"
}

resource "aws_sns_topic" "aws_alerts_sns_topic" {
  name = "aws-alerts-sns-topic"
}

resource "aws_sns_topic_policy" "aws_alerts_sns_topic_policy" {
  arn = aws_sns_topic.aws_alerts_sns_topic.arn

  policy = jsonencode({
    Version = "2012-10-17"
    Id      = "Pid1"
    Statement = [
      {
        Sid    = "Sid1"
        Effect = "Allow"
        Principal = {
          AWS = "*"
        }
        Action = [
          "SNS:Publish",
          "SNS:RemovePermission",
          "SNS:SetTopicAttributes",
          "SNS:DeleteTopic",
          "SNS:ListSubscriptionsByTopic",
          "SNS:GetTopicAttributes",
          "SNS:Receive",
          "SNS:AddPermission",
          "SNS:Subscribe"
        ]
        Resource = aws_sns_topic.aws_alerts_sns_topic.id
        Condition = {
          StringEquals = {
            "AWS:SourceOwner" = data.aws_caller_identity.current.account_id
          }
        }
      },
      {
        Sid    = "Sid2"
        Effect = "Allow"
        Principal = {
          Service = [
            "datapipeline.amazonaws.com",
            "dms.amazonaws.com",
            "events.amazonaws.com",
            "lambda.amazonaws.com",
            "cloudwatch.amazonaws.com",
            "monitoring.rds.amazonaws.com",
            "rds.amazonaws.com",
            "s3.amazonaws.com"
          ]
        }
        Action = [
          "SNS:Publish"
        ]
        Resource = aws_sns_topic.aws_alerts_sns_topic.id
      }
    ]
  })
}

resource "aws_iam_role" "aws_alerts_lambda_iam_role" {
  name = "aws-alerts-lambda-iam-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = ""
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  inline_policy {
    name = "AWSAlertsLambdaFunctionIAMPolicy"

    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Effect = "Allow"
          Action = [
            "logs:CreateLogStream",
            "logs:CreateLogGroup",
            "logs:PutLogEvents",
            "ssm:DescribeParameters"
          ]
          Resource = "*"
        },
        {
          Effect = "Allow"
          Action = [
            "ssm:GetParameterHistory",
            "ssm:GetParametersByPath",
            "ssm:GetParameters",
            "ssm:GetParameter"
          ]
          Resource = "arn:aws:ssm:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:parameter${var.slack_webhook_url_aws_ssm_parameter_name}"
        }
      ]
    })
  }
}

resource "aws_lambda_function" "aws_alerts_lambda_function" {
  depends_on = [
    null_resource.local_package,
    data.archive_file.lambda
  ]

  function_name = "aws-alerts-lambda-function"
  description   = "AWS Lambda function based on Python 3.12 to send alerts to AWS SNS."
  role          = aws_iam_role.aws_alerts_lambda_iam_role.arn
  handler       = "aws_alerts_lambda_function.lambda_handler"
  runtime       = "python3.12"
  timeout       = 30
  memory_size   = 128

  environment {
    variables = {
      SLACK_WEBHOOK_URL_AWS_SSM_PARAMETER_NAME = var.slack_webhook_url_aws_ssm_parameter_name
    }
  }

  source_code_hash = data.archive_file.lambda.output_base64sha256
  filename         = data.archive_file.lambda.output_path

  tags = {
    Name = "aws-alerts-lambda-function"
  }
}

resource "null_resource" "local_package" {
  triggers = {
    run_on_requirements_change = filemd5("${path.module}/../function/requirements.txt")
    run_on_code_change         = filemd5("${path.module}/../function/aws_alerts_lambda_function.py")
    run_on_command_change      = md5(local.lambda_function_build_command)
  }

  provisioner "local-exec" {
    command = local.lambda_function_build_command
  }
}

data "archive_file" "lambda" {
  depends_on       = [null_resource.local_package]
  type             = "zip"
  source_dir       = "${path.module}/../function/"
  output_file_mode = "0666"
  output_path      = "${path.module}/../code.zip"
}

resource "aws_sns_topic_subscription" "aws_alerts_sns_topic_subscription" {
  topic_arn = aws_sns_topic.aws_alerts_sns_topic.arn
  protocol  = "lambda"
  endpoint  = aws_lambda_function.aws_alerts_lambda_function.arn
}

resource "aws_lambda_permission" "lambda_invoke_permission" {
  function_name = aws_lambda_function.aws_alerts_lambda_function.arn
  action        = "lambda:InvokeFunction"
  principal     = "sns.amazonaws.com"
  source_arn    = aws_sns_topic.aws_alerts_sns_topic.id
}

resource "aws_cloudwatch_metric_alarm" "lambda_failure_cloud_watch_alarm" {
  count = var.enable_lambda_failure_alerts ? length(local.lambda_function_names) : 0

  alarm_name          = "aws-alerts-lambda-function-${local.lambda_function_names[count.index]}-failure-alarm"
  alarm_description   = "AWS CloudWatch Alarm to send alerts on AWS SNS regarding AWS Lambda function failures for '${local.lambda_function_names[count.index]}' function."
  namespace           = "AWS/Lambda"
  metric_name         = "Errors"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "1"
  period              = "60"
  statistic           = "Sum"
  threshold           = "1"
  treat_missing_data  = "missing"

  dimensions = {
    FunctionName = local.lambda_function_names[count.index]
  }

  alarm_actions = [
    aws_sns_topic.aws_alerts_sns_topic.id
  ]
}

resource "aws_dms_event_subscription" "dms_instance_failure_event" {
  count = var.enable_dms_failure_warning_alerts ? 1 : 0
  name  = "dms-instance-failure-warning-event"
  event_categories = [
    "failure",
    "low storage",
    "failover",
    "deletion"
  ]
  sns_topic_arn = aws_sns_topic.aws_alerts_sns_topic.id
  source_type   = "replication-instance"
  tags = {
    Name = "dms-instance-failure-event"
  }
}

resource "aws_dms_event_subscription" "dms_task_failure_event" {
  count = var.enable_dms_failure_warning_alerts ? 1 : 0
  name  = "dms-task-failure-event"
  event_categories = [
    "failure",
    "deletion"
  ]
  sns_topic_arn = aws_sns_topic.aws_alerts_sns_topic.id
  source_type   = "replication-task"
  tags = {
    Name = "dms-task-failure-event"
  }
}

resource "aws_db_event_subscription" "db_instance_failure_warning_event" {
  count       = var.enable_rds_failure_warning_alerts ? 1 : 0
  name        = "aws-rds-event-subscription-db-instance-failure-warning-event"
  sns_topic   = aws_sns_topic.aws_alerts_sns_topic.arn
  source_type = "db-instance"

  event_categories = [
    "low storage",
    "failover",
    "failure"
  ]
}

resource "aws_db_event_subscription" "db_security_group_failure_warning_event" {
  count       = var.enable_rds_failure_warning_alerts ? 1 : 0
  name        = "aws-rds-event-subscription-db-security-group-failure-warning-event"
  sns_topic   = aws_sns_topic.aws_alerts_sns_topic.arn
  source_type = "db-security-group"

  event_categories = [
    "failure"
  ]
}

resource "aws_db_event_subscription" "db_cluster_failure_warning_event" {
  count       = var.enable_rds_failure_warning_alerts ? 1 : 0
  name        = "aws-rds-event-subscription-db-cluster-failure-warning-event"
  sns_topic   = aws_sns_topic.aws_alerts_sns_topic.arn
  source_type = "db-cluster"

  event_categories = [
    "failover",
    "failure",
    "global-failover"
  ]
}

resource "aws_db_event_subscription" "custom_engine_version_failure_warning_event" {
  count       = var.enable_rds_failure_warning_alerts ? 1 : 0
  name        = "aws-rds-event-subscription-custom-engine-version-failure-warning-event"
  sns_topic   = aws_sns_topic.aws_alerts_sns_topic.arn
  source_type = "custom-engine-version"

  event_categories = [
    "failure"
  ]
}

resource "aws_db_event_subscription" "blue_green_deployment_failure_warning_event" {
  count       = var.enable_rds_failure_warning_alerts ? 1 : 0
  name        = "aws-rds-event-subscription-blue-green-deployment-failure-warning-event"
  sns_topic   = aws_sns_topic.aws_alerts_sns_topic.arn
  source_type = "blue-green-deployment"

  event_categories = [
    "failure"
  ]
}

resource "aws_redshift_event_subscription" "cluster_error_event" {
  count         = var.enable_redshift_error_alerts ? 1 : 0
  name          = "aws-redshift-event-subscription-cluster-error-event"
  sns_topic_arn = aws_sns_topic.aws_alerts_sns_topic.arn
  source_type   = "cluster"
  severity      = "ERROR"
}

resource "aws_redshift_event_subscription" "cluster_parameter_group_error_event" {
  count         = var.enable_redshift_error_alerts ? 1 : 0
  name          = "aws-redshift-event-subscription-cluster-parameter-group-error-event"
  sns_topic_arn = aws_sns_topic.aws_alerts_sns_topic.arn
  source_type   = "cluster-parameter-group"
  severity      = "ERROR"
}

resource "aws_redshift_event_subscription" "cluster_security_group_error_event" {
  count         = var.enable_redshift_error_alerts ? 1 : 0
  name          = "aws-redshift-event-subscription-cluster-security-group-error-event"
  sns_topic_arn = aws_sns_topic.aws_alerts_sns_topic.arn
  source_type   = "cluster-security-group"
  severity      = "ERROR"
}

resource "aws_redshift_event_subscription" "cluster_snapshot_error_event" {
  count         = var.enable_redshift_error_alerts ? 1 : 0
  name          = "aws-redshift-event-subscription-cluster-snapshot-error-event"
  sns_topic_arn = aws_sns_topic.aws_alerts_sns_topic.arn
  source_type   = "cluster-snapshot"
  severity      = "ERROR"
}

resource "aws_redshift_event_subscription" "scheduled_action_error_event" {
  count         = var.enable_redshift_error_alerts ? 1 : 0
  name          = "aws-redshift-event-subscription-scheduled-action-error-event"
  sns_topic_arn = aws_sns_topic.aws_alerts_sns_topic.arn
  source_type   = "scheduled-action"
  severity      = "ERROR"
}

resource "aws_cloudwatch_event_rule" "cb_failure_cloud_watch_event" {
  count       = var.enable_code_build_failure_alerts ? 1 : 0
  name        = "cb-failure-cloudwatch-event"
  description = "AWS CloudWatch Event to send alerts on AWS SNS regarding AWS CodeBuild Failures."
  event_pattern = jsonencode({
    source = [
      "aws.codebuild"
    ]
    detail-type = [
      "CodeBuild Build State Change"
    ]
    detail = {
      build-status = [
        "FAILED"
      ]
    }
  })
}

resource "aws_cloudwatch_event_target" "cb_failure_cloud_watch_event_target" {
  count     = var.enable_code_build_failure_alerts ? 1 : 0
  rule      = aws_cloudwatch_event_rule.cb_failure_cloud_watch_event[0].name
  target_id = "FailurealertSNSTopicTarget"
  arn       = aws_sns_topic.aws_alerts_sns_topic.id
  input_transformer {
    input_paths = {
      detail      = "$.detail",
      detail-type = "$.detail-type",
      resources   = "$.resources",
      time        = "$.time",
      region      = "$.region",
      account     = "$.account",
    }
    input_template = <<EOF
{
  "account_id": <account>,
  "region": <region>,
  "time": <time>,
  "service": "CodeBuild",
  "name": <detail-type>,
  "type": "FAILURE",
  "resource(s)": <resources>,
  "details": <detail>
}
EOF
  }
}

resource "aws_cloudwatch_event_rule" "ec2_auto_scaling_failure_cloud_watch_event" {
  count       = var.enable_ec2_auto_scaling_failure_alerts ? 1 : 0
  name        = "ec2-autoscaling-failure-cloudwatch-event"
  description = "AWS CloudWatch Event to send alerts on AWS SNS regarding AWS EC2 Auto Scaling Failures."
  event_pattern = jsonencode({
    source = [
      "aws.autoscaling"
    ]
    detail-type = [
      "EC2 Instance Launch Unsuccessful",
      "EC2 Instance Terminate Unsuccessful"
    ]
  })
}

resource "aws_cloudwatch_event_target" "ec2_auto_scaling_failure_cloud_watch_event_target" {
  count     = var.enable_ec2_auto_scaling_failure_alerts ? 1 : 0
  rule      = aws_cloudwatch_event_rule.ec2_auto_scaling_failure_cloud_watch_event[0].name
  target_id = "FailurealertSNSTopicTarget"
  arn       = aws_sns_topic.aws_alerts_sns_topic.id
  input_transformer {
    input_paths = {
      detail      = "$.detail",
      detail-type = "$.detail-type",
      resources   = "$.resources",
      time        = "$.time",
      region      = "$.region",
      account     = "$.account",
    }
    input_template = <<EOF
{
  "account_id": <account>,
  "region": <region>,
  "time": <time>,
  "service": "AWS EC2 Auto Scaling",
  "name": <detail-type>,
  "type": "FAILURE",
  "resource(s)": <resources>,
  "details": <detail>
}
EOF
  }
}

resource "aws_cloudwatch_event_rule" "batch_failure_cloud_watch_event" {
  count       = var.enable_batch_failure_alerts ? 1 : 0
  name        = "batch-failure-cloudwatch-event"
  description = "AWS CloudWatch Event to send alerts on AWS SNS regarding AWS Batch Failures."
  event_pattern = jsonencode({
    source = [
      "aws.batch"
    ]
    detail-type = [
      "Batch Job State Change"
    ]
    detail = {
      status = [
        "FAILED"
      ]
    }
  })
}

resource "aws_cloudwatch_event_target" "batch_failure_cloud_watch_event_target" {
  count     = var.enable_batch_failure_alerts ? 1 : 0
  rule      = aws_cloudwatch_event_rule.batch_failure_cloud_watch_event[0].name
  target_id = "FailurealertSNSTopicTarget"
  arn       = aws_sns_topic.aws_alerts_sns_topic.id
  input_transformer {
    input_paths = {
      detail      = "$.detail",
      detail-type = "$.detail-type",
      resources   = "$.resources",
      time        = "$.time",
      region      = "$.region",
      account     = "$.account",
    }
    input_template = <<EOF
  {
    "account_id": <account>,
    "region": <region>,
    "time": <time>,
    "service": "AWS Batch",
    "name": <detail-type>,
    "type": "FAILURE",
    "resource(s)": <resources>,
    "details": <detail>
  }
  EOF
  }
}

resource "aws_cloudwatch_event_rule" "code_deploy_failure_cloud_watch_event" {
  count       = var.enable_code_deploy_failure_alerts ? 1 : 0
  name        = "codedeploy-failure-cloudwatch-event"
  description = "AWS CloudWatch Event to send alerts on AWS SNS regarding AWS CodeDeploy Failures."
  event_pattern = jsonencode({
    source = [
      "aws.codedeploy"
    ]
    detail-type = [
      "CodeDeploy Deployment State-change Notification",
      "CodeDeploy Instance State-change Notification"
    ]
    detail = {
      state = [
        "FAILURE"
      ]
    }
  })
}

resource "aws_cloudwatch_event_target" "code_deploy_failure_cloud_watch_event_target" {
  count     = var.enable_code_deploy_failure_alerts ? 1 : 0
  rule      = aws_cloudwatch_event_rule.code_deploy_failure_cloud_watch_event[0].name
  target_id = "FailurealertSNSTopicTarget"
  arn       = aws_sns_topic.aws_alerts_sns_topic.id
  input_transformer {
    input_paths = {
      detail      = "$.detail",
      detail-type = "$.detail-type",
      resources   = "$.resources",
      time        = "$.time",
      region      = "$.region",
      account     = "$.account",
    }
    input_template = <<EOF
  {
    "account_id": <account>,
    "region": <region>,
    "time": <time>,
    "service": "AWS CodeDeploy",
    "name": <detail-type>,
    "type": "FAILURE",
    "resource(s)": <resources>,
    "details": <detail>
  }
  EOF
  }
}

resource "aws_cloudwatch_event_rule" "code_pipeline_failure_cloud_watch_event" {
  count       = var.enable_code_pipeline_failure_alerts ? 1 : 0
  name        = "codepipeline-failure-cloudwatch-event"
  description = "AWS CloudWatch Event to send alerts on AWS SNS regarding AWS CodePipeline Failures."
  event_pattern = jsonencode({
    source = [
      "aws.codepipeline"
    ]
    detail-type = [
      "CodePipeline Pipeline Execution State Change"
    ]
    detail = {
      state = [
        "CANCELED",
        "FAILED"
      ]
    }
  })
}

resource "aws_cloudwatch_event_target" "code_pipeline_failure_cloud_watch_event_target" {
  count     = var.enable_code_pipeline_failure_alerts ? 1 : 0
  rule      = aws_cloudwatch_event_rule.code_pipeline_failure_cloud_watch_event[0].name
  target_id = "FailurealertSNSTopicTarget"
  arn       = aws_sns_topic.aws_alerts_sns_topic.id
  input_transformer {
    input_paths = {
      detail      = "$.detail",
      detail-type = "$.detail-type",
      resources   = "$.resources",
      time        = "$.time",
      region      = "$.region",
      account     = "$.account",
    }
    input_template = <<EOF
  {
    "account_id": <account>,
    "region": <region>,
    "time": <time>,
    "service": "AWS CodePipeline",
    "name": <detail-type>,
    "type": "FAILURE",
    "resource(s)": <resources>,
    "details": <detail>
  }
  EOF
  }
}

resource "aws_cloudwatch_event_rule" "config_failure_cloud_watch_event" {
  count       = var.enable_config_failure_alerts ? 1 : 0
  name        = "config-failure-cloudwatch-event"
  description = "AWS CloudWatch Event to send alerts on AWS SNS regarding AWS Config Failures."
  event_pattern = jsonencode({
    source = [
      "aws.config"
    ]
    detail-type = [
      "Config Configuration Snapshot Delivery Status"
    ]
    detail = {
      messageType = [
        "ConfigurationSnapshotDeliveryFailed"
      ]
    }
  })
}

resource "aws_cloudwatch_event_target" "config_failure_cloud_watch_event_target" {
  count     = var.enable_config_failure_alerts ? 1 : 0
  rule      = aws_cloudwatch_event_rule.config_failure_cloud_watch_event[0].name
  target_id = "FailurealertSNSTopicTarget"
  arn       = aws_sns_topic.aws_alerts_sns_topic.id
  input_transformer {
    input_paths = {
      detail      = "$.detail",
      detail-type = "$.detail-type",
      resources   = "$.resources",
      time        = "$.time",
      region      = "$.region",
      account     = "$.account",
    }
    input_template = <<EOF
  {
    "account_id": <account>,
    "region": <region>,
    "time": <time>,
    "service": "AWS Config",
    "name": <detail-type>,
    "type": "FAILURE",
    "resource(s)": <resources>,
    "details": <detail>
  }
  EOF
  }
}

resource "aws_cloudwatch_event_rule" "ebs_failure_cloud_watch_event" {
  count       = var.enable_ebs_failure_alerts ? 1 : 0
  name        = "ebs-failure-cloudwatch-event"
  description = "AWS CloudWatch Event to send alerts on AWS SNS regarding AWS EBS Failures."
  event_pattern = jsonencode({
    source = [
      "aws.ec2"
    ]
    detail-type = [
      "EBS Snapshot Notification",
      "EBS Multi-Volume Snapshots Completion Status",
      "EBS Volume Notification"
    ]
    detail = {
      event = [
        "createSnapshot",
        "createSnapshots",
        "copySnapshot",
        "createVolume",
        "attachVolume",
        "modifyVolume",
        "reattachVolume"
      ]
      result = [
        "failed"
      ]
    }
  })
}

resource "aws_cloudwatch_event_target" "ebs_failure_cloud_watch_event_target" {
  count     = var.enable_ebs_failure_alerts ? 1 : 0
  rule      = aws_cloudwatch_event_rule.ebs_failure_cloud_watch_event[0].name
  target_id = "FailurealertSNSTopicTarget"
  arn       = aws_sns_topic.aws_alerts_sns_topic.id
  input_transformer {
    input_paths = {
      detail      = "$.detail",
      detail-type = "$.detail-type",
      resources   = "$.resources",
      time        = "$.time",
      region      = "$.region",
      account     = "$.account",
    }
    input_template = <<EOF
  {
    "account_id": <account>,
    "region": <region>,
    "time": <time>,
    "service": "AWS EBS",
    "name": <detail-type>,
    "type": "FAILURE",
    "resource(s)": <resources>,
    "details": <detail>
  }
  EOF
  }
}

resource "aws_cloudwatch_event_rule" "glue_failure_cloud_watch_event" {
  count       = var.enable_glue_failure_alerts ? 1 : 0
  name        = "glue-failure-cloudwatch-event"
  description = "AWS CloudWatch Event to send alerts on AWS SNS regarding AWS Glue Failures."
  event_pattern = jsonencode({
    source = [
      "aws.glue"
    ]
    detail-type = [
      "Glue Crawler State Change",
      "Glue Job State Change"
    ]
    detail = {
      state = [
        "FAILED",
        "TIMEOUT"
      ]
    }
  })
}

resource "aws_cloudwatch_event_target" "glue_failure_cloud_watch_event_target" {
  count     = var.enable_glue_failure_alerts ? 1 : 0
  rule      = aws_cloudwatch_event_rule.glue_failure_cloud_watch_event[0].name
  target_id = "FailurealertSNSTopicTarget"
  arn       = aws_sns_topic.aws_alerts_sns_topic.id
  input_transformer {
    input_paths = {
      detail      = "$.detail",
      detail-type = "$.detail-type",
      resources   = "$.resources",
      time        = "$.time",
      region      = "$.region",
      account     = "$.account",
    }
    input_template = <<EOF
  {
    "account_id": <account>,
    "region": <region>,
    "time": <time>,
    "service": "AWS Glue",
    "name": <detail-type>,
    "type": "FAILURE",
    "resource(s)": <resources>,
    "details": <detail>
  }
  EOF
  }
}

resource "aws_cloudwatch_event_rule" "emr_failure_cloud_watch_event" {
  count       = var.enable_emr_failure_alerts ? 1 : 0
  name        = "emr-failure-cloudwatch-event"
  description = "AWS CloudWatch Event to send alerts on AWS SNS regarding AWS EMR Failures."
  event_pattern = jsonencode({
    source = [
      "aws.emr"
    ]
    detail-type = [
      "EMR Instance Fleet State Change",
      "EMR Auto Scaling Policy State Change",
      "EMR Cluster State Change",
      "EMR Step Status Change"
    ]
    detail = {
      state = [
        "SUSPENDED",
        "FAILED",
        "TERMINATED",
        "TERMINATED_WITH_ERRORS",
        "CANCELLED"
      ]
    }
  })
}

resource "aws_cloudwatch_event_target" "emr_failure_cloud_watch_event_target" {
  count     = var.enable_emr_failure_alerts ? 1 : 0
  rule      = aws_cloudwatch_event_rule.emr_failure_cloud_watch_event[0].name
  target_id = "FailurealertSNSTopicTarget"
  arn       = aws_sns_topic.aws_alerts_sns_topic.id
  input_transformer {
    input_paths = {
      detail      = "$.detail",
      detail-type = "$.detail-type",
      resources   = "$.resources",
      time        = "$.time",
      region      = "$.region",
      account     = "$.account",
    }
    input_template = <<EOF
  {
    "account_id": <account>,
    "region": <region>,
    "time": <time>,
    "service": "AWS EMR",
    "name": <detail-type>,
    "type": "FAILURE",
    "resource(s)": <resources>,
    "details": <detail>
  }
  EOF
  }
}

resource "aws_cloudwatch_event_rule" "emr_error_cloud_watch_event" {
  count       = var.enable_emr_error_alerts ? 1 : 0
  name        = "emr-error-cloudwatch-event"
  description = "AWS CloudWatch Event to send alerts on AWS SNS regarding AWS EMR Errors."
  event_pattern = jsonencode({
    source = [
      "aws.emr"
    ]
    detail-type = [
      "EMR Configuration Error"
    ]
  })
}

resource "aws_cloudwatch_event_target" "emr_error_cloud_watch_event_target" {
  count     = var.enable_emr_error_alerts ? 1 : 0
  rule      = aws_cloudwatch_event_rule.emr_error_cloud_watch_event[0].name
  target_id = "FailurealertSNSTopicTarget"
  arn       = aws_sns_topic.aws_alerts_sns_topic.id
  input_transformer {
    input_paths = {
      detail      = "$.detail",
      detail-type = "$.detail-type",
      resources   = "$.resources",
      time        = "$.time",
      region      = "$.region",
      account     = "$.account",
    }
    input_template = <<EOF
  {
    "account_id": <account>,
    "region": <region>,
    "time": <time>,
    "service": "AWS EMR",
    "name": <detail-type>,
    "type": "ERROR",
    "resource(s)": <resources>,
    "details": <detail>
  }
  EOF
  }
}

resource "aws_cloudwatch_event_rule" "ecs_instance_termination_cloud_watch_event" {
  count       = var.enable_ecs_instance_termination_alerts ? 1 : 0
  name        = "ecs-instance-termination-cloudwatch-event"
  description = "AWS CloudWatch Event to send alerts on AWS SNS regarding AWS ECS Instance Terminations."
  event_pattern = jsonencode({
    source = [
      "aws.ecs"
    ]
    detail-type = [
      "ECS Container Instance State Change"
    ]
    detail = {
      status = [
        "STOPPED"
      ]
    }
  })
}

resource "aws_cloudwatch_event_target" "ecs_instance_termination_cloud_watch_event_target" {
  count     = var.enable_ecs_instance_termination_alerts ? 1 : 0
  rule      = aws_cloudwatch_event_rule.ecs_instance_termination_cloud_watch_event[0].name
  target_id = "FailurealertSNSTopicTarget"
  arn       = aws_sns_topic.aws_alerts_sns_topic.id
  input_transformer {
    input_paths = {
      detail      = "$.detail",
      detail-type = "$.detail-type",
      resources   = "$.resources",
      time        = "$.time",
      region      = "$.region",
      account     = "$.account",
    }
    input_template = <<EOF
  {
    "account_id": <account>,
    "region": <region>,
    "time": <time>,
    "service": "AWS ECS",
    "name": <detail-type>,
    "type": "TERMINATION",
    "resource(s)": <resources>,
    "details": <detail>
  }
  EOF
  }
}

resource "aws_cloudwatch_event_rule" "ecs_task_termination_cloud_watch_event" {
  count       = var.enable_ecs_task_termination_alerts ? 1 : 0
  name        = "ecs-task-termination-cloudwatch-event"
  description = "AWS CloudWatch Event to send alerts on AWS SNS regarding AWS ECS Task Terminations."
  event_pattern = jsonencode({
    source = [
      "aws.ecs"
    ]
    detail-type = [
      "ECS Task State Change"
    ]
    detail = {
      status = [
        "STOPPED"
      ]
    }
  })
}

resource "aws_cloudwatch_event_target" "ecs_task_termination_cloud_watch_event_target" {
  count     = var.enable_ecs_task_termination_alerts ? 1 : 0
  rule      = aws_cloudwatch_event_rule.ecs_task_termination_cloud_watch_event[0].name
  target_id = "FailurealertSNSTopicTarget"
  arn       = aws_sns_topic.aws_alerts_sns_topic.id
  input_transformer {
    input_paths = {
      detail      = "$.detail",
      detail-type = "$.detail-type",
      resources   = "$.resources",
      time        = "$.time",
      region      = "$.region",
      account     = "$.account",
    }
    input_template = <<EOF
  {
    "account_id": <account>,
    "region": <region>,
    "time": <time>,
    "service": "AWS ECS",
    "name": <detail-type>,
    "type": "TERMINATION",
    "resource(s)": <resources>,
    "details": <detail>
  }
  EOF
  }
}

resource "aws_cloudwatch_event_rule" "ec2_instance_termination_cloud_watch_event" {
  count       = var.enable_ec2_instance_termination_alerts ? 1 : 0
  name        = "ec2-instance-termination-cloudwatch-event"
  description = "AWS CloudWatch Event to send alerts on AWS SNS regarding AWS EC2 Instance Terminations."
  event_pattern = jsonencode({
    source = [
      "aws.ec2"
    ]
    detail-type = [
      "EC2 Instance State-change Notification"
    ]
    detail = {
      state = [
        "stopping",
        "shutting-down"
      ]
    }
  })
}

resource "aws_cloudwatch_event_target" "ec2_instance_termination_cloud_watch_event_target" {
  count     = var.enable_ec2_instance_termination_alerts ? 1 : 0
  rule      = aws_cloudwatch_event_rule.ec2_instance_termination_cloud_watch_event[0].name
  target_id = "FailurealertSNSTopicTarget"
  arn       = aws_sns_topic.aws_alerts_sns_topic.id
  input_transformer {
    input_paths = {
      detail      = "$.detail",
      detail-type = "$.detail-type",
      resources   = "$.resources",
      time        = "$.time",
      region      = "$.region",
      account     = "$.account",
    }
    input_template = <<EOF
  {
    "account_id": <account>,
    "region": <region>,
    "time": <time>,
    "service": "AWS EC2",
    "name": <detail-type>,
    "type": "TERMINATION",
    "resource(s)": <resources>,
    "details": <detail>
  }
  EOF
  }
}

resource "aws_cloudwatch_event_rule" "ec2_spot_instance_error_cloud_watch_event" {
  count       = var.enable_ec2_spot_instance_error_alerts ? 1 : 0
  name        = "ec2-spot-instance-error-cloudwatch-event"
  description = "AWS CloudWatch Event to send alerts on AWS SNS regarding AWS EC2 Spot Instance Errors."
  event_pattern = jsonencode({
    source = [
      "aws.ec2"
    ]
    detail-type = [
      "EC2 Spot Instance Interruption Warning"
    ]
  })
}

resource "aws_cloudwatch_event_target" "ec2_spot_instance_error_cloud_watch_event_target" {
  count     = var.enable_ec2_spot_instance_error_alerts ? 1 : 0
  rule      = aws_cloudwatch_event_rule.ec2_spot_instance_error_cloud_watch_event[0].name
  target_id = "FailurealertSNSTopicTarget"
  arn       = aws_sns_topic.aws_alerts_sns_topic.id
  input_transformer {
    input_paths = {
      detail      = "$.detail",
      detail-type = "$.detail-type",
      resources   = "$.resources",
      time        = "$.time",
      region      = "$.region",
      account     = "$.account",
    }
    input_template = <<EOF
  {
    "account_id": <account>,
    "region": <region>,
    "time": <time>,
    "service": "AWS EC2",
    "name": <detail-type>,
    "type": "ERROR",
    "resource(s)": <resources>,
    "details": <detail>
  }
  EOF
  }
}

resource "aws_cloudwatch_event_rule" "trusted_advisor_error_warning_cloud_watch_event" {
  count       = var.enable_trusted_advisor_error_warning_alerts ? 1 : 0
  name        = "trusted-advisor-error-warning-cloudwatch-event"
  description = "AWS CloudWatch Event to send alerts on AWS SNS regarding AWS Trusted Advisor Errors and Warnings."
  event_pattern = jsonencode({
    source = [
      "aws.trustedadvisor"
    ]
    detail-type = [
      "Trusted Advisor Check Item Refresh Notification"
    ]
    detail = {
      status = [
        "ERROR",
        "WARN"
      ]
    }
  })
}

resource "aws_cloudwatch_event_target" "trusted_advisor_error_warning_cloud_watch_event_target" {
  count     = var.enable_trusted_advisor_error_warning_alerts ? 1 : 0
  rule      = aws_cloudwatch_event_rule.trusted_advisor_error_warning_cloud_watch_event[0].name
  target_id = "FailurealertSNSTopicTarget"
  arn       = aws_sns_topic.aws_alerts_sns_topic.id
  input_transformer {
    input_paths = {
      detail      = "$.detail",
      detail-type = "$.detail-type",
      resources   = "$.resources",
      time        = "$.time",
      region      = "$.region",
      account     = "$.account",
    }
    input_template = <<EOF
  {
    "account_id": <account>,
    "region": <region>,
    "time": <time>,
    "service": "AWS Trusted Advisor",
    "name": <detail-type>,
    "type": "ERROR or WARNING",
    "resource(s)": <resources>,
    "details": <detail>
  }
  EOF
  }
}

resource "aws_cloudwatch_event_rule" "health_error_cloud_watch_event" {
  count       = var.enable_health_error_alerts ? 1 : 0
  name        = "health-error-cloudwatch-event"
  description = "AWS CloudWatch Event to send alerts on AWS SNS regarding AWS Health Errors."
  event_pattern = jsonencode({
    source = [
      "aws.health"
    ]
    detail-type = [
      "AWS Health Event",
      "AWS Health Abuse Event"
    ]
    detail = {
      eventTypeCategory = [
        "issue"
      ]
    }
  })
}

resource "aws_cloudwatch_event_target" "health_error_cloud_watch_event_target" {
  count     = var.enable_health_error_alerts ? 1 : 0
  rule      = aws_cloudwatch_event_rule.health_error_cloud_watch_event[0].name
  target_id = "FailurealertSNSTopicTarget"
  arn       = aws_sns_topic.aws_alerts_sns_topic.id
  input_transformer {
    input_paths = {
      detail      = "$.detail",
      detail-type = "$.detail-type",
      resources   = "$.resources",
      time        = "$.time",
      region      = "$.region",
      account     = "$.account",
    }
    input_template = <<EOF
  {
    "account_id": <account>,
    "region": <region>,
    "time": <time>,
    "service": "AWS Health",
    "name": <detail-type>,
    "type": "ERROR",
    "resource(s)": <resources>,
    "details": <detail>
  }
  EOF
  }
}

resource "aws_cloudwatch_event_rule" "sms_failure_cloud_watch_event" {
  count       = var.enable_sms_failure_alerts ? 1 : 0
  name        = "sms-failure-cloudwatch-event"
  description = "AWS CloudWatch Event to send alerts on AWS SNS regarding AWS SMS Failures."
  event_pattern = jsonencode({
    source = [
      "aws.sms"
    ]
    detail-type = [
      "Server Migration Job State Change"
    ]
    detail = {
      state = [
        "Failed"
      ]
    }
  })
}

resource "aws_cloudwatch_event_target" "sms_failure_cloud_watch_event_target" {
  count     = var.enable_sms_failure_alerts ? 1 : 0
  rule      = aws_cloudwatch_event_rule.sms_failure_cloud_watch_event[0].name
  target_id = "FailurealertSNSTopicTarget"
  arn       = aws_sns_topic.aws_alerts_sns_topic.id
  input_transformer {
    input_paths = {
      detail      = "$.detail",
      detail-type = "$.detail-type",
      resources   = "$.resources",
      time        = "$.time",
      region      = "$.region",
      account     = "$.account",
    }
    input_template = <<EOF
  {
    "account_id": <account>,
    "region": <region>,
    "time": <time>,
    "service": "AWS Server Migration Service (SMS)",
    "name": <detail-type>,
    "type": "FAILURE",
    "resource(s)": <resources>,
    "details": <detail>
  }
  EOF
  }
}

resource "aws_cloudwatch_event_rule" "step_functions_failure_cloud_watch_event" {
  count       = var.enable_step_functions_failure_alerts ? 1 : 0
  name        = "step-functions-failure-cloudwatch-event"
  description = "AWS CloudWatch Event to send alerts on AWS SNS regarding AWS Step Functions Failures."
  event_pattern = jsonencode({
    source = [
      "aws.states"
    ]
    detail-type = [
      "Step Functions Execution Status Change"
    ]
    detail = {
      status = [
        "ABORTED",
        "FAILED",
        "TIMED_OUT"
      ]
    }
  })
}

resource "aws_cloudwatch_event_target" "step_functions_failure_cloud_watch_event_target" {
  count     = var.enable_step_functions_failure_alerts ? 1 : 0
  rule      = aws_cloudwatch_event_rule.step_functions_failure_cloud_watch_event[0].name
  target_id = "FailurealertSNSTopicTarget"
  arn       = aws_sns_topic.aws_alerts_sns_topic.id
  input_transformer {
    input_paths = {
      detail      = "$.detail",
      detail-type = "$.detail-type",
      resources   = "$.resources",
      time        = "$.time",
      region      = "$.region",
      account     = "$.account",
    }
    input_template = <<EOF
  {
    "account_id": <account>,
    "region": <region>,
    "time": <time>,
    "service": "AWS Step Functions",
    "name": <detail-type>,
    "type": "FAILURE",
    "resource(s)": <resources>,
    "details": <detail>
  }
  EOF
  }
}

resource "aws_cloudwatch_event_rule" "ssm_maintainance_window_failure_cloud_watch_event" {
  count       = var.enable_ssm_maintainance_window_failure_alerts ? 1 : 0
  name        = "ssm-maintainance-window-failure-cloudwatch-event"
  description = "AWS CloudWatch Event to send alerts on AWS SNS regarding AWS SSM Maintainance Window Failures."
  event_pattern = jsonencode({
    source = [
      "aws.ssm"
    ]
    detail-type = [
      "Maintenance Window Execution State-change Notification",
      "Maintenance Window Task Execution State-change Notification",
      "Maintenance Window Task Target Invocation State-change Notification"
    ]
    detail = {
      status = [
        "CANCELLED",
        "FAILED",
        "TIMED_OUT"
      ]
    }
  })
}

resource "aws_cloudwatch_event_target" "ssm_maintainance_window_failure_cloud_watch_event_target" {
  count     = var.enable_ssm_maintainance_window_failure_alerts ? 1 : 0
  rule      = aws_cloudwatch_event_rule.ssm_maintainance_window_failure_cloud_watch_event[0].name
  target_id = "FailurealertSNSTopicTarget"
  arn       = aws_sns_topic.aws_alerts_sns_topic.id
  input_transformer {
    input_paths = {
      detail      = "$.detail",
      detail-type = "$.detail-type",
      resources   = "$.resources",
      time        = "$.time",
      region      = "$.region",
      account     = "$.account",
    }
    input_template = <<EOF
  {
    "account_id": <account>,
    "region": <region>,
    "time": <time>,
    "service": "AWS SSM Maintainance Window",
    "name": <detail-type>,
    "type": "FAILURE",
    "resource(s)": <resources>,
    "details": <detail>
  }
  EOF
  }
}

resource "aws_cloudwatch_event_rule" "ssmec2_failure_cloud_watch_event" {
  count       = var.enable_ssmec2_failure_alerts ? 1 : 0
  name        = "ssm-ec2-failure-cloudwatch-event"
  description = "AWS CloudWatch Event to send alerts on AWS SNS regarding AWS SSM EC2 State Manager, Run Command and Automation Failures."
  event_pattern = jsonencode({
    source = [
      "aws.ssm"
    ]
    detail-type = [
      "EC2 State Manager Association State Change",
      "EC2 State Manager Instance Association State Change",
      "EC2 Command Status-change Notification",
      "EC2 Command Invocation Status-change Notification",
      "EC2 Automation Step Status-change Notification",
      "EC2 Automation Execution Status-change Notification"
    ]
    detail = {
      status = [
        "Failed",
        "Cancelled",
        "TimedOut"
      ]
    }
  })
}

resource "aws_cloudwatch_event_target" "ssmec2_failure_cloud_watch_event_target" {
  count     = var.enable_ssmec2_failure_alerts ? 1 : 0
  rule      = aws_cloudwatch_event_rule.ssmec2_failure_cloud_watch_event[0].name
  target_id = "FailurealertSNSTopicTarget"
  arn       = aws_sns_topic.aws_alerts_sns_topic.id
  input_transformer {
    input_paths = {
      detail      = "$.detail",
      detail-type = "$.detail-type",
      resources   = "$.resources",
      time        = "$.time",
      region      = "$.region",
      account     = "$.account",
    }
    input_template = <<EOF
  {
    "account_id": <account>,
    "region": <region>,
    "time": <time>,
    "service": "AWS SSM EC2",
    "name": <detail-type>,
    "type": "FAILURE",
    "resource(s)": <resources>,
    "details": <detail>
  }
  EOF
  }
}

resource "aws_cloudwatch_event_rule" "ssm_compliance_warning_cloud_watch_event" {
  count       = var.enable_ssm_compliance_warning_alerts ? 1 : 0
  name        = "ssm-compliance-warning-cloudwatch-event"
  description = "AWS CloudWatch Event to send alerts on AWS SNS regarding AWS SSM Compliance Warnings."
  event_pattern = jsonencode({
    source = [
      "aws.ssm"
    ]
    detail-type = [
      "Configuration Compliance State Change"
    ]
    detail = {
      compliance-status = [
        "non_compliant"
      ]
    }
  })
}

resource "aws_cloudwatch_event_target" "ssm_compliance_warning_cloud_watch_event_target" {
  count     = var.enable_ssm_compliance_warning_alerts ? 1 : 0
  rule      = aws_cloudwatch_event_rule.ssm_compliance_warning_cloud_watch_event[0].name
  target_id = "FailurealertSNSTopicTarget"
  arn       = aws_sns_topic.aws_alerts_sns_topic.id
  input_transformer {
    input_paths = {
      detail      = "$.detail",
      detail-type = "$.detail-type",
      resources   = "$.resources",
      time        = "$.time",
      region      = "$.region",
      account     = "$.account",
    }
    input_template = <<EOF
  {
    "account_id": <account>,
    "region": <region>,
    "time": <time>,
    "service": "AWS SSM Compliance",
    "name": <detail-type>,
    "type": "WARNING",
    "resource(s)": <resources>,
    "details": <detail>
  }
  EOF
  }
}

resource "aws_cloudwatch_event_rule" "ops_works_failure_cloud_watch_event" {
  count       = var.enable_ops_works_failure_alerts ? 1 : 0
  name        = "opsworks-failure-cloudwatch-event"
  description = "AWS CloudWatch Event to send alerts on AWS SNS regarding AWS OpsWorks Failures."
  event_pattern = jsonencode({
    source = [
      "aws.opsworks"
    ]
    detail-type = [
      "OpsWorks Command State Change",
      "OpsWorks Instance State Change",
      "OpsWorks Deployment State Change"
    ]
    detail = {
      status = [
        "expired",
        "failed",
        "skipped",
        "connection_lost",
        "setup_failed",
        "shutting_down",
        "start_failed",
        "stop_failed",
        "stopped",
        "terminated"
      ]
    }
  })
}

resource "aws_cloudwatch_event_target" "ops_works_failure_cloud_watch_event_target" {
  count     = var.enable_ops_works_failure_alerts ? 1 : 0
  rule      = aws_cloudwatch_event_rule.ops_works_failure_cloud_watch_event[0].name
  target_id = "FailurealertSNSTopicTarget"
  arn       = aws_sns_topic.aws_alerts_sns_topic.id
  input_transformer {
    input_paths = {
      detail      = "$.detail",
      detail-type = "$.detail-type",
      resources   = "$.resources",
      time        = "$.time",
      region      = "$.region",
      account     = "$.account",
    }
    input_template = <<EOF
  {
    "account_id": <account>,
    "region": <region>,
    "time": <time>,
    "service": "AWS OpsWorks",
    "name": <detail-type>,
    "type": "FAILURE",
    "resource(s)": <resources>,
    "details": <detail>
  }
  EOF
  }
}

resource "aws_cloudwatch_event_rule" "ops_works_error_cloud_watch_event" {
  count       = var.enable_ops_works_error_alerts ? 1 : 0
  name        = "opsworks-error-cloudwatch-event"
  description = "AWS CloudWatch Event to send alerts on AWS SNS regarding AWS OpsWorks Errors."
  event_pattern = jsonencode({
    source = [
      "aws.opsworks"
    ]
    detail-type = [
      "OpsWorks Alert"
    ]
  })
}

resource "aws_cloudwatch_event_target" "ops_works_error_cloud_watch_event_target" {
  count     = var.enable_ops_works_error_alerts ? 1 : 0
  rule      = aws_cloudwatch_event_rule.ops_works_error_cloud_watch_event[0].name
  target_id = "FailurealertSNSTopicTarget"
  arn       = aws_sns_topic.aws_alerts_sns_topic.id
  input_transformer {
    input_paths = {
      detail      = "$.detail",
      detail-type = "$.detail-type",
      resources   = "$.resources",
      time        = "$.time",
      region      = "$.region",
      account     = "$.account",
    }
    input_template = <<EOF
  {
    "account_id": <account>,
    "region": <region>,
    "time": <time>,
    "service": "AWS OpsWorks",
    "name": <detail-type>,
    "type": "ERROR",
    "resource(s)": <resources>,
    "details": <detail>
  }
  EOF
  }
}

resource "aws_cloudwatch_event_rule" "kms_key_expiration_warning_cloud_watch_event" {
  count       = var.enable_kms_key_expiration_warning_alerts ? 1 : 0
  name        = "kms-key-expiration-warning-cloudwatch-event"
  description = "AWS CloudWatch Event to send alerts on AWS SNS regarding AWS KMS Key Expiration Warnings."
  event_pattern = jsonencode({
    source = [
      "aws.kms"
    ]
    detail-type = [
      "KMS Imported Key Material Expiration"
    ]
  })
}

resource "aws_cloudwatch_event_target" "kms_key_expiration_warning_cloud_watch_event_target" {
  count     = var.enable_kms_key_expiration_warning_alerts ? 1 : 0
  rule      = aws_cloudwatch_event_rule.kms_key_expiration_warning_cloud_watch_event[0].name
  target_id = "FailurealertSNSTopicTarget"
  arn       = aws_sns_topic.aws_alerts_sns_topic.id
  input_transformer {
    input_paths = {
      detail      = "$.detail",
      detail-type = "$.detail-type",
      resources   = "$.resources",
      time        = "$.time",
      region      = "$.region",
      account     = "$.account",
    }
    input_template = <<EOF
  {
    "account_id": <account>,
    "region": <region>,
    "time": <time>,
    "service": "AWS KMS",
    "name": <detail-type>,
    "type": "WARNING",
    "resource(s)": <resources>,
    "details": <detail>
  }
  EOF
  }
}

resource "aws_cloudwatch_event_rule" "macie_warning_cloud_watch_event" {
  count       = var.enable_macie_warning_alerts ? 1 : 0
  name        = "macie-warning-cloudwatch-event"
  description = "AWS CloudWatch Event to send alerts on AWS SNS regarding AWS Macie Warnings."
  event_pattern = jsonencode({
    source = [
      "aws.macie"
    ]
    detail-type = [
      "Macie Alert"
    ]
  })
}

resource "aws_cloudwatch_event_target" "macie_warning_cloud_watch_event_target" {
  count     = var.enable_macie_warning_alerts ? 1 : 0
  rule      = aws_cloudwatch_event_rule.macie_warning_cloud_watch_event[0].name
  target_id = "FailurealertSNSTopicTarget"
  arn       = aws_sns_topic.aws_alerts_sns_topic.id
  input_transformer {
    input_paths = {
      detail      = "$.detail",
      detail-type = "$.detail-type",
      resources   = "$.resources",
      time        = "$.time",
      region      = "$.region",
      account     = "$.account",
    }
    input_template = <<EOF
  {
    "account_id": <account>,
    "region": <region>,
    "time": <time>,
    "service": "AWS Macie",
    "name": <detail-type>,
    "type": "WARNING",
    "resource(s)": <resources>,
    "details": <detail>
  }
  EOF
  }
}

resource "aws_cloudwatch_event_rule" "game_lift_failure_cloud_watch_event" {
  count       = var.enable_game_lift_failure_alerts ? 1 : 0
  name        = "gamelift-failure-cloudwatch-event"
  description = "AWS CloudWatch Event to send alerts on AWS SNS regarding AWS GameLift Failures."
  event_pattern = jsonencode({
    source = [
      "aws.gamelift"
    ]
    detail-type = [
      "GameLift Matchmaking Event"
    ]
    detail = {
      type = [
        "MatchmakingTimedOut",
        "MatchmakingCancelled",
        "MatchmakingFailed"
      ]
    }
  })
}

resource "aws_cloudwatch_event_target" "game_lift_failure_cloud_watch_event_target" {
  count     = var.enable_game_lift_failure_alerts ? 1 : 0
  rule      = aws_cloudwatch_event_rule.game_lift_failure_cloud_watch_event[0].name
  target_id = "FailurealertSNSTopicTarget"
  arn       = aws_sns_topic.aws_alerts_sns_topic.id
  input_transformer {
    input_paths = {
      detail      = "$.detail",
      detail-type = "$.detail-type",
      resources   = "$.resources",
      time        = "$.time",
      region      = "$.region",
      account     = "$.account",
    }
    input_template = <<EOF
  {
    "account_id": <account>,
    "region": <region>,
    "time": <time>,
    "service": "AWS GameLift",
    "name": <detail-type>,
    "type": "FAILURE",
    "resource(s)": <resources>,
    "details": <detail>
  }
  EOF
  }
}

resource "aws_cloudwatch_event_rule" "transcribe_failure_cloud_watch_event" {
  count       = var.enable_transcribe_failure_alerts ? 1 : 0
  name        = "transcribe-failure-cloudwatch-event"
  description = "AWS CloudWatch Event to send alerts on AWS SNS regarding AWS Transcribe Failures."
  event_pattern = jsonencode({
    source = [
      "aws.transcribe"
    ]
    detail-type = [
      "Transcribe Job State Change"
    ]
    detail = {
      TranscriptionJobStatus = [
        "FAILED"
      ]
    }
  })
}

resource "aws_cloudwatch_event_target" "transcribe_failure_cloud_watch_event_target" {
  count     = var.enable_transcribe_failure_alerts ? 1 : 0
  rule      = aws_cloudwatch_event_rule.transcribe_failure_cloud_watch_event[0].name
  target_id = "FailurealertSNSTopicTarget"
  arn       = aws_sns_topic.aws_alerts_sns_topic.id
  input_transformer {
    input_paths = {
      detail      = "$.detail",
      detail-type = "$.detail-type",
      resources   = "$.resources",
      time        = "$.time",
      region      = "$.region",
      account     = "$.account",
    }
    input_template = <<EOF
  {
    "account_id": <account>,
    "region": <region>,
    "time": <time>,
    "service": "AWS Transcribe",
    "name": <detail-type>,
    "type": "FAILURE",
    "resource(s)": <resources>,
    "details": <detail>
  }
  EOF
  }
}

resource "aws_cloudwatch_event_rule" "signer_failure_cloud_watch_event" {
  count       = var.enable_signer_failure_alerts ? 1 : 0
  name        = "signer-failure-cloudwatch-event"
  description = "AWS CloudWatch Event to send alerts on AWS SNS regarding AWS Signer Failures."
  event_pattern = jsonencode({
    source = [
      "aws.signer"
    ]
    detail-type = [
      "Signer Job Status Change"
    ]
    detail = {
      status = [
        "Failed"
      ]
    }
  })
}

resource "aws_cloudwatch_event_target" "signer_failure_cloud_watch_event_target" {
  count     = var.enable_signer_failure_alerts ? 1 : 0
  rule      = aws_cloudwatch_event_rule.signer_failure_cloud_watch_event[0].name
  target_id = "FailurealertSNSTopicTarget"
  arn       = aws_sns_topic.aws_alerts_sns_topic.id
  input_transformer {
    input_paths = {
      detail      = "$.detail",
      detail-type = "$.detail-type",
      resources   = "$.resources",
      time        = "$.time",
      region      = "$.region",
      account     = "$.account",
    }
    input_template = <<EOF
  {
    "account_id": <account>,
    "region": <region>,
    "time": <time>,
    "service": "AWS Signer",
    "name": <detail-type>,
    "type": "FAILURE",
    "resource(s)": <resources>,
    "details": <detail>
  }
  EOF
  }
}

resource "aws_cloudwatch_event_rule" "data_sync_error_warning_cloud_watch_event" {
  count       = var.enable_data_sync_error_warning_alerts ? 1 : 0
  name        = "datasync-error-warning-cloudwatch-event"
  description = "AWS CloudWatch Event to send alerts on AWS SNS regarding AWS DataSync Errors and Warnings."
  event_pattern = jsonencode({
    source = [
      "aws.datasync"
    ]
    detail-type = [
      "DataSync Task Execution State Change",
      "DataSync Task State Change",
      "DataSync Agent State Change"
    ]
    detail = {
      State = [
        "ERROR",
        "UNAVAILABLE",
        "OFFLINE"
      ]
    }
  })
}

resource "aws_cloudwatch_event_target" "data_sync_error_warning_cloud_watch_event_target" {
  count     = var.enable_data_sync_error_warning_alerts ? 1 : 0
  rule      = aws_cloudwatch_event_rule.data_sync_error_warning_cloud_watch_event[0].name
  target_id = "FailurealertSNSTopicTarget"
  arn       = aws_sns_topic.aws_alerts_sns_topic.id
  input_transformer {
    input_paths = {
      detail      = "$.detail",
      detail-type = "$.detail-type",
      resources   = "$.resources",
      time        = "$.time",
      region      = "$.region",
      account     = "$.account",
    }
    input_template = <<EOF
  {
    "account_id": <account>,
    "region": <region>,
    "time": <time>,
    "service": "AWS DataSync",
    "name": <detail-type>,
    "type": "ERROR or WARNING",
    "resource(s)": <resources>,
    "details": <detail>
  }
  EOF
  }
}

resource "aws_cloudwatch_event_rule" "iot_analytics_failure_cloud_watch_event" {
  count       = var.enable_iot_analytics_failure_alerts ? 1 : 0
  name        = "iot-analytics-failure-cloudwatch-event"
  description = "AWS CloudWatch Event to send alerts on AWS SNS regarding AWS IoT Analytics Failures."
  event_pattern = jsonencode({
    source = [
      "aws.iotanalytics"
    ]
    detail-type = [
      "IoT Analytics Dataset Lifecycle Notification"
    ]
    detail = {
      state = [
        "CONTENT_DELIVERY_FAILED"
      ]
    }
  })
}

resource "aws_cloudwatch_event_target" "iot_analytics_failure_cloud_watch_event_target" {
  count     = var.enable_iot_analytics_failure_alerts ? 1 : 0
  rule      = aws_cloudwatch_event_rule.iot_analytics_failure_cloud_watch_event[0].name
  target_id = "FailurealertSNSTopicTarget"
  arn       = aws_sns_topic.aws_alerts_sns_topic.id
  input_transformer {
    input_paths = {
      detail      = "$.detail",
      detail-type = "$.detail-type",
      resources   = "$.resources",
      time        = "$.time",
      region      = "$.region",
      account     = "$.account",
    }
    input_template = <<EOF
  {
    "account_id": <account>,
    "region": <region>,
    "time": <time>,
    "service": "AWS IoT Analytics",
    "name": <detail-type>,
    "type": "FAILURE",
    "resource(s)": <resources>,
    "details": <detail>
  }
  EOF
  }
}

resource "aws_cloudwatch_event_rule" "data_lifecycle_manager_error_cloud_watch_event" {
  count       = var.enable_data_lifecycle_manager_error_alerts ? 1 : 0
  name        = "data-lifecycle-manager-error-cloudwatch-event"
  description = "AWS CloudWatch Event to send alerts on AWS SNS regarding AWS Data Lifecycle Manager Errors."
  event_pattern = jsonencode({
    source = [
      "aws.dlm"
    ]
    detail-type = [
      "DLM Policy State Change"
    ]
    detail = {
      state = [
        "ERROR"
      ]
    }
  })
}

resource "aws_cloudwatch_event_target" "data_lifecycle_manager_error_cloud_watch_event_target" {
  count     = var.enable_data_lifecycle_manager_error_alerts ? 1 : 0
  rule      = aws_cloudwatch_event_rule.data_lifecycle_manager_error_cloud_watch_event[0].name
  target_id = "FailurealertSNSTopicTarget"
  arn       = aws_sns_topic.aws_alerts_sns_topic.id
  input_transformer {
    input_paths = {
      detail      = "$.detail",
      detail-type = "$.detail-type",
      resources   = "$.resources",
      time        = "$.time",
      region      = "$.region",
      account     = "$.account",
    }
    input_template = <<EOF
  {
    "account_id": <account>,
    "region": <region>,
    "time": <time>,
    "service": "AWS Data Lifecycle Manager",
    "name": <detail-type>,
    "type": "ERROR",
    "resource(s)": <resources>,
    "details": <detail>
  }
  EOF
  }
}

resource "aws_cloudwatch_event_rule" "elemental_media_package_error_cloud_watch_event" {
  count       = var.enable_elemental_media_package_error_alerts ? 1 : 0
  name        = "elemental-mediapackage-error-cloudwatch-event"
  description = "AWS CloudWatch Event to send alerts on AWS SNS regarding AWS Elemental MediaPackage Errors."
  event_pattern = jsonencode({
    source = [
      "aws.mediapackage"
    ]
    detail-type = [
      "MediaPackage Input Notification",
      "MediaPackage Key Provider Notification"
    ]
    detail = {
      event = [
        "MaxIngestStreamsError",
        "IngestError",
        "KeyProviderError"
      ]
    }
  })
}

resource "aws_cloudwatch_event_target" "elemental_media_package_error_cloud_watch_event_target" {
  count     = var.enable_elemental_media_package_error_alerts ? 1 : 0
  rule      = aws_cloudwatch_event_rule.elemental_media_package_error_cloud_watch_event[0].name
  target_id = "FailurealertSNSTopicTarget"
  arn       = aws_sns_topic.aws_alerts_sns_topic.id
  input_transformer {
    input_paths = {
      detail      = "$.detail",
      detail-type = "$.detail-type",
      resources   = "$.resources",
      time        = "$.time",
      region      = "$.region",
      account     = "$.account",
    }
    input_template = <<EOF
  {
    "account_id": <account>,
    "region": <region>,
    "time": <time>,
    "service": "AWS Elemental MediaPackage",
    "name": <detail-type>,
    "type": "ERROR",
    "resource(s)": <resources>,
    "details": <detail>
  }
  EOF
  }
}

resource "aws_cloudwatch_event_rule" "elemental_media_live_error_cloud_watch_event" {
  count       = var.enable_elemental_media_live_error_alerts ? 1 : 0
  name        = "elemental-medialive-error-cloudwatch-event"
  description = "AWS CloudWatch Event to send alerts on AWS SNS regarding AWS Elemental MediaLive Errors."
  event_pattern = jsonencode({
    source = [
      "aws.medialive"
    ]
    detail-type = [
      "MediaLive Channel Alert"
    ]
  })
}

resource "aws_cloudwatch_event_target" "elemental_media_live_error_cloud_watch_event_target" {
  count     = var.enable_elemental_media_live_error_alerts ? 1 : 0
  rule      = aws_cloudwatch_event_rule.elemental_media_live_error_cloud_watch_event[0].name
  target_id = "FailurealertSNSTopicTarget"
  arn       = aws_sns_topic.aws_alerts_sns_topic.id
  input_transformer {
    input_paths = {
      detail      = "$.detail",
      detail-type = "$.detail-type",
      resources   = "$.resources",
      time        = "$.time",
      region      = "$.region",
      account     = "$.account",
    }
    input_template = <<EOF
  {
    "account_id": <account>,
    "region": <region>,
    "time": <time>,
    "service": "AWS Elemental MediaLive",
    "name": <detail-type>,
    "type": "ERROR",
    "resource(s)": <resources>,
    "details": <detail>
  }
  EOF
  }
}

resource "aws_cloudwatch_event_rule" "elemental_media_convert_error_cloud_watch_event" {
  count       = var.enable_elemental_media_convert_error_alerts ? 1 : 0
  name        = "elemental-mediaconvert-error-cloudwatch-event"
  description = "AWS CloudWatch Event to send alerts on AWS SNS regarding AWS Elemental MediaConvert Errors."
  event_pattern = jsonencode({
    source = [
      "aws.mediaconvert"
    ]
    detail-type = [
      "MediaConvert Job State Change"
    ]
    detail = {
      status = [
        "ERROR"
      ]
    }
  })
}

resource "aws_cloudwatch_event_target" "elemental_media_convert_error_cloud_watch_event_target" {
  count     = var.enable_elemental_media_convert_error_alerts ? 1 : 0
  rule      = aws_cloudwatch_event_rule.elemental_media_convert_error_cloud_watch_event[0].name
  target_id = "FailurealertSNSTopicTarget"
  arn       = aws_sns_topic.aws_alerts_sns_topic.id
  input_transformer {
    input_paths = {
      detail      = "$.detail",
      detail-type = "$.detail-type",
      resources   = "$.resources",
      time        = "$.time",
      region      = "$.region",
      account     = "$.account",
    }
    input_template = <<EOF
  {
    "account_id": <account>,
    "region": <region>,
    "time": <time>,
    "service": "AWS Elemental MediaConvert",
    "name": <detail-type>,
    "type": "ERROR",
    "resource(s)": <resources>,
    "details": <detail>
  }
  EOF
  }
}

resource "aws_cloudwatch_event_rule" "sage_maker_hyper_parameter_tuning_failure_cloud_watch_event" {
  count       = var.enable_sage_maker_hyper_parameter_tuning_failure_alerts ? 1 : 0
  name        = "sagemaker-hyperparameter-tuning-failure-cloudwatch-event"
  description = "AWS CloudWatch Event to send alerts on AWS SNS regarding AWS SageMaker HyperParameter Tuning Failures."
  event_pattern = jsonencode({
    source = [
      "aws.sagemaker"
    ]
    detail-type = [
      "SageMaker HyperParameter Tuning Job State Change"
    ]
    detail = {
      HyperParameterTuningJobStatus = [
        "Failed"
      ]
    }
  })
}

resource "aws_cloudwatch_event_target" "sage_maker_hyper_parameter_tuning_failure_cloud_watch_event_target" {
  count     = var.enable_sage_maker_hyper_parameter_tuning_failure_alerts ? 1 : 0
  rule      = aws_cloudwatch_event_rule.sage_maker_hyper_parameter_tuning_failure_cloud_watch_event[0].name
  target_id = "FailurealertSNSTopicTarget"
  arn       = aws_sns_topic.aws_alerts_sns_topic.id
  input_transformer {
    input_paths = {
      detail      = "$.detail",
      detail-type = "$.detail-type",
      resources   = "$.resources",
      time        = "$.time",
      region      = "$.region",
      account     = "$.account",
    }
    input_template = <<EOF
  {
    "account_id": <account>,
    "region": <region>,
    "time": <time>,
    "service": "AWS SageMaker HyperParameter Tuning",
    "name": <detail-type>,
    "type": "FAILURE",
    "resource(s)": <resources>,
    "details": <detail>
  }
  EOF
  }
}

resource "aws_cloudwatch_event_rule" "sage_maker_transform_failure_cloud_watch_event" {
  count       = var.enable_sage_maker_transform_failure_alerts ? 1 : 0
  name        = "sagemaker-transform-failure-cloudwatch-event"
  description = "AWS CloudWatch Event to send alerts on AWS SNS regarding AWS SageMaker Transform Failures."
  event_pattern = jsonencode({
    source = [
      "aws.sagemaker"
    ]
    detail-type = [
      "SageMaker Transform Job State Change"
    ]
    detail = {
      TransformJobStatus = [
        "Failed"
      ]
    }
  })
}

resource "aws_cloudwatch_event_target" "sage_maker_transform_failure_cloud_watch_event_target" {
  count     = var.enable_sage_maker_transform_failure_alerts ? 1 : 0
  rule      = aws_cloudwatch_event_rule.sage_maker_transform_failure_cloud_watch_event[0].name
  target_id = "FailurealertSNSTopicTarget"
  arn       = aws_sns_topic.aws_alerts_sns_topic.id
  input_transformer {
    input_paths = {
      detail      = "$.detail",
      detail-type = "$.detail-type",
      resources   = "$.resources",
      time        = "$.time",
      region      = "$.region",
      account     = "$.account",
    }
    input_template = <<EOF
  {
    "account_id": <account>,
    "region": <region>,
    "time": <time>,
    "service": "AWS SageMaker Transform",
    "name": <detail-type>,
    "type": "FAILURE",
    "resource(s)": <resources>,
    "details": <detail>
  }
  EOF
  }
}

resource "aws_cloudwatch_event_rule" "sage_maker_training_failure_cloud_watch_event" {
  count       = var.enable_sage_maker_training_failure_alerts ? 1 : 0
  name        = "sagemaker-training-failure-cloudwatch-event"
  description = "AWS CloudWatch Event to send alerts on AWS SNS regarding AWS SageMaker Training Failures."
  event_pattern = jsonencode({
    source = [
      "aws.sagemaker"
    ]
    detail-type = [
      "SageMaker Training Job State Change"
    ]
    detail = {
      TrainingJobStatus = [
        "Failed"
      ]
    }
  })
}

resource "aws_cloudwatch_event_target" "sage_maker_training_failure_cloud_watch_event_target" {
  count     = var.enable_sage_maker_training_failure_alerts ? 1 : 0
  rule      = aws_cloudwatch_event_rule.sage_maker_training_failure_cloud_watch_event[0].name
  target_id = "FailurealertSNSTopicTarget"
  arn       = aws_sns_topic.aws_alerts_sns_topic.id
  input_transformer {
    input_paths = {
      detail      = "$.detail",
      detail-type = "$.detail-type",
      resources   = "$.resources",
      time        = "$.time",
      region      = "$.region",
      account     = "$.account",
    }
    input_template = <<EOF
  {
    "account_id": <account>,
    "region": <region>,
    "time": <time>,
    "service": "AWS SageMaker Training",
    "name": <detail-type>,
    "type": "FAILURE",
    "resource(s)": <resources>,
    "details": <detail>
  }
  EOF
  }
}
