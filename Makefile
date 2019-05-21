runtime := nodejs10.x
image   := amancevice/slackbot
images   = $(shell docker image ls --filter reference=$(image) --quiet)

.PHONY: build test clean

package.layer.zip: package-lock.json
	docker run --rm $(image):build-$(runtime) \
	cat $@ > $@

package-lock.json: package.json
	docker run --rm $(image):build-$(runtime) \
	cat /opt/nodejs/$@ > $@

package.json: build

build:
	terraform fmt
	docker build \
	--build-arg RUNTIME=$(runtime) \
	--tag $(image):$@-$(runtime) \
	--target $@ .

test: package.layer.zip
	docker build \
	--build-arg RUNTIME=$(runtime) \
	--tag $(image):$(runtime) .

	docker run --rm \
	--env AWS_ACCESS_KEY_ID \
	--env AWS_DEFAULT_REGION \
	--env AWS_PROFILE \
	--env AWS_SECRET \
	--env AWS_SECRET_ACCESS_KEY \
	--env AWS_SNS_PREFIX \
	$(image):$(runtime) \
	index.handler '{"path":"/health","httpMethod":"GET"}'

clean:
	docker rmi -f $(images)
