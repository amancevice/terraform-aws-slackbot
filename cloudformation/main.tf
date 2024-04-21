###########
#   AWS   #
###########

provider "aws" {
  default_tags {
    tags = {
      Name = var.name
    }
  }
}

##########
#   S3   #
##########

resource "aws_s3_object" "template" {
  bucket       = var.bucket
  key          = "cloudformation/slackbot/template.yml"
  content      = file("${path.module}/template.yml")
  content_type = "application/x-yaml"
}

######################
#   CLOUDFORMATION   #
######################

resource "aws_cloudformation_stack" "slackbot" {
  capabilities = ["CAPABILITY_IAM"]
  name         = var.name
  parameters   = var.parameters
  # template_url = "https://${aws_s3_object.template.bucket}.s3.amazonaws.com/${aws_s3_object.template.key}"
  template_body = aws_s3_object.template.content
}
