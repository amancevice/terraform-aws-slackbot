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

variable "domain" { type = string }
variable "parameters" { type = map(string) }

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
  providers  = { aws = aws.us-east-1 }
  source     = "./region"
  domain     = var.domain
  parameters = var.parameters
}

# module "us-west-2" {
#   providers = { aws = aws.us-west-2 }
#   source    = "./region"
#   domain    = var.domain
#   secret    = var.secret
# }
