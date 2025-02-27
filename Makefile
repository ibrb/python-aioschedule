###############################################################################
#
#		UNIMAKE MASTER MAKEFILE (PYTHON)
#
#
###############################################################################
ifneq ($(wildcard config.mk),)
include config.mk
endif
ifneq ($(wildcard local.mk),)
include local.mk
endif
APP_RUNDIR ?= .
APP_SECDIR ?= var/run/secrets
APP_PKIDIR ?= pki
APP_PKIDIR_SERVER ?= $(APP_PKIDIR)/server
APP_PKIDIR_PKCS ?= $(APP_PKIDIR)/pkcs
COVERAGE_CONFIG=.coveragerc
COVERAGE_FILE = .coverage-$(TEST_STAGE)
ifdef CI_JOB_ID
COVERAGE_FILE = .coverage-$(CI_JOB_ID)
endif
CURDIR ?= $(shell pwd)
DEBUG=1
DEPLOYMENT_ENV=local
DEPSCHECKSUMFILES += config.mk
DOCKER_BASE_TAG ?= $(PYTHON_VERSION)-$(OS_RELEASE_ID)$(OS_RELEASE_VERSION)
DOCKER_BASE_IMAGE ?= python:$(DOCKER_BASE_TAG)
HTML_COVERAGE_DIR=$(HTML_DOCUMENT_ROOT)/coverage
HTML_DOCUMENT_ROOT=public
MAKEFILE=Makefile
ifdef CI_JOB_ID
# It is assumed here that in a CI/CD pipeline environment, there is only one
# Python version installed.
PYTHON = python3
endif
ifndef PYTHON_VERSION
PYTHON_VERSION = 3.9
endif
PYTHON ?= python$(PYTHON_VERSION)
PIP ?= $(PYTHON) -m pip
PIP_INSTALL=$(PIP) install
PYTEST_ROOT_CONFTEST = $(PYTHON_PKG_WORKDIR)/conftest.py
PYTHONPATH=$(CURDIR):$(CURDIR)/$(PYTHON_RUNTIME_LIBS):$(CURDIR)/$(PYTHON_TESTING_LIBS):$(CURDIR)/.lib/python/docs:$(CURDIR)/$(PYTHON_INFRA_LIBS)
PYTHON_INFRA_LIBS=.lib/python/infra
PYTHON_PKG_NAME ?= $(error Define PYTHON_PKG_NAME in config.mk)
PYTHON_REQUIREMENTS ?= requirements.txt
PYTHON_RUNTIME_LIBS=.lib/python/runtime
PYTHON_RUNTIME_PACKAGES += 'unimatrix>=0.2.1' python-ioc
PYTHON_RUNTIME_PKG ?= $(PYTHON_PKG_WORKDIR)/runtime
PYTHON_SEED_URL=$(SEED_URL)/python
PYTHON_SHELL ?= $(PYTHON)
PYTHON_SUBPKG_DIR ?= $(PYTHON_PKG_NAME)/ext
PYTHON_SUBPKG_PATH=$(PYTHON_SUBPKG_DIR)/$(PYTHON_SUBPKG_NAME)
PYTHON_TEST_PACKAGES += bandit safety yamllint pylint twine sphinx
PYTHON_TEST_PACKAGES += pytest pytest-cov pytest-asyncio semver piprot doc8
PYTHON_TEST_PACKAGES += watchdog argh 'chardet<4,>=3.0.2'
PYTHON_TEST_PACKAGES += flake8 flake8-print
PYTHON_TESTING_LIBS=.lib/python/testing
PYTHON_WATCH = $(PYTHON) -c 'from watchdog.watchmedo import main; main()'
PYTHON_WATCH += auto-restart --directory=$(PYTHON_PKG_WORKDIR) --pattern=*.py --recursive
SECRET_KEY=0000000000000000000000000000000000000000000000000000000000000000
SEED_URL=https://gitlab.com/unimatrixone/seed/-/raw/master
SEMVER_FILE ?= VERSION
TWINE_USERNAME ?= $(PYPI_USERNAME)
TWINE_PASSWORD ?= $(PYPI_PASSWORD)
UNIMAKE_INCLUDE_DIR=ops/make
UNIMAKE_TEMPLATE_DIR=.lib/templates
UNIMAKE=$(PYTHON) -m unimake
ifneq ($(wildcard .git),)
GIT_REMOTE=$(shell git remote get-url origin)
GIT_COMMIT_HASH=$(shell git rev-parse --short HEAD | tr -d "\n")
VCS_COMMIT_HASH=$(GIT_COMMIT_HASH)
endif
ifneq ($(wildcard ./ops/make/*.mk),)
include ops/make/*.mk
endif
PYTHON ?= python3
OS_RELEASE_ID ?= alpine
OS_RELEASE_VERSION ?= 3.12
TEST_STAGE ?= any
export
build.alpine.packages += curl gcc g++ git libc-dev libffi-dev libressl-dev make
build.debian.packages += curl gcc g++ git libc-dev libffi-dev libssl-dev make
cmd.curl=curl --fail --silent -H 'Cache-Control: no-cache'
cmd.git=git
cmd.git.add=$(cmd.git) add
cmd.openssl = openssl
cmd.screen = screen -c screen.conf
cmd.semver=$(PYTHON) -c "import semver; semver.main()"
cmd.sh=bash
cmd.sha1sum=sha1sum
cmd.sha256sum=sha256sum
mk.configure += python-$(PROJECT_SCOPE)
os.alpine.pkg.install ?= apk add --no-cache
os.debian.pkg.install ?= apt-get install -y
os.alpine.pkg.update ?= apk update
os.debian.pkg.update ?= apt-get update -y
ifndef project.title
project.title = Enter a Project Title
endif
unimake.template.ctx += -v project_title=$(project_title)
vcs.defaults.mainline ?= origin/mainline
vcs.defaults.stable ?= origin/stable


# Block until the required infrastructure services are available.
awaitservices:
	@$(cmd.awaitservices)


bash:
	@PS1="env:  λ " $(cmd.sh)


# Bootstraps a project. The implementations in ./ops should add their targets
# as a dependency.
bootstrap:
	@$(MAKE) post-bootstrap
	@$(cmd.git.add) .
	@$(cmd.git) commit -m "Bootstrap project with Unimake"


# Check if the packaging mechanics are ok.
check-package:
	@$(cmd.check-package)


# Check if there are CVEs in the project dependencies.
check-requirements-cve:
	@$(cmd.check-requirements-cve)


# Check for outdated requirements/dependencies.
check-requirements-outdated:
	@$(cmd.check-requirements-outdated)


ci-runner-id:
	@echo $(OS_RELEASE_ID)$(OS_RELEASE_VERSION)


# Completely cleans the working tree.
clean: depsclean distclean envclean pkgclean docsclean htmlclean testclean destroyinfra
	@rm -rf .lib
ifneq ($(wildcard .git),)
	@$(cmd.git) clean -fdx
endif


# Ensures that all includes specified in mk.configure are present inthe
# ./ops/mk directory.
configure:
	@mkdir -p $(UNIMAKE_INCLUDE_DIR)
	@echo "Configuring $(mk.configure)"
	@$(MAKE) $(addprefix $(UNIMAKE_INCLUDE_DIR)/, $(addsuffix .mk, $(mk.configure)))


# Spawn an interactive interpreter if the language supports it.
console:
	@$(cmd.console)


# Create a CHECKSUMS file that contains a checksum of the source dependencies
# for this project. This file is used by the CI to determine if a testing
# environment should be rebuilt.
depschecksums:
ifdef DEPSCHECKSUMFILES
	@$(cmd.sha256sum) $(DEPSCHECKSUMFILES) > CHECKSUMS
else
	@touch CHECKSUMS
endif


# Build the documentation
documentation:
	@$(cmd.documentation)


# Destroys the local infrastructure used for development.
destroyinfra: killinfra
	@rm -rf ./var


# Remove documentation build artifacts.
docsclean:
	@$(cmd.docsclean)


# Remove dependencies from the source tree.
depsclean:
	@$(cmd.depsclean)


# Installs the project dependencies, relative to the current working
# directory.
depsinstall:


# Remove dependencies from the source tree and rebuild them or download from
# packaging services.
depsrebuild: depsclean
	@$(MAKE) depsinstall


# Remove artifacts created by packaging.
distclean:
	@$(cmd.distclean)


# Setup the local development environment.
env:


# Cleans the local development environment.
envclean:


# Remove HTML artifacts
htmlclean:
	@$(cmd.htmlclean)


# Kill the local infrastructure
killinfra:
	@$(cmd.killinfra)


# Run documentation linting tools.
lint-docs:
	@$(cmd.lint-docs)


# Lint exceptions
lint-exceptions:
	@$(cmd.lint-exceptions)


# Exit nonzero if the source code contains files that have an inappropriate
# import orde.
lint-import-order:
	@$(or $(cmd.lint.import-order), $(error Set cmd.lint.import-order))


# Exit nonzero if a maximum line length is exceeded by source code.
lint-line-length:
	@$(or $(cmd.lint.line-length), $(error Set cmd.lint.line-length))


# Ensures that there are no print statements or other unwanted calls.
lint-nodebug:
	@$(or $(cmd.lint-nodebug), $(error Set cmd.lint-nodebug))


lint-security:
	@$(or $(cmd.lint-security), $(error Set cmd.lint-security))


# Exit nonzero if there is trailing whitespace.
lint-trailing-whitespace:
	@$(or $(cmd.lint.trailing-whitespace), $(error Set cmd.lint.trailing-whitespace))


# Exit nonzero if the source code contains unused imports.
lint-unused:
	@$(or $(cmd.lint.unused), $(error Set cmd.lint.unused))


# Exit nonzero if any YAML file in the source tree violates the linting
# requirements.
lint-yaml:
	@$(PYTHON) -m yamllint .


# Ensures that database migrations are ran.
migrate:
	@$(cmd.migrate)


# Render database migrations
migrations:
	@$(cmd.migrations)


# Render database migrations for a specific module.
migrations-%:
	@$(MAKE) migrations MODULE_NAME=$(*)


# Rebuild the environment
rebuild: killinfra
	@$(MAKE) clean && $(MAKE) env


# Remove temporary files from the package source tree.
pkgclean:
	@$(cmd.pkgclean)


# Publish the package to a package registry.
publish: distclean
	@$(cmd.dist)
	@$(cmd.publish)


rebase:
	@$(cmd.git) remote update && $(cmd.git) rebase $(vcs.defaults.mainline)


# Resets the infrastructure and its storage to a pristine state.
resetinfra: destroyinfra
	@$(MAKE) runinfra DAEMONIZE_SERVICES=1


# Run all application components and infrastructure service dependencies
# in a single process. Kills existing infrastructure to run it in the
# foreground.
run: screen.conf killinfra
	@$(cmd.screen)


# For server applications, such as HTTP, starts the program and binds
# it to a well-known local port. If the application also exposes a
# websocket, then it is assumed that during development it is served
# by the same process as the main application.
runhttp: $(APP_PKIDIR_SERVER)/tls.crt
	@$(cmd.runhttp)


# Runs infrastructure services on the local machine.
runinfra:
	@$(cmd.runinfra)


# Runs the infrastructure services daemonized.
runinfra-daemon:
	@$(MAKE) runinfra DAEMONIZE_SERVICES=1


# Run a script
runscript:
ifdef path
	@$(PYTHON) $(path)
endif


# Run the worker.
runworker:
	@$(cmd.runworker)


# Run tests, excluding system tests.
runtests:
	@$(MAKE) test-unit test-integration
	@$(MAKE) testcoverage test.coverage=$(test.coverage.nonsystem)


# Print the current version.
semantic-version:
	@cat $(SEMVER_FILE)


# Clean artifacts created during tests.
testclean:


testcoverage:
	@$(cmd.testcoverage)


test-%:
	@$(MAKE) pkgclean
	@$(MAKE) test TEST_STAGE=$(*)


test: pkgclean
	@$(cmd.runtests)


testall: runinfra-daemon
	@$(MAKE) testclean
	@$(MAKE) -j3 test-unit test-integration test-system
	@$(MAKE) testcoverage


# Invoke when the bootstrap target finishes.
post-bootstrap:


# Updates the UniMake includes.
update:
	@$(cmd.curl) $(SEED_URL)/Makefile > $(MAKEFILE)
	@$(cmd.git.add) $(MAKEFILE)
	@rm -f $(addprefix $(UNIMAKE_INCLUDE_DIR)/, $(addsuffix .mk, $(mk.configure)))
	@$(MAKE) $(addprefix $(UNIMAKE_INCLUDE_DIR)/, $(addsuffix .mk, $(mk.configure)))
	@$(cmd.git.add) -u && $(cmd.git) commit -m "Update GNU Make includes"


# Watch source code for changes and run tests.
watch:
	@$(or $(cmd.watch), $(shell echo "make watch is not implemented."))


# Export environment variables
.env:
	@env | sort > .env


# Creates the Git ignore rules.
.gitignore:
	@$(cmd.curl) $(or $(seed.git.ignore), $(error Set seed.git.ignore))\
		> .gitignore
	@$(cmd.git.add) .gitignore && $(cmd.git) commit -m "Add Git ignore rules"


$(APP_PKIDIR):
	@mkdir -p $(APP_PKIDIR)


$(APP_PKIDIR_SERVER): $(APP_PKIDIR)
	@mkdir -p $(APP_PKIDIR_SERVER)


$(APP_PKIDIR_PKCS): $(APP_PKIDIR)
	@mkdir -p $(APP_PKIDIR_PKCS)


$(APP_PKIDIR_SERVER)/tls.crt: $(APP_PKIDIR_SERVER)
	@$(cmd.openssl) req -new -newkey rsa:2048 -days 365 -nodes -x509\
		-keyout $(APP_PKIDIR_SERVER)/tls.key -out $(APP_PKIDIR_SERVER)/tls.crt\
		-subj "/C=NL/ST=Zuid-Holland/L=Den Haag/O=Unimatrix One/CN=localhost"
	@$(cmd.git) add $(APP_PKIDIR_SERVER)/*\
		&& $(cmd.git) commit -m "Add local development TLS certificate and key"


$(APP_PKIDIR_PKCS)/noop.rsa: $(APP_PKIDIR_PKCS)
	@$(cmd.openssl) genrsa -out $(APP_PKIDIR_PKCS)/noop.rsa
	@$(cmd.git) add $(APP_PKIDIR_PKCS)/*\
		&& $(cmd.git) commit -m "Add local development private key"


$(APP_PKIDIR_PKCS)/noop.pub: $(APP_PKIDIR_PKCS)/noop.rsa
	@$(cmd.openssl) rsa -pubout -in $(APP_PKIDIR_PKCS)/noop.rsa\
		> $(APP_PKIDIR_PKCS)/noop.pub
	@$(cmd.git) add $(APP_PKIDIR_PKCS)/*\
		&& $(cmd.git) commit -m "Add local development public key"


# Provide the bump-major, bump-minor and bump-patch targets if
# SEMVER_FILE is defined.
ifdef SEMVER_FILE
bump-%:
	@$(cmd.semver) bump $(*) $$(cat $(SEMVER_FILE)) > $(SEMVER_FILE)
	@git add $(SEMVER_FILE) && git commit -m "Bump $(*) version"


$(SEMVER_FILE):
ifeq ($(wildcard $(SEMVER_FILE)),)
	@echo '0.0.1' | tr -d '\n' > $(SEMVER_FILE)
	@$(cmd.git.add) $(SEMVER_FILE)
endif

ifneq ($(wildcard $(SEMVER_FILE)),)
SEMVER_RELEASE=$(shell cat $(SEMVER_FILE))
endif
endif


# Fetch UniMake include.
$(UNIMAKE_INCLUDE_DIR)/%.mk:
	@echo "Updating $(UNIMAKE_INCLUDE_DIR)/$(*).mk"
	@$(cmd.curl) $(SEED_URL)/ops/$(*).mk > $(UNIMAKE_INCLUDE_DIR)/$(*).mk
	@$(MAKE) configure-$(*)
	@$(cmd.git.add) $(UNIMAKE_INCLUDE_DIR)/$(*).mk


bootstrap: .gitignore
configure:
lint: lint-unused lint-security lint-line-length lint-import-order lint-trailing-whitespace
prepush: lint testall
run: env
