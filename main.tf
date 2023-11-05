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

  lambda_runtime  = "python3.11"
  lambda_handlers = fileset(path.module, "functions/*/src/index.py")
  lambda_packages = {
    for x in local.lambda_handlers :
    split("/", x)[1] => dirname(dirname(x))
  }

  request_mime_types = [
    "application/json",
    "application/x-www-form-urlencoded",
  ]

  request_parameters = {
    default = {
      "method.request.header.x-slack-request-timestamp" = true
      "method.request.header.x-slack-signature"         = true
    }
    install = null
    oauth = {
      "method.request.querystring.code"  = true
      "method.request.querystring.state" = true
    }
  }

  request_templates = {
    default = {
      routeKey  = "$context.httpMethod $context.resourcePath"
      signature = "$input.params('x-slack-signature')"
      ts        = "$input.params('x-slack-request-timestamp')"
      body      = "$input.body"
    }
    install = {
      routeKey = "$context.httpMethod $context.resourcePath"
    }
    oauth = {
      routeKey = "$context.httpMethod $context.resourcePath"
      code     = "$input.params('code')"
      state    = "$input.params('state')"
    }
  }

  routes = {
    "GET /install" = {
      resource               = "install"
      http_method            = "GET"
      request_parameters     = local.request_parameters.install
      request_template       = local.request_templates.install
      state_machine_template = "install"
    }
    "GET /oauth" = {
      resource               = "oauth"
      http_method            = "GET"
      request_parameters     = local.request_parameters.oauth
      request_template       = local.request_templates.oauth
      state_machine_template = "oauth"
    }
    "POST /callback" = {
      resource               = "callback"
      http_method            = "POST"
      request_parameters     = local.request_parameters.default
      request_template       = local.request_templates.default
      state_machine_template = "default"
    }
    "POST /event" = {
      resource               = "event"
      http_method            = "POST"
      request_parameters     = local.request_parameters.default
      request_template       = local.request_templates.default
      state_machine_template = "default"
    }
    "POST /menu" = {
      resource               = "menu"
      http_method            = "POST"
      request_parameters     = local.request_parameters.default
      request_template       = local.request_templates.default
      state_machine_template = "default"
    }
    "POST /slash" = {
      resource               = "slash"
      http_method            = "POST"
      request_parameters     = local.request_parameters.default
      request_template       = local.request_templates.default
      state_machine_template = "default"
    }
  }

  resources = toset([
    for key, route in local.routes : route.resource
  ])

  methods = {
    for key, route in local.routes : key => {
      resource_id        = aws_api_gateway_resource.resources[route.resource].id
      http_method        = route.http_method
      request_parameters = route.request_parameters
    }
  }

  integrations = {
    for key, route in local.routes : key => {
      resource_id = aws_api_gateway_resource.resources[route.resource].id
      http_method = aws_api_gateway_method.methods[key].http_method
      request_templates = {
        for mime_type in local.request_mime_types : mime_type => jsonencode({
          stateMachineArn = aws_sfn_state_machine.states[key].arn
          input           = jsonencode(route.request_template)
        })
      }
    }
  }

  state_machines = merge(
    {
      for key, route in local.routes : key => {
        name     = "${var.name}-${lower(route.http_method)}-${route.resource}"
        template = "${path.module}/state-machines/${route.state_machine_template}.asl.yml"
        type     = "EXPRESS"
      }
    },
    {
      state = {
        name     = "${var.name}-state"
        template = "${path.module}/state-machines/state.asl.yml"
        type     = "STANDARD"
      }
    }
  )
}

#######################
#   EVENTBRIDGE BUS   #
#######################

resource "aws_cloudwatch_event_bus" "bus" {
  name = var.name
  tags = var.tags
}

################
#   REST API   #
################

resource "aws_api_gateway_rest_api" "api" {
  description                  = "${var.name} REST API"
  disable_execute_api_endpoint = true
  name                         = var.name
  tags                         = var.tags

  endpoint_configuration {
    types = ["REGIONAL"]
  }
}

