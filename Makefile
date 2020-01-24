RUNTIME   := nodejs12.x
STAGES    := build test
TERRAFORM := latest
CLEANS    := $(foreach STAGE,$(STAGES),clean@$(STAGE))
IMAGES    := $(foreach STAGE,$(STAGES),image@$(STAGE))
SHELLS    := $(foreach STAGE,$(STAGES),shell@$(STAGE))
BUILD     := $(shell git describe --tags --always)
TIMESTAMP := $(shell date +%s)

.PHONY: default clean clobber test $(CLEANS) $(IMAGES) $(SHELLS)

default: node_modules package-lock.json package.zip image@test

.docker:
	mkdir -p $@

.docker/$(BUILD)-%: | .docker
	docker build \
	--build-arg RUNTIME=$(RUNTIME) \
	--build-arg TERRAFORM=$(TERRAFORM) \
	--iidfile $@@$(TIMESTAMP) \
	--tag amancevice/slackbot:$(BUILD)-$* \
	--target $* \
	.
	cp $@@$(TIMESTAMP) $@

node_modules:
	npm install

package-lock.json package.zip: .docker/$(BUILD)-build
	docker run --rm --entrypoint cat $(shell cat $<) $@ > $@

clean@test: clean@build
clean:      clean@test

clobber:
	-awk {print} .docker/* 2> /dev/null | uniq | xargs docker image rm --force
	-rm -rf .docker node_modules

image@test: image@build
image:      image@test

$(CLEANS): clean@%:
	-rm .docker/$(BUILD)-$*

$(IMAGES): image@%: .docker/$(BUILD)-%

$(shells): shell@%: .docker/$(build)@%
	docker run --rm -it --entrypoint sh $(shell cat $<)
