FUNCTION = $(shell find * -type d -depth 0 | fzf --no-info --reverse)

build clean test:
	make -C http-authorizer $@
	make -C http-transformer $@
	make -C oauth $@

ipython:
	make -C $(FUNCTION) $@

.PHONY: build clean ipython test
