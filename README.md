# AWS Slackbot

Slackbot endpoints backed by API Gateway + Lambda.

## Quickstart

The module is quite configurable, but a very basic setup will do the trick.

```terraform
module "socialismbot" {
  source                   = "amancevice/slackbot/aws"
  api_name                 = "my-slackbot"
  slack_verification_token = "<verification-token>"
  # auto_encrypt_token       = false

  callback_ids = [
    # ...
  ]

  event_types = [
    # ...
  ]
}
```

It's important your verification token is kept secret, so the module will encrypt it for you unless you specifically tell it not to. Once it's encrypted you may replace the raw token with the encrypted one and set `auto_encrypt_token = false`.

This will create an API with the following endpoints to be configured in Slack:

- `/v1/callbacks` The request URL for interactive components
- `/v1/events` The request URL for Slack events

For every callback you plan on making (these are all custom values), add the callback ID to the `callback_id` list.

Similarly, for every event you wish to listen for, add the [event type](https://api.slack.com/events) to the `event_types` list.

An SNS topic is automatically created for every callback and event. Both the event and callback endpoints listen for `POST` requests made by Slack (using the verification token to ensure the request is indeed coming from Slack) simply publish the `POST` payload to the SNS topic to which the request applies.

For example, if Slack sends a `channel_rename` event, the event will be published to the `slack_event_channel_rename` topic. How the event is handled from there is left to the user to decide.
