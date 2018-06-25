output "request_urls" {
  description = "Slackbot Request URLs."

  value {
    events    = "${module.slackbot.events_request_url}"
    callbacks = "${module.slackbot.callbacks_request_url}"
  }
}

output "sns_topics" {
  description = "SNS topics created."
  value       = ["${module.slackbot.sns_topics}"]
}
