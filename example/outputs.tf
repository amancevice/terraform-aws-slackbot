output api_execution_arn {
  description = "REST API deployment execution ARN."
  value       = "${module.slackbot.api_execution_arn}"
}

output api_id {
  description = "REST API ID."
  value       = "${module.slackbot.api_id}"
}

output api_invoke_url {
  description = "REST API deployment invocation URL."
  value       = "${module.slackbot.api_invoke_url}"
}

output api_name {
  description = "REST API Name."
  value       = "${module.slackbot.api_name}"
}

output api_proxy_resource_id {
  description = "REST API {proxy+} resource ID."
  value       = "${module.slackbot.api_proxy_resource_id}"
}

output kms_key_id {
  description = "KMS Key ID."
  value       = "${module.slackbot.kms_key_id}"
}

output lambda_arn {
  description = "API Lambda ARN."
  value       = "${module.slackbot.lambda_arn}"
}

output lambda_name {
  description = "API Lambda name."
  value       = "${module.slackbot.lambda_name}"
}

output request_urls {
  description = "Callbacks Request URL."
  value       = ["${module.slackbot.request_urls}"]
}

output role_arn {
  description = "ARN of basic execution role for Slackbot lambdas."
  value       = "${aws_iam_role.slackbot.arn}"
}


output role_name {
  description = "Name of basic execution role for Slackbot lambdas."
  value       = "${module.slackbot.role_name}"
}

output secret_arn {
  description = "Slackbot SecretsManager secret ARN."
  value       = "${module.slackbot.secret_arn}"
}

output secret_name {
  description = "Slackbot SecretsManager secret name."
  value       = "${module.slackbot.secret_name}"
}

output secrets_policy_arn {
  description = "Slackbot KMS key decryption permission policy ARN."
  value       = "${module.slackbot.secrets_policy_arn}"
}
