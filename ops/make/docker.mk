#DOCKER_IMAGE ?= alpine:3.12
DOCKER ?= docker
DOCKER_BASE_REPO ?= registry.gitlab.com/unimatrixone/docker/drone
ifdef DOCKER_CACHE_IMAGE
DOCKER_BUILD_ARGS += --cache-from $(DOCKER_CACHE_IMAGE)
endif
ifdef DOCKER_TARGET
DOCKER_BUILD_ARGS += --target $(DOCKER_TARGET)
endif
DOCKER_COMPOSE_ARGS =
ifeq ($(DAEMONIZE_SERVICES), 1)
DOCKER_COMPOSE_ARGS += -d
endif
DOCKER_IMAGE_BASE ?= $(DOCKER_BASE_REPO)/runtime/$(DOCKER_BASE_IMAGE)
DOCKER_IMAGE_BUILD ?= $(DOCKER_BASE_REPO)/build/$(DOCKER_BASE_IMAGE)
export

docker.build_dir ?= build/docker
docker.build.files +=
docker.dockerfile = Dockerfile
docker.entrypoint = bin/docker-entrypoint
docker.entrypoint.shebang.alpine = \#!/bin/ash
docker.entrypoint.shebang.debian = \#!/bin/bash
ifneq ($(wildcard docker-compose.yml),)
cmd.killinfra = docker-compose down
cmd.runinfra = docker-compose up $(DOCKER_COMPOSE_ARGS)
endif


.dockerignore:
ifneq ($(seed.docker.dockerignore),)
	@$(cmd.curl) $(seed.docker.dockerignore) > .dockerignore
	@$(cmd.git.add) .dockerignore
endif


# Invoked prior to building a Docker image.
docker-prebuild:
	@mkdir -p $(docker.build_dir)


docker-compose.yml:
ifneq ($(seed.docker.compose),)
	@$(cmd.curl) $(seed.docker.compose) > docker-compose.yml
endif


docker-image: $(docker.dockerfile) $(docker.entrypoint) docker-prebuild
	@echo "Building Docker image with build image $(DOCKER_IMAGE_BUILD)"
	@docker build $(DOCKER_BUILD_ARGS) -t $(DOCKER_IMAGE_NAME)\
		--build-arg BUILD_OS_PACKAGES="$(build.$(OS_RELEASE_ID).packages)"\
		--build-arg BUILDKIT_INLINE_CACHE=1\
		--build-arg DOCKER_BUILD_DIR="$(docker.build_dir)"\
		--build-arg DOCKER_IMAGE_BASE="$(DOCKER_IMAGE_BASE)"\
		--build-arg DOCKER_IMAGE_BUILD="$(DOCKER_IMAGE_BUILD)"\
		--build-arg RUNTIME_OS_PACKAGES="$(runtime.$(OS_RELEASE_ID).packages)"\
		--build-arg GIT_COMMIT_SHA="$(VCS_COMMIT_HASH)"\
		$(docker.build.args) .


docker-run%:
	@docker run -it $(addprefix -e , $(docker.run.env))\
		$(DOCKER_IMAGE_NAME) run$(*)


docker-push: docker-image
ifdef DOCKER_QUALNAME
	@docker tag $(DOCKER_IMAGE_NAME) $(DOCKER_QUALNAME)
	@docker push $(DOCKER_QUALNAME)
endif


$(docker.build_dir):
	@mkdir -p $(docker.build_dir)


$(docker.build_dir)/%: $(docker.build_dir)
	@mkdir -p $(docker.build_dir)/$(shell dirname $(*))
	@cp -R $(*) $(docker.build_dir)/$(*)


$(docker.dockerfile):
	@$(cmd.curl) $(or $(seed.docker.dockerfile), $(error seed.docker.dockerfile is not defined))\
		-o $(docker.dockerfile)


$(docker.entrypoint):
	@mkdir -p $(shell dirname $(docker.entrypoint))
	@$(cmd.curl) $(or $(seed.docker.entrypoint), $(error seed.docker.entrypoint is not defined))\
		-o $(docker.entrypoint)
	@chmod +x $(docker.entrypoint)
	@sed -i.bak "1s|.*|$(docker.entrypoint.shebang.$(OS_RELEASE_ID))|" $(docker.entrypoint)\
        && rm $(docker.entrypoint).bak


bootstrap: .dockerignore
clean: killinfra
configure-docker:
runinfra-daemon: docker-compose.yml
runinfra: docker-compose.yml
ifneq ($(wildcard etc),)
docker-prebuild: $(docker.build_dir)/etc
endif
ifneq ($(wildcard pki/pkcs),)
docker-prebuild: $(docker.build_dir)/pki/pkcs
endif
