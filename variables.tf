variable base_url {
  description = "REST API base url (must begin and end with /)"
  default     = "/"
}

variable debug {
  description = "Node debug logger config"
  default     = "slackend:*"
}

variable http_api_id {
  description = "API Gateway v2 HTTP API ID"
}

variable http_api_execution_arn {
  description = "API Gateway v2 HTTP API execution ARN"
}

variable lambda_description {
  description = "Lambda function description"
  default     = "Slack request handler"
}

variable lambda_function_name {
  description = "Lambda function name"
}

variable lambda_handler {
  description = "Lambda handler signature"
  default     = "index.handler"
}

variable lambda_kms_key_arn {
  description = "Lambda function KMS key ARN"
  default     = null
}

variable lambda_publish {
  description = "Lambda publish flag"
  default     = false
  type        = bool
}

variable lambda_memory_size {
  description = "Lambda function memory size"
  default     = 1024
}

variable lambda_permissions {
  description = "Lambda permissions for API Gateway v2 HTTP API"
  type        = list(string)
  default     = []
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
  default     = null
}

variable log_group_tags {
  description = "CloudWatch log group resource tags"
  type        = map(string)
  default     = {}
}

variable role_description {
  description = "Lambda role description"
  default     = "Slackbot resource access"
}

variable role_name {
  description = "Lambda role name"
}

variable role_path {
  description = "Lambda role path"
  default     = null
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
}
