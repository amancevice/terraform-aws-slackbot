###############
#   OUTPUTS   #
###############

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

output "functions" {
  description = "Lambda functions"
  value       = aws_lambda_function.functions
}

output "logs" {
  description = "CloudWatch log groups"
  value       = aws_cloudwatch_log_group.logs
}

output "openapi" {
  description = "OpenAPI JSON definition"
  value = {
    json = aws_api_gateway_rest_api.api.body
    yaml = yamlencode(jsondecode(aws_api_gateway_rest_api.api.body))
  }
}

output "roles" {
  description = "IAM roles"
  value       = aws_iam_role.roles
}

output "state_machines" {
  description = "State Machines"
  value       = aws_sfn_state_machine.states
}
