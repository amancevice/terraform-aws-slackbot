name    := slackbot
runtime := nodejs10.x
stages  := build test
shells  := $(foreach stage,$(stages),shell@$(stage))
build   := $(shell git describe --tags --always)
digest   = $(shell cat .docker/$(build)$(1))

.PHONY: all clean $(stages) $(shells)

all: package-lock.json package.zip

.docker:
	mkdir -p $@

.docker/$(build)@test: .docker/$(build)@build
.docker/$(build)@%: | .docker
	docker build \
	--build-arg RUNTIME=$(runtime) \
	--iidfile $@ \
	--tag amancevice/$(name):$(build)-$* \
	--target $* .

package-lock.json package.zip: build
	docker run --rm -w /var/task/ $(call digest,@$<) cat $@ > $@

clean:
	-docker image rm -f $(shell awk {print} .docker/*)
	-rm -rf .docker

$(stages): %: .docker/$(build)@%

$(shells) shell@%: %
	docker run --rm -it $(call digest,@$*) /bin/bash
