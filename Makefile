REPO      := amancevice/slackbot
RUNTIME   := nodejs12.x
STAGES    := zip dev test
TERRAFORM := latest

.PHONY: default clean clobber test $(STAGES)

default: package-lock.json package.zip test

.docker:
	mkdir -p $@

.docker/zip: package.json *.tf
.docker/dev: .docker/zip
.docker/test: .docker/dev
.docker/%: | .docker
	docker build \
	--build-arg RUNTIME=$(RUNTIME) \
	--build-arg TERRAFORM=$(TERRAFORM) \
	--iidfile $@ \
	--tag $(REPO):$* \
	--target $* \
	.

package-lock.json package.zip: .docker/zip
	docker run --rm --entrypoint cat $$(cat $<) $@ > $@

clean:
	rm -rf .docker

clobber: clean
	docker image ls $(REPO) --quiet | uniq | xargs docker image rm --force

$(STAGES): %: .docker/%
