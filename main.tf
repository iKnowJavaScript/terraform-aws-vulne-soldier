provider "aws" {
  region = var.aws_region
}

locals {
  function_name     = "${var.name}-${var.environment}"
  ssm_document_name = "${var.name}-inspector-findings-${var.environment}"
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
      "default": "${var.remediation_options.region}"
    },
    "reboot_option": {
      "type": "String",
      "description": "(Optional) Reboot option for patching. Allowed values: NoReboot, RebootIfNeeded, AlwaysReboot",
      "default": "${var.remediation_options.reboot_option}"
    },
    "target_ec2_tag_name": {
      "type": "String",
      "description": "The tag name to filter EC2 instances.",
      "default": "${var.remediation_options.target_ec2_tag_name}"
    },
    "target_ec2_tag_value": {
      "type": "String",
      "description": "The tag value to filter EC2 instances.",
      "default": "${var.remediation_options.target_ec2_tag_value}"
    },
    "vulnerability_severities": {
      "type": "StringList",
      "description": "(Optional) List of vulnerability severities to filter findings. Allowed values are comma separated list of : CRITICAL, HIGH, MEDIUM, LOW, INFORMATIONAL",
      "default": "${var.remediation_options.vulnerability_severities}"
    },
    "override_findings_for_target_instances_ids": {
      "type": "StringList",
      "description": "(Optional) List of instance IDs to override findings for target instances. If not provided, all matched findings will be remediated. Values are in comma separated list of instance IDs.",
      "default": "${var.remediation_options.override_findings_for_target_instances_ids}"
    }
  },
  "mainSteps": [
    {
      "name": "invokeLambdaFunction",
      "action": "aws:invokeLambdaFunction",
      "inputs": {
        "FunctionName": "arn:aws:lambda:${var.aws_region}:${var.account_id}:function:${local.function_name}",
        "Payload": "{ \"region\": \"{{ region }}\", \"reboot_option\": \"{{ reboot_option }}\", \"target_ec2_tag_name\": \"{{ target_ec2_tag_name }}\", \"target_ec2_tag_value\": \"{{ target_ec2_tag_value }}\", \"vulnerability_severities\": \"{{ vulnerability_severities }}\", \"override_findings_for_target_instances_ids\": \"{{ override_findings_for_target_instances_ids }}\" }"
      }
    }
  ]
}
DOC
}

# Set up an EventBridge rule that triggers on AWS Inspector findings.
resource "aws_cloudwatch_event_rule" "inspector_findings" {
  name        = "manual-inspector-findings-rule"
  description = "Triggers on AWS Inspector findings."

  event_pattern = jsonencode({
    source        = ["aws.inspector"],
    "detail-type" = ["Inspector Finding"],
    detail = {
      severity = ["High", "Critical", "MEDIUM", "LOW", "INFORMATIONAL"]
    }
  })
}

resource "aws_cloudwatch_event_target" "ssm_remediation" {
  rule      = aws_cloudwatch_event_rule.inspector_findings.name
  target_id = "SSMVulneRemediationTarget"
  arn       = aws_ssm_document.remediation_document.arn

  run_command_targets {
    key    = "tag:${var.remediation_options.target_ec2_tag_name}"
    values = [var.remediation_options.target_ec2_tag_value]
  }


  role_arn = aws_iam_role.ssm_role.arn
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

  inline_policy {
    name = "SSMDocumentExecution"
    policy = jsonencode({
      Version = "2012-10-17",
      Statement = [
        {
          Action = [
            "ssm:StartAutomationExecution",
            "ssm:GetAutomationExecution"
          ],
          Effect   = "Allow",
          Resource = "arn:aws:ssm:*:*:document/${local.ssm_document_name}*"
        }
      ]
    })
  }
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
      Resource = "arn:aws:logs:*:*:*"
      },
      {
        "Effect" : "Allow",
        "Action" : [
          "ssm:StartAutomationExecution",
          "ssm:DescribeAutomationExecutions",
          "ssm:GetAutomationExecution"
        ],
        "Resource" : "*"
      },
      {
        "Effect" : "Allow",
        "Action" : [
          "ec2:DescribeInstances"
        ],
        "Resource" : "*"
      },
      {
        "Effect" : "Allow",
        "Action" : [
          "ssm:SendCommand"
        ],
        "Resource" : "*"
      },
      {
        "Effect" : "Allow",
        "Action" : [
          "inspector2:DescribeFindings",
          "inspector2:ListFindings",
          "inspector2:updateFindings"
        ],
        "Resource" : "*"
      },
      {
        "Effect" : "Allow",
        "Action" : [
          "inspector:DescribeFindings",
          "inspector:ListFindings"
        ],
        "Resource" : "*"
    }],
  })
}


resource "aws_lambda_function" "inspector_remediation" {
  filename         = "../../lambda.zip" # You should zip your lambda_function.js before deploying
  function_name    = local.function_name
  role             = aws_iam_role.lambda_execution_role.arn
  handler          = "findings-remediate.handler"
  runtime          = "nodejs18.x"
  source_code_hash = filebase64sha256("./lambda.zip")

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


resource "aws_cloudwatch_event_target" "lambda" {
  rule = aws_cloudwatch_event_rule.inspector_findings.name
  arn  = aws_lambda_function.inspector_remediation.arn
}

resource "aws_lambda_permission" "allow_cloudwatch_to_call_lambda" {
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.inspector_remediation.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.inspector_findings.arn
}


