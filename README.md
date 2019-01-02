# AWS Slackbot

Slackbot endpoints backed by API Gateway + Lambda.

## Architecture

The archetecture for the Slackbot API is fairly straightforward. All requests are routed asynchronously to to SNS. By convention, payloads are routed to topics corresponding to the specific event:

- `slack_<your_bot>_event_<event_type>`
- `slack_<your_bot>_callback_<callback_id>`
- `slack_<your_bot>_slash_<command>`.

OAuth requests are authenticated using the Slack client and redirected to the configured redirect URL.

<img src="https://github.com/amancevice/terraform-aws-slackbot/blob/master/docs/images/arch.png?raw=true"></img>

## Quickstart

The module is quite configurable, but a very basic setup will do the trick.

_Note: as of v9.0.0, Slack secrets are broken out into a [separate dependent module](https://github.com/amancevice/terraform-aws-slackbot-secrets)_

```hcl
module slackbot_secrets {
  source               = "amancevice/slackbot-secrets/aws"
  kms_key_alias        = "alias/slack/your-kms-key-alias"
  secret_name          = "slack/your-secret-name"
  slack_bot_token      = "${var.slack_bot_access_token}"
  slack_client_id      = "${var.slack_client_id}"
  slack_client_secret  = "${var.slack_client_secret}"
  slack_signing_secret = "${var.slack_signing_secret}"
  slack_user_token     = "${var.slack_user_access_token}"
}

module slackbot {
  source          = "amancevice/slackbot/aws"
  api_description = "My Slack REST API"
  api_name        = "<my-api>"
  api_stage_name  = "<my-api-stage>"
  secret_arn      = "${module.slackbot_secrets.secret_arn}"
  kms_key_id      = "${module.slackbot_secrets.kms_key_id}"
}
```

This will create an API with the following endpoints to be configured in Slack:

- `/<my-api-stage>/callbacks` The request URL for interactive components
- `/<my-api-stage>/events` The request URL for Slack events
- `/<my-api-stage>/oauth` The request URL for Slack OAuth
- `/<my-api-stage>/slash/<cmd>` The request URL for Slack slash commands

You will need to separately create an SNS topic for every callback, event, and slash command your app will invoke. Event, callback, and slash command endpoints listen for `POST` requests made by Slack (using the verification token to ensure the request is indeed coming from Slack) and simply publish the payload to the SNS topic to which the request applies.
