variable "base_path" {
  description = "Slack API base path"
  default     = "/"
}

variable "debug" {
  description = "Node debug logger config"
  default     = "SLACK:*"
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

variable "http_api_route_prefix" {
  description = "API Gateway v2 HTTP API route prefix"
  default     = "/"
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

variable "lambda_description" {
  description = "Lambda function description"
  default     = "Slack request handler"
}

variable "lambda_function_name" {
  description = "Lambda function name"
}

variable "lambda_handler" {
  description = "Lambda handler signature"
  default     = "index.handler"
}

variable "lambda_publish" {
  description = "Lambda publish flag"
  default     = false
  type        = bool
}

variable "lambda_memory_size" {
  description = "Lambda function memory size"
  default     = 1024
}

variable "lambda_permissions" {
  description = "Lambda permissions for API Gateway v2 HTTP API"
  type        = list(string)
  default     = []
}

variable "lambda_runtime" {
  description = "Lambda function runtime"
  default     = "nodejs14.x"
}

variable "lambda_tags" {
  description = "Lambda function resource tags"
  type        = map(string)
  default     = {}
}

variable "lambda_timeout" {
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

variable "topic_name" {
  description = "SNS topic name"
}
