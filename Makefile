# Project
runtime := nodejs10.x
name    := slackbot
release := $(shell git describe --tags)
build   := $(release)-$(runtime)

# Docker Build
image := amancevice/$(name)
digest = $(shell cat build/$(build).build)

package.layer.zip: package-lock.json | build/$(build).build
	docker run --rm --entrypoint cat $(digest) $@ > $@

package-lock.json: package.json | build/$(build).build
	docker run --rm --entrypoint cat $(digest) /opt/nodejs/$@ > $@

build/$(build).build: index.js | build
	docker build \
	--build-arg RUNTIME=$(runtime) \
	--tag $(image):$(build) .
	docker image inspect --format '{{.Id}}' $(image):$(build) > $@

build:
	mkdir -p $@

.PHONY: test clean

test:
	docker run --rm \
	--env AWS_ACCESS_KEY_ID \
	--env AWS_DEFAULT_REGION \
	--env AWS_PROFILE \
	--env AWS_SECRET \
	--env AWS_SECRET_ACCESS_KEY \
	--env AWS_SNS_PREFIX \
	$(digest) \
	index.handler '{"path":"/health","httpMethod":"GET"}'

clean:
	rm -rf build
	docker rmi -f $(image):$(build)
