###############
#   GENERAL   #
###############

variable "name" {
  description = "Slack app name"
  type        = string
}

variable "log_retention_in_days" {
  description = "Slackbot log retention in days"
  type        = number
  default     = 14
}

variable "oauth_timeout_seconds" {
  description = "TTL for OAuth state"
  type        = number
  default     = 300
}

variable "tags" {
  description = "Slackbot tags"
  type        = map(string)
  default     = null
}

###########
#   API   #
###########

variable "api_base_path" {
  description = "Slack API base path"
  type        = string
  default     = null
}

variable "api_log_format" {
  description = "Slack API log format"
  type        = map(string)
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
  description = "Slack API custom domain ACM certificate ARN"
  type        = string
}

variable "domain_name" {
  description = "Slack API custom domain"
  type        = string
}

variable "domain_zone_id" {
  description = "Slack API Route53 hosted zone ID"
  type        = string
}

#############
#   SLACK   #
#############

variable "slack_signing_secret" {
  description = "Slackbot signing secret SSM parameter name"
  type        = string
  sensitive   = true
}

variable "slack_client_id" {
  description = "Slackbot OAuth client ID"
  type        = string
}

variable "slack_client_secret" {
  description = "Slackbot OAuth client secret SSM parameter name"
  type        = string
  sensitive   = true
}

variable "slack_error_uri" {
  description = "Slackbot OAuth error URI"
  type        = string
  default     = ""
}

variable "slack_scope" {
  description = "Slackbot OAuth scopes"
  type        = string
  default     = ""
}

variable "slack_success_uri" {
  description = "Slackbot OAuth success URI"
  type        = string
  default     = "slack://open"
}

variable "slack_user_scope" {
  description = "Slackbot OAuth user scopes"
  type        = string
  default     = ""
}

variable "slack_token" {
  description = "Slackbot OAuth token SSM parameter name"
  type        = string
  sensitive   = true
}
