variable "base_path" {
  description = "Slack API base path"
  default     = "/"
}

variable "event_bus_arn" {
  description = "EventBridge bus ARN"
  default     = null
}

variable "event_post_rule_description" {
  description = "Post Lambda EventBridge rule name"
  default     = "Capture events destined for post Lambda"
}

variable "event_post_rule_name" {
  description = "Post Lambda EventBridge rule name"
  default     = "slack-post"
}

variable "event_source" {
  description = "EventBridge source"
  default     = "slack"
}

variable "http_api_execution_arn" {
  description = "API Gateway v2 HTTP API execution ARN"
}

variable "http_api_id" {
  description = "API Gateway v2 HTTP API ID"
}

variable "http_api_integration_description" {
  description = "API Gateway v2 HTTP API integration description"
  default     = "Slack request Lambda integration"
}

variable "kms_key_alias" {
  description = "KMS Key alias"
  default     = null
}

variable "kms_key_deletion_window_in_days" {
  description = "KMS Key deletion window"
  default     = 30
}

variable "kms_key_enable_key_rotation" {
  description = "KMS Key rotation flag"
  default     = false
}

variable "kms_key_is_enabled" {
  description = "KMS Key enabled flag"
  default     = true
}

variable "kms_key_description" {
  description = "KMS Key description"
  default     = "Slackbot key"
}

variable "kms_key_policy_document" {
  description = "KMS Key policy JSON document"
  default     = null
}

variable "kms_key_tags" {
  description = "KMS Key resource tags"
  type        = map(string)
  default     = {}
}

variable "kms_key_usage" {
  description = "KMS Key usage"
  default     = "ENCRYPT_DECRYPT"
}

variable "lambda_tags" {
  description = "Lambda function resource tags"
  type        = map(string)
  default     = {}
}

variable "lambda_post_description" {
  description = "Lambda function description"
  default     = "Slack API handler"
}

variable "lambda_post_function_name" {
  description = "Lambda function name prefix"
}

variable "lambda_post_publish" {
  description = "Lambda publish flag"
  default     = false
  type        = bool
}

variable "lambda_post_memory_size" {
  description = "Lambda function memory size"
  default     = 1024
}

variable "lambda_post_runtime" {
  description = "Lambda function runtime"
  default     = "python3.8"
}

variable "lambda_post_timeout" {
  description = "Lambda function timeout in seconds"
  default     = 3
}

variable "lambda_proxy_description" {
  description = "Lambda function description"
  default     = "Slack request handler"
}

variable "lambda_proxy_function_name" {
  description = "Lambda function name prefix"
}

variable "lambda_proxy_publish" {
  description = "Lambda publish flag"
  default     = false
  type        = bool
}

variable "lambda_proxy_memory_size" {
  description = "Lambda function memory size"
  default     = 1024
}

variable "lambda_proxy_runtime" {
  description = "Lambda function runtime"
  default     = "python3.8"
}

variable "lambda_proxy_timeout" {
  description = "Lambda function timeout in seconds"
  default     = 3
}

variable "log_group_retention_in_days" {
  description = "CloudWatch log group retention in days"
  default     = null
}

variable "log_group_tags" {
  description = "CloudWatch log group resource tags"
  type        = map(string)
  default     = {}
}

variable "role_description" {
  description = "Lambda role description"
  default     = "Slackbot resource access"
}

variable "role_name" {
  description = "Lambda role name"
}

variable "role_path" {
  description = "Lambda role path"
  default     = null
}

variable "role_tags" {
  description = "Lambda role resource tags"
  type        = map(string)
  default     = {}
}

variable "secret_description" {
  description = "SecretsManager Secret description"
  default     = "Slackbot secrets"
}

variable "secret_name" {
  description = "SecretsManager secret name"
}

variable "secret_tags" {
  description = "SecretsManager Secret resource tags"
  type        = map(string)
  default     = {}
}
