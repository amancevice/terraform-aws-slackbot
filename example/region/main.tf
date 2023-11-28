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

##############
#   LOCALS   #
##############

locals {
  name   = "slackbot"
  region = data.aws_region.current.name

  parameters = {
    client_secret  = { key : "/${local.name}/client_secret", value : var.slack_client_secret }
    signing_secret = { key : "/${local.name}/signing_secret", value : var.slack_signing_secret }
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

######################
#   SSM PARAMETERS   #
######################

resource "aws_ssm_parameter" "parameters" {
  for_each = local.parameters
  name     = each.value.key
  value    = each.value.value
  type     = "SecureString"
}

################
#   SLACKBOT   #
################

module "slackbot" {
  source = "./../.."

  # App Name
  name = local.name

  # DNS
  domain_name            = "slack.${var.domain}"
  domain_certificate_arn = data.aws_acm_certificate.cert.arn
  domain_zone_id         = data.aws_route53_zone.zone.id

  # SLACK
  slack_client_id                = var.slack_client_id
  slack_client_secret_parameter  = local.parameters.client_secret.key
  slack_error_uri                = var.slack_error_uri
  slack_scope                    = var.slack_scope
  slack_signing_secret_parameter = local.parameters.signing_secret.key
  slack_success_uri              = var.slack_success_uri
  slack_user_scope               = var.slack_user_scope
  # TAGS
  tags = { Region = local.region }
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

# resource "aws_iam_role" "app_home_opened_events" {
#   description = "Slackbot app home opened events"
#   name        = "${local.region}-slackbot-app-home-opened-events"

#   assume_role_policy = jsonencode({
#     Version = "2012-10-17"
#     Statement = [{
#       Sid       = "AssumeEvents"
#       Effect    = "Allow"
#       Action    = "sts:AssumeRole"
#       Principal = { Service = ["events.amazonaws.com"] }
#     }]
#   })

#   inline_policy {
#     name = "access"
#     policy = jsonencode({
#       Version = "2012-10-17"
#       Statement = [{
#         Sid      = "StartExecution"
#         Effect   = "Allow"
#         Action   = "states:StartExecution"
#         Resource = aws_sfn_state_machine.app_home_opened.arn
#       }]
#     })
#   }
# }

# resource "aws_iam_role" "app_home_opened_states" {
#   description = "Slackbot app home opened states"
#   name        = "${local.region}-slackbot-app-home-opened-states"

#   assume_role_policy = jsonencode({
#     Version = "2012-10-17"
#     Statement = [{
#       Sid       = "AssumeEvents"
#       Effect    = "Allow"
#       Action    = "sts:AssumeRole"
#       Principal = { Service = ["states.amazonaws.com"] }
#     }]
#   })

#   inline_policy {
#     name = "access"
#     policy = jsonencode({
#       Version = "2012-10-17"
#       Statement = [{
#         Sid      = "InvokeFunction"
#         Effect   = "Allow"
#         Action   = "lambda:InvokeFunction"
#         Resource = module.slackbot.functions.slack_api.arn
#       }]
#     })
#   }
# }

# resource "aws_cloudwatch_event_rule" "app_home_opened" {
#   description    = "Slackbot app home opened"
#   event_bus_name = "slackbot"
#   name           = "slackbot-app-home-opened"

#   event_pattern = jsonencode({
#     source      = ["event_callback"]
#     detail-type = ["app_home_opened"]
#   })
# }

# resource "aws_cloudwatch_event_target" "app_home_opened" {
#   arn            = aws_sfn_state_machine.app_home_opened.arn
#   event_bus_name = aws_cloudwatch_event_rule.app_home_opened.event_bus_name
#   role_arn       = aws_iam_role.app_home_opened_events.arn
#   rule           = aws_cloudwatch_event_rule.app_home_opened.name
#   target_id      = aws_sfn_state_machine.app_home_opened.name
# }

# resource "aws_sfn_state_machine" "app_home_opened" {
#   name     = "slackbot-app-home-opened"
#   role_arn = aws_iam_role.app_home_opened_states.arn

#   definition = jsonencode({
#     StartAt = "GetView"
#     States = {
#       GetView = {
#         Type      = "Pass"
#         Next      = "EncodeView"
#         InputPath = "$.detail"
#         Parameters = {
#           "user_id.$" = "$.event.user",
#           view = {
#             type = "home"
#             blocks = [
#               {
#                 type = "header"
#                 text = { type : "plain_text", text : "Slackbot Home" }
#               },
#               {
#                 type = "actions"
#                 elements = [{
#                   type      = "button"
#                   action_id = "open_modal"
#                   value     = "open_modal"
#                   text      = { type : "plain_text", text : "Open Modal" }
#                 }]
#               }
#             ]
#           }
#         }
#       }
#       EncodeView = {
#         Type = "Pass"
#         Next = "PublishView"
#         Parameters = {
#           "user_id.$" = "$.user_id"
#           "view.$"    = "States.JsonToString($.view)"
#         }
#       }
#       PublishView = {
#         Type     = "Task"
#         Resource = module.slackbot.functions.slack_api.arn
#         End      = true
#         Parameters = {
#           method   = "POST"
#           url      = "https://slack.com/api/views.publish"
#           headers  = { content-type = "application/json; charset=utf-8" }
#           "data.$" = "States.JsonToString($)"
#         }
#       }
#     }
#   })
# }

##################
#   OPEN MODAL   #
##################

# resource "aws_iam_role" "open_modal_events" {
#   description = "Slackbot open modal events"
#   name        = "${local.region}-slackbot-open-modal-events"

#   assume_role_policy = jsonencode({
#     Version = "2012-10-17"
#     Statement = [{
#       Sid       = "AssumeEvents"
#       Effect    = "Allow"
#       Action    = "sts:AssumeRole"
#       Principal = { Service = ["events.amazonaws.com"] }
#     }]
#   })

#   inline_policy {
#     name = "access"
#     policy = jsonencode({
#       Version = "2012-10-17"
#       Statement = [{
#         Sid      = "StartExecution"
#         Effect   = "Allow"
#         Action   = "states:StartExecution"
#         Resource = aws_sfn_state_machine.open_modal.arn
#       }]
#     })
#   }
# }

# resource "aws_iam_role" "open_modal_states" {
#   description = "Slackbot open modal states"
#   name        = "${local.region}-slackbot-open-modal-states"

#   assume_role_policy = jsonencode({
#     Version = "2012-10-17"
#     Statement = [{
#       Sid       = "AssumeEvents"
#       Effect    = "Allow"
#       Action    = "sts:AssumeRole"
#       Principal = { Service = ["states.amazonaws.com"] }
#     }]
#   })

#   inline_policy {
#     name = "access"
#     policy = jsonencode({
#       Version = "2012-10-17"
#       Statement = [{
#         Sid      = "InvokeFunction"
#         Effect   = "Allow"
#         Action   = "lambda:InvokeFunction"
#         Resource = module.slackbot.functions.slack_api.arn
#       }]
#     })
#   }
# }

# resource "aws_cloudwatch_event_rule" "open_modal" {
#   description    = "Slackbot open modal"
#   event_bus_name = "slackbot"
#   name           = "slackbot-open-modal"

#   event_pattern = jsonencode({
#     source      = ["block_actions"]
#     detail-type = ["open_modal"]
#   })
# }

# resource "aws_cloudwatch_event_target" "open_modal" {
#   arn            = aws_sfn_state_machine.open_modal.arn
#   event_bus_name = aws_cloudwatch_event_rule.open_modal.event_bus_name
#   role_arn       = aws_iam_role.open_modal_events.arn
#   rule           = aws_cloudwatch_event_rule.open_modal.name
#   target_id      = aws_sfn_state_machine.open_modal.name
# }

# resource "aws_sfn_state_machine" "open_modal" {
#   name     = "slackbot-open-modal"
#   role_arn = aws_iam_role.open_modal_states.arn

#   definition = jsonencode({
#     StartAt = "GetView"
#     States = {
#       GetView = {
#         Type      = "Pass"
#         Next      = "EncodeView"
#         InputPath = "$.detail"
#         Parameters = {
#           "trigger_id.$" = "$.trigger_id"
#           view = {
#             type   = "modal"
#             title  = { type : "plain_text", text : "My App" }
#             submit = { type : "plain_text", text : "Submit" }
#             close  = { type : "plain_text", text : "Cancel" }
#             blocks = [{
#               block_id = "slack_oauth_scopes"
#               type     = "input"
#               label    = { type : "plain_text", text : "Slack OAuth Scopes" }
#               element = {
#                 type        = "external_select"
#                 action_id   = "slack_oauth_scopes"
#                 placeholder = { type : "plain_text", text : "Select scope" }
#               }
#             }]
#           }
#         }
#       }
#       EncodeView = {
#         Type = "Pass"
#         Next = "PublishView"
#         Parameters = {
#           "trigger_id.$" = "$.trigger_id"
#           "view.$"       = "States.JsonToString($.view)"
#         }
#       }
#       PublishView = {
#         Type     = "Task"
#         Resource = module.slackbot.functions.slack_api.arn
#         End      = true
#         Parameters = {
#           method   = "POST"
#           url      = "https://slack.com/api/views.open"
#           headers  = { content-type = "application/json; charset=utf-8" }
#           "data.$" = "States.JsonToString($)"
#         }
#       }
#     }
#   })
# }
