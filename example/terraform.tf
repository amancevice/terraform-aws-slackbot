###########
#   AWS   #
###########

locals {
  tags = { Name = "slackbot" }
}

provider "aws" {
  alias  = "us-west-2"
  region = "us-west-2"
  default_tags { tags = local.tags }
}

provider "aws" {
  alias  = "us-east-1"
  region = "us-east-1"
  default_tags { tags = local.tags }
}

provider "aws" {
  alias  = "eu-west-2"
  region = "eu-west-2"
  default_tags { tags = local.tags }
}

#################
#   VARIABLES   #
#################

variable "domain" {
  type = string
}

variable "slack_signing_secret" {
  type      = string
  sensitive = true
}

variable "slack_client_id" {
  type = string
}

variable "slack_client_secret" {
  type      = string
  sensitive = true
}

variable "slack_scope" {
  type = string
}

variable "slack_user_scope" {
  type = string
}

variable "slack_error_uri" {
  type = string
}

variable "slack_success_uri" {
  type = string
}

variable "slack_token" {
  type = string
}

###############
#   REGIONS   #
###############

module "us-east-1" {
  providers            = { aws = aws.us-east-1 }
  source               = "./region"
  domain               = var.domain
  slack_signing_secret = var.slack_signing_secret
  slack_client_id      = var.slack_client_id
  slack_client_secret  = var.slack_client_secret
  slack_scope          = var.slack_scope
  slack_user_scope     = var.slack_user_scope
  slack_error_uri      = var.slack_error_uri
  slack_success_uri    = var.slack_success_uri
  slack_token          = var.slack_token
}
