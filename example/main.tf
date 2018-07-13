provider "aws" {
  region = "us-east-1"
}

module "slackbot" {
  source                   = "amancevice/slackbot/aws"
  callback_ids             = ["my_callback_1"]
  event_types              = ["channel_rename"]
  slack_access_token       = "${var.slack_access_token}"
  slack_bot_access_token   = "${var.slack_bot_access_token}"
  slack_signing_secret     = "${var.slack_signing_secret}"
}
