###########
#   AWS   #
###########

provider "aws" {
  region = "us-east-1"

  default_tags {
    tags = local.tags
  }
}

##############
#   LOCALS   #
##############

locals {
  domain = "slack.${var.domain}"
  name   = "slackbot"
  region = data.aws_region.current.name

  parameters = {
    client_secret  = var.slack_client_secret
    signing_secret = var.slack_signing_secret
    token          = var.slack_token
  }

  tags = {
    Name = "slackbot"
  }
}

############
#   DATA   #
############

data "aws_region" "current" {
}

data "aws_acm_certificate" "cert" {
  domain = var.domain
  types  = ["AMAZON_ISSUED"]
}

data "aws_route53_zone" "zone" {
  name = "${var.domain}."
}

################
#   SLACKBOT   #
################

module "slackbot" {
  source = "./.."

  # App Name
  name = local.name

  # DNS
  domain_name            = local.domain
  domain_certificate_arn = data.aws_acm_certificate.cert.arn
  domain_zone_id         = data.aws_route53_zone.zone.id

  # SLACK
  slack_client_id      = var.slack_client_id
  slack_client_secret  = var.slack_client_secret
  slack_error_uri      = var.slack_error_uri
  slack_scope          = var.slack_scope
  slack_signing_secret = var.slack_signing_secret
  slack_success_uri    = var.slack_success_uri
  slack_user_scope     = var.slack_user_scope
  slack_token          = var.slack_token

  # TAGS
  tags = local.tags
}

#########################
#   CUSTOM RESPONDERS   #
#########################

locals {
  indexes           = fileset("${path.module}/functions", "**/index.py")
  custom_responders = toset([for index in local.indexes : dirname(dirname(index))])
}

data "archive_file" "custom_responders" {
  for_each    = local.custom_responders
  source_dir  = "${path.module}/functions/${each.value}/src"
  output_path = "${path.module}/functions/${each.value}/package.zip"
  type        = "zip"
}

resource "aws_iam_role" "custom_responders" {
  for_each = local.custom_responders

  name = "${local.region}-${local.name}-${each.value}"

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

resource "aws_lambda_function" "custom_responders" {
  for_each         = local.custom_responders
  architectures    = ["arm64"]
  description      = "Custom ${each.value}"
  filename         = data.archive_file.custom_responders[each.value].output_path
  function_name    = "${local.name}-${each.value}"
  handler          = "index.handler"
  memory_size      = 128
  role             = aws_iam_role.custom_responders[each.value].arn
  runtime          = "python3.11"
  source_code_hash = data.archive_file.custom_responders[each.value].output_base64sha256
  timeout          = 3
}

resource "aws_cloudwatch_log_group" "custom_responders" {
  for_each          = local.custom_responders
  name              = "/aws/lambda/${aws_lambda_function.custom_responders[each.key].function_name}"
  retention_in_days = 14
}

#######################
#   APP HOME OPENED   #
#######################

resource "aws_iam_role" "app_home_opened" {
  description = "Slackbot app home opened events"
  name        = "${local.region}-${local.name}-app-home-opened-events"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "AssumeEvents"
      Effect    = "Allow"
      Action    = "sts:AssumeRole"
      Principal = { Service = ["events.amazonaws.com"] }
    }]
  })

  inline_policy {
    name = "access"
    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [{
        Sid      = "StartExecution"
        Effect   = "Allow"
        Action   = "states:StartExecution"
        Resource = aws_sfn_state_machine.app_home_opened.arn
      }]
    })
  }
}

resource "aws_cloudwatch_event_rule" "app_home_opened" {
  description    = "Slackbot app home opened"
  event_bus_name = local.name
  name           = "${local.name}-app-home-opened"

  event_pattern = jsonencode({
    source      = [local.domain]
    detail-type = ["POST /event"]
    detail = {
      type = ["event_callback"]
      event = {
        type = ["app_home_opened"]
      }
    }
  })
}

resource "aws_cloudwatch_event_target" "app_home_opened" {
  arn            = aws_sfn_state_machine.app_home_opened.arn
  event_bus_name = aws_cloudwatch_event_rule.app_home_opened.event_bus_name
  role_arn       = aws_iam_role.app_home_opened.arn
  rule           = aws_cloudwatch_event_rule.app_home_opened.name
  target_id      = aws_sfn_state_machine.app_home_opened.name
}

resource "aws_sfn_state_machine" "app_home_opened" {
  name     = "${local.name}-app-home-opened"
  role_arn = module.slackbot.roles.states.arn
  type     = "STANDARD"

  definition = jsonencode(yamldecode(templatefile("${path.module}/state-machines/app_home_opened.asl.yml", {
    connection_arn = module.slackbot.connection.arn
  })))
}

##################
#   OPEN MODAL   #
##################

resource "aws_iam_role" "open_modal" {
  description = "Slackbot open modal events"
  name        = "${local.region}-${local.name}-open-modal-events"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "AssumeEvents"
      Effect    = "Allow"
      Action    = "sts:AssumeRole"
      Principal = { Service = ["events.amazonaws.com"] }
    }]
  })

  inline_policy {
    name = "access"
    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [{
        Sid      = "StartExecution"
        Effect   = "Allow"
        Action   = "states:StartExecution"
        Resource = aws_sfn_state_machine.open_modal.arn
      }]
    })
  }
}

resource "aws_cloudwatch_event_rule" "open_modal" {
  description    = "Slackbot open modal"
  event_bus_name = local.name
  name           = "${local.name}-open-modal"

  event_pattern = jsonencode({
    source      = [local.domain]
    detail-type = ["POST /callback"]
    detail = {
      type = ["block_actions"]
      actions = {
        action_id = ["open_modal"]
      }
    }
  })
}

resource "aws_cloudwatch_event_target" "open_modal" {
  arn            = aws_sfn_state_machine.open_modal.arn
  event_bus_name = aws_cloudwatch_event_rule.open_modal.event_bus_name
  role_arn       = aws_iam_role.open_modal.arn
  rule           = aws_cloudwatch_event_rule.open_modal.name
  target_id      = aws_sfn_state_machine.open_modal.name
}

resource "aws_sfn_state_machine" "open_modal" {
  name     = "${local.name}-open-modal"
  role_arn = module.slackbot.roles.states.arn
  type     = "STANDARD"

  definition = jsonencode(yamldecode(templatefile("${path.module}/state-machines/open_modal.asl.yml", {
    connection_arn = module.slackbot.connection.arn
  })))
}
