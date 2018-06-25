provider "archive" {
  version = "~> 1.0"
}

locals {
  aws_account_id                     = "${coalesce("${var.aws_account_id}", "${data.aws_caller_identity.current.account_id}")}"
  aws_region                         = "${coalesce("${var.aws_region}", "${data.aws_region.current.name}")}"
  log_arn_prefix                     = "arn:aws:logs:${local.aws_region}:${local.aws_account_id}"
  role_name                          = "${coalesce("${var.role_name}", "slackbot-role")}"
  role_inline_policy_name            = "${coalesce("${var.role_inline_policy_name}", "${local.role_name}-inline-policy")}"
  sns_arn_prefix                     = "arn:aws:sns:${local.aws_region}:${local.aws_account_id}"
  slack_verification_token_encrypted = "${element(coalescelist("${data.aws_kms_ciphertext.verification_token.*.ciphertext_blob}", list("${var.slack_verification_token}")), 0)}"
}

data "aws_region" "current" {
}

data "aws_caller_identity" "current" {
}

// Role
data "aws_iam_policy_document" "assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "inline" {
  statement {
    actions   = ["logs:CreateLogGroup"]
    resources = ["*"]
  }

  statement {
    actions   = [
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
    resources = [
      "${local.log_arn_prefix}:log-group:/aws/lambda/${aws_lambda_function.events.function_name}:*",
      "${local.log_arn_prefix}:log-group:/aws/lambda/${aws_lambda_function.callbacks.function_name}:*"
    ]
  }

  statement {
    actions   = ["kms:Decrypt"]
    resources = ["${aws_kms_key.slackbot.arn}"]
  }

  statement {
    actions   = ["sns:Publish"]
    resources = ["${local.sns_arn_prefix}:*"]
  }
}

resource "aws_iam_role" "slackbot" {
  assume_role_policy = "${data.aws_iam_policy_document.assume_role.json}"
  name               = "${local.role_name}"
  path               = "${var.role_path}"
}

resource "aws_iam_role_policy" "slackbot" {
  name   = "${local.role_inline_policy_name}"
  role   = "${aws_iam_role.slackbot.id}"
  policy = "${data.aws_iam_policy_document.inline.json}"
}

// KMS
resource "aws_kms_key" "slackbot" {
  description             = "${var.kms_key_name}"
  key_usage               = "${var.kms_key_usage}"
  deletion_window_in_days = "${var.kms_key_deletion_window_in_days}"
  is_enabled              = "${var.kms_key_is_enabled}"
  enable_key_rotation     = "${var.kms_key_enable_key_rotation}"
  tags                    = "${var.kms_key_tags}"
}

resource "aws_kms_alias" "slackbot" {
  name          = "${var.kms_key_alias}"
  target_key_id = "${aws_kms_key.slackbot.key_id}"
}

data "aws_kms_ciphertext" "verification_token" {
  count     = "${var.auto_encrypt_token}"
  key_id    = "${aws_kms_key.slackbot.key_id}"
  plaintext = "${var.slack_verification_token}"
}

// REST API
resource "aws_api_gateway_rest_api" "api" {
  description =  "${var.api_description}"
  name        =  "${var.api_name}"
}

resource "aws_api_gateway_deployment" "api" {
  depends_on  = [
    "aws_api_gateway_integration.events",
    "aws_api_gateway_integration.callbacks"
  ]
  rest_api_id = "${aws_api_gateway_rest_api.api.id}"
  stage_name  = "${var.api_stage_name}"
}

// Events API
resource "aws_api_gateway_resource" "events" {
  rest_api_id = "${aws_api_gateway_rest_api.api.id}"
  parent_id   = "${aws_api_gateway_rest_api.api.root_resource_id}"
  path_part   = "events"
}

resource "aws_api_gateway_resource" "event" {
  count       = "${length("${var.event_types}")}"
  rest_api_id = "${aws_api_gateway_rest_api.api.id}"
  parent_id   = "${aws_api_gateway_resource.events.id}"
  path_part   = "${element("${var.event_types}", count.index)}"
}

