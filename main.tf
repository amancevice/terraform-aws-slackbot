#################
#   TERRAFORM   #
#################

terraform {
  required_version = "~> 1.0"

  required_providers {
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.0"
    }

    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
}

##################
#   AWS REGION   #
##################

data "aws_region" "current" {}

##############
#   LOCALS   #
##############

locals {
  lambda_runtime = "python3.9"

  receiver_routes = [
    "ANY /health",
    "ANY /install",
    "GET /oauth",
    "POST /callbacks",
    "POST /events",
    "POST /menus",
    "POST /slash/{cmd}",
  ]

  responder_routes = [
    "POST /-/{proxy+}",
  ]
}

#######################
#   EVENTBRIDGE BUS   #
#######################

resource "aws_cloudwatch_event_bus" "bus" {
  name = var.event_bus_name
  tags = var.tags
}

#######################
#   SECRET CONTAINER  #
#######################

resource "aws_secretsmanager_secret" "secret" {
  description = var.secret_description
  name        = var.secret_name
  tags        = var.tags
}

###########
#   DNS   #
###########

resource "aws_route53_record" "api" {
  name           = aws_apigatewayv2_domain_name.api.domain_name
  set_identifier = data.aws_region.current.name
  type           = "A"
  zone_id        = var.domain_zone_id

  alias {
    evaluate_target_health = false
    name                   = aws_apigatewayv2_domain_name.api.domain_name_configuration[0].target_domain_name
    zone_id                = aws_apigatewayv2_domain_name.api.domain_name_configuration[0].hosted_zone_id
  }

  latency_routing_policy {
    region = data.aws_region.current.name
  }
}

################
#   HTTP API   #
################

resource "aws_apigatewayv2_api" "api" {
  description                  = var.api_description
  disable_execute_api_endpoint = true
  name                         = var.api_name
  protocol_type                = "HTTP"
  tags                         = var.tags
}

resource "aws_apigatewayv2_api_mapping" "api" {
  api_id      = aws_apigatewayv2_api.api.id
  domain_name = aws_apigatewayv2_domain_name.api.domain_name
  stage       = aws_apigatewayv2_stage.default.name
}

resource "aws_apigatewayv2_domain_name" "api" {
  domain_name = var.domain_name

  domain_name_configuration {
    certificate_arn = var.domain_certificate_arn
    endpoint_type   = "REGIONAL"
    security_policy = "TLS_1_2"
  }
}

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.api.id
  auto_deploy = var.api_auto_deploy
  description = var.api_description
  name        = "$default"

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api.arn
    format          = jsonencode(var.api_log_format)
  }

  lifecycle {
    ignore_changes = [deployment_id]
  }
}

############################
#   HTTP API :: RECEIVER   #
############################

resource "aws_apigatewayv2_route" "receiver" {
  for_each           = toset(local.receiver_routes)
  api_id             = aws_apigatewayv2_api.api.id
  authorization_type = "NONE"
  route_key          = each.value
  target             = "integrations/${aws_apigatewayv2_integration.receiver.id}"
}

resource "aws_apigatewayv2_integration" "receiver" {
  api_id                 = aws_apigatewayv2_api.api.id
  description            = var.receiver_function_description
  integration_method     = "POST"
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.receiver.invoke_arn
  payload_format_version = "2.0"
}

#############################
#   HTTP API :: RESPONDER   #
#############################

resource "aws_apigatewayv2_route" "responder" {
  for_each           = toset(local.responder_routes)
  api_id             = aws_apigatewayv2_api.api.id
  authorization_type = "AWS_IAM"
  route_key          = each.value
  target             = "integrations/${aws_apigatewayv2_integration.responder.id}"
}

resource "aws_apigatewayv2_integration" "responder" {
  api_id                 = aws_apigatewayv2_api.api.id
  description            = var.responder_function_description
  integration_method     = "POST"
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.responder.invoke_arn
  payload_format_version = "2.0"
}

#####################################
#   HTTP API :: CUSTOM RESPONDERS   #
#####################################

data "aws_lambda_function" "custom" {
  for_each      = var.custom_responders
  function_name = each.value
}

resource "aws_apigatewayv2_route" "custom" {
  for_each           = var.custom_responders
  api_id             = aws_apigatewayv2_api.api.id
  authorization_type = "AWS_IAM"
  route_key          = each.key
  target             = "integrations/${aws_apigatewayv2_integration.custom[each.key].id}"
}

resource "aws_apigatewayv2_integration" "custom" {
  for_each               = var.custom_responders
  api_id                 = aws_apigatewayv2_api.api.id
  description            = data.aws_lambda_function.custom[each.key].description
  integration_method     = "POST"
  integration_type       = "AWS_PROXY"
  integration_uri        = data.aws_lambda_function.custom[each.key].invoke_arn
  payload_format_version = "2.0"
}

resource "aws_lambda_permission" "custom" {
  for_each      = var.custom_responders
  action        = "lambda:InvokeFunction"
  function_name = data.aws_lambda_function.custom[each.key].function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = join("/", [aws_apigatewayv2_api.api.execution_arn, aws_apigatewayv2_stage.default.name, replace(each.key, " ", "")])
}

#######################
#   LAMBDA PACKAGES   #
#######################

data "archive_file" "packages" {
  for_each    = toset(["receiver", "responder", "slack-api"])
  source_dir  = "${path.module}/functions/${each.value}/src"
  output_path = "${path.module}/functions/${each.value}/package.zip"
  type        = "zip"
}

################################
#   LAMBDA RECEIVER FUNCTION   #
################################

