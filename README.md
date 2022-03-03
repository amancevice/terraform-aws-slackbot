# Serverless Slackbot

![arch](./docs/arch.png)

[![terraform](https://img.shields.io/github/v/tag/amancevice/terraform-aws-slackbot?color=62f&label=version&logo=terraform&style=flat-square)](https://registry.terraform.io/modules/amancevice/slackbot/aws)
[![build](https://img.shields.io/github/workflow/status/amancevice/terraform-aws-slackbot/validate?logo=github&style=flat-square)](https://github.com/amancevice/terraform-aws-slackbot/actions)

A simple, serverless, asynchronous HTTP back end for your Slack app.

> NOTE — v22.0.0 is a complete rewrite the module. See the [release notes](https://github.com/amancevice/terraform-aws-slackbot/releases/tag/22.0.0) for more info

The application intentionally does very little: it will receive an event from Slack in the form of an HTTP request, verify its origin, and then hand off the payload to EventBridge, where it can be processed downstream using [event patterns](https://docs.aws.amazon.com/eventbridge/latest/userguide/eb-event-patterns.html).

Adding features to your slackbot is as simple as adding the appropriate EventBridge rule/target, and some kind of handler function. See the section on [processing events](#processing-events) for details.

## HTTP Routes

Endpoints are provided for the following routes:

- `GET /health` — a simple healthcheck to ensure your slackbot is up
- `GET /install` — a helper to begin Slack's OAuth flow
- `GET /oauth/v2` — completes Slack's [OAuth2](https://api.slack.com/docs/oauth) workflow (v2)
- `POST /callbacks` — handle Slack's [interactive messages](https://api.slack.com/interactive-messages)
- `POST /events` — handle events from Slack's [Events API](https://api.slack.com/events-api)
- `POST /slash/{cmd}` — handle Slack's [slash commands](https://api.slack.com/slash-commands)

Payloads from `POST` requests are published to EventBridge, as are successful logins during the execution of the OAuth callback route, `GET /oauth/v2`.

## Processing Events

EventBridge events are discoverable using [event patterns](https://docs.aws.amazon.com/eventbridge/latest/userguide/eb-event-patterns.html). Filter events using a bus name, source value, detail-type, or even parts of the event payload.

By default, the EventBridge bus name is `default` and the source is `slack`. Both these values are configurable in the module. The detail-type is derived from the endpoint and the detail is the payload itself.

The following table shows the mapping of route-to-detail-type:

| Route               | Detail Type |
| :------------------ | :---------- |
| `GET /oauth/v2`     | `oauth`     |
| `POST /callbacks`   | `callback`  |
| `POST /events`      | `event`     |
| `POST /slash/{cmd}` | `slash`     |

## Responding to Events

In addition to handing events _from_ Slack, you can use EventBridge to send payloads _to_ Slack. Publish an event to EventBridge with the detail-type `api/<slack-api-method>`.

For example, to send a message using the `chat.postMessage`, the following payload could be sent to the `PutEvents` method of the EventBridge API:

```json
{
  "EventBusName": "<your-bus>",
  "Source": "slack",
  "DetailType": "api/chat.postMessage",
  "Detail": "{\"text\":\"hello, world\"}"
}
```

After executing the Slack API method, the response from Slack is itself published to EventBridge with the same detail-type value, prefixed with `result/`. In the example above, the result would be published to:

```json
{
  "EventBusName": "<your-bus>",
  "Source": "slack",
  "DetailType": "result/api/chat.postMessage",
  "Detail": "<slack-response-JSON>"
}
```

## Terraform Usage

Create an HTTP API

```terraform
resource "aws_apigatewayv2_api" "http_api" {
  name          = "my-slack-api"
  protocol_type = "HTTP"
  # …
}
```

(Optional) Create an event bus

```terraform
resource "aws_cloudwatch_event_bus" "slackbot" {
  name = "slackbot"
}
```

Add the `slackbot module`

```terraform
module "slackbot" {
  source  = "amancevice/slackbot/aws"
  version = "~> 23.1"

  # Required

  http_api_execution_arn     = aws_apigatewayv2_api.http_api.execution_arn
  http_api_id                = aws_apigatewayv2_api.http_api.id
  lambda_post_function_name  = "slack-http-proxy"
  lambda_proxy_function_name = "slack-api-post"
  role_name                  = "my-role-name"
  secret_name                = module.slackbot_secrets.secret.name

  # Optional

  event_bus_arn = aws_cloudwatch_event_bus.slackbot.arn
  event_source  = "slackbot"

  lambda_post_description = "My Slack post lambda description"
  lambda_post_publish     = true | false
  lambda_post_memory_size = 128
  lambda_post_runtime     = "python3.9"
  lambda_post_timeout     = 3

  lambda_proxy_description = "My API proxy lambda description"
  lambda_proxy_publish     = true | false
  lambda_proxy_memory_size = 128
  lambda_proxy_runtime     = "python3.9"
  lambda_proxy_timeout     = 3

  log_group_retention_in_days = 14

  role_description = "My role description"
  role_path        = "/"

  lambda_tags    = { /* … */ }
  log_group_tags = { /* … */ }
  role_tags      = { /* … */ }
}
```

Use the [`slackbot-secrets`](https://github.com/amancevice/terraform-aws-slackbot-secrets) module to add your Slack credentials

> **WARNING** Be extremely cautious when using this module. **NEVER** store secrets in plaintext and encrypt your remote state. I recommend applying this module in a separate workspace without a remote backend.

```terraform
module "slackbot_secrets" {
  source  = "amancevice/slackbot-secrets/aws"
  version = "~> 7.0"

  secret                   = module.slackbot.secret
  slack_client_id          = "{slack_client_id}"
  slack_client_secret      = "{slack_client_secret}"
  slack_oauth_error_uri    = "{slack_oauth_error_uri}"
  slack_oauth_redirect_uri = "{slack_oauth_redirect_uri}"
  slack_oauth_success_uri  = "{slack_oauth_success_uri}"
  slack_signing_secret     = "{slack_signing_secret}"
  slack_signing_version    = "{slack_signing_version}"
  slack_token              = "{slack_token}"
}
```

## Example Event Patterns

In order to process a given event you will need to create an EventBridge rule with a pattern that targets a specific event.

The following examples show how a subscription might me made in Terraform:

**Callback**

```terraform
resource "aws_cloudwatch_event_rule" "callback" {
  event_pattern = jsonencode({
    source      = ["slack"]
    detail-type = ["callback"]
  })
}
```

**Event**

```terraform
resource "aws_cloudwatch_event_rule" "event" {
  event_pattern = jsonencode({
    source      = ["slack"]
    detail-type = ["event"]
  })
}
```

**OAuth**

```terraform
resource "aws_cloudwatch_event_rule" "oauth" {
  event_pattern = jsonencode({
    source      = ["slack"]
    detail-type = ["oauth"]
  })
}
```

**Slash Command**

```terraform
resource "aws_cloudwatch_event_rule" "slash" {
  event_pattern = jsonencode({
    source      = ["slack"]
    detail-type = ["slash"]
  })
}
```

## Featured Add-Ons

Some plugins are provided that can be hooked into the Slackbot out-of-the-box:

**Slash Command**

```terraform
module "slackbot_slash_command" {
  source  = "amancevice/slackbot-slash-command/aws"
  version = "~> 19.0"

  # Required

  lambda_role_arn   = module.slackbot.role.arn
  slack_secret_name = module.slackbot.secret.name
  slack_topic_arn   = module.slackbot.topic.arn

  lambda_function_name = "my-slash-command"
  slack_slash_command  = "example"

  slack_response = jsonencode({
    response_type = "ephemeral | in_channel"
    text          = ":sparkles: This will be the response"
    blocks        = [ /* … */ ]
  })

  # Optional

  lambda_description          = "Slackbot handler for /example"
  lambda_memory_size          = 128
  lambda_timeout              = 3
  log_group_retention_in_days = 30
  slack_response_type         = "direct | modal"

  log_group_tags = { /* … */ }
  lambda_tags    = { /* … */ }
}
```
