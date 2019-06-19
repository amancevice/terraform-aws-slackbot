output api_id {
  description = "REST API ID."
  value       = aws_api_gateway_rest_api.api.id
}

output api_name {
  description = "REST API name."
  value       = aws_api_gateway_rest_api.api.name
}

output api_stage_name {
  description = "REST API stage name."
  value       = aws_api_gateway_deployment.api.stage_name
}

output kms_key_arn {
  description = "KMS key ARN."
  value       = data.aws_kms_key.key.arn
}

output role_arn {
  description = "Lambda function role ARN."
  value       = aws_iam_role.role.arn
}

output role_name {
  description = "Lambda function role name."
  value       = aws_iam_role.role.name
}

output secret_arn {
  description = "SecretsManager secret ARN."
  value       = data.aws_secretsmanager_secret.secret.arn
}

output secret_name {
  description = "SecretsManager secret name."
  value       = data.aws_secretsmanager_secret.secret.name
}

output topic_arn {
  description = "Slackbot OAuth SNS topic ARN."
  value       = aws_sns_topic.topic.arn
}

output topic_name {
  description = "Slackbot OAuth SNS topic name."
  value       = aws_sns_topic.topic.name
}
