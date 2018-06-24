output "api_execution_arn" {
  description = "REST API deployment execution ARN."
  value       = "${aws_api_gateway_deployment.api.execution_arn}"
}

output "api_invoke_url" {
  description = "REST API deployment invocation URL."
  value       = "${aws_api_gateway_deployment.api.invoke_url}"
}

output "api_name" {
  description = "REST API Name."
  value       = "${aws_api_gateway_rest_api.api.name}"
}

output "kms_key_id" {
  description = "KMS Key ID."
  value       = "${aws_kms_key.slackbot.key_id}"
}

output "encrypted_slack_verification_token" {
  description = "Encrypted Slack verification token"
  value       = "${local.encrypted_slack_verification_token}"
}

output "events_request_url" {
  description = "Events Request URL."
  value       = "${aws_api_gateway_deployment.api.invoke_url}/${aws_api_gateway_resource.events.path_part}"
}

output "interactive_components_request_url" {
  description = "Interactive Components Request URL."
  value        = "${aws_api_gateway_deployment.api.invoke_url}/${aws_api_gateway_resource.interactive_components.path_part}"
}

output "sns_topics" {
  description = "SNS topics."
  value       = [
    "${aws_sns_topic.callback_ids.*.name}",
    "${aws_sns_topic.event_types.*.name}"
  ]
}
