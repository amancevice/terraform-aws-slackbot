FUNCTION = $(shell find * -type d -depth 0 | fzf --no-info --reverse)

build clean test:
	make -C authorizer $@
	make -C oauth $@
	make -C transformer $@

ipython:
	make -C $(FUNCTION) $@

.PHONY: build clean ipython test
