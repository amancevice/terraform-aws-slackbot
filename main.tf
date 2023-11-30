#################
#   TERRAFORM   #
#################

terraform {
  required_version = "~> 1.0"

  required_providers {
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.3"
    }

    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

##################
#   AWS REGION   #
##################

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

##############
#   LOCALS   #
##############

locals {
  account = data.aws_caller_identity.current.account_id
  region  = data.aws_region.current.name

  redirect_uri = "https://${var.domain_name}/oauth"

  lambda_runtime  = "python3.11"
  lambda_handlers = fileset(path.module, "functions/*/src/index.py")
  lambda_packages = {
    for x in local.lambda_handlers :
    split("/", x)[1] => dirname(dirname(x))
  }

  state_machines = {
    install  = "EXPRESS"
    oauth    = "EXPRESS"
    callback = "EXPRESS"
    event    = "EXPRESS"
    menu     = "EXPRESS"
    slash    = "EXPRESS"
    state    = "STANDARD"
  }

  api_body = jsonencode(yamldecode(templatefile("${path.module}/openapi.yml", {
    description = "${var.name} REST API"
    region      = local.region
    role_arn    = aws_iam_role.apigateway.arn
    server_url  = "https://${var.domain_name}${coalesce(var.api_base_path, "/")}"
    title       = var.name
  })))
}

#######################
#   EVENTBRIDGE BUS   #
#######################

resource "aws_cloudwatch_event_bus" "bus" {
  name = var.name
  tags = var.tags
}

##############################
#   EVENTBRIDGE CONNECTION   #
##############################

resource "aws_cloudwatch_event_connection" "slack" {
  name               = var.name
  description        = "${var.name} Slack API connection"
  authorization_type = "API_KEY"

  auth_parameters {
    api_key {
      key   = "authorization"
      value = "Bearer ${var.slack_token}"
    }
  }
}

################
#   REST API   #
################

resource "aws_api_gateway_rest_api" "api" {
  body        = local.api_body
  description = "${var.name} REST API"
  name        = var.name
  tags        = var.tags

  endpoint_configuration {
    types = ["REGIONAL"]
  }
}

resource "aws_api_gateway_deployment" "api" {
  rest_api_id = aws_api_gateway_rest_api.api.id

  triggers = {
    redeployment = sha1(local.api_body)
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_api_gateway_stage" "api" {
  deployment_id = aws_api_gateway_deployment.api.id
  rest_api_id   = aws_api_gateway_rest_api.api.id
  description   = "${var.name} default stage"
  stage_name    = "default"

  variables = {
    for key, state_machine in aws_sfn_state_machine.states :
    "${key}StateMachineArn" => state_machine.arn
  }

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api.arn
    format          = jsonencode(var.api_log_format)
  }
}

resource "aws_cloudwatch_log_group" "api" {
  name              = "/aws/apigateway/${aws_api_gateway_rest_api.api.name}"
  retention_in_days = var.log_retention_in_days
}

#######################
#   REST API :: DNS   #
#######################

resource "aws_route53_record" "api" {
  name           = aws_api_gateway_domain_name.api.domain_name
  set_identifier = local.region
  type           = "A"
  zone_id        = var.domain_zone_id

  alias {
    evaluate_target_health = false
    name                   = aws_api_gateway_domain_name.api.cloudfront_domain_name
    zone_id                = aws_api_gateway_domain_name.api.cloudfront_zone_id
  }

  latency_routing_policy {
    region = local.region
  }
}

resource "aws_api_gateway_domain_name" "api" {
  certificate_arn = var.domain_certificate_arn
  domain_name     = var.domain_name
}

resource "aws_api_gateway_base_path_mapping" "api" {
  api_id      = aws_api_gateway_rest_api.api.id
  base_path   = var.api_base_path
  domain_name = var.domain_name
  stage_name  = aws_api_gateway_stage.api.stage_name
}

############################
#   REST API :: IAM ROLE   #
############################

resource "aws_iam_role" "apigateway" {
  name        = "${var.name}-${local.region}-apigateway"
  description = "${var.name} API Gateway role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "AssumeApiGateway"
      Effect    = "Allow"
      Action    = "sts:AssumeRole"
      Principal = { Service = "apigateway.amazonaws.com" }
    }]
  })

  inline_policy {
    name = "states"
    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [{
        Sid      = "StartExecution"
        Effect   = "Allow"
        Action   = "states:StartSyncExecution"
        Resource = [for sfn in aws_sfn_state_machine.states : sfn.arn]
      }]
    })
  }
}

