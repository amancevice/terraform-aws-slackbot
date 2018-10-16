# AWS Slackbot

Slackbot endpoints backed by API Gateway + Lambda.

## Architecture

The archetecture for the Slackbot API is fairly straightforward. All requests are routed asynchronously to to SNS. By convention, payloads are routed to topics corresponding to the specific event. Eg, `slack_event_<event_type>`, `slack_callback_<callback_id>`, or `slack_slash_<command>`.

OAuth requests are authenticated using the Slack client and redirected to the configured redirect URL.

<img src="https://github.com/amancevice/terraform-aws-slackbot/blob/master/docs/images/arch.png?raw=true"></img>

## Quickstart

The module is quite configurable, but a very basic setup will do the trick.

```terraform
module slackbot {
  source                  = "amancevice/slackbot/aws"
  api_description         = "My Slack app API"
  api_name                = "<my-api>"
  api_stage_name          = "<my-api-stage>"
  slack_bot_access_token  = "${var.slack_bot_access_token}"
  slack_client_id         = "${var.slack_client_id}"
  slack_client_secret     = "${var.slack_client_secret}"
  slack_signing_secret    = "${var.slack_signing_secret}"
  slack_user_access_token = "${var.slack_access_token}"
}
```

This will create an API with the following endpoints to be configured in Slack:

- `/<my-api-stage>/callbacks` The request URL for interactive components
- `/<my-api-stage>/events` The request URL for Slack events
- `/<my-api-stage>/oauth` The request URL for Slack OAuth
- `/<my-api-stage>/slash/<cmd>` The request URL for Slack slash commands

You will need to separately create an SNS topic for every callback, event, and slash command your app will invoke. Event, callback, and slash command endpoints listen for `POST` requests made by Slack (using the verification token to ensure the request is indeed coming from Slack) and simply publish the payload to the SNS topic to which the request applies.
