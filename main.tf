provider "archive" {
  version = "~> 1.0"
}

locals {
  callbacks_function_name = "${coalesce("${var.callbacks_lambda_function_name}", "slack-${var.api_name}-callbacks")}"
  events_function_name    = "${coalesce("${var.events_lambda_function_name}", "slack-${var.api_name}-events")}"
  kms_key_alias           = "${coalesce("${var.kms_key_alias}", "alias/${var.api_name}")}"
  lambda_policy           = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
  role_path               = "${coalesce("${var.role_path}", "/${var.api_name}/")}"
  secret_name             = "${coalesce("${var.secret_name}", "${var.api_name}")}"
  sns_arn_prefix          = "arn:aws:sns:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}"

  callback {
    "$schema" = "http://json-schema.org/draft-04/schema#"
    type      = "object"

    properties {
      payload {
        type = "string"
      }
    }
  }

  challenge {
    "$schema" = "http://json-schema.org/draft-04/schema#"
    type      = "object"

    properties {
      challenge {
        type = "string"
      }
    }
  }

  event {
    "$schema" = "http://json-schema.org/draft-04/schema#"
    type      = "object"

    properties {
      api_app_id {
        type = "string"
      }

      authed_users {
        type = "array"

        items {
          type = "string"
        }
      }

      event_id {
        type = "string"
      }

      team_id {
        type = "string"
      }

      token {
        type = "string"
      }

      type {
        type = "string"
      }

      event_time {
        type = "number"
      }

      event {
        type = "object"

        properties {
          channel {
            type = "object"

            properties {
              id {
                type = "string"
              }

              name {
                type = "string"
              }

              name_normalized {
                type = "string"
              }

              is_group {
                type = "boolean"
              }

              created {
                type = "number"
              }

            }
          }
          event_ts {
            type = "string"
          }

          type {
            type = "string"
          }
        }
      }
    }
  }

  secrets {
    BOT_ACCESS_TOKEN  = "${var.slack_bot_access_token}"
    CLIENT_ID         = "${var.slack_client_id}"
    CLIENT_SECRET     = "${var.slack_client_secret}"
    SIGNING_SECRET    = "${var.slack_signing_secret}"
    SIGNING_VERSION   = "${var.slack_signing_version}"
    USER_ACCESS_TOKEN = "${var.slack_user_access_token}"
    WORKSPACE_TOKEN   = "${var.slack_workspace_token}"
  }
}

data "archive_file" "callbacks" {
  type        = "zip"
  output_path = "${path.module}/dist/callbacks.zip"

  source {
    content  = "${file("${path.module}/src/index.js")}"
    filename = "index.js"
  }
}

data "archive_file" "events" {
  type        = "zip"
  output_path = "${path.module}/dist/events.zip"

  source {
    content  = "${file("${path.module}/src/index.js")}"
    filename = "index.js"
  }
}

data "aws_caller_identity" "current" {
}

data "aws_region" "current" {
}

data "aws_iam_policy_document" "assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "secrets" {
  statement {
    actions   = [
      "kms:Decrypt",
      "secretsmanager:GetSecretValue"
    ]
    resources = [
      "${aws_kms_key.slackbot.arn}",
      "${aws_secretsmanager_secret.slackbot.arn}"
    ]
  }
}

data "aws_iam_policy_document" "publish_callbacks" {
  statement {
    actions   = ["sns:Publish"]
    resources = ["${local.sns_arn_prefix}:slack_callback_*"]
  }
}

data "aws_iam_policy_document" "publish_events" {
  statement {
    actions   = ["sns:Publish"]
    resources = ["${local.sns_arn_prefix}:slack_event_*"]
  }
}

resource "aws_api_gateway_deployment" "api" {
  depends_on  = [
    "aws_api_gateway_integration.events",
    "aws_api_gateway_integration.callbacks"
  ]
  rest_api_id = "${aws_api_gateway_rest_api.api.id}"
  stage_name  = "${var.api_stage_name}"
}

resource "aws_api_gateway_integration" "callbacks" {
  content_handling        = "CONVERT_TO_TEXT"
  http_method             = "${aws_api_gateway_method.callbacks_post.http_method}"
  integration_http_method = "POST"
  resource_id             = "${aws_api_gateway_resource.callbacks.id}"
  rest_api_id             = "${aws_api_gateway_rest_api.api.id}"
  type                    = "AWS_PROXY"
  uri                     = "${aws_lambda_function.callbacks.invoke_arn}"
}

resource "aws_api_gateway_integration" "events" {
  content_handling        = "CONVERT_TO_TEXT"
  http_method             = "${aws_api_gateway_method.events_post.http_method}"
  integration_http_method = "POST"
  resource_id             = "${aws_api_gateway_resource.events.id}"
  rest_api_id             = "${aws_api_gateway_rest_api.api.id}"
  type                    = "AWS_PROXY"
  uri                     = "${aws_lambda_function.events.invoke_arn}"
}

