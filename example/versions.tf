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
