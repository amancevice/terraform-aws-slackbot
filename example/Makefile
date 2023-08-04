# AWS_REGION ?= $(shell aws ec2 describe-regions | jq -r '.Regions[].RegionName' | sort | fzf --no-info --reverse)
LOG_GROUP  ?= $(shell aws logs describe-log-groups | jq -r '.logGroups[].logGroupName' | fzf --no-info --reverse)


validate:
	terraform fmt -check
	terraform init -backend=false
	AWS_REGION=us-east-1 terraform validate

logs:
	aws logs tail --follow $(LOG_GROUP)

apply: | .terraform
	terraform apply

.PHONY: logs validate apply

.terraform:
	terraform init
