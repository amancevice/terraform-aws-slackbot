provider aws {
  region = "us-east-1"
}

module slackbot_secret {
  source               = "amancevice/slackbot-secrets/aws"
  kms_key_alias        = "alias/slack/bot"
  secret_name          = "slack/bot"
  slack_bot_token      = "${var.slack_bot_token}"
  slack_client_id      = "${var.slack_client_id}"
  slack_client_secret  = "${var.slack_client_secret}"
  slack_signing_secret = "${var.slack_signing_secret}"
  slack_user_token     = "${var.slack_user_token}"
}

module slackbot {
  source          = "amancevice/slackbot/aws"
  api_description = "My Slackbot REST API"
  api_name        = "slackbot"
  api_stage_name  = "prod"
}
