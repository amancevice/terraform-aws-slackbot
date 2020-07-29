# Asynchronous Slackbot

[![terraform](https://img.shields.io/github/v/tag/amancevice/terraform-aws-slackbot?color=62f&label=version&logo=terraform&style=flat-square)](https://registry.terraform.io/modules/amancevice/serverless-pypi/aws)
[![build](https://img.shields.io/github/workflow/status/amancevice/terraform-aws-slackbot/validate?logo=github&style=flat-square)](https://github.com/amancevice/terraform-aws-slackbot/actions)

A simple, asynchronous back end for your Slack app.

The app intentionally does very little: it is essentially middleware for [ExpressJS](https://expressjs.com) that accepts an incoming request, verifies its origin, and passes the request to a user-provided callback, where the payload is sent to a queue/trigger for asynchronous processing.

Endpoints are provided for:

- `/callbacks` publishes [interactive messages](https://api.slack.com/interactive-messages)
- `/events` publishes events from the [Events API](https://api.slack.com/events-api)
- `/oauth` completes the [OAuth2](https://api.slack.com/docs/oauth) workflow
- `/slash/:cmd` publishes [slash commands](https://api.slack.com/slash-commands)

In production it is expected that users will attach their own publishing functions to connect to a messaging service like [Amazon SNS](https://aws.amazon.com/sns/), or [Google Pub/Sub](https://cloud.google.com/pubsub/docs/).

## Architecture

The archetecture for the Slackbot API is fairly straightforward. All requests are routed asynchronously to to SNS.

OAuth requests are authenticated using the Slack client and redirected to the configured redirect URL.

<img alt="arch" src="https://github.com/amancevice/slackend/raw/main/docs/aws.png"/>

## Usage

Deploy directly to AWS using this and [`slackbot-secrets`](https://github.com/amancevice/terraform-aws-slackbot-secrets) modules:


```hcl
module slackbot_secrets {
  source               = "amancevice/slackbot-secrets/aws"
  source               = "~> 3.0"
  kms_key_alias        = "alias/slack/your-kms-key-alias"
  secret_name          = "slack/your-secret-name"
  slack_bot_token      = var.slack_bot_token
  slack_client_id      = var.slack_client_id
  slack_client_secret  = var.slack_client_secret
  slack_signing_secret = var.slack_signing_secret
  slack_user_token     = var.slack_user_token

  // Optional additional secrets
  secrets = {
    FIZZ = "buzz"
  }
}

module slackbot {
  source          = "amancevice/slackbot/aws"
  version         = "~> 18.0"
  api_description = "My Slack REST API"
  api_name        = "<my-api-name>"
  api_stage_name  = "<my-api-stage>"
  secret_name     = module.slackbot_secrets.secret.name
  kms_key_arn     = module.slackbot_secrets.kms_key.arn
  // ... etc
}
```

## Featured Plugins

Some plugins are provided that can be hooked into the Slackbot out-of-the-box:

**Chat**

```hcl
module slackbot_chat {
  source         = "amancevice/slackbot-chat/aws"
  version        = "~> 1.0"
  api_name       = module.slackbot.api.name
  chat_method    = "postMessage | postEphemeral"
  role_arn       = module.slackbot.role.arn
  secret_name    = "<secretsmanager-secret-name>"
  topic_arn      = module.slackbot.topic.arn
}
```

**Slash Command**

```hcl
locals {
  slash_response = {
    response_type = "[ ephemeral | in_channel | dialog ]"
    text          = ":sparkles: This will be the response of the Slash Command."

    blocks = {
      /* … */
    }
  }
}

module slackbot_slash_command {
  source        = "amancevice/slack-slash-command/aws"
  version       = "~> 15.0"
  api_name      = module.slackbot.api.name
  role_name     = module.slackbot.role.name
  secret_name   = module.slackbot.secret.name
  response      = jsonencode(local.slash_response)
  slash_command = "my-command-name"
}
```

## Processing Events

SNS messages are published with attributes that can be used to discriminate where the message should be routed.

In very simple terms, all events are processed by:

- Extracting `type` and `id` fields from the POST payload.
- Nesting the payload in a new JSON object containing the `type`, `id`, and `message` fields.
- Forwarding the new payload to your processing topic/queue

The general idea is to infer some kind of routing logic from the request.

The `type` field's value is taken from the path of the original request and will be one of `callback`, `event`, `oauth`, or `slash`.

The following table illustrates how the `type` and `id` field's respective values are calculated:

| Endpoint      | Type       | ID Recipe       |
|:------------- |:---------- |:--------------- |
| `/callbacks`  | `callback` | `$.callback_id` |
| `/events`     | `event`    | `$.event.type`  |
| `/oauth`      | `oauth`    | `$.code`        |
| `/slash/:cmd` | `slash`    | `:cmd`          |

## Example Subscriptions

In order to process a given event you will need to create a subscription with a filter policy that targets a specific event.

The following examples show how a subscription might me made in Terraform:

**Callback**

```hcl
locals {
  filter_policy = {
    type = ["callback"]
    id   = ["<callback-id>", "…"]
  }
}

resource aws_sns_topic_subscription subscription {
  endpoint      = "<subscriber-arn>"
  filter_policy = jsonencode(local.filter_policy)
  protocol      = "<subscription-protocol>"
  topic_arn     = "<sns-topic-arn>"
}
```

**Event**

```hcl
resource aws_sns_topic_subscription subscription {
  endpoint      = "<subscriber-arn>"
  filter_policy = jsonencode({ type = ["event"] id = ["<event-type>"] })
  protocol      = "<subscription-protocol>"
  topic_arn     = "<sns-topic-arn>"
}
```

**OAuth**

```hcl
resource aws_sns_topic_subscription subscription {
  endpoint      = "<subscriber-arn>"
  filter_policy = jsonencode({ type = ["oauth"] })
  protocol      = "<subscription-protocol>"
  topic_arn     = "<sns-topic-arn>"
}
```

**Slash Command**

```hcl
resource aws_sns_topic_subscription subscription {
  endpoint      = "<subscriber-arn>"
  filter_policy = jsonencode({ type = ["slash"], id = ["<slash-cmd>"] })
  protocol      = "<subscription-protocol>"
  topic_arn     = "<sns-topic-arn>"
}
```