resource "aws_api_gateway_method" "callbacks_post" {
  authorization = "NONE"
  http_method   = "POST"
  resource_id   = "${aws_api_gateway_resource.callbacks.id}"
  rest_api_id   = "${aws_api_gateway_rest_api.api.id}"

  request_models {
    "application/json" = "Callback"
  }

  request_parameters {
    "method.request.header.X-Slack-Request-Timestamp" = 1
    "method.request.header.X-Slack-Signature"         = 1
  }
}

resource "aws_api_gateway_method" "events_post" {
  authorization = "NONE"
  http_method   = "POST"
  resource_id   = "${aws_api_gateway_resource.events.id}"
  rest_api_id   = "${aws_api_gateway_rest_api.api.id}"

  request_models {
    "application/json" = "Event"
  }

  request_parameters {
    "method.request.header.X-Slack-Request-Timestamp" = 1
    "method.request.header.X-Slack-Signature"         = 1
  }
}

resource "aws_api_gateway_method_response" "callbacks_200" {
  http_method = "${aws_api_gateway_method.callbacks_post.http_method}"
  resource_id = "${aws_api_gateway_method.callbacks_post.resource_id}"
  rest_api_id = "${aws_api_gateway_rest_api.api.id}"
  status_code = "200"

  response_models {
    "application/json" = "Empty"
  }
}

resource "aws_api_gateway_method_response" "events_200" {
  depends_on  = ["aws_api_gateway_model.challenge"]
  http_method = "${aws_api_gateway_method.events_post.http_method}"
  resource_id = "${aws_api_gateway_method.events_post.resource_id}"
  rest_api_id = "${aws_api_gateway_rest_api.api.id}"
  status_code = "200"

  response_models {
    "application/json" = "Empty"
    "application/json" = "Challenge"
  }
}

resource "aws_api_gateway_model" "callback" {
  content_type = "application/json"
  description  = "Slack callback request"
  name         = "Callback"
  rest_api_id  = "${aws_api_gateway_rest_api.api.id}"
  schema       = "${jsonencode("${local.callback}")}"
}

resource "aws_api_gateway_model" "challenge" {
  content_type = "application/json"
  description  = "Slack Event API challenge response"
  name         = "Challenge"
  rest_api_id  = "${aws_api_gateway_rest_api.api.id}"
  schema       = "${jsonencode("${local.challenge}")}"
}

resource "aws_api_gateway_model" "event" {
  content_type = "application/json"
  description  = "Slack event request"
  name         = "Event"
  rest_api_id  = "${aws_api_gateway_rest_api.api.id}"
  schema       = "${jsonencode("${local.event}")}"
}

resource "aws_api_gateway_resource" "callback" {
  count       = "${length("${var.callback_ids}")}"
  rest_api_id = "${aws_api_gateway_rest_api.api.id}"
  parent_id   = "${aws_api_gateway_resource.callbacks.id}"
  path_part   = "${element("${var.callback_ids}", count.index)}"
}

resource "aws_api_gateway_resource" "callbacks" {
  rest_api_id = "${aws_api_gateway_rest_api.api.id}"
  parent_id   = "${aws_api_gateway_rest_api.api.root_resource_id}"
  path_part   = "callbacks"
}

resource "aws_api_gateway_resource" "event" {
  count       = "${length("${var.event_types}")}"
  rest_api_id = "${aws_api_gateway_rest_api.api.id}"
  parent_id   = "${aws_api_gateway_resource.events.id}"
  path_part   = "${element("${var.event_types}", count.index)}"
}

resource "aws_api_gateway_resource" "events" {
  rest_api_id = "${aws_api_gateway_rest_api.api.id}"
  parent_id   = "${aws_api_gateway_rest_api.api.root_resource_id}"
  path_part   = "events"
}

resource "aws_api_gateway_resource" "slash_commands" {
  rest_api_id = "${aws_api_gateway_rest_api.api.id}"
  parent_id   = "${aws_api_gateway_rest_api.api.root_resource_id}"
  path_part   = "slash-commands"
}

resource "aws_api_gateway_rest_api" "api" {
  description            = "${var.api_description}"
  name                   = "${var.api_name}"
  endpoint_configuration = ["${var.api_endpoint_configuration}"]
}

resource "aws_iam_policy" "callbacks" {
  name        = "slack-${var.api_name}-publish-callbacks"
  path        = "${local.role_path}"
  description = "Publish Slackbot callbacks"
  policy      = "${data.aws_iam_policy_document.publish_callbacks.json}"
}

resource "aws_iam_policy" "events" {
  name        = "slack-${var.api_name}-publish-events"
  path        = "${local.role_path}"
  description = "Publish Slackbot events"
  policy      = "${data.aws_iam_policy_document.publish_events.json}"
}

resource "aws_iam_policy" "secrets" {
  name        = "slack-${var.api_name}-decrypt-secrets"
  path        = "${local.role_path}"
  description = "Decrypt Slackbot SecretsManager secret"
  policy      = "${data.aws_iam_policy_document.secrets.json}"
}

resource "aws_iam_role" "slackbot" {
  assume_role_policy = "${data.aws_iam_policy_document.assume_role.json}"
  description        = "Slackbot resource access"
  name               = "slack-${var.api_name}-role"
  path               = "${local.role_path}"
}

