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

variable "secret" {
  type = object({
    SLACK_API_TOKEN           = string
    SLACK_OAUTH_CLIENT_ID     = string
    SLACK_OAUTH_CLIENT_SECRET = string
    SLACK_OAUTH_SCOPE         = string
    SLACK_OAUTH_USER_SCOPE    = string
    SLACK_OAUTH_ERROR_URI     = string
    SLACK_OAUTH_REDIRECT_URI  = string
    SLACK_OAUTH_SUCCESS_URI   = string
    SLACK_SIGNING_SECRET      = string
    SLACK_SIGNING_VERSION     = string
  })
}

###############
#   REGIONS   #
###############

# module "eu-west-2" {
#   providers = { aws = aws.eu-west-2 }
#   source    = "./region"
#   domain    = var.domain
#   secret    = var.secret
# }

module "us-east-1" {
  providers = { aws = aws.us-east-1 }
  source    = "./region"
  domain    = var.domain
  secret    = var.secret
}

# module "us-west-2" {
#   providers = { aws = aws.us-west-2 }
#   source    = "./region"
#   domain    = var.domain
#   secret    = var.secret
# }
