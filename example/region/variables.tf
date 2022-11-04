variable "domain" {
  type = string
}

variable "secret" {
  type = object({
    SLACK_API_TOKEN           = string
    SLACK_OAUTH_CLIENT_ID     = string
    SLACK_OAUTH_CLIENT_SECRET = string
    SLACK_OAUTH_SCOPE         = string
    SLACK_OAUTH_USER_SCOPE    = string
    SLACK_OAUTH_ERROR_URI     = string
    SLACK_OAUTH_REDIRECT_URI  = string
    SLACK_OAUTH_SUCCESS_URI   = string
    SLACK_SIGNING_SECRET      = string
    SLACK_SIGNING_VERSION     = string
  })
}
