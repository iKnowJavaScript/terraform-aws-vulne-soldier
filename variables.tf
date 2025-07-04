variable "name" {
  description = "Name of the application"
  type        = string
  default     = "vulne-soldier-compliance-remediate"
}

variable "aws_region" {
  description = "AWS region where the resources will be created"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Name of the environment"
  type        = string
  default     = "dev"
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

variable "path_to_lambda_zip" {
  description = "File location of the lambda zip file for remediation."
  type        = string
  validation {
    condition     = can(regex("^.+\\.zip$", var.path_to_lambda_zip))
    error_message = "The path_to_lambda_zip must be a path to a zip file."
  }
}

variable "remediation_options" {
  description = "List of remediation option objects"
  type = list(object({
    region                                     = string
    reboot_option                              = string
    target_ec2_tag_name                        = string
    target_ec2_tag_value                       = string
    vulnerability_severities                   = string
    override_findings_for_target_instances_ids = string
  }))
  default = [
    {
      region                                     = "us-east-1"
      reboot_option                              = "NoReboot"
      target_ec2_tag_name                        = "AmazonECSManaged"
      target_ec2_tag_value                       = "true"
      vulnerability_severities                   = "CRITICAL, HIGH"
      override_findings_for_target_instances_ids = null
    }
  ]
  validation {
    condition = alltrue([
      for opt in var.remediation_options : contains(["NoReboot", "RebootIfNeeded"], opt.reboot_option)
    ])
    error_message = "Each remediation_option.reboot_option must be either NoReboot or RebootIfNeeded."
  }
  validation {
    condition = alltrue([
      for opt in var.remediation_options : can(regex("^([A-Z]+, )*[A-Z]+$", opt.vulnerability_severities))
    ])
    error_message = "Each remediation_option.vulnerability_severities must be a comma-separated list of severities in uppercase."
  }
}

variable "ssn_notification_topic_arn" {
  description = "SNS topic ARN for notifications"
  type        = string
  default     = null
  validation {
    condition     = var.ssn_notification_topic_arn == null || can(regex("^arn:aws:sns:[a-z0-9-]+:[0-9]{12}:[a-zA-Z0-9_-]+$", var.ssn_notification_topic_arn))
    error_message = "The ssn_notification_topic_arn must be null or a valid SNS topic ARN."
  }
}

variable "remediation_schedule_days" {
  description = "List of days in the month to trigger remediation (e.g., [15, \"L\"] for 15th and last day)"
  type        = list(string)
  default     = ["15", "L"]
  validation {
    condition     = length(var.remediation_schedule_days) > 0 && alltrue([for d in var.remediation_schedule_days : can(regex("^(0?[1-9]|[12][0-9]|3[01]|L)$", d))])
    error_message = "Each value in remediation_schedule_days must be a day number (1-31) or 'L' for last day."
  }
}