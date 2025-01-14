
output "lambda_function_arn" {
  description = "Lambda function ARN"
  value       = aws_lambda_function.inspector_remediation.arn
}

output "lambda_function_name" {
  description = "Lambda function name"
  value       = aws_lambda_function.inspector_remediation.function_name
}

output "ssm_document_name" {
  description = "SSM document name"
  value       = aws_ssm_document.remediation_document.name
}

