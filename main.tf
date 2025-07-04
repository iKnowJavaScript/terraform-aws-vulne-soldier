provider "aws" {
  region = var.aws_region
}

locals {
  function_name     = "${var.name}-${var.environment}"
  ssm_document_name = "${var.name}-inspector-findings-${var.environment}"
  lambda_zip        = var.path_to_lambda_zip
}

resource "aws_ssm_document" "remediation_document" {
  name          = local.ssm_document_name
  document_type = "Automation"

  content = <<DOC
{
  "schemaVersion": "0.3",
  "description": "Triggers AWS Inspector findings remediation.",
  "parameters": {
    "region": {
      "type": "String",
      "description": "(Required) The region to use.",
      "default": "${local.default_remediation_option.region}"
    },
    "rebootOption": {
      "type": "String",
      "description": "(Optional) Reboot option for patching. Allowed values: NoReboot, RebootIfNeeded, AlwaysReboot",
      "default": "${local.default_remediation_option.reboot_option}"
    },
    "targetEC2TagName": {
      "type": "String",
      "description": "The tag name to filter EC2 instances.",
      "default": "${local.default_remediation_option.target_ec2_tag_name}"
    },
    "targetEC2TagValue": {
      "type": "String",
      "description": "The tag value to filter EC2 instances.",
      "default": "${local.default_remediation_option.target_ec2_tag_value}"
    },
    "vulnerabilitySeverities": {
      "type": "String",
      "description": "(Optional) Comma separated list of vulnerability severities to filter findings. Allowed values are comma separated list of : CRITICAL, HIGH, MEDIUM, LOW, INFORMATIONAL",
      "default": "${local.default_remediation_option.vulnerability_severities}"
    },
    "overrideFindingsForTargetInstancesIDs": {
      "type": "String",
      "description": "(Optional) Comma separated list of instance IDs to override findings for target instances. If not provided, all matched findings will be remediated. Values are in comma separated list of instance IDs.",
      "default": "${local.default_remediation_option.override_findings_for_target_instances_ids}"
    }
  },
  "mainSteps": [
    {
      "name": "invokeLambdaFunction",
      "action": "aws:invokeLambdaFunction",
      "inputs": {
        "FunctionName": "arn:aws:lambda:${var.aws_region}:${var.account_id}:function:${local.function_name}",
        "Payload": "{ \"region\": \"{{ region }}\", \"reboot_option\": \"{{ rebootOption }}\", \"target_ec2_tag_name\": \"{{ targetEC2TagName }}\", \"target_ec2_tag_value\": \"{{ targetEC2TagValue }}\", \"vulnerability_severities\": \"{{ vulnerabilitySeverities }}\", \"override_findings_for_target_instances_ids\": \"{{ overrideFindingsForTargetInstancesIDs }}\" }"
      }
    }
  ]
}
DOC
}

locals {
  remediation_options_count  = length(var.remediation_options)
  default_remediation_option = var.remediation_options[0]
}

resource "aws_cloudwatch_event_rule" "inspector_findings_last" {
  count               = local.remediation_options_count
  name                = "manual-inspector-findings-rule-last-${count.index}-${var.remediation_options[count.index].region}"
  description         = "Triggers SSM remediation document on the last day of each month for remediation option ${count.index}."
  schedule_expression = "cron(0 2 L * ? *)"

  tags = {
    Environment = var.environment
    Name        = "manual-inspector-findings-rule-last-${var.environment}-${count.index}"
  }
}

