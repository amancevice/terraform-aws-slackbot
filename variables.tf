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
  description = "Base URL for handling slackend requests"
  default     = "/"
}

variable debug {
  description = "Debug log string"
  default     = "slackend:*"
}

variable kms_key_arn {
  description = "KMS key ARN"
}

variable lambda_memory_size {
  description = "Memory for Lambda function"
  default     = 1024
}

variable lambda_runtime {
  description = "Lambda function runtime"
  default     = "nodejs12.x"
}

variable lambda_tags {
  description = "AWS resource tags"
  type        = map
  default     = {}
}

variable lambda_timeout {
  description = "Timeout in seconds for Lambda function"
  default     = 3
}

variable log_group_retention_in_days {
  description = "Days to retain logs in CloudWatch"
  default     = 30
}

variable log_group_tags {
  description = "AWS resource tags"
  type        = map
  default     = {}
}

variable role_name {
  description = "Name for Slackbot role"
  default     = ""
}

variable role_path {
  description = "Path for Slackbot role"
  default     = "/"
}

variable role_policy_attachments {
  description = "Additional role policy ARNs to attach to role"
  type        = list
  default     = []
}

variable role_tags {
  description = "AWS resource tags"
  type        = map
  default     = {}
}

variable secret_name {
  description = "SecretsManager secret name"
}

variable topic_name {
  description = "Slackbot SNS topic name"
  default     = ""
}
