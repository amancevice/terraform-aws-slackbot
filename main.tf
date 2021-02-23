terraform {
  required_version = "~> 0.13"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.29"
    }

    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.0"
    }
  }
}

locals {
  base_path = var.base_path
  debug     = var.debug

  kms_key = {
    alias                   = coalesce(var.kms_key_alias, "alias/${local.secret.name}")
    deletion_window_in_days = var.kms_key_deletion_window_in_days
    description             = var.kms_key_description
    enable_key_rotation     = var.kms_key_enable_key_rotation
    is_enabled              = var.kms_key_is_enabled
    policy_document         = var.kms_key_policy_document
    tags                    = var.kms_key_tags
    usage                   = var.kms_key_usage
  }

  lambda = {
    description   = var.lambda_description
    function_name = var.lambda_function_name
    filename      = "${path.module}/package.zip"
    handler       = var.lambda_handler
    memory_size   = var.lambda_memory_size
    publish       = var.lambda_publish
    runtime       = var.lambda_runtime
    tags          = var.lambda_tags
    timeout       = var.lambda_timeout

    permissions = coalescelist(var.lambda_permissions, [
      "${local.http_api.execution_arn}/*/*${local.http_api.route_prefix}health",
      "${local.http_api.execution_arn}/*/*${local.http_api.route_prefix}install",
      "${local.http_api.execution_arn}/*/*${local.http_api.route_prefix}oauth",
      "${local.http_api.execution_arn}/*/*${local.http_api.route_prefix}oauth/v2",
      "${local.http_api.execution_arn}/*/*${local.http_api.route_prefix}callbacks",
      "${local.http_api.execution_arn}/*/*${local.http_api.route_prefix}events",
      "${local.http_api.execution_arn}/*/*${local.http_api.route_prefix}slash/*",
    ])
  }

  log_group = {
    retention_in_days = var.log_group_retention_in_days
    tags              = var.log_group_tags
  }

  http_api = {
    execution_arn           = var.http_api_execution_arn
    id                      = var.http_api_id
    integration_description = var.http_api_integration_description
    route_prefix            = var.http_api_route_prefix
  }

  role = {
    description = var.role_description
    name        = var.role_name
    path        = var.role_path
    tags        = var.role_tags
  }

  secret = {
    description = var.secret_description
    name        = var.secret_name
    tags        = var.secret_tags
  }

  topic = {
    name = var.topic_name
  }
}

# HTTP API

resource "aws_apigatewayv2_integration" "proxy" {
  api_id               = local.http_api.id
  connection_type      = "INTERNET"
  description          = local.http_api.integration_description
  integration_method   = "POST"
  integration_type     = "AWS_PROXY"
  integration_uri      = aws_lambda_function.api.invoke_arn
  timeout_milliseconds = 3000
}

resource "aws_apigatewayv2_route" "post_callbacks" {
  api_id             = local.http_api.id
  route_key          = "POST ${local.http_api.route_prefix}callbacks"
  authorization_type = "NONE"
  target             = "integrations/${aws_apigatewayv2_integration.proxy.id}"
}

resource "aws_apigatewayv2_route" "post_events" {
  api_id             = local.http_api.id
  route_key          = "POST ${local.http_api.route_prefix}events"
  authorization_type = "NONE"
  target             = "integrations/${aws_apigatewayv2_integration.proxy.id}"
}

resource "aws_apigatewayv2_route" "get_health" {
  api_id             = local.http_api.id
  route_key          = "GET ${local.http_api.route_prefix}health"
  authorization_type = "NONE"
  target             = "integrations/${aws_apigatewayv2_integration.proxy.id}"
}

resource "aws_apigatewayv2_route" "get_install" {
  api_id             = local.http_api.id
  route_key          = "GET ${local.http_api.route_prefix}install"
  authorization_type = "NONE"
  target             = "integrations/${aws_apigatewayv2_integration.proxy.id}"
}

resource "aws_apigatewayv2_route" "head_install" {
  api_id             = local.http_api.id
  route_key          = "HEAD ${local.http_api.route_prefix}install"
  authorization_type = "NONE"
  target             = "integrations/${aws_apigatewayv2_integration.proxy.id}"
}

resource "aws_apigatewayv2_route" "head_health" {
  api_id             = local.http_api.id
  route_key          = "HEAD ${local.http_api.route_prefix}health"
  authorization_type = "NONE"
  target             = "integrations/${aws_apigatewayv2_integration.proxy.id}"
}

