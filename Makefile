all: build validate

build clean ipython test:
	make -C functions $@

test: build

validate:
	terraform fmt -check
	make -C example $@

.PHONY: all build clean ipython test validate