resource "aws_api_gateway_method" "events_post" {
  authorization = "NONE"
  http_method   = "POST"
  resource_id   = "${aws_api_gateway_resource.events.id}"
  rest_api_id   = "${aws_api_gateway_rest_api.api.id}"
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

resource "aws_api_gateway_method_response" "events_200" {
  http_method = "${aws_api_gateway_method.events_post.http_method}"
  resource_id = "${aws_api_gateway_method.events_post.resource_id}"
  rest_api_id = "${aws_api_gateway_rest_api.api.id}"
  status_code = "200"

  response_models {
    "application/json" = "Empty"
  }
}

// Callbacks API
resource "aws_api_gateway_resource" "callbacks" {
  rest_api_id = "${aws_api_gateway_rest_api.api.id}"
  parent_id   = "${aws_api_gateway_rest_api.api.root_resource_id}"
  path_part   = "callbacks"
}

resource "aws_api_gateway_resource" "callback" {
  count       = "${length("${var.callback_ids}")}"
  rest_api_id = "${aws_api_gateway_rest_api.api.id}"
  parent_id   = "${aws_api_gateway_resource.callbacks.id}"
  path_part   = "${element("${var.callback_ids}", count.index)}"
}

resource "aws_api_gateway_method" "callbacks_post" {
  authorization = "NONE"
  http_method   = "POST"
  resource_id   = "${aws_api_gateway_resource.callbacks.id}"
  rest_api_id   = "${aws_api_gateway_rest_api.api.id}"
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

resource "aws_api_gateway_method_response" "callbacks_200" {
  http_method = "${aws_api_gateway_method.callbacks_post.http_method}"
  resource_id = "${aws_api_gateway_method.callbacks_post.resource_id}"
  rest_api_id = "${aws_api_gateway_rest_api.api.id}"
  status_code = "200"

  response_models {
    "application/json" = "Empty"
  }
}

// Slash Commands API
resource "aws_api_gateway_resource" "slash_commands" {
  rest_api_id = "${aws_api_gateway_rest_api.api.id}"
  parent_id   = "${aws_api_gateway_rest_api.api.root_resource_id}"
  path_part   = "slash-commands"
}

// SNS Topics
resource "aws_sns_topic" "callback_ids" {
  count = "${length("${var.callback_ids}")}"
  name  = "slack_callback_${element("${var.callback_ids}", count.index)}"
}

resource "aws_sns_topic" "event_types" {
  count = "${length("${var.event_types}")}"
  name  = "slack_event_${element("${var.event_types}", count.index)}"
}

// Events
data "archive_file" "events" {
  type        = "zip"
  output_path = "${path.module}/dist/events.zip"

  source {
    content  = "${file("${path.module}/src/events.js")}"
    filename = "events.js"
  }
}

resource "aws_lambda_function" "events" {
  description      = "${var.events_lambda_description}"
  filename         = "${data.archive_file.events.output_path}"
  function_name    = "${var.events_lambda_function_name}"
  handler          = "events.handler"
  memory_size      = "${var.events_lambda_memory_size}"
  role             = "${aws_iam_role.slackbot.arn}"
  runtime          = "nodejs8.10"
  source_code_hash = "${base64sha256(file("${data.archive_file.events.output_path}"))}"
  timeout          = "${var.events_lambda_timeout}"

  environment {
    variables = {
      ENCRYPTED_VERIFICATION_TOKEN = "${local.slack_verification_token_encrypted}"
      SNS_TOPIC_PREFIX             = "${local.sns_arn_prefix}"
    }
  }

  tags {
    deployment-tool = "terraform"
  }
}

resource "aws_lambda_permission" "events" {
  action        = "lambda:InvokeFunction"
  function_name = "${aws_lambda_function.events.arn}"
  principal     = "apigateway.amazonaws.com"
  statement_id  = "AllowAPIGatewayInvoke"
  source_arn    = "${aws_api_gateway_deployment.api.execution_arn}/POST/${aws_api_gateway_resource.events.path_part}"
}

// Callbacks
data "archive_file" "callbacks" {
  type        = "zip"
  output_path = "${path.module}/dist/callbacks.zip"

  source {
    content  = "${file("${path.module}/src/callbacks.js")}"
    filename = "callbacks.js"
  }
}

resource "aws_lambda_function" "callbacks" {
  description      = "${var.callbacks_lambda_description}"
  filename         = "${data.archive_file.callbacks.output_path}"
  function_name    = "${var.callbacks_lambda_function_name}"
  handler          = "callbacks.handler"
  memory_size      = "${var.callbacks_lambda_memory_size}"
  role             = "${aws_iam_role.slackbot.arn}"
  runtime          = "nodejs8.10"
  source_code_hash = "${base64sha256(file("${data.archive_file.callbacks.output_path}"))}"
  timeout          = "${var.callbacks_lambda_timeout}"

  environment {
    variables = {
      ENCRYPTED_VERIFICATION_TOKEN = "${local.slack_verification_token_encrypted}"
      SNS_TOPIC_PREFIX             = "${local.sns_arn_prefix}"
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

  # The /*/* portion grants access from any method on any resource
  # within the API Gateway "REST API".
  source_arn    = "${aws_api_gateway_deployment.api.execution_arn}/POST/${aws_api_gateway_resource.callbacks.path_part}"
}
