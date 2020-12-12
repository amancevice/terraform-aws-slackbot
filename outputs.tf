output "kms_key" {
  description = "SecretsManager secret"
  value       = aws_kms_key.key
}

output "kms_key_alias" {
  description = "SecretsManager secret"
  value       = aws_kms_alias.alias
}

output "lambda" {
  description = "API Gateway REST API proxy Lambda"
  value       = aws_lambda_function.api
}

output "role" {
  description = "Lambda function role"
  value       = aws_iam_role.role
}

output "secret" {
  description = "SecretsManager secret"
  value       = aws_secretsmanager_secret.secret
}

output "topic" {
  description = "Slackbot SNS topic"
  value       = aws_sns_topic.topic
}
