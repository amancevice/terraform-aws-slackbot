output "api_execution_arn" {
  description = "REST API deployment execution ARN."
  value       = "${aws_api_gateway_deployment.api.execution_arn}"
}

output "api_id" {
  description = "REST API ID."
  value       = "${aws_api_gateway_rest_api.api.id}"
}

output "api_invoke_url" {
  description = "REST API invocation URL."
  value       = "${aws_api_gateway_deployment.api.invoke_url}"
}

output "api_name" {
  description = "REST API Name."
  value       = "${aws_api_gateway_rest_api.api.name}"
}

output "api_root_resource_id" {
  description = "REST API root resource ID."
  value       = "${aws_api_gateway_rest_api.api.root_resource_id}"
}

output "kms_key_alias" {
  description = "Slackbot KMS Key alias."
  value       = "${aws_kms_alias.slackbot.name}"
}

output "kms_key_arn" {
  description = "Slackbot KMS Key ARN."
  value       = "${aws_kms_key.slackbot.arn}"
}

output "kms_key_id" {
  description = "Slackbot KMS Key ID."
  value       = "${aws_kms_key.slackbot.key_id}"
}

output "events_request_url" {
  description = "Slackbot Events Request URL."
  value       = "${aws_api_gateway_deployment.api.invoke_url}/${aws_api_gateway_resource.events.path_part}"
}

output "interactive_components_request_url" {
  description = "Slackbot Interactive Components Request URL."
  value        = "${aws_api_gateway_deployment.api.invoke_url}/${aws_api_gateway_resource.interactive_components.path_part}"
}

output "sns_topics" {
  description = "SNS topics created."
  value       = [
    "${aws_sns_topic.callback_ids.*.name}",
    "${aws_sns_topic.event_types.*.name}"
  ]
}
