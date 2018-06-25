// AWS
variable "aws_region" {
  description = "AWS region name."
  default     = ""
}

variable "aws_account_id" {
  description = "AWS account ID."
  default     = ""
}

// Slack
variable "slack_verification_token" {
  description = "Slack verification token."
}

// Role
variable "role_name" {
  description = "Name of role for Slackbot Lambdas."
  default     = "slackbot-role"
}

variable "role_path" {
  description = "Path for Slackbot role."
  default     = "/service-role/"
}

variable "role_policy_name" {
  description = "Name of inline Slackbot role policy."
  default     = "slackbot-role-inline-policy"
}

// KMS Key
variable "kms_key_name" {
  description = "Name of Slackbot KMS Key."
  default     = "Slackbot key"
}

variable "kms_key_usage" {
  description = "Usage of Slackbot KMS Key."
  default     = "ENCRYPT_DECRYPT"
}

variable "kms_key_deletion_window_in_days" {
  description = "KMS key deletion window."
  default     = 30
}

variable "kms_key_is_enabled" {
  description = "Flag to enable/disable KMS Key."
  default     = true
}

variable "kms_key_enable_key_rotation" {
  description = "Flag to enable/disable KMS Key rotation."
  default     = false
}

variable "kms_key_tags" {
  description = "KMS Key tags."

  default {
    deployment-tool = "terraform"
  }
}

variable "kms_key_alias" {
  description = "KMS Key alias."
  default     = "alias/slackbot"
}

// REST API
variable "api_description" {
  description = "Slackbot API description."
  default     = "Slackbot REST API"
}

variable "api_name" {
  description = "Slackbot API name"
  default     = "slackbot"
}

variable "api_stage_name" {
  description = "Slackbot API stage."
  default     = "v1"
}

// Slack resources
variable "callback_ids" {
  description = "List of Slack callback IDs."
  type        = "list"
  default     = []
}

variable "event_types" {
  description = "List of slack event types."
  type        = "list"
  default     = []
}

// Lambda
variable "events_lambda_description" {
  description = "Description of the function."
  default     = "Slack events handler"
}

variable "events_lambda_function_name" {
  description = "Lambda Function for publishing events from Slack to SNS."
  default     = "slack-events"
}

variable "events_lambda_tags" {
  description = "A set of key/value label pairs to assign to the function."
  type        = "map"

  default {
    deployment-tool = "terraform"
  }
}

variable "events_lambda_memory_size" {
  description = "Memory for Lambda function."
  default     = 128
}

variable "events_lambda_timeout" {
  description = "Timeout in seconds for Lambda function."
  default     = 3
}

variable "callbacks_lambda_description" {
  description = "Description of the function."
  default     = "Slack callbacks handler"
}

variable "callbacks_lambda_function_name" {
  description = "Lambda Function for publishing events from Slack to SNS."
  default     = "slack-callbacks"
}

variable "callbacks_lambda_tags" {
  description = "A set of key/value label pairs to assign to the function."
  type        = "map"

  default {
    deployment-tool = "terraform"
  }
}

variable "callbacks_lambda_memory_size" {
  description = "Memory for Lambda function."
  default     = 128
}

variable "callbacks_lambda_timeout" {
  description = "Timeout in seconds for Lambda function."
  default     = 3
}
