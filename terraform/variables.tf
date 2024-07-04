variable "slack_webhook_url_aws_ssm_parameter_name" {
  description = "Name of the AWS SSM Parameter Name from the Parameter Store which is having Slack Webhook URL."
  type        = string
}

variable "enable_lambda_failure_alerts" {
  description = "Option to Enable AWS Lambda Failure Notification."
  type        = string
  default     = false
}

variable "lambda_function_names" {
  description = "List of AWS Lambda function names to monitor for failures."
  type        = list(string)
  default     = []
}

variable "enable_dms_failure_warning_alerts" {
  description = "Option to Enable AWS DMS Failure and Warning Notification."
  type        = string
  default     = false
}

variable "enable_rds_failure_warning_alerts" {
  description = "Option to Enable AWS RDS Failure and Warning Notification."
  type        = string
  default     = false
}

variable "enable_redshift_error_alerts" {
  description = "Option to Enable AWS Redshift Error Notification."
  type        = string
  default     = false
}

variable "enable_code_build_failure_alerts" {
  description = "Option to Enable AWS CodeBuild Failure Notification."
  type        = string
  default     = false
}

variable "enable_ec2_auto_scaling_failure_alerts" {
  description = "Option to Enable AWS EC2 Auto Scaling Failure Notification."
  type        = string
  default     = false
}

variable "enable_batch_failure_alerts" {
  description = "Option to Enable AWS Batch Failure Notification."
  type        = string
  default     = false
}

variable "enable_code_deploy_failure_alerts" {
  description = "Option to Enable AWS CodeDeploy Failure Notification."
  type        = string
  default     = false
}

variable "enable_code_pipeline_failure_alerts" {
  description = "Option to Enable AWS CodePipeline Failure Notification."
  type        = string
  default     = false
}

variable "enable_config_failure_alerts" {
  description = "Option to Enable AWS Config Failure Notification."
  type        = string
  default     = false
}

variable "enable_ebs_failure_alerts" {
  description = "Option to Enable AWS EBS Failure Notification."
  type        = string
  default     = false
}

variable "enable_glue_failure_alerts" {
  description = "Option to Enable AWS Glue Failure Notification."
  type        = string
  default     = false
}

variable "enable_emr_failure_alerts" {
  description = "Option to Enable AWS EMR Failure Notification."
  type        = string
  default     = false
}

variable "enable_emr_error_alerts" {
  description = "Option to Enable AWS EMR Error Notification."
  type        = string
  default     = false
}

variable "enable_ecs_instance_termination_alerts" {
  description = "Option to Enable AWS ECS Instance Termination Notification."
  type        = string
  default     = false
}

variable "enable_ecs_task_termination_alerts" {
  description = "Option to Enable AWS ECS Task Termination Notification."
  type        = string
  default     = false
}

variable "enable_ec2_instance_termination_alerts" {
  description = "Option to Enable AWS EC2 Instance Termination Notification."
  type        = string
  default     = false
}

variable "enable_ec2_spot_instance_error_alerts" {
  description = "Option to Enable AWS EC2 Spot Instance Error Notification."
  type        = string
  default     = false
}

variable "enable_trusted_advisor_error_warning_alerts" {
  description = "Option to Enable AWS Trusted Advisor Error and Warning Notification."
  type        = string
  default     = false
}

variable "enable_health_error_alerts" {
  description = "Option to Enable AWS Health Error Notification."
  type        = string
  default     = false
}

variable "enable_sms_failure_alerts" {
  description = "Option to Enable AWS Server Migration Service Failure Notification."
  type        = string
  default     = false
}

variable "enable_step_functions_failure_alerts" {
  description = "Option to Enable AWS Step Functions Failure Notification."
  type        = string
  default     = false
}

variable "enable_ssm_maintainance_window_failure_alerts" {
  description = "Option to Enable AWS SSM Maintainance Window Failure Notification."
  type        = string
  default     = false
}

variable "enable_ssmec2_failure_alerts" {
  description = "Option to Enable AWS SSM EC2 State Manager, Run Command and Automation Failure Notification."
  type        = string
  default     = false
}

variable "enable_ssm_compliance_warning_alerts" {
  description = "Option to Enable AWS SSM Compliance Warning Notification."
  type        = string
  default     = false
}

variable "enable_ops_works_failure_alerts" {
  description = "Option to Enable AWS OpsWorks Failure Notification."
  type        = string
  default     = false
}

variable "enable_ops_works_error_alerts" {
  description = "Option to Enable AWS OpsWorks Error Notification."
  type        = string
  default     = false
}

variable "enable_kms_key_expiration_warning_alerts" {
  description = "Option to Enable AWS KMS Key Expiration Warning Notification."
  type        = string
  default     = false
}

variable "enable_macie_warning_alerts" {
  description = "Option to Enable AWS Macie Warning Notification."
  type        = string
  default     = false
}

variable "enable_game_lift_failure_alerts" {
  description = "Option to Enable AWS GameLift Failure Notification."
  type        = string
  default     = false
}

variable "enable_transcribe_failure_alerts" {
  description = "Option to Enable AWS Transcribe Failure Notification."
  type        = string
  default     = false
}

variable "enable_signer_failure_alerts" {
  description = "Option to Enable AWS Signer Failure Notification."
  type        = string
  default     = false
}

variable "enable_data_sync_error_warning_alerts" {
  description = "Option to Enable AWS DataSync Error and Warning Notification."
  type        = string
  default     = false
}

variable "enable_iot_analytics_failure_alerts" {
  description = "Option to Enable AWS IoT Analytics Failure Notification."
  type        = string
  default     = false
}

variable "enable_data_lifecycle_manager_error_alerts" {
  description = "Option to Enable AWS Data Lifecycle Manager Error Notification."
  type        = string
  default     = false
}

variable "enable_elemental_media_package_error_alerts" {
  description = "Option to Enable AWS Elemental MediaPackage Error Notification."
  type        = string
  default     = false
}

variable "enable_elemental_media_live_error_alerts" {
  description = "Option to Enable AWS Elemental MediaLive Error Notification."
  type        = string
  default     = false
}

variable "enable_elemental_media_convert_error_alerts" {
  description = "Option to Enable AWS Elemental MediaConvert Error Notification."
  type        = string
  default     = false
}

variable "enable_sage_maker_hyper_parameter_tuning_failure_alerts" {
  description = "Option to Enable AWS SageMaker HyperParameter Tuning Failure Notification."
  type        = string
  default     = false
}

variable "enable_sage_maker_transform_failure_alerts" {
  description = "Option to Enable AWS SageMaker Transform Failure Notification."
  type        = string
  default     = false
}

variable "enable_sage_maker_training_failure_alerts" {
  description = "Option to Enable AWS SageMaker Training Failure Notification."
  type        = string
  default     = false
}
