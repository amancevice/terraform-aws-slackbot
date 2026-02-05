all: test

build: .venv

clean:
	pipenv --rm

ipython: .venv
	PYTHONPATH=src pipenv run ipython

test: .venv
	pipenv run ruff check src test
	PYTHONPATH=src pipenv run pytest

.PHONY: all build clean test

Pipfile.lock: Pipfile | .venv
	pipenv lock
	touch $@

.venv:
	mkdir -p $@
	pipenv install --dev
	touch $@
