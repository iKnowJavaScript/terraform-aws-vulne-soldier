output "lambda_function_arn" {
  description = "Lambda function ARN"
  value       = module.remediation.lambda_function_arn
}

output "lambda_function_name" {
  description = "Lambda function name"
  value       = module.remediation.lambda_function_name
}

output "ssm_document_name" {
  description = "SSM document name"
  value       = module.remediation.ssm_document_name
}

