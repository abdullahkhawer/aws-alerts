provider "aws" {
  region = "eu-west-1"
}

module "aws-alerts" {
  source                                   = "./terraform"
  slack_webhook_url_aws_ssm_parameter_name = "/${var.environment}/aws-alerts-slack-webhook-url"

  # lambda_function_names is an optional variable.
  # It is used to provide a list of AWS Lambda function names to monitor for failures.
  # If not provided, it will fetch all AWS Lambda function names.
  # Only works if enable_lambda_failure_notification variable is set to true.
  # e.g., lambda_function_names = ["function-1", "function-2"]

  # Enabled
  enable_lambda_failure_alerts                  = true
  enable_rds_failure_warning_alerts             = true
  enable_ec2_auto_scaling_failure_alerts        = true
  enable_config_failure_alerts                  = true
  enable_ebs_failure_alerts                     = true
  enable_ec2_spot_instance_error_alerts         = true
  enable_trusted_advisor_error_warning_alerts   = true
  enable_health_error_alerts                    = true
  enable_ssm_maintainance_window_failure_alerts = true
  enable_ssmec2_failure_alerts                  = true
  enable_ssm_compliance_warning_alerts          = true
  enable_kms_key_expiration_warning_alerts      = true

  # Disabled
  enable_dms_failure_warning_alerts                       = false
  enable_redshift_error_alerts                            = false
  enable_code_build_failure_alerts                        = false
  enable_batch_failure_alerts                             = false
  enable_code_deploy_failure_alerts                       = false
  enable_code_pipeline_failure_alerts                     = false
  enable_glue_failure_alerts                              = false
  enable_emr_failure_alerts                               = false
  enable_emr_error_alerts                                 = false
  enable_ecs_instance_termination_alerts                  = false
  enable_ecs_task_termination_alerts                      = false
  enable_ec2_instance_termination_alerts                  = false
  enable_sms_failure_alerts                               = false
  enable_step_functions_failure_alerts                    = false
  enable_ops_works_failure_alerts                         = false
  enable_ops_works_error_alerts                           = false
  enable_macie_warning_alerts                             = false
  enable_game_lift_failure_alerts                         = false
  enable_transcribe_failure_alerts                        = false
  enable_signer_failure_alerts                            = false
  enable_data_sync_error_warning_alerts                   = false
  enable_iot_analytics_failure_alerts                     = false
  enable_data_lifecycle_manager_error_alerts              = false
  enable_elemental_media_package_error_alerts             = false
  enable_elemental_media_live_error_alerts                = false
  enable_elemental_media_convert_error_alerts             = false
  enable_sage_maker_hyper_parameter_tuning_failure_alerts = false
  enable_sage_maker_transform_failure_alerts              = false
  enable_sage_maker_training_failure_alerts               = false
}
