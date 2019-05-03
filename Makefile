.PHONY: default clean test init validate

default: package.zip

package-lock.json: package.json
	docker-compose run --rm build \
	npm install --package-lock-only

node_modules: package-lock.json
	docker-compose run --rm build \
	npm install --production

package.zip: node_modules
	docker-compose run --rm -T -w /opt build \
	zip -r - . > $@
	git add $@

clean:
	rm -rf .terraform node_modules

test:
	docker-compose run --rm test

.terraform:
	docker-compose run --rm terraform init

init: .terraform

validate: .terraform
	docker-compose run --rm terraform validate -check-variables=false
