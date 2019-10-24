runtime   := nodejs10.x
stages    := build test
terraform := latest
build     := $(shell git describe --tags --always)
shells    := $(foreach stage,$(stages),shell@$(stage))


.PHONY: all clean $(stages) $(shells)

all: node_modules package-lock.json package.zip

.docker:
	mkdir -p $@

.docker/$(build)@test: .docker/$(build)@build
.docker/$(build)@%: | .docker
	docker build \
	--build-arg RUNTIME=$(runtime) \
	--build-arg TERRAFORM=$(terraform) \
	--iidfile $@ \
	--tag amancevice/slackbot:$(build)-$* \
	--target $* .

node_modules:
	npm install

package-lock.json package.zip: .docker/$(build)@build
	docker run --rm $(shell cat $<) cat $@ > $@

clean:
	-docker image rm -f $(shell awk {print} .docker/*)
	-rm -rf .docker node_modules

$(stages): %: .docker/$(build)@%

$(shells): shell@%: .docker/$(build)@%
	docker run --rm -it $(shell cat $<) /bin/bash
