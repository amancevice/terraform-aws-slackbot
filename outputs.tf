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

output lambda_api_arn {
  description = "API Lambda ARN."
  value       = aws_lambda_function.api.arn
}

output lambda_api_function_name {
  description = "API Lambda function name."
  value       = aws_lambda_function.api.function_name
}

output lambda_post_message_arn {
  description = "Post message Lambda ARN."
  value       = aws_lambda_function.post_message.arn
}

output lambda_post_message_function_name {
  description = "Post message Lambda function name."
  value       = aws_lambda_function.post_message.function_name
}

output lambda_post_ephemeral_arn {
  description = "Post ephemeral Lambda ARN."
  value       = aws_lambda_function.post_ephemeral.arn
}

output lambda_post_ephemeral_function_name {
  description = "Post ephemeral Lambda function name."
  value       = aws_lambda_function.post_ephemeral.function_name
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