########################
#   LAMBDA FUNCTIONS   #
########################

data "archive_file" "packages" {
  for_each    = local.lambda_packages
  source_dir  = "${path.module}/${each.value}/src"
  output_path = "${path.module}/${each.value}/package.zip"
  type        = "zip"
}

#######################################
#   LAMBDA HTTP AUTHORIZER FUNCTION   #
#######################################

resource "aws_cloudwatch_log_group" "authorizer" {
  name              = "/aws/lambda/${var.name}-api-authorizer"
  retention_in_days = var.log_retention_in_days
}

resource "aws_iam_role" "authorizer" {
  name        = "${var.name}-${local.region}-api-authorizer"
  description = "${var.name} HTTP event authorizer role"

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
    name = "logs"
    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [{
        Sid      = "Logs"
        Effect   = "Allow"
        Action   = "logs:*"
        Resource = "${aws_cloudwatch_log_group.authorizer.arn}:*"
      }]
    })
  }
}

resource "aws_lambda_function" "authorizer" {
  architectures    = ["arm64"]
  description      = "${var.name} API authorizer function"
  filename         = data.archive_file.packages["authorizer"].output_path
  function_name    = "${var.name}-api-authorizer"
  handler          = "index.handler"
  memory_size      = 1024
  role             = aws_iam_role.authorizer.arn
  runtime          = local.lambda_runtime
  source_code_hash = data.archive_file.packages["authorizer"].output_base64sha256
  tags             = var.tags
  timeout          = 3

  environment {
    variables = {
      SIGNING_SECRET = var.slack_signing_secret
    }
  }
}

########################################
#   LAMBDA HTTP TRANSFORMER FUNCTION   #
########################################

resource "aws_cloudwatch_log_group" "transformer" {
  name              = "/aws/lambda/${var.name}-api-transformer"
  retention_in_days = var.log_retention_in_days
}

resource "aws_iam_role" "transformer" {
  name        = "${var.name}-${local.region}-api-transformer"
  description = "${var.name} HTTP event transformer role"

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
    name = "logs"
    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [{
        Sid      = "Logs"
        Effect   = "Allow"
        Action   = "logs:*"
        Resource = "${aws_cloudwatch_log_group.transformer.arn}:*"
      }]
    })
  }
}

resource "aws_lambda_function" "transformer" {
  architectures    = ["arm64"]
  description      = "${var.name} API transformer function"
  filename         = data.archive_file.packages["transformer"].output_path
  function_name    = "${var.name}-api-transformer"
  handler          = "index.handler"
  memory_size      = 1024
  role             = aws_iam_role.transformer.arn
  runtime          = local.lambda_runtime
  source_code_hash = data.archive_file.packages["transformer"].output_base64sha256
  tags             = var.tags
  timeout          = 3
}

####################
#   LAMBDA OAUTH   #
####################

resource "aws_cloudwatch_log_group" "oauth" {
  name              = "/aws/lambda/${var.name}-oauth"
  retention_in_days = var.log_retention_in_days
}

resource "aws_iam_role" "oauth" {
  name        = "${var.name}-${local.region}-oauth"
  description = "${var.name} HTTP event transformer role"

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
    name = "logs"
    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [{
        Sid      = "Logs"
        Effect   = "Allow"
        Action   = "logs:*"
        Resource = "${aws_cloudwatch_log_group.oauth.arn}:*"
      }]
    })
  }
}

resource "aws_lambda_function" "oauth" {
  architectures    = ["arm64"]
  description      = "${var.name} OAuth function"
  filename         = data.archive_file.packages["oauth"].output_path
  function_name    = "${var.name}-oauth"
  handler          = "index.handler"
  memory_size      = 256
  role             = aws_iam_role.oauth.arn
  runtime          = local.lambda_runtime
  source_code_hash = data.archive_file.packages["oauth"].output_base64sha256
  tags             = var.tags
  timeout          = 3

  environment {
    variables = {
      CLIENT_ID     = var.slack_client_id
      CLIENT_SECRET = var.slack_client_secret
    }
  }
}

