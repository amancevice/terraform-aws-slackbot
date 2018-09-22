# AWS Slackbot

Slackbot endpoints backed by API Gateway + Lambda.

## Architecture

The archetecture for the Slackbot API is fairly straightforward. All requests are routed asynchronously to to SNS. By convention, payloads are routed to topics corresponding to the specific event. Eg, `slack_event_<event_type>`, `slack_callback_<callback_id>`, or `slack_slash_<slash_command_name>`.

OAuth requests are authenticated using the Slack client and redirected to the configured redirect URL.

<img src="https://github.com/amancevice/terraform-aws-slackbot/blob/master/docs/images/arch.png?raw=true"></img>

## Quickstart

The module is quite configurable, but a very basic setup will do the trick.

```terraform
module "slackbot" {
  source                 = "amancevice/slackbot/aws"
  slack_access_token     = "${var.slack_access_token}"
  slack_bot_access_token = "${var.slack_bot_access_token}"
  slack_signing_secret   = "${var.slack_signing_secret}"
}
```

This will create an API with the following endpoints to be configured in Slack:

- `/v1/callbacks` The request URL for interactive components
- `/v1/events` The request URL for Slack events
- `/v1/oauth` The request URL for Slack OAuth
- `/v1/slash-commands` The request URL for Slack slash commands

You will need to separately create an SNS topic for every callback, event, and slash command your app will invoke. Event, callback, and slash command endpoints listen for `POST` requests made by Slack (using the verification token to ensure the request is indeed coming from Slack) and simply publish the payload to the SNS topic to which the request applies.
