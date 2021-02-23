REPO := amancevice/$(shell basename $$PWD)

ENDPOINT = http://$$(REPO=$(REPO) docker-compose port lambda 8080)/2015-03-31/functions/function/invocations

all: validate

clean:
	REPO=$(REPO) docker-compose down
	rm -rf package.iid

clobber: clean
	REPO=$(REPO) docker-compose down --rmi all --volumes

down:
	REPO=$(REPO) docker-compose down

shell:
	docker run -it --rm --entrypoint bash $(REPO)

up: package.iid
	REPO=$(REPO) docker-compose up --detach lambda
	@echo $(ENDPOINT)

validate: package.zip .terraform.lock.hcl
	terraform fmt -check
	AWS_REGION=us-east-1 terraform validate

zip: package.zip

.PHONY: all clean clobber down shell up validate zip

package.zip: package.iid package-lock.json
	docker run --rm --entrypoint cat $(REPO) $@ > $@

package-lock.json: package.json | package.iid
	docker run --rm --entrypoint cat $(REPO) $@ > $@

package.iid: Dockerfile index.js package.json
	docker build --iidfile $@ --tag $(REPO) .

.terraform.lock.hcl:
	terraform init
