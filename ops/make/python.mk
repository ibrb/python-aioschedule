# Celery/RabbitMQ settings
RABBITMQ_USERNAME ?= rabbitmq
RABBITMQ_PASSWORD ?= rabbitmq
RABBITMQ_PORT ?= 5672
RABBITMQ_VHOST ?= /

# Add the appropriate files to DEPSCHECKSUMFILES so that the CI rebuilds
# the environment if any dependency has changed.
DEPSCHECKSUMFILES += $(PYPI_METADATA_FILE)
ifneq ($(wildcard $(PYTHON_REQUIREMENTS)),)
DEPSCHECKSUMFILES += $(PYTHON_REQUIREMENTS)
endif
ifeq ($(PROJECT_KIND), application)
UNIMATRIX_SETTINGS_MODULE ?= $(PYTHON_PKG_NAME).runtime.settings
UNIMATRIX_BOOT_MODULE ?= $(PYTHON_PKG_NAME).runtime.boot
endif

# Command-definitions and parameters
cmd.console ?= $(PYTHON)
cmd.check-package = $(PYTHON) setup.py check
ifneq ($(wildcard $(PYTHON_REQUIREMENTS)),)
cmd.check-requirements-cve = $(PYTHON) -m safety check -r $(PYTHON_REQUIREMENTS)
endif
cmd.check-requirements-outdated = $(PYTHON) -c "from piprot.piprot import piprot; piprot()" -o
cmd.dist = $(PYTHON) setup.py sdist
cmd.distclean = rm -rf ./dist && rm -rf *.egg.info
cmd.flake8 = $(PYTHON) -m flake8
cmd.htmlclean ?= rm -rf $(HTML_DOCUMENT_ROOT)
cmd.lint-exceptions ?= $(PYTHON) -m pylint --disable=all --enable=W0704,W0702,E0701,E0702,E0703,E0704,E0710,E0711,E0712,E1603,E1604,W0150,W0623,W0703,W0705,W0706,W0711,W0715 $(python.lint.packages)
cmd.lint-nodebug ?= $(cmd.flake8) --ignore=all --select=T001,T002,T003,T004 $(python.lint.packages)
cmd.lint-security ?= $(PYTHON) -m bandit
ifneq ($(wildcard .bandit.yml),)
cmd.lint-security += -c .bandit.yml
endif
cmd.lint-security += -r $(or $(BANDIT_DIRS), $(python.lint.packages))
cmd.lint.import-order ?= $(PYTHON) -m pylint --disable=all --enable=C0413 $(python.lint.packages)
cmd.lint.unused ?= $(PYTHON) -m pylint --disable=all --enable=W0611,W0612 $(python.lint.packages)
cmd.lint.line-length ?= $(PYTHON) -m pylint --disable=all --enable=C0301 $(python.lint.packages)
cmd.lint.trailing-whitespace ?= $(PYTHON) -m pylint --disable=all --enable=C0303 $(python.lint.packages)
cmd.localinstall ?= $(PIP_INSTALL) --target $(PYTHON_RUNTIME_LIBS) .[all]
cmd.publish = $(cmd.twine) upload dist/*
cmd.runtests = $(PYTHON) -m pytest -v
cmd.runtests += --cov-report term-missing:skip-covered
cmd.runtests += --cov=$(or $(cmd.test.cover-package), $(PYTHON_PKG_NAME))
cmd.runtests += --cov-append
ifdef test.coverage.$(TEST_STAGE)
cmd.runtests += --cov-fail-under=$(test.coverage.$(TEST_STAGE))
endif
cmd.runtests += $(PYTEST_ARGS)
cmd.testcoverage = $(PYTHON) -m coverage combine .coverage-*
cmd.testcoverage += && $(PYTHON) -m coverage report -m --skip-covered --show-missing
ifdef TEST_MIN_COVERAGE
cmd.testcoverage += --fail-under $(TEST_MIN_COVERAGE)
endif
ifdef test.coverage
cmd.testcoverage += --fail-under $(test.coverage)
endif
ifdef CI_JOB_ID
cmd.testcoverage += && $(PYTHON) -m coverage html -d $(HTML_COVERAGE_DIR)
endif
cmd.twine = $(PYTHON) -m twine
ifndef cmd.test.path
ifeq ($(PROJECT_SCOPE), namespaced)
cmd.runtests += $(shell find $(CURDIR)/tests | grep test_$(TEST_STAGE)_.*\.py$$)
else
cmd.runtests += $(shell find $(CURDIR)/tests | grep test_$(TEST_STAGE)_.*\.py$$)
endif
else
cmd.runtests += $(shell find $(CURDIR)/$(cmd.test.path) | grep test_$(TEST_STAGE)_.*\.py$$)
endif
cmd.watch ?= fswatch -o $(PYTHON_PKG_NAME) | xargs -n1 -I{} $(MAKE) test-unit
docker.build.args += --build-arg HTTP_WSGI_MODULE="$(HTTP_WSGI_MODULE)"
docker.build.args += --build-arg PYTHON_PKG_NAME="$(PYTHON_PKG_NAME)"
docker.build.args += --build-arg PYTHON_SUBPKG_NAME="$(PYTHON_SUBPKG_NAME)"
python.lint.packages ?= $(PYTHON_PKG_NAME)
seed.git.ignore = $(PYTHON_SEED_URL)/.gitignore


cleanpythondeps:
	@rm -rf $(PYTHON_DOCS_LIBS)
	@rm -rf $(PYTHON_INFRA_LIBS)
	@rm -rf $(PYTHON_RUNTIME_LIBS)
	@rm -rf $(PYTHON_TESTING_LIBS)


configure-python: pythonclean


eggclean:
	@rm -rf *.egg-info


python-install-%:
	@$(PIP) install $(*) --target $(PYTHON_RUNTIME_LIBS)
	@rm -rf $(PYTHON_REQUIREMENTS) && $(MAKE) $(PYTHON_REQUIREMENTS)


pythonclean:
	@find . -type f -name '*.py[co]' -delete -o -type d -name __pycache__ -delete


pythontestclean:
	@rm -rf .coverage
	@rm -rf .coverage-*
	@rm -rf .pytest_cache
	@rm -rf htmlcov


$(COVERAGE_CONFIG):
	@$(cmd.curl) $(PYTHON_SEED_URL)/.coveragerc > $(COVERAGE_CONFIG)
	@$(cmd.git) add $(COVERAGE_CONFIG)\
		&& $(cmd.git) commit -m "Add Coverage configuration"


$(PYTEST_ROOT_CONFTEST):
	@mkdir -p $(shell dirname $(PYTEST_ROOT_CONFTEST))
	@$(cmd.curl) $(PYTHON_SEED_URL)/pkg/conftest.py > $(PYTEST_ROOT_CONFTEST)
	@$(cmd.git) add $(PYTEST_ROOT_CONFTEST)\
		&& $(cmd.git) commit -m "Add root PyTest configuration"


$(PYTHON_BOOT_MODULE):
	@mkdir -p $(shell dirname $(PYTHON_BOOT_MODULE))
	@$(cmd.curl) $(PYTHON_SEED_URL)/pkg/runtime/boot.py > $(PYTHON_BOOT_MODULE)
	@$(cmd.git) add $(PYTHON_BOOT_MODULE) && $(cmd.git) commit -m "Add boot module"


$(PYTHON_INFRA_LIBS):
ifdef PYTHON_INFRA_PACKAGES
	@$(PIP_INSTALL) --target $(PYTHON_INFRA_LIBS) $(PYTHON_INFRA_PACKAGES)
endif


$(PYTHON_RUNTIME_LIBS): setup.py
ifeq ($(wildcard $(PYTHON_RUNTIME_LIBS)),)
	@$(cmd.localinstall)
ifeq ($(PROJECT_SCOPE), namespaced)
	@rm -rf $(PYTHON_RUNTIME_LIBS)/$(PYTHON_PKG_NAME)/ext/$(PYTHON_SUBPKG_NAME)
	@rm -rf $(PYTHON_RUNTIME_LIBS)/$(PYTHON_PKG_NAME).ext.$(PYTHON_SUBPKG_NAME)*
else
	@rm -rf $(PYTHON_RUNTIME_LIBS)/$(PYTHON_PKG_NAME)
	@rm -rf $(PYTHON_RUNTIME_LIBS)/$(PYTHON_PKG_NAME)-*
	@rm -rf $(PYTHON_RUNTIME_LIBS)/$(PYTHON_PKG_NAME).*
endif
endif


$(PYTHON_TESTING_LIBS):
ifeq ($(wildcard $(PYTHON_TESTING_LIBS)),)
	@$(PIP_INSTALL) --target $(PYTHON_TESTING_LIBS) $(PYTHON_TEST_PACKAGES)
endif


$(PYTHON_PKG_NAME):
	@mkdir -p $(PYTHON_PKG_NAME)


ifeq ($(PROJECT_SCOPE), namespaced)


$(PYTHON_SUBPKG_PATH):
	@mkdir -p $(PYTHON_SUBPKG_PATH)


$(PYTHON_SUBPKG_PATH)/__init__.py: $(PYTHON_SUBPKG_PATH)
	@touch $(PYTHON_SUBPKG_PATH)/__init__.py

bootstrap: $(PYTHON_SUBPKG_PATH)/__init__.py
bootstrap: $(PYTHON_SUBPKG_PATH)/package.json
endif


bootstrap-python:
	@touch $(PYTHON_PKG_WORKDIR)/__init__.py\
		&& $(cmd.git.add) $(PYTHON_PKG_WORKDIR)/__init__.py
ifdef PYTHON_RUNTIME_PACKAGES
	@$(PIP) install $(PYTHON_RUNTIME_PACKAGES)\
		--target $(PYTHON_RUNTIME_LIBS)
endif
ifeq ($(PROJECT_KIND), application)
	@# Create some default test cases for application boot, settings load etc.
	@mkdir -p $(PYTHON_PKG_WORKDIR)/app
	@mkdir -p $(PYTHON_PKG_WORKDIR)/infra
	@mkdir -p $(PYTHON_PKG_WORKDIR)/runtime/tests
	@touch $(PYTHON_PKG_WORKDIR)/app/__init__.py
	@touch $(PYTHON_PKG_WORKDIR)/infra/__init__.py
	@touch $(PYTHON_PKG_WORKDIR)/runtime/__init__.py
	@touch $(PYTHON_PKG_WORKDIR)/runtime/tests/__init__.py
	@$(cmd.curl) $(PYTHON_SEED_URL)/pkg/runtime/tests/test_unit_settings.py\
		> $(PYTHON_PKG_WORKDIR)/runtime/tests/test_unit_settings.py
	@$(cmd.curl) $(PYTHON_SEED_URL)/pkg/runtime/tests/test_system_boot.py\
		> $(PYTHON_PKG_WORKDIR)/runtime/tests/test_system_boot.py
	@$(cmd.git.add) -A $(PYTHON_PKG_WORKDIR)
else
	@mkdir -p $(PYTHON_PKG_WORKDIR)/tests
	@$(cmd.curl) $(PYTHON_SEED_URL)/pkg/tests/test_unit_noop.py\
		> $(PYTHON_PKG_WORKDIR)/tests/test_unit_noop.py
	@$(cmd.curl) $(PYTHON_SEED_URL)/pkg/tests/test_integration_noop.py\
		> $(PYTHON_PKG_WORKDIR)/tests/test_integration_noop.py
	@$(cmd.curl) $(PYTHON_SEED_URL)/pkg/tests/test_system_noop.py\
		> $(PYTHON_PKG_WORKDIR)/tests/test_system_noop.py
	@$(cmd.git.add) -A $(PYTHON_PKG_WORKDIR)/tests
endif


MANIFEST.in:
	@$(cmd.curl) $(PYTHON_SEED_URL)/MANIFEST.in.tpl\
		| sed 's|$$SEMVER_FILE|$(SEMVER_FILE)|g'\
		| sed 's|$$PYTHON_SETUPTOOLS_PKG_FINDER|$(PYTHON_SETUPTOOLS_PKG_FINDER)|g'\
		| sed 's|$$PYPI_METADATA_FILE|$(PYPI_METADATA_FILE)|g'\
		| sed 's|$$PYTHON_PKG_NAME|$(PYTHON_PKG_NAME)|g'\
		> MANIFEST.in
	@$(cmd.git.add) MANIFEST.in


setup.py: $(SEMVER_FILE) $(PYPI_METADATA_FILE) MANIFEST.in
ifeq ($(wildcard setup.py),)
	@$(cmd.curl) $(PYTHON_SEED_URL)/setup.py.tpl\
		| sed 's|$$SEMVER_FILE|$(SEMVER_FILE)|g'\
		| sed 's|$$PYTHON_REQUIREMENTS|$(PYTHON_REQUIREMENTS)|g'\
		| sed 's|$$PYTHON_SETUPTOOLS_PKG_FINDER|$(PYTHON_SETUPTOOLS_PKG_FINDER)|g'\
		| sed 's|$$PYTHON_QUALNAME|$(PYTHON_QUALNAME)|g'\
		| sed 's|$$PYPI_METADATA_FILE|$(PYPI_METADATA_FILE)|g'\
		> setup.py
	@$(cmd.git.add) setup.py
endif


$(HTML_COVERAGE_DIR):
	@mkdir -p $(HTML_COVERAGE_DIR)


$(PYPI_METADATA_FILE):
	@mkdir -p $$(dirname $(PYPI_METADATA_FILE))
	@$(cmd.curl) $(or $(seed.python.package), $(PYTHON_SEED_URL)/pkg/package.json)\
		> $(PYPI_METADATA_FILE)
	@$(cmd.git.add) $(PYPI_METADATA_FILE)


$(PYTHON_REQUIREMENTS):
	@$(PIP) freeze --path $(PYTHON_RUNTIME_LIBS) > $(PYTHON_REQUIREMENTS)


# Create the application settings module. The core Python include does not
# create the defaults - this is up to the specific implementation for a
# framework, such as Django or FastAPI.
ifeq ($(PROJECT_SCOPE), parent)
$(PYTHON_RUNTIME_PKG):
	@mkdir -p $(PYTHON_RUNTIME_PKG)
	@touch $(PYTHON_RUNTIME_PKG)/__init__.py
	@$(cmd.git) add $(PYTHON_RUNTIME_PKG)/__init__.py


$(PYTHON_SETTINGS_PKG): $(PYTHON_RUNTIME_PKG)
	@mkdir -p $(PYTHON_SETTINGS_PKG)


$(PYTHON_SETTINGS_PKG)/__init__.py:
	@$(MAKE) $(PYTHON_SETTINGS_PKG)/defaults.py
	@$(cmd.curl) $(PYTHON_SEED_URL)/pkg/runtime/settings/__init__.py\
		> $(PYTHON_SETTINGS_PKG)/__init__.py
	@$(cmd.git.add) -A $(PYTHON_SETTINGS_PKG)


$(PYTHON_SETTINGS_PKG)/defaults.py: $(PYTHON_SETTINGS_PKG)
	@echo "$(or $(app.settings.defaults.seed), $(error Set app.settings.defaults.seed))"
	@$(cmd.curl) $(app.settings.defaults.seed)\
		> $(PYTHON_SETTINGS_PKG)/defaults.py
	@$(cmd.git.add) $(PYTHON_SETTINGS_PKG)/*
endif


bootstrap: setup.py
bootstrap: bootstrap-python
bootstrap: $(COVERAGE_CONFIG)
bootstrap: $(SEMVER_FILE)
ifeq ($(PROJECT_KIND), application)
bootstrap: $(PYTEST_ROOT_CONFTEST)
bootstrap: $(PYTHON_BOOT_MODULE)
post-bootstrap: $(PYTHON_REQUIREMENTS)
endif
configure-python:
distclean: eggclean
ifdef PYTHON_INFRA_PACKAGES
depsinstall: $(PYTHON_INFRA_LIBS)
endif
depsinstall: $(PYTHON_RUNTIME_LIBS)
depsinstall: $(PYTHON_TESTING_LIBS)
docker-image: MANIFEST.in
docker-image: setup.py
docker-image: $(PYTHON_REQUIREMENTS)
env: depsinstall
depsclean: cleanpythondeps
envclean: cleanpythondeps
test: $(HTML_COVERAGE_DIR)
testclean: pythontestclean
testcoverage: $(HTML_COVERAGE_DIR)
ifndef CI_JOB_ID
test: $(PYTHON_RUNTIME_LIBS) $(PYTHON_TESTING_LIBS)
shell: $(PYTHON_RUNTIME_LIBS)
endif
