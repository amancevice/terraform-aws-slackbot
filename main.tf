terraform {
  required_version = ">= 0.12.0"

  required_providers {
    aws     = ">= 2.7.0"
    archive = ">= 1.2"
  }
}

locals {
  base_path = var.base_path
  debug     = var.debug

  lambda = {
    description   = var.lambda_description
    function_name = var.lambda_function_name
    filename      = "${path.module}/package.zip"
    handler       = var.lambda_handler
    kms_key_arn   = var.lambda_kms_key_arn
    memory_size   = var.lambda_memory_size
    publish       = var.lambda_publish
    runtime       = var.lambda_runtime
    tags          = var.lambda_tags
    timeout       = var.lambda_timeout

    permissions = coalescelist(var.lambda_permissions, [
      "${local.http_api.execution_arn}/*/*${local.http_api.route_prefix}*",
    ])
  }

  log_group = {
    retention_in_days = var.log_group_retention_in_days
    tags              = var.log_group_tags
  }

  http_api = {
    execution_arn = var.http_api_execution_arn
    id            = var.http_api_id
    route_prefix  = var.http_api_route_prefix
  }

  role = {
    description = var.role_description
    name        = var.role_name
    path        = var.role_path
    tags        = var.role_tags
  }

  secret = {
    name = var.secret_name
  }

  topic = {
    name = var.topic_name
  }
}

# HTTP API

resource aws_apigatewayv2_integration proxy {
  api_id               = local.http_api.id
  connection_type      = "INTERNET"
  description          = "Lambda example"
  integration_method   = "POST"
  integration_type     = "AWS_PROXY"
  integration_uri      = aws_lambda_function.api.invoke_arn
  passthrough_behavior = "WHEN_NO_MATCH"
  timeout_milliseconds = 3000

  lifecycle {
    ignore_changes = [passthrough_behavior]
  }
}

resource aws_apigatewayv2_route post_callbacks {
  api_id             = local.http_api.id
  route_key          = "POST ${local.http_api.route_prefix}callbacks"
  authorization_type = "NONE"
  target             = "integrations/${aws_apigatewayv2_integration.proxy.id}"
}

resource aws_apigatewayv2_route post_events {
  api_id             = local.http_api.id
  route_key          = "POST ${local.http_api.route_prefix}events"
  authorization_type = "NONE"
  target             = "integrations/${aws_apigatewayv2_integration.proxy.id}"
}

resource aws_apigatewayv2_route get_health {
  api_id             = local.http_api.id
  route_key          = "GET ${local.http_api.route_prefix}health"
  authorization_type = "NONE"
  target             = "integrations/${aws_apigatewayv2_integration.proxy.id}"
}

resource aws_apigatewayv2_route get_oauth {
  api_id             = local.http_api.id
  route_key          = "GET ${local.http_api.route_prefix}oauth"
  authorization_type = "NONE"
  target             = "integrations/${aws_apigatewayv2_integration.proxy.id}"
}

resource aws_apigatewayv2_route post_slash_cmd {
  api_id             = local.http_api.id
  route_key          = "POST ${local.http_api.route_prefix}slash/{proxy+}"
  authorization_type = "NONE"
  target             = "integrations/${aws_apigatewayv2_integration.proxy.id}"
}

# LOG GROUPS

resource aws_cloudwatch_log_group logs {
  name              = "/aws/lambda/${aws_lambda_function.api.function_name}"
  retention_in_days = local.log_group.retention_in_days
  tags              = local.log_group.tags
}

# LAMBDA FUNCTIONS

resource aws_lambda_function api {
  description      = local.lambda.description
  filename         = local.lambda.filename
  function_name    = local.lambda.function_name
  handler          = "index.handler"
  kms_key_arn      = local.lambda.kms_key_arn
  memory_size      = local.lambda.memory_size
  publish          = local.lambda.publish
  role             = aws_iam_role.role.arn
  runtime          = local.lambda.runtime
  source_code_hash = filebase64sha256(local.lambda.filename)
  tags             = local.lambda.tags
  timeout          = local.lambda.timeout

  environment {
    variables = {
      AWS_SECRET        = local.secret.name
      AWS_SNS_TOPIC_ARN = aws_sns_topic.topic.arn
      BASE_PATH         = local.base_path
      DEBUG             = local.debug
    }
  }
}

# SNS TOPIC

resource aws_sns_topic topic {
  name = local.topic.name
}

# IAM

data aws_secretsmanager_secret secret {
  name = local.secret.name
}

data aws_iam_policy_document assume_role {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

data aws_iam_policy_document api {
  statement {
    sid       = "DecryptKmsKey"
    actions   = ["kms:Decrypt"]
    resources = [local.lambda.kms_key_arn]
  }

  statement {
    sid       = "GetSecretValue"
    actions   = ["secretsmanager:GetSecretValue"]
    resources = [data.aws_secretsmanager_secret.secret.arn]
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

resource aws_iam_role role {
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
  description        = local.role.description
  name               = local.role.name
  path               = local.role.path
  tags               = local.role.tags
}

resource aws_iam_role_policy api {
  name   = "api"
  role   = aws_iam_role.role.id
  policy = data.aws_iam_policy_document.api.json
}

resource aws_lambda_permission invoke_api {
  count         = length(local.lambda.permissions)
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.api.arn
  principal     = "apigateway.amazonaws.com"
  source_arn    = element(local.lambda.permissions, count.index)
  statement_id  = "AllowAPIGatewayV2-${count.index}"
}
