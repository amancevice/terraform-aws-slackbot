REPO         := amancevice/$(shell basename $$PWD)
NODE_VERSION := 12

ENDPOINT = http://$$(REPO=$(REPO) docker-compose port lambda 8080)/2015-03-31/functions/function/invocations

.PHONY: clean clobber shell up validate zip

validate: package.zip | .terraform
	terraform fmt -check
	AWS_REGION=us-east-1 terraform validate

package.zip: package.iid package-lock.json
	docker run --rm --entrypoint cat $$(cat $<) $@ > $@

package-lock.json: package.iid
	docker run --rm --entrypoint cat $$(cat $<) $@ > $@

package.iid: index.js package.json Dockerfile
	docker build --build-arg NODE_VERSION=$(NODE_VERSION) --iidfile $@ --tag $(REPO) .

.terraform:
	terraform init

clean:
	docker image ls --quiet $(REPO) | uniq | xargs docker image rm --force

clobber: clean
	rm -rf package.iid

down:
	REPO=$(REPO) docker-compose down

shell: | up
	REPO=$(REPO) docker-compose exec lambda bash

up: package.iid
	REPO=$(REPO) docker-compose up --detach lambda
	@echo $(ENDPOINT)

zip: package.zip
