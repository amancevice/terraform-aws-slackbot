FUNCTION = $(shell find * -type d -depth 0 | fzf --no-info --reverse)

build clean test:
	make -C receiver $@
	make -C responder $@
	make -C slack-api $@

ipython:
	make -C $(FUNCTION) $@

.PHONY: build clean ipython test
