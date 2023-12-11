module "aws-failure-error-warning-termination-notification-framework" {
  source                                                            = "./terraform"
  failure_error_warning_termination_notification_sns_topic_protocol = "email"
  failure_error_warning_termination_notification_sns_topic_endpoint = "abc.xyz@gmail.com"

  # Following is an optional variable.
  # It is used to provide a list of AWS Lambda function names to monitor for failures.
  # If not provided, it will fetch all AWS Lambda function names.
  # Only works if enable_lambda_failure_notification variable is set to true.
  # e.g., lambda_function_names = ["function-1", "function-2"]

  # Enabled
  enable_cloudformation_failure_notification          = true
  enable_lambda_failure_notification                  = true
  enable_rds_failure_warning_notification             = true
  enable_ec2_auto_scaling_failure_notification        = true
  enable_config_failure_notification                  = true
  enable_ebs_failure_notification                     = true
  enable_ec2_spot_instance_error_notification         = true
  enable_trusted_advisor_error_warning_notification   = true
  enable_health_error_notification                    = true
  enable_ssm_maintainance_window_failure_notification = true
  enable_ssmec2_failure_notification                  = true
  enable_ssm_compliance_warning_notification          = true
  enable_kms_key_expiration_warning_notification      = true

  # Not Enabled
  enable_dms_failure_warning_notification                       = false
  enable_redshift_error_notification                            = false
  enable_code_build_failure_notification                        = false
  enable_batch_failure_notification                             = false
  enable_code_deploy_failure_notification                       = false
  enable_code_pipeline_failure_notification                     = false
  enable_glue_failure_notification                              = false
  enable_emr_failure_notification                               = false
  enable_emr_error_notification                                 = false
  enable_ecs_instance_termination_notification                  = false
  enable_ecs_task_termination_notification                      = false
  enable_ec2_instance_termination_notification                  = false
  enable_sms_failure_notification                               = false
  enable_step_functions_failure_notification                    = false
  enable_ops_works_failure_notification                         = false
  enable_ops_works_error_notification                           = false
  enable_macie_warning_notification                             = false
  enable_game_lift_failure_notification                         = false
  enable_transcribe_failure_notification                        = false
  enable_signer_failure_notification                            = false
  enable_data_sync_error_warning_notification                   = false
  enable_iot_analytics_failure_notification                     = false
  enable_data_lifecycle_manager_error_notification              = false
  enable_elemental_media_package_error_notification             = false
  enable_elemental_media_live_error_notification                = false
  enable_elemental_media_convert_error_notification             = false
  enable_sage_maker_hyper_parameter_tuning_failure_notification = false
  enable_sage_maker_transform_failure_notification              = false
  enable_sage_maker_training_failure_notification               = false
}
