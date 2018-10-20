provider aws {
  region = "us-east-1"
}

module slackbot {
  source                  = "amancevice/slackbot/aws"
  api_description         = "My Slackbot REST API"
  api_name                = "slackbot"
  api_stage_name          = "v1"
  slack_bot_access_token  = "${var.slack_bot_access_token}"
  slack_client_id         = "${var.slack_client_id}"
  slack_client_secret     = "${var.slack_client_secret}"
  slack_signing_secret    = "${var.slack_signing_secret}"
  slack_user_access_token = "${var.slack_user_access_token}"
}
