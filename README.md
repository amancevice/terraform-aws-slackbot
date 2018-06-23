# AWS Slackbot

Slackbot endpoints backed by API Gateway + Lambda.

## Quickstart

Create a `main.tf` file with the following contents:

```terraform
# main.tf

provider "aws" {
  region = "<region-name>"
}

module "slackbot" {
  source                       = "amancevice/slackbot/aws"
  encrypted_verification_token = "<encrypted-slack-verification-token>"
}
```

In a terminal window, initialize the state:

```bash
terraform init
```

Then review & apply the changes

```bash
terraform apply
```
