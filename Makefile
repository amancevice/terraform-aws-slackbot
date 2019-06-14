name    := slackbot
runtime := nodejs10.x
build   := $(shell git describe --tags --always)

.PHONY: all clean shell@% test

all: package-lock.json package.layer.zip

.docker:
	mkdir -p $@

.docker/$(build)@test: .docker/$(build)@build
.docker/$(build)@%: .dockerignore Dockerfile package.json | .docker
	docker build \
	--build-arg RUNTIME=$(runtime) \
	--iidfile $@ \
	--tag amancevice/$(name):$(build)-$* \
	--target $* .

package-lock.json package.layer.zip: .docker/$(build)@build
	docker run --rm -w /opt/nodejs/ $(shell cat $<) cat $@ > $@

test: all .docker/$(build)@test

clean:
	-docker image rm -f $(shell awk {print} .docker/*)
	-rm -rf .docker

shell@%: .docker/$(build)@%
	docker run --rm -it --entrypoint /bin/bash $(shell cat $<)