resource "aws_iam_role" "receiver" {
  name = "${var.receiver_function_name}-${data.aws_region.current.name}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "AssumeLambda"
      Effect    = "Allow"
      Action    = "sts:AssumeRole"
      Principal = { Service = ["lambda.amazonaws.com"] }
    }]
  })

  inline_policy {
    name = "access"
    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Sid      = "ExecuteApi"
          Effect   = "Allow"
          Action   = "execute-api:Invoke"
          Resource = join("/", [aws_apigatewayv2_api.api.execution_arn, aws_apigatewayv2_stage.default.name, "POST/-/*"])
        },
        {
          Sid      = "EventBridge"
          Effect   = "Allow"
          Action   = "events:PutEvents"
          Resource = aws_cloudwatch_event_bus.bus.arn
        },
        {
          Sid      = "Logs"
          Effect   = "Allow"
          Action   = "logs:*"
          Resource = "*"
        },
        {
          Sid      = "SecretsManager"
          Effect   = "Allow"
          Action   = "secretsmanager:GetSecretValue"
          Resource = aws_secretsmanager_secret.secret.arn
        }
      ]
    })
  }
}

resource "aws_lambda_function" "receiver" {
  architectures    = ["arm64"]
  description      = var.receiver_function_description
  filename         = data.archive_file.packages["receiver"].output_path
  function_name    = var.receiver_function_name
  handler          = "index.handler"
  memory_size      = var.receiver_function_memory_size
  role             = aws_iam_role.receiver.arn
  runtime          = "python3.9"
  source_code_hash = data.archive_file.packages["receiver"].output_base64sha256
  tags             = var.tags
  timeout          = 3

  environment {
    variables = {
      EVENT_BUS_NAME = aws_cloudwatch_event_bus.bus.name
      SECRET_ID      = aws_secretsmanager_secret.secret.id
    }
  }
}

resource "aws_lambda_permission" "receiver" {
  for_each      = toset([for x in local.receiver_routes : replace(x, " ", "")])
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.receiver.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = join("/", [aws_apigatewayv2_api.api.execution_arn, aws_apigatewayv2_stage.default.name, each.value])
}

#################################
#   LAMBDA RESPONDER FUNCTION   #
#################################

resource "aws_iam_role" "responder" {
  name = "${var.responder_function_name}-${data.aws_region.current.name}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "AssumeLambda"
      Effect    = "Allow"
      Action    = "sts:AssumeRole"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })

  inline_policy {
    name = "access"
    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [{
        Sid      = "Logs"
        Effect   = "Allow"
        Action   = "logs:*"
        Resource = "*"
      }]
    })
  }
}

resource "aws_lambda_function" "responder" {
  architectures    = ["arm64"]
  description      = var.responder_function_description
  filename         = data.archive_file.packages["responder"].output_path
  function_name    = var.responder_function_name
  handler          = "index.handler"
  memory_size      = var.responder_function_memory_size
  role             = aws_iam_role.responder.arn
  runtime          = "python3.9"
  source_code_hash = data.archive_file.packages["responder"].output_base64sha256
  tags             = var.tags
  timeout          = 3
}

resource "aws_lambda_permission" "responder" {
  for_each      = toset([for x in local.responder_routes : replace(x, " ", "")])
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.responder.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = join("/", [aws_apigatewayv2_api.api.execution_arn, aws_apigatewayv2_stage.default.name, each.value])
}

##########################
#   SLACK API FUNCTION   #
##########################

resource "aws_iam_role" "slack_api" {
  name = "${var.slack_api_function_name}-${data.aws_region.current.name}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "AssumeLambda"
      Effect    = "Allow"
      Action    = "sts:AssumeRole"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })

  inline_policy {
    name = "access"
    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Sid      = "Logs"
          Effect   = "Allow"
          Action   = "logs:*"
          Resource = "*"
        },
        {
          Sid      = "SecretsManager"
          Effect   = "Allow"
          Action   = "secretsmanager:GetSecretValue"
          Resource = aws_secretsmanager_secret.secret.arn
      }]
    })
  }
}

resource "aws_lambda_function" "slack_api" {
  architectures    = ["arm64"]
  description      = var.slack_api_function_description
  filename         = data.archive_file.packages["slack-api"].output_path
  function_name    = var.slack_api_function_name
  handler          = "index.handler"
  memory_size      = var.slack_api_function_memory_size
  role             = aws_iam_role.slack_api.arn
  runtime          = "python3.9"
  source_code_hash = data.archive_file.packages["slack-api"].output_base64sha256
  tags             = var.tags
  timeout          = 3

  environment {
    variables = {
      SECRET_ID = aws_secretsmanager_secret.secret.id
    }
  }
}

############
#   LOGS   #
############

resource "aws_cloudwatch_log_group" "api" {
  name              = "/aws/apigatewayv2/${aws_apigatewayv2_api.api.name}"
  retention_in_days = var.log_retention_in_days
}

resource "aws_cloudwatch_log_group" "receiver" {
  name              = "/aws/lambda/${aws_lambda_function.receiver.function_name}"
  retention_in_days = var.log_retention_in_days
}

resource "aws_cloudwatch_log_group" "responder" {
  name              = "/aws/lambda/${aws_lambda_function.responder.function_name}"
  retention_in_days = var.log_retention_in_days
}

resource "aws_cloudwatch_log_group" "slack_api" {
  name              = "/aws/lambda/${aws_lambda_function.slack_api.function_name}"
  retention_in_days = var.log_retention_in_days
}
