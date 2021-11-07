terraform {
  required_version = "~> 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.55"
    }

    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.0"
    }
  }
}

locals {
  base_path = var.base_path

  aws = {
    account_id = data.aws_caller_identity.current.account_id
    partition  = data.aws_partition.current.partition
    region     = data.aws_region.current.name
  }

  events = {
    source = var.event_source

    bus = {
      arn  = data.aws_arn.event_bus.arn
      name = split("/", data.aws_arn.event_bus.resource)[1]
    }

    post = {
      rule_name        = var.event_post_rule_name
      rule_description = var.event_post_rule_description
    }
  }

  http_api = {
    execution_arn           = var.http_api_execution_arn
    id                      = var.http_api_id
    integration_description = var.http_api_integration_description
  }

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
    post = {
      description   = var.lambda_post_description
      function_name = var.lambda_post_function_name
      memory_size   = var.lambda_post_memory_size
      publish       = var.lambda_post_publish
      runtime       = var.lambda_post_runtime
      timeout       = var.lambda_post_timeout
    }

    proxy = {
      description   = var.lambda_proxy_description
      function_name = var.lambda_proxy_function_name
      memory_size   = var.lambda_proxy_memory_size
      publish       = var.lambda_proxy_publish
      runtime       = var.lambda_proxy_runtime
      timeout       = var.lambda_proxy_timeout
    }

    environment_variables = {
      EVENT_BUS_NAME  = local.events.bus.name
      EVENT_SOURCE    = local.events.source
      LOG_JSON_INDENT = var.log_json_indent
      SECRET_ID       = aws_secretsmanager_secret.secret.name
    }

    permissions = [
      "${local.http_api.execution_arn}/*/*/health",
      "${local.http_api.execution_arn}/*/*/install",
      "${local.http_api.execution_arn}/*/*/oauth",
      "${local.http_api.execution_arn}/*/*/oauth/v2",
      "${local.http_api.execution_arn}/*/*/callbacks",
      "${local.http_api.execution_arn}/*/*/events",
      "${local.http_api.execution_arn}/*/*/slash/*",
    ]

    tags = var.lambda_tags
  }

  log_group = {
    retention_in_days = var.log_group_retention_in_days
    tags              = var.log_group_tags
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
}

# AWS

data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}
data "aws_region" "current" {}

# EVENTS

data "aws_arn" "event_bus" {
  arn = var.event_bus_arn == null ? "arn:${local.aws.partition}:events:${local.aws.region}:${local.aws.account_id}:event-bus/default" : var.event_bus_arn
}

resource "aws_cloudwatch_event_rule" "post" {
  event_bus_name = local.events.bus.name
  name           = local.events.post.rule_name
  description    = local.events.post.rule_description

  event_pattern = jsonencode({
    detail-type = ["post"]
    source      = [local.events.source]
  })
}

resource "aws_cloudwatch_event_target" "post" {
  arn            = aws_lambda_function.post.arn
  event_bus_name = local.events.bus.name
  input_path     = "$.detail"
  rule           = aws_cloudwatch_event_rule.post.name
  target_id      = "slack-post"
}

# HTTP API

resource "aws_apigatewayv2_integration" "proxy" {
  api_id                 = local.http_api.id
  connection_type        = "INTERNET"
  description            = local.http_api.integration_description
  integration_method     = "POST"
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.proxy.invoke_arn
  payload_format_version = "2.0"
  timeout_milliseconds   = 3000
}

resource "aws_apigatewayv2_route" "post_callbacks" {
  api_id             = local.http_api.id
  route_key          = "POST /callbacks"
  authorization_type = "NONE"
  target             = "integrations/${aws_apigatewayv2_integration.proxy.id}"
}

resource "aws_apigatewayv2_route" "post_events" {
  api_id             = local.http_api.id
  route_key          = "POST /events"
  authorization_type = "NONE"
  target             = "integrations/${aws_apigatewayv2_integration.proxy.id}"
}

resource "aws_apigatewayv2_route" "get_health" {
  api_id             = local.http_api.id
  route_key          = "GET /health"
  authorization_type = "NONE"
  target             = "integrations/${aws_apigatewayv2_integration.proxy.id}"
}