resource "aws_api_gateway_deployment" "api" {
  rest_api_id = aws_api_gateway_rest_api.api.id

  triggers = {
    redeployment = sha1(jsonencode([
      timestamp(),
      [for x in aws_api_gateway_resource.resources : x.id],
      [for x in aws_api_gateway_method.methods : x.id],
      [for x in aws_api_gateway_integration.integrations : x.id],
      [for x in aws_api_gateway_integration.integrations : jsonencode(x.request_templates)],
      [for x in aws_api_gateway_integration_response.responses : jsonencode(x.response_templates)],
      [for x in aws_api_gateway_method_response.responses : jsonencode(x.response_models)],
    ]))
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

#############################
#   REST API :: RESOURCES   #
#############################

resource "aws_api_gateway_resource" "resources" {
  for_each = local.resources

  rest_api_id = aws_api_gateway_rest_api.api.id
  parent_id   = aws_api_gateway_rest_api.api.root_resource_id
  path_part   = each.key
}

###########################
#   REST API :: METHODS   #
###########################

resource "aws_api_gateway_request_validator" "headers" {
  name                        = "Validate query string parameters and headers"
  rest_api_id                 = aws_api_gateway_rest_api.api.id
  validate_request_parameters = true
}

resource "aws_api_gateway_method" "methods" {
  depends_on = [aws_api_gateway_resource.resources]
  for_each   = local.methods

  http_method        = each.value.http_method
  request_parameters = each.value.request_parameters
  resource_id        = each.value.resource_id

  authorization        = "NONE"
  request_validator_id = aws_api_gateway_request_validator.headers.id
  rest_api_id          = aws_api_gateway_rest_api.api.id
}

################################
#   REST API :: INTEGRATIONS   #
################################

resource "aws_api_gateway_integration" "integrations" {
  depends_on = [aws_api_gateway_method.methods]
  for_each   = local.integrations

  http_method       = each.value.http_method
  request_templates = each.value.request_templates
  resource_id       = each.value.resource_id

  credentials             = aws_iam_role.apigateway.arn
  integration_http_method = "POST"
  passthrough_behavior    = "NEVER"
  rest_api_id             = aws_api_gateway_rest_api.api.id
  timeout_milliseconds    = 3000
  type                    = "AWS"
  uri                     = "arn:aws:apigateway:${local.region}:states:action/StartSyncExecution"
}

#########################################
#   REST API :: INTEGRATION RESPONSES   #
#########################################

resource "aws_api_gateway_integration_response" "responses" {
  depends_on = [aws_api_gateway_integration.integrations]
  for_each   = local.methods

  http_method = each.value.http_method
  resource_id = each.value.resource_id

  rest_api_id = aws_api_gateway_rest_api.api.id
  status_code = 200

  response_templates = {
    "application/json" = <<-EOT
      #if($input.path('$.status') != "SUCCEEDED")
      #set($context.responseOverride.status = 403)
      {"message":"Forbidden"}#else
      #set($output = $util.parseJson($input.path('$.output')))
      #set($context.responseOverride.status = $output.statusCode)
      #if($output.headers.location)#set($context.responseOverride.header.location = $output.headers.location)#end
      #if($output.body)$output.body#end
      #end
    EOT
  }
}

####################################
#   REST API :: METHOD RESPONSES   #
####################################

resource "aws_api_gateway_method_response" "responses" {
  depends_on = [aws_api_gateway_integration.integrations]
  for_each   = local.methods

  http_method = each.value.http_method
  resource_id = each.value.resource_id

  rest_api_id = aws_api_gateway_rest_api.api.id
  status_code = 200

  response_models = {
    "application/json" = "Empty"
  }
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

resource "aws_cloudwatch_log_group" "http_authorizer" {
  name              = "/aws/lambda/${var.name}-http-authorizer"
  retention_in_days = var.log_retention_in_days
}

resource "aws_iam_role" "http_authorizer" {
  name        = "${var.name}-${local.region}-http-authorizer"
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
        Resource = "${aws_cloudwatch_log_group.http_authorizer.arn}:*"
      }]
    })
  }

  inline_policy {
    name = "ssm"
    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [{
        Sid      = "GetParameter"
        Effect   = "Allow"
        Action   = "ssm:GetParameter"
        Resource = "arn:aws:ssm:${local.region}:${local.account}:parameter${var.parameters.signing_secret}"
      }]
    })
  }
}

