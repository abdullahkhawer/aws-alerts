Need to install the following packages:
git-cliff@1.4.0
Ok to proceed? (y) # Changelog

All notable changes to this project will be documented in this file.


## [1.1.1] - 2023-11-30

[1.1.1]: https://github.com/abdullahkhawer/aws-failure-error-warning-termination-notification-framework/releases/tag/v1.1.1

### Bug Fixes

- Update main.tf to fix paths for code related to Python AWS Lambda function.
- Remove libraries from requirements.txt which are not required anymore.
- Create terraform-usage-example.tf as usage example for Terraform.

## [1.1.0] - 2023-09-12

[1.1.0]: https://github.com/abdullahkhawer/aws-failure-error-warning-termination-notification-framework/releases/tag/v1.1.0

### Bug Fixes

- Update AWS CloudFormation templates to make both endpoint and protocol for AWS SNS topic generic, update Python version to 3.9, refactor code and fix minor bugs.

### Features

- Add Terraform templates to enable Terraform for IaC tool to use it to deploy this framework

### Miscellaneous Tasks

- Update .gitignore to ignore .terraform and .zip files from git commit.
- Add git cliff config to generate changelog.md
- Change the location of aws_cloudformation_failure_notification.py Python script and add requirements.txt file to mention the modules used in it.
- Update README.md with new details regarding Terraform support and correct mistakes in it.
