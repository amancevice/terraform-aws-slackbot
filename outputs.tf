output "apigateway" {
  description = "API Gateway resources"
  value = {
    rest_api    = aws_api_gateway_rest_api.api
    domain_name = aws_api_gateway_domain_name.api
    stage       = aws_api_gateway_stage.api
  }
}

output "connection" {
  description = "EventBridge connection"
  value       = aws_cloudwatch_event_connection.slack
}

output "roles" {
  description = "IAM roles"
  value = {
    apigateway  = aws_iam_role.apigateway
    states      = aws_iam_role.states
    authorizer  = aws_iam_role.authorizer
    oauth       = aws_iam_role.oauth
    transformer = aws_iam_role.transformer
  }
}

output "functions" {
  description = "Lambda functions"
  value = {
    authorizer  = aws_lambda_function.authorizer
    transformer = aws_lambda_function.transformer
    oauth       = aws_lambda_function.oauth
  }
}

output "state_machines" {
  description = "State Machines"
  value       = aws_sfn_state_machine.states
}
