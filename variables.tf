###############
#   GENERAL   #
###############

variable "function_runtime" {
  type        = string
  description = "Lambda function runtime"
  default     = "python3.11"
}

variable "log_retention_in_days" {
  type        = number
  description = "Slackbot log retention in days"
  default     = 14
}

variable "tags" {
  type        = map(string)
  description = "Slackbot tags"
  default     = null
}

###########
#   API   #
###########

variable "api_auto_deploy" {
  type        = bool
  description = "Slack API auto deploy"
  default     = true
}

variable "api_description" {
  type        = string
  description = "Slack API description"
  default     = "Slack API"
}

variable "api_log_format" {
  type        = map(string)
  description = "Slack API log format"
  default = {
    httpMethod              = "$context.httpMethod"
    integrationErrorMessage = "$context.integrationErrorMessage"
    ip                      = "$context.identity.sourceIp"
    path                    = "$context.path"
    protocol                = "$context.protocol"
    requestId               = "$context.requestId"
    requestTime             = "$context.requestTime"
    responseLength          = "$context.responseLength"
    routeKey                = "$context.routeKey"
    status                  = "$context.status"
  }
}

variable "api_name" {
  type        = string
  description = "Slack API name"
}

variable "api_stage_description" {
  type        = string
  description = "Slack API stage description"
  default     = "Slack API stage"
}

####################
#   CUSTOMIZATION  #
####################

variable "custom_responders" {
  type        = map(string)
  description = "Optional route key => Lambda invocation ARN mappings"
  default     = {}

  validation {
    condition     = alltrue([for key, _ in var.custom_responders : startswith(key, "POST /-/")])
    error_message = "Each key in custom_responders must start with \"POST /-/\""
  }
}

###########
#   DNS   #
###########

variable "domain_certificate_arn" {
  type        = string
  description = "Slack API custom domain ACM certificate ARN"
}

variable "domain_name" {
  type        = string
  description = "Slack API custom domain"
}

variable "domain_zone_id" {
  type        = string
  description = "Slack API Route53 hosted zone ID"
}

#################
#   EVENT BUS   #
#################

variable "event_bus_name" {
  type        = string
  description = "EventBridge bus name"
}

##############
#   SECRET   #
##############

variable "secret_description" {
  type        = string
  description = "SecretsManager secret description"
  default     = "Slackbot secrets"
}

variable "secret_name" {
  type        = string
  description = "SecretsManager secret name"
}

#######################
#   RECEIVER LAMBDA   #
#######################

variable "receiver_function_description" {
  type        = string
  description = "Slack HTTP receiver function description"
  default     = "Slack HTTP receiver"
}

variable "receiver_function_memory_size" {
  type        = number
  description = "Slack HTTP receiver memory size in MB"
  default     = 3008
}

variable "receiver_function_name" {
  type        = string
  description = "Slack HTTP receiver function name"
}

variable "receiver_function_role_name" {
  type        = string
  description = "Slack HTTP receiver function role name"
  default     = null
}

########################
#   RESPONDER LAMBDA   #
########################

variable "responder_function_description" {
  type        = string
  description = "Slack HTTP responder function description"
  default     = "Slack HTTP responder"
}

variable "responder_function_memory_size" {
  type        = number
  description = "Slack HTTP receiver memory size in MB"
  default     = 128
}

variable "responder_function_name" {
  type        = string
  description = "Slack HTTP responder function name"
}

variable "responder_function_role_name" {
  type        = string
  description = "Slack HTTP responder function role name"
  default     = null
}

########################
#   SLACK API LAMBDA   #
########################

variable "slack_api_function_description" {
  type        = string
  description = "Slack API function description"
  default     = "Slack API"
}

variable "slack_api_function_memory_size" {
  type        = number
  description = "Slack HTTP receiver memory size in MB"
  default     = 512
}

variable "slack_api_function_name" {
  type        = string
  description = "Slack API function name"
}

variable "slack_api_function_role_name" {
  type        = string
  description = "Slack API function role name"
  default     = null
}
