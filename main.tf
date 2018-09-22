provider "archive" {
  version = "~> 1.0"
}

locals {
  kms_key_alias  = "${coalesce(var.kms_key_alias, "alias/${var.api_name}")}"
  function_name  = "${coalesce(var.lambda_function_name, "slack-${var.api_name}-api")}"
  lambda_policy  = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
  role_name      = "${coalesce(var.role_name, var.api_name)}"
  role_path      = "${coalesce(var.role_path, "/slackbot/")}"
  secret_name    = "${coalesce(var.secret_name, var.api_name)}"
  sns_arn_prefix = "arn:aws:sns:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}"

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

data "archive_file" "package" {
  output_path = "${path.module}/dist/package.zip"
  source_dir  = "${path.module}/src"
  type        = "zip"
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
    actions   = ["kms:Decrypt", "secretsmanager:GetSecretValue"]
    resources = [
      "${aws_kms_key.slackbot.arn}",
      "${aws_secretsmanager_secret.slackbot.arn}",
    ]
  }
}

data "aws_iam_policy_document" "publish" {
  statement {
    actions   = ["sns:Publish"]
    resources = ["${local.sns_arn_prefix}:slack_*"]
  }
}

resource "aws_api_gateway_deployment" "api" {
  rest_api_id = "${aws_api_gateway_rest_api.api.id}"
  stage_name  = "${var.api_stage_name}"
}

resource "aws_api_gateway_integration" "proxy_any" {
  content_handling        = "CONVERT_TO_TEXT"
  http_method             = "${aws_api_gateway_method.any.http_method}"
  integration_http_method = "POST"
  resource_id             = "${aws_api_gateway_resource.proxy.id}"
  rest_api_id             = "${aws_api_gateway_rest_api.api.id}"
  timeout_milliseconds    = 3000
  type                    = "AWS_PROXY"
  uri                     = "${aws_lambda_function.lambda.invoke_arn}"
}

resource "aws_api_gateway_method" "any" {
  authorization = "NONE"
  http_method   = "ANY"
  resource_id   = "${aws_api_gateway_resource.proxy.id}"
  rest_api_id   = "${aws_api_gateway_rest_api.api.id}"
}

resource "aws_api_gateway_resource" "proxy" {
  rest_api_id = "${aws_api_gateway_rest_api.api.id}"
  parent_id   = "${aws_api_gateway_rest_api.api.root_resource_id}"
  path_part   = "{proxy+}"
}

resource "aws_api_gateway_rest_api" "api" {
  description            = "${var.api_description}"
  name                   = "${var.api_name}"
  endpoint_configuration = ["${var.api_endpoint_configuration}"]
}

resource "aws_iam_policy" "publish" {
  name        = "slack-${var.api_name}-publish"
  path        = "${local.role_path}"
  description = "Publish Slackbot callbacks"
  policy      = "${data.aws_iam_policy_document.publish.json}"
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
  name               = "${local.role_name}"
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

resource "aws_iam_role_policy_attachment" "publish" {
  role       = "${aws_iam_role.slackbot.name}"
  policy_arn = "${aws_iam_policy.publish.arn}"
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

resource "aws_lambda_function" "lambda" {
  description      = "Slack request handler"
  filename         = "${data.archive_file.package.output_path}"
  function_name    = "${local.function_name}"
  handler          = "index.handler"
  memory_size      = "${var.lambda_memory_size}"
  role             = "${aws_iam_role.slackbot.arn}"
  runtime          = "nodejs8.10"
  source_code_hash = "${data.archive_file.package.output_base64sha256}"
  timeout          = "${var.lambda_timeout}"

  environment {
    variables {
      OAUTH_REDIRECT   = "${var.oauth_redirect}"
      SECRET           = "${aws_secretsmanager_secret.slackbot.name}"
      SNS_TOPIC_PREFIX = "${local.sns_arn_prefix}:slack_"
    }
  }

  tags {
    deployment-tool = "terraform"
  }
}

resource "aws_lambda_permission" "invoke" {
  action        = "lambda:InvokeFunction"
  function_name = "${aws_lambda_function.lambda.arn}"
  principal     = "apigateway.amazonaws.com"
  statement_id  = "AllowAPIGatewayInvoke"
  source_arn    = "${aws_api_gateway_rest_api.api.execution_arn}/*/*/*"
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
  secret_string = "${jsonencode(local.secrets)}"
}
