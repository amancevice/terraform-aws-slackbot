output lambda {
  description = "API Gateway REST API proxy Lambda"
  value       = aws_lambda_function.api
}

output role {
  description = "Lambda function role"
  value       = aws_iam_role.role
}

output secret {
  description = "SecretsManager secret"
  value       = data.aws_secretsmanager_secret.secret
}

output topic {
  description = "Slackbot SNS topic"
  value       = aws_sns_topic.topic
}
