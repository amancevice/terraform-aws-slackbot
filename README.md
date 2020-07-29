# Asynchronous Slackbot

[![terraform](https://img.shields.io/github/v/tag/amancevice/terraform-aws-slackbot?color=62f&label=version&logo=terraform&style=flat-square)](https://registry.terraform.io/modules/amancevice/serverless-pypi/aws)
[![build](https://img.shields.io/github/workflow/status/amancevice/terraform-aws-slackbot/validate?logo=github&style=flat-square)](https://github.com/amancevice/terraform-aws-slackbot/actions)

A simple, asynchronous back end for your Slack app.

_NOTE—as of v19.0.0 users are expected to define an (API Gateway v2) HTTP API outside of this project and inject the ID/ExecutionArn as inputs._

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


```terraform
resource aws_apigatewayv2_api http_api {
  name          = "my-slack-api"
  protocol_type = "HTTP"
  # …
}

# WARNING Be extremely cautious when using this module
# NEVER store secrets in plaintext and encrypt your remote state
module slackbot_secrets {
  source  = "amancevice/slackbot-secrets/aws"
  version = "~> 5.0"
  # …
}

module slackbot {
  source  = "amancevice/slackbot/aws"
  version = "~> 19.0"

  # Required…

  http_api_execution_arn = aws_apigatewayv2_api.http_api.execution_arn
  http_api_id            = aws_apigatewayv2_api.http_api.id
  lambda_function_name   = "my-function-name"
  role_name              = "my-role-name"
  secret_name            = module.slackbot_secrets.secret.name
  topic_name             = "my-topic-name"

  # Optional…

  base_path                   = "/my/base/path"
  debug                       = "slackend:*"
  lambda_description          = "My lambda description"
  lambda_handler              = "index.handler"
  lambda_kms_key_arn          = module.slackbot_secrets.kms_key.arn
  lambda_publish              = true | false
  lambda_memory_size          = 128
  lambda_runtime              = "nodejs12.x"
  lambda_timeout              = 3
  log_group_retention_in_days = 30
  role_description            = "My role description"
  role_path                   = "/"

  lambda_permissions = [
    # list explicit API Gateway Lambda permissions <execution-arn>/<stage>/<http-method>/<path>
  ]

  lambda_tags = {
    # …
  }

  log_group_tags = {
    # …
  }

  role_tags = {
    # …
  }
}
```

## Featured Add-Ons

Some plugins are provided that can be hooked into the Slackbot out-of-the-box:

**Chat**

Send messages to Slack via SNS

```terraform
module slackbot_chat {
  source  = "amancevice/slackbot-chat/aws"
  version = "~> 2.0"

  # Required

  lambda_function_name = "slack-chat-postMessage"
  lambda_role_arn      = module.slackbot.role.arn
  slack_secret_name    = module.slackbot.secret.name
  slack_topic_arn      = module.slackbot.topic.arn

  # Optional

  lambda_description = "Your Lambda description"
  lambda_kms_key_arn = "<kms-key-arn>"
  lambda_memory_size = 128
  lambda_timeout     = 3

  log_group_retention_in_days = 30

  slack_debug       = "slackend:*"
  slack_chat_method = "postMessage | postEphemeral"

  log_group_tags = {
    # …
  }

  lambda_tags = {
    # …
  }
}
```

**Slash Command**

```terraform
module slackbot_slash_command {
  source  = "amancevice/slackbot-slash-command/aws"
  version = "~> 16.0"

  # Required

  lambda_role_arn   = module.slackbot.role.arn
  slack_secret_name = module.slackbot.secret.name
  slack_topic_arn   = module.slackbot.topic.arn

  lambda_function_name = "my-slash-command"
  slack_slash_command  = "example"

  slack_response = jsonencode({
    response_type = "ephemeral | in_channel | dialog | modal"
    text          = ":sparkles: This will be the response"

    blocks = [
      /* … */
    ]
  })

  # Optional

  lambda_description          = "Slackbot handler for /example"
  lambda_kms_key_arn          = "<kms-key-arn>"
  lambda_memory_size          = 128
  lambda_timeout              = 3
  log_group_retention_in_days = 30

  log_group_tags = {
    /* … */
  }

  lambda_tags = {
    /* … */
  }
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
