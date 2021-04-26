output "kms_key" {
  description = "SecretsManager secret"
  value       = aws_kms_key.key
}

output "kms_key_alias" {
  description = "SecretsManager secret"
  value       = aws_kms_alias.alias
}

output "lambda_post" {
  description = "Slack API helper Lambda"
  value       = aws_lambda_function.post
}

output "lambda_proxy" {
  description = "API Gateway REST API proxy Lambda"
  value       = aws_lambda_function.proxy
}

output "role" {
  description = "Lambda function role"
  value       = aws_iam_role.role
}

output "secret" {
  description = "SecretsManager secret"
  value       = aws_secretsmanager_secret.secret
}
