variable "name" {
  description = "Name of the application"
  type        = string
  default = "vulne-soldier-compliance-remediate"
}

variable "aws_region" {
  description = "AWS region where the resources will be created"
  type        = string
  default = "us-east-1"
}

variable "environment" {
  description = "Name of the environment"
  type        = string
  default = "dev"
}

variable "account_id" {
  description = "AWS account ID"
  type        = string
  validation {
    condition     = can(regex("^[0-9]{12}$", var.account_id))
    error_message = "The account_id must be a 12-digit number."
  }
}

variable "lambda_log_group" {
  description = "Name of the CloudWatch Log Group for the Lambda function"
  type        = string
}

variable "lambda_zip" {
  description = "File location of the lambda zip file for remediation."
  type        = string
  validation {
    condition     = can(regex("^.+\\.zip$", var.lambda_zip))
    error_message = "The lambda_zip must be a path to a zip file."
  }
}

variable "remediation_options" {
  description = "Options for the remediation document"
  type = object({
    region                                     = string
    reboot_option                              = string
    target_ec2_tag_name                        = string
    target_ec2_tag_value                       = string
    vulnerability_severities                   = string
    override_findings_for_target_instances_ids = string
  })
  default = {
    region                                     = "us-east-1"
    reboot_option                              = "NoReboot"
    target_ec2_tag_name                        = "AmazonECSManaged"
    target_ec2_tag_value                       = "true"
    vulnerability_severities                   = "CRITICAL, HIGH"
    override_findings_for_target_instances_ids = null
  }
  validation {
    condition     = contains(["NoReboot", "RebootIfNeeded"], var.remediation_options.reboot_option)
    error_message = "The reboot_option must be either NoReboot or RebootIfNeeded."
  }
  validation {
    condition     = can(regex("^([A-Z]+, )*[A-Z]+$", var.remediation_options.vulnerability_severities))
    error_message = "The vulnerability_severities must be a comma-separated list of severities in uppercase."
  }
}
