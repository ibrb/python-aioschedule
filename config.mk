# The name of this Python package, or the parent package if this is a
# namespaced package.
PYTHON_PKG_NAME=aioschedule

# The subpackage name in a packaging namespace.
#PYTHON_SUBPKG_NAME = $(error Set PYTHON_SUBPKG_NAME in config.mk)

# Choose from 'application' or 'package'.
PROJECT_KIND=package

# Choose from 'parent' or 'namespaced'. If you are not sure, choose 'parent'.
# If PROJECT_SCOPE=namespaced, then PYTHON_SUBPKG_NAME must also be set.
PROJECT_SCOPE=parent

# The Python version to use.
PYTHON_VERSION = 3.11

# Tables to truncate when invoking `make dbtruncate`, separated by a space.
#RDBMS_TRUNCATE=

# Components to configure.
mk.configure += python python-package python-gitlab python-docs docker
mk.configure +=
test.coverage := 100

# User-defined
LOG_LEVEL=DEBUG
OS_RELEASE_ID ?= debian
OS_RELEASE_VERSION ?= 11
test.coverage.unit=100

ifdef CI_COMMIT_REF_NAME
BRANCH_NAME=$(CI_COMMIT_REF_NAME)
endif
DOCS_BASE_PATH="python/aioschedule"
DOCS_GS_BUCKET=unimatrix-docs
MINOR_VERSION=$(shell cut -d '.' -f 1,2 <<< "$$(cat VERSION)")