resource "aws_cloudwatch_event_target" "ssm_remediation_last" {
  count     = local.remediation_options_count
  rule      = aws_cloudwatch_event_rule.inspector_findings_last[count.index].name
  target_id = "SSMVulneRemediationTarget-${count.index}-${var.remediation_options[count.index].region}"
  arn       = aws_ssm_document.remediation_document.arn
  input = jsonencode({
    region                                = var.remediation_options[count.index].region,
    rebootOption                          = var.remediation_options[count.index].reboot_option,
    targetEC2TagName                      = var.remediation_options[count.index].target_ec2_tag_name,
    targetEC2TagValue                     = var.remediation_options[count.index].target_ec2_tag_value,
    vulnerabilitySeverities               = var.remediation_options[count.index].vulnerability_severities,
    overrideFindingsForTargetInstancesIDs = var.remediation_options[count.index].override_findings_for_target_instances_ids,
  })

  role_arn = aws_iam_role.ssm_role.arn
}

resource "aws_cloudwatch_event_target" "sns_inspector_alert_last" {
  count     = local.remediation_options_count
  rule      = aws_cloudwatch_event_rule.inspector_findings_last[count.index].name
  target_id = "InspectorCriticalHighAlertsSNS-Last-${count.index}-${var.remediation_options[count.index].region}"
  arn       = var.ssn_notification_topic_arn
}

resource "aws_iam_role" "ssm_role" {
  name = "SSMVulneAutomationRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "events.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "ssm_document_execution" {
  name = "SSMDocumentExecution"
  role = aws_iam_role.ssm_role.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = concat(
      [
        {
          Action = [
            "ssm:StartAutomationExecution",
            "ssm:GetAutomationExecution"
          ],
          Effect   = "Allow",
          Resource = "arn:aws:ssm:*:*:document/${local.ssm_document_name}*"
        }
      ],
      var.ssn_notification_topic_arn != null ? [
        {
          Effect   = "Allow",
          Action   = "SNS:Publish",
          Resource = var.ssn_notification_topic_arn
        }
      ] : []
    )
  })
}

resource "aws_iam_role" "lambda_execution_role" {
  name = "compliance-vulne-remediate_lambda_execution_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action = "sts:AssumeRole",
      Effect = "Allow",
      Principal = {
        Service = "lambda.amazonaws.com"
      },
    }],
  })
}

resource "aws_iam_role_policy" "lambda_policy" {
  name = "compliance-vulne-remediate_lambda_policy"
  role = aws_iam_role.lambda_execution_role.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action = [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      Effect   = "Allow",
      Resource = "arn:aws:logs:*:${var.account_id}:*"
      },
      {
        Effect = "Allow",
        Action = [
          "ssm:StartAutomationExecution",
          "ssm:DescribeAutomationExecutions",
          "ssm:GetAutomationExecution"
        ],
        Resource = "arn:aws:ssm:*:${var.account_id}:automation-definition/*"
      },
      {
        "Effect" : "Allow",
        "Action" : [
          "ec2:DescribeInstances"
        ],
        "Resource" : "*"
      },
      {
        Effect = "Allow",
        Action = [
          "ssm:SendCommand"
        ],
        Resource = [
          "*",
          "arn:aws:ec2:*:${var.account_id}:instance/*"
        ]
      },
      {
        "Effect" : "Allow",
        "Action" : [
          "inspector2:DescribeFindings",
          "inspector2:ListFindings",
          "inspector2:updateFindings"
        ],
        "Resource" : "arn:aws:inspector2:*:${var.account_id}:*"
      },
      {
        "Effect" : "Allow",
        "Action" : [
          "inspector:DescribeFindings",
          "inspector:ListFindings"
        ],
        "Resource" : "arn:aws:inspector:*:${var.account_id}:*"
    }],
  })
}


resource "aws_lambda_function" "inspector_remediation" {
  filename         = local.lambda_zip # You should zip your lambda_function.js before deploying
  function_name    = local.function_name
  role             = aws_iam_role.lambda_execution_role.arn
  handler          = "index.handler"
  runtime          = "nodejs20.x"
  source_code_hash = filebase64sha256(local.lambda_zip)

  timeout = 300

  environment {
    variables = {
      LOG_LEVEL        = "INFO"
      LAMBDA_LOG_GROUP = var.lambda_log_group
    }
  }

  tags = {
    Environment = var.environment
  }
}

