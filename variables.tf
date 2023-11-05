###############
#   GENERAL   #
###############

variable "name" {
  type        = string
  description = "Slack app name"
}

variable "log_retention_in_days" {
  type        = number
  description = "Slackbot log retention in days"
  default     = 14
}

variable "parameters" {
  description = "Slackbot SSM ParameterStore parameter names"
  type = object({
    signing_secret = string
    client_id      = optional(string)
    client_secret  = optional(string)
    error_uri      = optional(string)
    redirect_uri   = optional(string)
    scope          = optional(string)
    success_uri    = optional(string)
    token          = optional(string)
    user_scope     = optional(string)
  })
}

variable "tags" {
  type        = map(string)
  description = "Slackbot tags"
  default     = null
}

###########
#   API   #
###########

variable "api_base_path" {
  type        = string
  description = "Slack API base path"
  default     = null
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

#########################
#   AUTHORIZER LAMBDA   #
#########################

variable "authorizer_function_memory_size" {
  type        = number
  description = "Slack HTTP event authorizer memory size in MB"
  default     = 1024
}

variable "transformer_function_memory_size" {
  type        = number
  description = "Slack HTTP event transformer memory size in MB"
  default     = 1024
}

variable "oauth_function_memory_size" {
  type        = number
  description = "Slack OAuth memory size in MB"
  default     = 512
}