######################
#   STATE MACHINES   #
######################

resource "aws_iam_role" "states" {
  name        = "${var.name}-${local.region}-states"
  description = "${var.name} HTTP event state machine role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "AssumeApiGateway"
      Effect    = "Allow"
      Action    = "sts:AssumeRole"
      Principal = { Service = "states.amazonaws.com" }
    }]
  })

  inline_policy {
    name = "slack-api"
    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Sid      = "InvokeHttp"
          Effect   = "Allow"
          Action   = "states:InvokeHTTPEndpoint"
          Resource = "*"
          Condition = {
            StringEquals = { "states:HTTPMethod" = ["GET", "POST"] }
            StringLike   = { "states:HTTPEndpoint" = "https://slack.com/api/*" }
          }
        },
        {
          Sid      = "GetConnection"
          Effect   = "Allow"
          Action   = "events:RetrieveConnectionCredentials"
          Resource = aws_cloudwatch_event_connection.slack.arn
        },
        {
          Sid      = "GetSecret"
          Effect   = "Allow"
          Resource = aws_cloudwatch_event_connection.slack.secret_arn
          Action = [
            "secretsmanager:DescribeSecret",
            "secretsmanager:GetSecretValue",
          ]
        }
      ]
    })
  }

  inline_policy {
    name = "events"
    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [{
        Effect   = "Allow"
        Action   = "events:PutEvents"
        Resource = aws_cloudwatch_event_bus.bus.arn
      }]
    })
  }

  inline_policy {
    name = "lambda"
    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [{
        Sid      = "Invoke"
        Effect   = "Allow"
        Action   = "lambda:InvokeFunction"
        Resource = "arn:aws:lambda:${local.region}:${local.account}:function:${var.name}-*"
      }]
    })
  }

  inline_policy {
    name = "logs"
    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [{
        Effect   = "Allow"
        Resource = "*"
        Action = [
          "logs:CreateLogDelivery",
          "logs:CreateLogStream",
          "logs:DeleteLogDelivery",
          "logs:DescribeLogGroups",
          "logs:DescribeResourcePolicies",
          "logs:GetLogDelivery",
          "logs:ListLogDeliveries",
          "logs:PutLogEvents",
          "logs:PutResourcePolicy",
          "logs:UpdateLogDelivery",
        ]
      }]
    })
  }

  inline_policy {
    name = "states"
    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [{
        Effect = "Allow"
        Action = [
          "states:DescribeExecution",
          "states:StartExecution",
        ]
        Resource = [
          "arn:aws:states:${local.region}:${local.account}:stateMachine:${var.name}-state",
          "arn:aws:states:${local.region}:${local.account}:execution:${var.name}-state:*",
        ]
      }]
    })
  }
}

resource "aws_cloudwatch_log_group" "states" {
  name              = "/aws/states/${var.name}"
  retention_in_days = 14
}

resource "aws_sfn_state_machine" "states" {
  for_each = local.state_machines

  name = "${var.name}-api-${each.key}"
  type = each.value

  role_arn = aws_iam_role.states.arn

  definition = jsonencode(yamldecode(templatefile(
    fileexists("${path.module}/state-machines/${each.key}.asl.yml") ?
    "${path.module}/state-machines/${each.key}.asl.yml" : "${path.module}/state-machines/default.asl.yml",
    {
      account            = local.account
      region             = local.region
      slack_redirect_uri = local.redirect_uri

      event_bus_name           = aws_cloudwatch_event_bus.bus.name
      authorizer_function_arn  = aws_lambda_function.authorizer.arn
      transformer_function_arn = aws_lambda_function.transformer.arn
      oauth_function_arn       = aws_lambda_function.oauth.arn

      detail_type = each.key

      name                  = var.name
      domain_name           = var.domain_name
      oauth_timeout_seconds = var.oauth_timeout_seconds
      slack_client_id       = var.slack_client_id
      slack_error_uri       = var.slack_error_uri
      slack_scope           = var.slack_scope
      slack_success_uri     = var.slack_success_uri
      slack_user_scope      = var.slack_user_scope
  })))

  logging_configuration {
    include_execution_data = true
    level                  = "ALL"
    log_destination        = "${aws_cloudwatch_log_group.states.arn}:*"
  }
}