resource "aws_iam_role_policy_attachment" "cloudwatch" {
  role       = "${aws_iam_role.slackbot.name}"
  policy_arn = "${local.lambda_policy}"
}

resource "aws_iam_role_policy_attachment" "secrets" {
  role       = "${aws_iam_role.slackbot.name}"
  policy_arn = "${aws_iam_policy.secrets.arn}"
}

resource "aws_iam_role_policy_attachment" "callbacks" {
  role       = "${aws_iam_role.slackbot.name}"
  policy_arn = "${aws_iam_policy.callbacks.arn}"
}

resource "aws_iam_role_policy_attachment" "events" {
  role       = "${aws_iam_role.slackbot.name}"
  policy_arn = "${aws_iam_policy.events.arn}"
}

resource "aws_kms_key" "slackbot" {
  description             = "${var.kms_key_name}"
  key_usage               = "${var.kms_key_usage}"
  deletion_window_in_days = "${var.kms_key_deletion_window_in_days}"
  is_enabled              = "${var.kms_key_is_enabled}"
  enable_key_rotation     = "${var.kms_key_enable_key_rotation}"
  tags                    = "${var.kms_key_tags}"
}

resource "aws_kms_alias" "slackbot" {
  name          = "${local.kms_key_alias}"
  target_key_id = "${aws_kms_key.slackbot.key_id}"
}

resource "aws_lambda_function" "callbacks" {
  description      = "${var.callbacks_lambda_description}"
  filename         = "${data.archive_file.callbacks.output_path}"
  function_name    = "${local.callbacks_function_name}"
  handler          = "index.callbacks"
  memory_size      = "${var.callbacks_lambda_memory_size}"
  role             = "${aws_iam_role.slackbot.arn}"
  runtime          = "nodejs8.10"
  source_code_hash = "${data.archive_file.callbacks.output_base64sha256}"
  timeout          = "${var.callbacks_lambda_timeout}"

  environment {
    variables {
      SECRET           = "${aws_secretsmanager_secret.slackbot.name}"
      SNS_TOPIC_PREFIX = "${local.sns_arn_prefix}:slack_callback_"
    }
  }

  tags {
    deployment-tool = "terraform"
  }
}

resource "aws_lambda_function" "events" {
  description      = "${var.events_lambda_description}"
  filename         = "${data.archive_file.events.output_path}"
  function_name    = "${local.events_function_name}"
  handler          = "index.events"
  memory_size      = "${var.events_lambda_memory_size}"
  role             = "${aws_iam_role.slackbot.arn}"
  runtime          = "nodejs8.10"
  source_code_hash = "${data.archive_file.events.output_base64sha256}"
  timeout          = "${var.events_lambda_timeout}"

  environment {
    variables {
      SECRET           = "${aws_secretsmanager_secret.slackbot.name}"
      SNS_TOPIC_PREFIX = "${local.sns_arn_prefix}:slack_event_"
    }
  }

  tags {
    deployment-tool = "terraform"
  }
}

resource "aws_lambda_permission" "callbacks" {
  action        = "lambda:InvokeFunction"
  function_name = "${aws_lambda_function.callbacks.arn}"
  principal     = "apigateway.amazonaws.com"
  statement_id  = "AllowAPIGatewayInvoke"
  source_arn    = "${aws_api_gateway_rest_api.api.execution_arn}/*/${aws_api_gateway_method.callbacks_post.http_method}/${aws_api_gateway_resource.callbacks.path_part}"
}

resource "aws_lambda_permission" "events" {
  action        = "lambda:InvokeFunction"
  function_name = "${aws_lambda_function.events.arn}"
  principal     = "apigateway.amazonaws.com"
  statement_id  = "AllowAPIGatewayInvoke"
  source_arn    = "${aws_api_gateway_rest_api.api.execution_arn}/*/${aws_api_gateway_method.events_post.http_method}/${aws_api_gateway_resource.events.path_part}"
}

resource "aws_secretsmanager_secret" "slackbot" {
  description             = "Slackbot access tokens."
  kms_key_id              = "${aws_kms_key.slackbot.key_id}"
  name                    = "${local.secret_name}"
  recovery_window_in_days = "${var.secret_recovery_window_in_days}"
  rotation_lambda_arn     = "${var.secret_rotation_lambda_arn}"
  rotation_rules          = "${var.secret_rotation_rules}"
  tags                    = "${var.secret_tags}"
}

resource "aws_secretsmanager_secret_version" "slackbot" {
  secret_id     = "${aws_secretsmanager_secret.slackbot.id}"
  secret_string = "${jsonencode("${local.secrets}")}"
}

resource "aws_sns_topic" "callback_ids" {
  count = "${length("${var.callback_ids}")}"
  name  = "slack_callback_${element("${var.callback_ids}", count.index)}"
}

resource "aws_sns_topic" "event_types" {
  count = "${length("${var.event_types}")}"
  name  = "slack_event_${element("${var.event_types}", count.index)}"
}
