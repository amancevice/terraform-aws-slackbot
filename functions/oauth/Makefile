all: test

build: .venv

clean:
	-pipenv remove
	-rm -f Pipfile.lock

ipython: .venv
	PYTHONPATH=src pipenv run ipython

lock: clean build

test: .venv
	pipenv run ruff check src test
	PYTHONPATH=src pipenv run pytest

.PHONY: all build clean lock test

Pipfile.lock: Pipfile | .venv
	pipenv lock
	touch $@

.venv:
	mkdir -p $@
	pipenv install --dev
	touch $@
