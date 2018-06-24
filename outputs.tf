output "api_id" {
  description = "REST API ID."
  value       = "${aws_api_gateway_rest_api.api.id}"
}

output "api_name" {
  description = "REST API Name."
  value       = "${aws_api_gateway_rest_api.api.name}"
}

output "api_root_resource_id" {
  description = "REST API root resource ID."
  value       = "${aws_api_gateway_rest_api.api.root_resource_id}"
}

output "kms_key_id" {
  description = "Slackbot KMS Key ID."
  value       = "${aws_kms_key.slackbot.key_id}"
}

output "request_urls" {
  description = "Slackbot Request URLs"
  value {
    events                 = "${aws_api_gateway_deployment.test.invoke_url}/${aws_api_gateway_resource.events.path_part}",
    interactive_components = "${aws_api_gateway_deployment.test.invoke_url}/${aws_api_gateway_resource.interactive_components.path_part}"
  }
}

output "sns_topics" {
  description = "SNS topics created."
  value       = [
    "${aws_sns_topic.callback_ids.*.name}",
    "${aws_sns_topic.event_types.*.name}"
  ]
}
