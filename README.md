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
  source             = "amancevice/slackbot/aws"
  verification_token = "<slack-verification-token>"
}
```

_Note: this is not a secure way of storing your verification token. See the [example](./example) for more secure/detailed deployment._


In a terminal window, initialize the state:

```bash
terraform init
```

Then review & apply the changes

```bash
terraform apply
```
