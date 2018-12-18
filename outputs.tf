output api_id {
  description = "REST API ID."
  value       = "${aws_api_gateway_rest_api.api.id}"
}

output api_name {
  description = "REST API Name."
  value       = "${aws_api_gateway_rest_api.api.name}"
}

output kms_key_arn {
  description = "KMS Key ARN."
  value       = "${aws_kms_key.key.arn}"
}

output kms_key_id {
  description = "KMS Key ID."
  value       = "${aws_kms_key.key.key_id}"
}

output role_arn {
  description = "ARN of basic execution role for Slackbot lambdas."
  value       = "${aws_iam_role.role.arn}"
}

output role_name {
  description = "Name of basic execution role for Slackbot lambdas."
  value       = "${aws_iam_role.role.name}"
}

output slack_secret_arn {
  description = "Slackbot SecretsManager secret ARN."
  value       = "${aws_secretsmanager_secret.slack_secret.arn}"
}

output slack_secret_name {
  description = "Slackbot SecretsManager secret name."
  value       = "${aws_secretsmanager_secret.slack_secret.name}"
}

output slack_post_message_topic_arn {
  description = "Slackbot post message SNS topic ARN."
  value       = "${aws_sns_topic.post_message.arn}"
}

output slack_post_ephemeral_topic_arn {
  description = "Slackbot post ephemeral SNS topic ARN."
  value       = "${aws_sns_topic.post_ephemeral.arn}"
}
