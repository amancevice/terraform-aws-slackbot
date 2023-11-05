all: test

build: .venv

clean:
	pipenv --rm

ipython: .venv
	PYTHONPATH=src pipenv run ipython

test: .venv
	pipenv run black --check src test
	PYTHONPATH=src pipenv run pytest

.PHONY: all build clean test

.venv: Pipfile
	mkdir -p $@
	pipenv install --dev
	touch $@
