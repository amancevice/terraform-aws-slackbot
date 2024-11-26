################
#   AWS DATA   #
################

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

##############
#   LOCALS   #
##############

locals {
  account = data.aws_caller_identity.current.account_id
  region  = data.aws_region.current.name

  api_body = jsonencode(yamldecode(templatefile("${path.module}/openapi.yml", {
    description = "${var.name} REST API"
    region      = local.region
    role_arn    = aws_iam_role.roles["apigateway"].arn
    server_url  = "https://${var.domain_name}${coalesce(var.api_base_path, "/")}"
    title       = var.name
  })))

  roles = {
    apigateway = {
      states = {
        Version = "2012-10-17"
        Statement = [{
          Sid    = "StartExecution"
          Effect = "Allow"
          Action = "states:StartSyncExecution"
          Resource = [
            for key, _ in local.state_machines :
            "arn:aws:states:${local.region}:${local.account}:stateMachine:${var.name}-api-${key}"
          ]
        }]
      }
    }

    events = {
      states = {
        Version = "2012-10-17"
        Statement = [{
          Sid      = "StartExecution"
          Effect   = "Allow"
          Resource = "arn:aws:states:${local.region}:${local.account}:stateMachine:${var.name}-*"
          Action = [
            "states:StartExecution",
            "states:StartSyncExecution",
          ]
        }]
      }
    }

    lambda = {
      logs = {
        Version = "2012-10-17"
        Statement = [{
          Sid      = "Logs"
          Effect   = "Allow"
          Action   = "logs:*"
          Resource = "*"
        }]
      }
    }

    states = {
      events = {
        Version = "2012-10-17"
        Statement = [{
          Effect   = "Allow"
          Action   = "events:PutEvents"
          Resource = aws_cloudwatch_event_bus.bus.arn
        }]
      }

      lambda = {
        Version = "2012-10-17"
        Statement = [{
          Sid      = "Invoke"
          Effect   = "Allow"
          Action   = "lambda:InvokeFunction"
          Resource = "arn:aws:lambda:${local.region}:${local.account}:function:${var.name}-*"
        }]
      }

      logs = {
        Version = "2012-10-17"
        Statement = [{
          Sid      = "Logs"
          Effect   = "Allow"
          Action   = "logs:*"
          Resource = "*"
        }]
      }

      slack-api = {
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
      }

      states = {
        Version = "2012-10-17"
        Statement = [{
          Effect = "Allow"
          Action = [
            "states:DescribeExecution",
            "states:StartExecution",
          ]
          Resource = [
            "arn:aws:states:${local.region}:${local.account}:stateMachine:${var.name}-api-state",
            "arn:aws:states:${local.region}:${local.account}:execution:${var.name}-api-state:*",
          ]
        }]
      }
    }
  }

  functions = {
    authorizer = {
      description = "Slack request authorizer"
      memory_size = 1024
      variables = {
        SIGNING_SECRET = var.slack_signing_secret
      }
    }
    oauth = {
      description = "Slack OAuth completion"
      memory_size = 256
      variables = {
        CLIENT_ID     = var.slack_client_id
        CLIENT_SECRET = var.slack_client_secret
      }
    }
  }

  state_machines = {
    callback = "EXPRESS"
    event    = "EXPRESS"
    install  = "EXPRESS"
    menu     = "EXPRESS"
    oauth    = "EXPRESS"
    slash    = "EXPRESS"
    state    = "STANDARD"
  }

  log_groups = merge(
    { apigateway = "/aws/apigateway/${var.name}" },
    { for key, _ in local.functions : "lambda-${key}" => "/aws/lambda/${var.name}-api-${key}" },
    { for key, _ in local.state_machines : "states-${key}" => "/aws/states/${var.name}-api-${key}" },
  )
}

###################
#   EVENTBRIDGE   #
###################

resource "aws_cloudwatch_event_bus" "bus" {
  name = var.name
  tags = var.tags
}

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
    destination_arn = aws_cloudwatch_log_group.logs["apigateway"].arn
    format          = jsonencode(var.api_log_format)
  }
}

resource "aws_api_gateway_domain_name" "api" {
  domain_name              = var.domain_name
  regional_certificate_arn = var.domain_certificate_arn

  endpoint_configuration {
    types = ["REGIONAL"]
  }
}

resource "aws_api_gateway_base_path_mapping" "api" {
  api_id      = aws_api_gateway_rest_api.api.id
  base_path   = var.api_base_path
  domain_name = var.domain_name
  stage_name  = aws_api_gateway_stage.api.stage_name
}

resource "aws_route53_record" "api" {
  name           = aws_api_gateway_domain_name.api.domain_name
  set_identifier = local.region
  type           = "A"
  zone_id        = var.domain_zone_id

  alias {
    evaluate_target_health = false
    name                   = aws_api_gateway_domain_name.api.regional_domain_name
    zone_id                = aws_api_gateway_domain_name.api.regional_zone_id
  }

  latency_routing_policy {
    region = local.region
  }
}

############
#   LOGS   #
############

resource "aws_cloudwatch_log_group" "logs" {
  for_each = local.log_groups

  name              = each.value
  retention_in_days = var.log_retention_in_days
}

#################
#   IAM ROLES   #
#################

resource "aws_iam_role" "roles" {
  for_each = local.roles

  name        = "${var.name}-${local.region}-${each.key}"
  description = "${var.name} ${each.key} role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "AssumeApiGateway"
      Effect    = "Allow"
      Action    = "sts:AssumeRole"
      Principal = { Service = "${each.key}.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy" "policies" {
  for_each = merge(flatten([
    for key, role in aws_iam_role.roles : [
      for name, policy in local.roles[key] : {
        "${key}-${name}" = {
          role   = role.id
          name   = name
          policy = policy
        }
      }
    ]
  ])...)

  name   = each.value.name
  policy = jsonencode(each.value.policy)
  role   = each.value.role
}

########################
#   LAMBDA FUNCTIONS   #
########################

data "archive_file" "packages" {
  for_each = local.functions

  source_dir  = "${path.module}/functions/${each.key}/src"
  output_path = "${path.module}/functions/${each.key}/package.zip"
  type        = "zip"
}

resource "aws_lambda_function" "functions" {
  for_each = local.functions

  architectures    = ["arm64"]
  description      = each.value.description
  filename         = data.archive_file.packages[each.key].output_path
  function_name    = "${var.name}-api-${each.key}"
  handler          = "index.handler"
  memory_size      = each.value.memory_size
  publish          = true
  role             = aws_iam_role.roles["lambda"].arn
  runtime          = var.lambda_runtime
  source_code_hash = data.archive_file.packages[each.key].output_base64sha256
  tags             = var.tags
  timeout          = 3

  environment {
    variables = each.value.variables
  }

  snap_start {
    apply_on = "PublishedVersions"
  }
}

######################
#   STATE MACHINES   #
######################

resource "aws_sfn_state_machine" "states" {
  depends_on = [aws_cloudwatch_log_group.logs]

  for_each = local.state_machines

  name = "${var.name}-api-${each.key}"
  type = each.value

  role_arn = aws_iam_role.roles["states"].arn

  definition = jsonencode(yamldecode(templatefile("${path.module}/state-machines/${each.key}.asl.yml", {
    account = local.account
    region  = local.region

    event_bus_name          = aws_cloudwatch_event_bus.bus.name
    authorizer_function_arn = aws_lambda_function.functions["authorizer"].arn
    oauth_function_arn      = aws_lambda_function.functions["oauth"].arn

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
    log_destination        = "${aws_cloudwatch_log_group.logs["states-${each.key}"].arn}:*"
  }
}
