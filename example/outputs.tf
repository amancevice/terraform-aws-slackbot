output "api_id" {
  description = "REST API ID."
  value       = "${module.slackbot.api_id}"
}

output "api_root_resource_id" {
  description = "REST API root resource ID."
  value       = "${module.slackbot.api_root_resource_id}"
}

output "callback_topics" {
  description = "SNS topics created."
  value       = "${module.slackbot.callback_topics}"
}

output "event_topics" {
  description = "SNS topics created."
  value       = "${module.slackbot.event_topics}"
}

output "kms_key_id" {
  description = "Slackbot KMS Key ID."
  value       = "${module.socialismbot.kms_key_id}"
}

output "request_urls" {
  description = "Slackbot Request URLs"
  value       = "${module.slackbot.request_urls}"
}
