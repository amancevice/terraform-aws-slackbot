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

output "callback_resource_ids" {
  description = "API Gateway Resource IDs for Slack callbacks."
  value       = "${zipmap("${var.callback_ids}", "${aws_api_gateway_resource.callback.*.id}")}"
}

output "callback_topics" {
  description = "SNS topics for Slack callbacks."
  value       = ["${aws_sns_topic.callback_ids.*.name}"]
}

output "callbacks_request_url" {
  description = "Callbacks Request URL."
  value        = "${aws_api_gateway_deployment.api.invoke_url}/${aws_api_gateway_resource.callbacks.path_part}"
}

output "event_resource_ids" {
  description = "API Gateway Resource IDs for Slack events."
  value       = "${zipmap("${var.event_types}", "${aws_api_gateway_resource.event.*.id}")}"
}

output "event_topics" {
  description = "SNS topics for Slack events."
  value       = ["${aws_sns_topic.event_types.*.name}"]
}

output "events_request_url" {
  description = "Events Request URL."
  value       = "${aws_api_gateway_deployment.api.invoke_url}/${aws_api_gateway_resource.events.path_part}"
}

output "kms_key_id" {
  description = "KMS Key ID."
  value       = "${aws_kms_key.slackbot.key_id}"
}

output "slash_commands_request_url" {
  description = "Slash commands base URL."
  value       = "${aws_api_gateway_deployment.api.invoke_url}/slash-commands"
}

output "slash_commands_resource_id" {
  description = "Slash Command resource ID."
  value       = "${aws_api_gateway_resource.slash_commands.id}"
}
