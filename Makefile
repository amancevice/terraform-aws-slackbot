runtime := nodejs10.x
name    := slackbot
build   := $(shell git describe --tags)

image   := amancevice/$(name)
iidfile := .docker/$(build)
digest   = $(shell cat $(iidfile))

$(name)-$(build).zip: main.tf outputs.tf variables.tf package.layer.zip | node_modules
	zip $@ $?

package.layer.zip: index.js package-lock.json
	docker run --rm $(digest) cat $@ > $@

package-lock.json: package.json | $(iidfile)
	docker run --rm -w /opt/nodejs/ $(digest) cat $@ > $@

node_modules: | $(iidfile)
	docker run --rm -w /opt/nodejs/ $(digest) tar czO $@ | tar xzf -

$(iidfile): package.json | .docker
	docker build \
	--build-arg RUNTIME=$(runtime) \
	--iidfile $@ \
	--tag $(image):$(build) .

.docker:
	mkdir -p $@

.PHONY: clean

shell: | $(iidfile)
	docker run --rm -it $(digest) /bin/bash

clean:
	docker image rm -f $(image) $(shell sed G .docker/*)
	rm -rf .docker $(name)*.zip node_modules