resource "aws_apigatewayv2_route" "get_install" {
  api_id             = local.http_api.id
  route_key          = "GET /install"
  authorization_type = "NONE"
  target             = "integrations/${aws_apigatewayv2_integration.proxy.id}"
}

resource "aws_apigatewayv2_route" "head_install" {
  api_id             = local.http_api.id
  route_key          = "HEAD /install"
  authorization_type = "NONE"
  target             = "integrations/${aws_apigatewayv2_integration.proxy.id}"
}

resource "aws_apigatewayv2_route" "head_health" {
  api_id             = local.http_api.id
  route_key          = "HEAD /health"
  authorization_type = "NONE"
  target             = "integrations/${aws_apigatewayv2_integration.proxy.id}"
}

resource "aws_apigatewayv2_route" "get_oauth" {
  api_id             = local.http_api.id
  route_key          = "GET /oauth"
  authorization_type = "NONE"
  target             = "integrations/${aws_apigatewayv2_integration.proxy.id}"
}

resource "aws_apigatewayv2_route" "get_oauth_v2" {
  api_id             = local.http_api.id
  route_key          = "GET /oauth/v2"
  authorization_type = "NONE"
  target             = "integrations/${aws_apigatewayv2_integration.proxy.id}"
}

resource "aws_apigatewayv2_route" "post_slash_cmd" {
  api_id             = local.http_api.id
  route_key          = "POST /slash/{cmd}"
  authorization_type = "NONE"
  target             = "integrations/${aws_apigatewayv2_integration.proxy.id}"
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

data "aws_iam_policy_document" "inline" {
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
    actions   = ["events:PutEvents"]
    resources = [local.events.bus.arn]
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

  statement {
    sid       = "SendTaskStatus"
    actions   = ["states:SendTask*"]
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
  policy = data.aws_iam_policy_document.inline.json
}

resource "aws_lambda_permission" "invoke_api" {
  count         = length(local.lambda.permissions)
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.proxy.arn
  principal     = "apigateway.amazonaws.com"
  source_arn    = element(local.lambda.permissions, count.index)
  statement_id  = "AllowAPIGatewayV2-${count.index}"
}

resource "aws_lambda_permission" "invoke_post" {
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.post.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.post.arn
  statement_id  = "AllowExecutionFromEventBridge"
}

# LAMBDA FUNCTIONS

data "archive_file" "package" {
  source_dir  = "${path.module}/src"
  output_path = "${path.module}/package.zip"
  type        = "zip"
}

resource "aws_lambda_function" "post" {
  description      = local.lambda.post.description
  filename         = data.archive_file.package.output_path
  function_name    = local.lambda.post.function_name
  handler          = "index.post"
  kms_key_arn      = aws_kms_key.key.arn
  memory_size      = local.lambda.post.memory_size
  publish          = local.lambda.post.publish
  role             = aws_iam_role.role.arn
  runtime          = local.lambda.post.runtime
  source_code_hash = data.archive_file.package.output_base64sha256
  tags             = local.lambda.tags
  timeout          = local.lambda.post.timeout

  environment {
    variables = local.lambda.environment_variables
  }
}

resource "aws_lambda_function" "proxy" {
  description      = local.lambda.proxy.description
  filename         = data.archive_file.package.output_path
  function_name    = local.lambda.proxy.function_name
  handler          = "index.proxy"
  kms_key_arn      = aws_kms_key.key.arn
  memory_size      = local.lambda.proxy.memory_size
  publish          = local.lambda.proxy.publish
  role             = aws_iam_role.role.arn
  runtime          = local.lambda.proxy.runtime
  source_code_hash = data.archive_file.package.output_base64sha256
  tags             = local.lambda.tags
  timeout          = local.lambda.proxy.timeout

  environment {
    variables = local.lambda.environment_variables
  }
}

# LOG GROUPS

resource "aws_cloudwatch_log_group" "post_logs" {
  name              = "/aws/lambda/${aws_lambda_function.post.function_name}"
  retention_in_days = local.log_group.retention_in_days
  tags              = local.log_group.tags
}

resource "aws_cloudwatch_log_group" "proxy_logs" {
  name              = "/aws/lambda/${aws_lambda_function.proxy.function_name}"
  retention_in_days = local.log_group.retention_in_days
  tags              = local.log_group.tags
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
