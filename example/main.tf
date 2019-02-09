provider aws {
  region = "us-east-1"
}

locals {
  tags {
    App     = "slackbot"
    Release = "2019.1.23"
  }
}

module slackbot_secret {
  source                   = "amancevice/slackbot-secrets/aws"
  kms_key_alias            = "alias/slack/bot"
  kms_key_tags             = "${local.tags}"
  secret_name              = "slack/bot"
  secret_tags              = "${local.tags}"
  slack_client_id          = "${var.slack_client_id}"
  slack_client_secret      = "${var.slack_client_secret}"
  slack_signing_secret     = "${var.slack_signing_secret}"
  slack_token              = "${var.slack_token}"
  slack_oauth_redirect_uri = "${var.slack_oauth_redirect_uri}"
}

module slackbot {
  source          = "amancevice/slackbot/aws"
  api_description = "My Slackbot REST API"
  api_name        = "slackbot"
  api_stage_name  = "prod"
  lambda_tags     = "${local.tags}"
  log_group_tags  = "${local.tags}"
  role_tags       = "${local.tags}"
  secret_name     = "${module.slackbot_secret.secret_name}"
}