resource "aws_lambda_function" "http_authorizer" {
  architectures    = ["arm64"]
  description      = "${var.name} HTTP event authorizer function"
  filename         = data.archive_file.packages["http-authorizer"].output_path
  function_name    = "${var.name}-http-authorizer"
  handler          = "index.handler"
  memory_size      = var.authorizer_function_memory_size
  role             = aws_iam_role.http_authorizer.arn
  runtime          = local.lambda_runtime
  source_code_hash = data.archive_file.packages["http-authorizer"].output_base64sha256
  tags             = var.tags
  timeout          = 3

  environment {
    variables = {
      SIGNING_SECRET_PARAMETER = var.parameters.signing_secret
    }
  }
}

########################################
#   LAMBDA HTTP TRANSFORMER FUNCTION   #
########################################

resource "aws_cloudwatch_log_group" "http_transformer" {
  name              = "/aws/lambda/${var.name}-http-transformer"
  retention_in_days = var.log_retention_in_days
}

resource "aws_iam_role" "http_transformer" {
  name        = "${var.name}-${local.region}-http-transformer"
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
        Resource = "${aws_cloudwatch_log_group.http_transformer.arn}:*"
      }]
    })
  }
}

resource "aws_lambda_function" "http_transformer" {
  architectures    = ["arm64"]
  description      = "${var.name} HTTP event transformer function"
  filename         = data.archive_file.packages["http-transformer"].output_path
  function_name    = "${var.name}-http-transformer"
  handler          = "index.handler"
  memory_size      = var.transformer_function_memory_size
  role             = aws_iam_role.http_transformer.arn
  runtime          = local.lambda_runtime
  source_code_hash = data.archive_file.packages["http-transformer"].output_base64sha256
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
        Resource = "${aws_cloudwatch_log_group.http_transformer.arn}:*"
      }]
    })
  }

  inline_policy {
    name = "ssm"
    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [{
        Sid    = "GetParameter"
        Effect = "Allow"
        Action = "ssm:GetParameter"
        Resource = [
          "arn:aws:ssm:${local.region}:${local.account}:parameter${var.parameters.client_id}",
          "arn:aws:ssm:${local.region}:${local.account}:parameter${var.parameters.client_secret}",
        ]
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
  memory_size      = var.oauth_function_memory_size
  role             = aws_iam_role.oauth.arn
  runtime          = local.lambda_runtime
  source_code_hash = data.archive_file.packages["oauth"].output_base64sha256
  tags             = var.tags
  timeout          = 3

  environment {
    variables = {
      CLIENT_ID_PARAMETER     = var.parameters.client_id
      CLIENT_SECRET_PARAMETER = var.parameters.client_secret
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
    name = "ssm"
    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [{
        Effect = "Allow"
        Action = "ssm:GetParameter"
        Resource = [
          for _, name in var.parameters :
          "arn:aws:ssm:${local.region}:${local.account}:parameter${name}"
          if name != null
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

  name = each.value.name
  type = each.value.type

  role_arn = aws_iam_role.states.arn

  definition = jsonencode(yamldecode(templatefile(each.value.template, {
    account                       = local.account
    client_id_parameter           = var.parameters.client_id == null ? "" : var.parameters.client_id
    client_secret_parameter       = var.parameters.client_secret == null ? "" : var.parameters.client_secret
    detail_type                   = each.key
    domain_name                   = var.domain_name
    error_uri_parameter           = var.parameters.error_uri == null ? "" : var.parameters.error_uri
    event_bus_name                = aws_cloudwatch_event_bus.bus.name
    http_authorizer_function_arn  = aws_lambda_function.http_authorizer.arn
    http_transformer_function_arn = aws_lambda_function.http_transformer.arn
    name                          = var.name
    oauth_function_arn            = aws_lambda_function.oauth.arn
    redirect_uri                  = "https://slack.beachplum.io/oauth"
    region                        = local.region
    scope_parameter               = var.parameters.scope == null ? "" : var.parameters.scope
    signing_secret_parameter      = var.parameters.signing_secret == null ? "" : var.parameters.signing_secret
    success_uri_parameter         = var.parameters.success_uri == null ? "" : var.parameters.success_uri
    user_scope_parameter          = var.parameters.user_scope == null ? "" : var.parameters.user_scope
  })))

  logging_configuration {
    include_execution_data = true
    level                  = "ALL"
    log_destination        = "${aws_cloudwatch_log_group.states.arn}:*"
  }
}
