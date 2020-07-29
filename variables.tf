variable api_description {
  description = "Slackbot API description"
  default     = "Slackbot REST API"
}

variable api_name {
  description = "Slackbot API name"
  default     = ""
}

variable api_stage_name {
  description = "Slackbot API stage"
  default     = "prod"
}

variable api_stage_tags {
  description = "Slackbot API tags"
  type        = map
  default     = {}
}

variable api_endpoint_configuration_type {
  description = "Slackbot API endpoint type"
  default     = "EDGE"
}

variable app_name {
  description = "Slackbot name"
}

variable base_url {
  description = "REST API base URL"
  default     = "/"
}

variable debug {
  description = "Lambda function logger config"
  default     = "slackend:*"
}

variable kms_key_arn {
  description = "KMS key ARN"
}

variable lambda_memory_size {
  description = "Lambda function memory size"
  default     = 1024
}

variable lambda_runtime {
  description = "Lambda function runtime"
  default     = "nodejs12.x"
}

variable lambda_tags {
  description = "Lambda function resource tags"
  type        = map(string)
  default     = {}
}

variable lambda_timeout {
  description = "Lambda function timeout in seconds"
  default     = 3
}

variable log_group_retention_in_days {
  description = "CloudWatch log group retention in days"
  default     = 30
}

variable log_group_tags {
  description = "CloudWatch log group resource tags"
  type        = map(string)
  default     = {}
}

variable role_name {
  description = "Lambda role name"
  default     = ""
}

variable role_path {
  description = "Lambda role path"
  default     = "/"
}

variable role_policy_attachments {
  description = "Additional role policy ARNs to attach to role"
  type        = list
  default     = []
}

variable role_tags {
  description = "Lambda role resource tags"
  type        = map(string)
  default     = {}
}

variable secret_name {
  description = "SecretsManager secret name"
}

variable topic_name {
  description = "SNS topic name"
  default     = null
}
