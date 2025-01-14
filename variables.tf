variable "name" {
  description = "Name of the application"
  type        = string
}

variable "aws_region" {
  description = "AWS region where the resources will be created"
  type        = string
}

variable "environment" {
  description = "Name of the environment"
  type        = string
}

variable "account_id" {
  description = "AWS account ID"
  type        = string
}

variable "lambda_log_group" {
  description = "Name of the CloudWatch Log Group for the Lambda function"
  type        = string
}

variable "remediation_options" {
  description = "Options for the remediation document"
  type = object({
    region                                     = string
    reboot_option                              = string
    target_ec2_tag_name                        = string
    target_ec2_tag_value                       = string
    vulnerability_severities                   = list(string)
    override_findings_for_target_instances_ids = list(string)
  })
  default = {
    region                                     = "us-east-1"
    reboot_option                              = "NoReboot"
    target_ec2_tag_name                        = "AmazonECSManaged"
    target_ec2_tag_value                       = "true"
    vulnerability_severities                   = ["CRITICAL, HIGH"]
    override_findings_for_target_instances_ids = []
  }
}
