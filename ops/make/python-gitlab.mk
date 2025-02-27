GITLAB_DOCKERFILE ?= ops/gitlab/Dockerfile
GITLAB_RUNNER_IMAGE_TAG ?= $(GITLAB_RUNNER_IMAGE_URL)
CI_DOCKERFILE ?= $(GITLAB_DOCKERFILE)
DEPSCHECKSUMFILES += $(GITLAB_DOCKERFILE)
export

gitlab.alpine.packages += $(build.alpine.packages)
gitlab.debian.packages += $(build.debian.packages)
gitlab.pip.packages += $(PYTHON_TEST_PACKAGES)
gitlab.runner.image ?= $(DOCKER_BASE_REPO)/gitlab-runner/python:$(DOCKER_BASE_TAG)


gitlab-docker-tag:
	@echo -n $(DOCKER_BASE_TAG)


gitlab-docker-image: $(GITLAB_DOCKERFILE)
	@echo "Building GitLab runner image with base $(gitlab.runner.image)"
	@$(DOCKER) build -t $(GITLAB_RUNNER_IMAGE_URL)\
		-f $(CI_DOCKERFILE)\
		--build-arg BASE_IMAGE=$(gitlab.runner.image)\
		--build-arg OS_PKG_INSTALL="$(os.$(OS_RELEASE_ID).pkg.install)"\
		--build-arg OS_PKG_UPDATE="$(os.$(OS_RELEASE_ID).pkg.update)"\
		--build-arg OS_PACKAGES="$(gitlab.$(OS_RELEASE_ID).packages)"\
		--build-arg "PIP_PKG_INSTALL=$(shell echo $(gitlab.pip.packages)|sed -e 's|["'\'']||g')"\
		--build-arg PYTHON_SUBPKG_NAME=$(PYTHON_SUBPKG_NAME)\
		.
	@$(DOCKER) push $(GITLAB_RUNNER_IMAGE_URL)


.gitlab-ci.yml:
	@$(cmd.curl) $(or $(seed.gitlab.pipeline), $(error Define seed.gitlab.pipeline)) > .gitlab-ci.yml
	@$(cmd.git) add .gitlab-ci.yml


ops/gitlab:
	@mkdir -p ./ops/gitlab


ops/gitlab/defaults.yml: ops/gitlab
ifeq ($(wildcard ops/gitlab/defaults.yml),)
	@$(cmd.curl) $(PYTHON_SEED_URL)/ops/gitlab/defaults.yml > ./ops/gitlab/defaults.yml
	@$(cmd.git.add) ./ops/gitlab/defaults.yml
endif


ops/gitlab/user-defined.yml: ops/gitlab
ifeq ($(wildcard ops/gitlab/user-defined.yml),)
	@echo "---\nvariables: {}" > ./ops/gitlab/user-defined.yml
	@$(cmd.git.add) ./ops/gitlab/user-defined.yml
endif


ops/gitlab/variables.yml: ops/gitlab
ifeq ($(wildcard ops/gitlab/variables.yml),)
	@echo "---\nvariables: {}" > ./ops/gitlab/variables.yml
	@$(cmd.git.add) ./ops/gitlab/variables.yml
endif


update-python-gitlab:
	@rm -f ./ops/gitlab/defaults.yml
	@$(MAKE) ops/gitlab/defaults.yml


$(GITLAB_DOCKERFILE): ops/gitlab
	@$(cmd.curl) $(PYTHON_SEED_URL)/ops/gitlab/Dockerfile > $(GITLAB_DOCKERFILE)


configure-python-gitlab:


bootstrap-python-gitlab:
	@$(MAKE) ops/gitlab/defaults.yml
	@$(MAKE) ops/gitlab/variables.yml
	@$(MAKE) ops/gitlab/user-defined.yml
	@$(MAKE) .gitlab-ci.yml


.gitlab-ci.yml: ops/gitlab/defaults.yml
.gitlab-ci.yml: ops/gitlab/variables.yml
.gitlab-ci.yml: ops/gitlab/user-defined.yml
bootstrap: bootstrap-python-gitlab
depschecksums: $(GITLAB_DOCKERFILE)
update: update-python-gitlab
