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
    caller            = "$context.identity.caller"
    extendedRequestId = "$context.extendedRequestId"
    httpMethod        = "$context.httpMethod"
    ip                = "$context.identity.sourceIp"
    integrationError  = "$context.integration.error"
    protocol          = "$context.protocol"
    requestId         = "$context.requestId"
    requestTime       = "$context.requestTime"
    resourcePath      = "$context.resourcePath"
    responseLength    = "$context.responseLength"
    status            = "$context.status"
    user              = "$context.identity.user"
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

#############
#   SLACK   #
#############

variable "slack_signing_secret_parameter" {
  description = "Slackbot signing secret SSM parameter name"
  type        = string
}

variable "slack_client_id" {
  description = "Slackbot OAuth client ID"
  type        = string
}

variable "slack_client_secret_parameter" {
  description = "Slackbot OAuth client secret SSM parameter name"
  type        = string
}

variable "slack_error_uri" {
  description = "Slackbot OAuth error URI"
  type        = string
  default     = null
}

variable "slack_scope" {
  description = "Slackbot OAuth scopes"
  type        = string
  default     = null
}

variable "slack_success_uri" {
  description = "Slackbot OAuth success URI"
  type        = string
  default     = "slack://open"
}

variable "slack_user_scope" {
  description = "Slackbot OAuth user scopes"
  type        = string
  default     = null
}
