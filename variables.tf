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

variable "api_endpoint_configuration" {
  description = "Slackbot API endpoint type."
  type        = "map"

  default {
    types = ["EDGE"]
  }
}

variable "callback_ids" {
  description = "List of Slack callback IDs."
  type        = "list"
  default     = []
}

variable "callbacks_lambda_description" {
  description = "Description of the function."
  default     = "Slack callbacks handler"
}

variable "callbacks_lambda_function_name" {
  description = "Lambda Function for publishing events from Slack to SNS."
  default     = ""
}

variable "callbacks_lambda_memory_size" {
  description = "Memory for Lambda function."
  default     = 1024
}

variable "callbacks_lambda_tags" {
  description = "A set of key/value label pairs to assign to the function."
  type        = "map"

  default {
    deployment-tool = "terraform"
  }
}

variable "callbacks_lambda_timeout" {
  description = "Timeout in seconds for Lambda function."
  default     = 3
}

variable "event_types" {
  description = "List of slack event types."
  type        = "list"
  default     = []
}

variable "events_lambda_description" {
  description = "Description of the function."
  default     = "Slack events handler"
}

variable "events_lambda_function_name" {
  description = "Lambda Function for publishing events from Slack to SNS."
  default     = ""
}

variable "events_lambda_memory_size" {
  description = "Memory for Lambda function."
  default     = 1024
}

variable "events_lambda_tags" {
  description = "A set of key/value label pairs to assign to the function."
  type        = "map"

  default {
    deployment-tool = "terraform"
  }
}

variable "events_lambda_timeout" {
  description = "Timeout in seconds for Lambda function."
  default     = 3
}

variable "kms_key_alias" {
  description = "KMS Key alias."
  default     = ""
}

variable "kms_key_deletion_window_in_days" {
  description = "KMS key deletion window."
  default     = 30
}

variable "kms_key_enable_key_rotation" {
  description = "Flag to enable/disable KMS Key rotation."
  default     = false
}

variable "kms_key_is_enabled" {
  description = "Flag to enable/disable KMS Key."
  default     = true
}

variable "kms_key_name" {
  description = "Name of Slackbot KMS Key."
  default     = "Slackbot key"
}

variable "kms_key_tags" {
  description = "KMS Key tags."

  default {
    deployment-tool = "terraform"
  }
}

variable "kms_key_usage" {
  description = "Usage of Slackbot KMS Key."
  default     = "ENCRYPT_DECRYPT"
}

variable "role_path" {
  description = "Path for Slackbot role."
  default     = ""
}

variable "secret_name" {
  description = "Name of secret."
  default     = ""
}

variable "secret_recovery_window_in_days" {
  description = "Recovery window for secret."
  default     = 30
}

variable "secret_rotation_lambda_arn" {
  description = "ARN of Lambda with permission to rotate permission."
  default     = ""
}

variable "secret_rotation_rules" {
  description = "Rotation configuration for secret."
  type        = "list"
  default     = []
}

variable "secret_tags" {
  description = "Secret tags"
  type        = "map"

  default {
    deployment-tool = "terraform"
  }
}

variable "slack_bot_access_token" {
  description = "Slack OAuth bot access token."
  default     = ""
}

variable "slack_signing_secret" {
  description = "Slack signing secret."
}

variable "slack_signing_version" {
  description = "Slack signing version."
  default     = "v0"
}

variable "slack_user_access_token" {
  description = "Slack OAuth user access token."
  default     = ""
}

variable "slack_workspace_token" {
  description = "Slack workspace token."
  default     = ""
}
