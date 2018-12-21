output api_id {
  description = "REST API ID."
  value       = "${aws_api_gateway_rest_api.api.id}"
}

output api_name {
  description = "REST API name."
  value       = "${aws_api_gateway_rest_api.api.name}"
}

output api_stage_name {
  description = "REST API stage name."
  value       = "${aws_api_gateway_deployment.api.stage_name}"
}

output kms_key_arn {
  description = "KMS key ARN."
  value       = "${data.aws_kms_key.key.arn}"
}

output role_arn {
  description = "Lambda function role ARN."
  value       = "${aws_iam_role.role.arn}"
}

output role_name {
  description = "Lambda function role name."
  value       = "${aws_iam_role.role.name}"
}

output secret_name {
  description = "SecretsManager secret name."
  value       = "${data.aws_secretsmanager_secret.secret.name}"
}

output post_message_topic_arn {
  description = "Slackbot post message SNS topic ARN."
  value       = "${aws_sns_topic.post_message.arn}"
}

output post_ephemeral_topic_arn {
  description = "Slackbot post ephemeral SNS topic ARN."
  value       = "${aws_sns_topic.post_ephemeral.arn}"
}
