output "api" {
  description = "API Gateway API"
  value       = aws_apigatewayv2_api.api
}

output "api_domain" {
  description = "API Gateway custom domain"
  value       = aws_apigatewayv2_domain_name.api
}

output "api_stage" {
  description = "API Gateway stage"
  value       = aws_apigatewayv2_stage.default
}

output "functions" {
  description = "Lambda functions"
  value = {
    receiver  = aws_lambda_function.receiver
    responder = aws_lambda_function.responder
    slack_api = aws_lambda_function.slack_api
  }
}

output "secret" {
  description = "SecretsManager secret container"
  value       = aws_secretsmanager_secret.secret
}
