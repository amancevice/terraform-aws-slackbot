provider "aws" {
  region = "us-east-1"
}

module "slackbot" {
  source             = "amancevice/slackbot/aws"
  callback_ids       = ["my_callback_1"]
  event_types        = ["channel_rename"]
  verification_token = "${var.slackbot_verification_token}"
}
