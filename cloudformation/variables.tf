#################
#   VARIABLES   #
#################

variable "bucket" {
  description = "S3 bucket name"
  type        = string
}

variable "name" {
  description = "CloudFormation stack name"
  type        = string
}

variable "parameters" {
  description = "CloudFormation stack parameters"
  type        = map(string)
}
