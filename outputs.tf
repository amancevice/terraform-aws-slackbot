output api {
  description = "API Gateway REST API"
  value       = aws_api_gateway_rest_api.api
}

output api_deployment {
  description = "API Gateway REST API deployment"
  value       = aws_api_gateway_deployment.api
}

output lambda {
  description = "API Gateway REST API proxy Lambda"
  value       = aws_lambda_function.api
}

output role {
  description = "Lambda function role"
  value       = aws_iam_role.role
}

output topic {
  description = "Slackbot SNS topic"
  value       = aws_sns_topic.topic
}
