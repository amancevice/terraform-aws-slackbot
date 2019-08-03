runtime := nodejs10.x
stages  := build test
shells  := $(foreach stage,$(stages),shell@$(stage))
build   := $(shell git describe --tags --always)

terraform_version := 0.12.6

.PHONY: all clean $(stages) $(shells)

all: package-lock.json package.zip

.docker:
	mkdir -p $@

.docker/$(build)@test: .docker/$(build)@build
.docker/$(build)@%: | .docker
	docker build \
	--build-arg RUNTIME=$(runtime) \
	--build-arg TERRAFORM_VERSION=$(terraform_version) \
	--iidfile $@ \
	--tag amancevice/slackbot:$(build)-$* \
	--target $* .

package-lock.json package.zip: .docker/$(build)@build
	docker run --rm -w /var/task/ $(shell cat $<) cat $@ > $@

clean:
	-docker image rm -f $(shell awk {print} .docker/*)
	-rm -rf .docker

$(stages): %: .docker/$(build)@%

$(shells): shell@%: .docker/$(build)@%
	docker run --rm -it $(shell cat $<) /bin/bash