resource "aws_apigatewayv2_route" "get_oauth" {
  api_id             = local.http_api.id
  route_key          = "GET ${local.http_api.route_prefix}oauth"
  authorization_type = "NONE"
  target             = "integrations/${aws_apigatewayv2_integration.proxy.id}"
}

resource "aws_apigatewayv2_route" "get_oauth_v2" {
  api_id             = local.http_api.id
  route_key          = "GET ${local.http_api.route_prefix}oauth/v2"
  authorization_type = "NONE"
  target             = "integrations/${aws_apigatewayv2_integration.proxy.id}"
}

resource "aws_apigatewayv2_route" "post_slash_cmd" {
  api_id             = local.http_api.id
  route_key          = "POST ${local.http_api.route_prefix}slash/{proxy+}"
  authorization_type = "NONE"
  target             = "integrations/${aws_apigatewayv2_integration.proxy.id}"
}

# LOG GROUPS

resource "aws_cloudwatch_log_group" "logs" {
  name              = "/aws/lambda/${aws_lambda_function.api.function_name}"
  retention_in_days = local.log_group.retention_in_days
  tags              = local.log_group.tags
}

# LAMBDA FUNCTIONS

resource "aws_lambda_function" "api" {
  description      = local.lambda.description
  filename         = local.lambda.filename
  function_name    = local.lambda.function_name
  handler          = "index.handler"
  kms_key_arn      = aws_kms_key.key.arn
  memory_size      = local.lambda.memory_size
  publish          = local.lambda.publish
  role             = aws_iam_role.role.arn
  runtime          = local.lambda.runtime
  source_code_hash = filebase64sha256(local.lambda.filename)
  tags             = local.lambda.tags
  timeout          = local.lambda.timeout

  environment {
    variables = {
      AWS_SECRET        = aws_secretsmanager_secret.secret.name
      AWS_SNS_TOPIC_ARN = aws_sns_topic.topic.arn
      BASE_PATH         = local.base_path
      DEBUG             = local.debug
      DEBUG_HIDE_DATE   = "1"
      DEBUG_COLORS      = "0"
      SLACKEND_DEBUG    = "SLACK:DEBUG"
      SLACKEND_INFO     = "SLACK:INFO"
      SLACKEND_WARN     = "SLACK:WARN"
      SLACKEND_ERROR    = "SLACK:ERROR"
    }
  }
}

# SNS TOPIC

resource "aws_sns_topic" "topic" {
  name = local.topic.name
}

# IAM

data "aws_iam_policy_document" "assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "api" {
  statement {
    sid       = "DecryptKmsKey"
    actions   = ["kms:Decrypt"]
    resources = [aws_kms_key.key.arn]
  }

  statement {
    sid       = "GetSecretValue"
    actions   = ["secretsmanager:GetSecretValue"]
    resources = [aws_secretsmanager_secret.secret.arn]
  }

  statement {
    sid       = "PublishEvents"
    actions   = ["sns:Publish"]
    resources = [aws_sns_topic.topic.arn]
  }

  statement {
    sid = "WriteLambdaLogs"

    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]

    resources = ["*"]
  }
}

resource "aws_iam_role" "role" {
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
  description        = local.role.description
  name               = local.role.name
  path               = local.role.path
  tags               = local.role.tags
}

resource "aws_iam_role_policy" "api" {
  name   = "api"
  role   = aws_iam_role.role.id
  policy = data.aws_iam_policy_document.api.json
}

resource "aws_lambda_permission" "invoke_api" {
  count         = length(local.lambda.permissions)
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.api.arn
  principal     = "apigateway.amazonaws.com"
  source_arn    = element(local.lambda.permissions, count.index)
  statement_id  = "AllowAPIGatewayV2-${count.index}"
}

# SECRETS

resource "aws_kms_key" "key" {
  deletion_window_in_days = local.kms_key.deletion_window_in_days
  description             = local.kms_key.description
  enable_key_rotation     = local.kms_key.enable_key_rotation
  is_enabled              = local.kms_key.is_enabled
  key_usage               = local.kms_key.usage
  policy                  = local.kms_key.policy_document
  tags                    = local.kms_key.tags
}

resource "aws_kms_alias" "alias" {
  name          = local.kms_key.alias
  target_key_id = aws_kms_key.key.key_id
}

resource "aws_secretsmanager_secret" "secret" {
  description = local.secret.description
  kms_key_id  = aws_kms_key.key.key_id
  name        = local.secret.name
  tags        = local.secret.tags
}
