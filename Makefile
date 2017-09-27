MAKEFLAGS  += --no-builtin-rules
.SUFFIXES:
.SECONDARY:
.DELETE_ON_ERROR:

# app specific naming and options
DOCKER_REGISTRY        ?= quay.io
DOCKER_IMAGE_REPO      ?= johnt337
UNIT                   ?= amazon-ssm-agent
UID                    ?= $(shell id -u)
USER                   ?= $(shell id -n)
VERSION                ?= $(shell cat version)
PROJECT_URL            ?= https://github.com/johnt337/${UNIT}/

# version arguments
GOLANG_VERSION         ?= 1.8.3-alpine3.6

# docker login
DOCKER_CONFIG          ?= .docker

# build time arguments
SRC_REPO_OWNER         ?= aws
SRC_REPO               ?= ${SRC_REPO_OWNER}/${UNIT}
SRC                    ?= github.com/${SRC_REPO}
SRC_VERSION            ?= 2.0.922.0
SRC_DIR                ?= /go/src/${SRC}
BIN_DIR                ?= /usr/local/amazon/bin
LOG_DIR                ?= /var/log/amazon/ssm
CONF_DIR               ?= /etc/amazon/ssm
REPO_INFO              ?= .repo.json

all: help

help:
	@echo "Usage: make <target>"
	@echo " "
	@echo "  where <target> is one of:"
	@echo "    - help               - display this help message"
	@echo "    - all/<package>      - build binary, image, flatten, and push (choices: ${UNIT})"
	@echo "    - bin                - build amazon-ssm-agent binary for packaging"
	@echo "    - bin/<package>      - build binary for specified package (choices: ${UNIT})"
	@echo "    - download           - download the src for compilation"
	@echo "    - get-release-info   - download src repo version info  (choices: 'latest' or release 'tag')"
	@echo "    - gen-systemd-unit   - render systemd unit file"
	@echo "    - image              - bundle container image for all package(s)"
	@echo "    - image/<package>    - bundle container image for specified package (choices: ${UNIT})"
	@echo "    - lint               - lint dockerfile based on the rules defined in linter.yml for all package(s)"
	@echo "    - lint /<package>    - lint dockerfile for specified package (choices: ${UNIT})"
	@echo "    - push               - push container image(s) for all package(s) to registry"
	@echo "    - push/<package>     - push container image for specified package to registry (choices: ${UNIT})"
	@echo "    - clean              - clean temp files, etc. for all packages"
	@echo "    - clean/<package>    - clean temp files, etc. for specified package (choices: ${UNIT})"
	@exit 0

all/%:
	$(MAKE) get-release-info
	$(MAKE) download
	$(MAKE) bin/$*
	$(MAKE) lint/$*
	$(MAKE) image/$*
	$(MAKE) push/$*

get-release-info:
	@if [ "${SRC_VERSION}" = "latest" ]; \
	then \
	  curl --progress-bar -fL https://api.github.com/repos/${SRC_REPO}/releases/${SRC_VERSION} -o ${REPO_INFO}; \
	else \
	  curl --progress-bar -fL https://api.github.com/repos/${SRC_REPO}/releases/tags/${SRC_VERSION} -o ${REPO_INFO}; \
	fi

gen-systemd-unit:
	@docker run \
		--rm \
		-e BIN_DIR=${BIN_DIR} \
		-e CONF_DIR=${CONF_DIR} \
		-e DOCKER_REGISTRY=${DOCKER_REGISTRY} \
	 	-e DOCKER_IMAGE_REPO=${DOCKER_IMAGE_REPO} \
		-e UNIT=${UNIT} \
		-e TAG=$(shell jq -r '.tag_name' ${REPO_INFO}) \
	  -v ${PWD}:/workspace \
		-w /workspace \
		golang:${GOLANG_VERSION} \
		/bin/sh -c 'apk add --no-cache gettext && cat ${UNIT}.service.tmpl | envsubst > ${UNIT}.service'
	@echo "enable with: 'systemctl enable ${UNIT}.service'"

download: ${REPO_INFO}
	@if [ ! -d "${UNIT}" ]; \
	then \
	  mkdir ${UNIT}; \
	  curl --progress-bar -fL $(shell jq -r '.tarball_url' ${REPO_INFO}) | tar --strip-components=1 -xzf - -C ${UNIT}; \
	fi

bin/%: ${UNIT}
	docker run \
	  --rm \
	  -e SRC_DIR=${SRC_DIR} -e BIN_DIR=/stage${BIN_DIR} -e CONF_DIR=/stage${CONF_DIR} \
	  -w ${SRC_DIR} \
	  -v ${PWD}/stage${BIN_DIR}:/stage${BIN_DIR} \
	  -v ${PWD}/stage${CONF_DIR}:/stage${CONF_DIR} \
	  -v ${PWD}/${UNIT}:${SRC_DIR} \
	  golang:${GOLANG_VERSION} \
	  /bin/sh -c 'apk add --no-cache bash git make && make build-linux && install -m 500 bin/linux_amd64/* $$BIN_DIR/ && install -m 400 $$SRC_DIR/amazon-ssm-agent.json.template $$CONF_DIR/amazon-ssm-agent.json && install -m 400 $$SRC_DIR/seelog_unix.xml $$CONF_DIR/seelog.xml'

image/%:
	@echo "building image for ${DOCKER_REGISTRY}/${DOCKER_IMAGE_REPO}/$*:$(shell jq -r '.tag_name' ${REPO_INFO})";
	docker build \
    --squash \
    --force-rm \
		--build-arg DOCKERFILE_VERSION=${VERSION} \
		--build-arg VERSION=$(shell jq -r '.tag_name' ${REPO_INFO}) \
		--build-arg RELEASE=$(shell cat ${UNIT}/VERSION) \
		--build-arg PROJECT_URL=${PROJECT_URL} \
    -t ${DOCKER_REGISTRY}/${DOCKER_IMAGE_REPO}/$*:$(shell jq -r '.tag_name' ${REPO_INFO}) -f ${UNIT}.Dockerfile  .

image: image/${UNIT}

lint: lint/${UNIT}

lint/%:
	dockerfile_lint -f ${UNIT}.Dockerfile -r linter.yml -p

push/%:
	@echo "pushing image ${DOCKER_REGISTRY}/${DOCKER_IMAGE_REPO}/$*:$(shell jq -r '.tag_name' ${REPO_INFO})"
	@docker --config=${DOCKER_CONFIG} push ${DOCKER_REGISTRY}/${DOCKER_IMAGE_REPO}/$*:$(shell jq -r '.tag_name' ${REPO_INFO})
	@docker tag ${DOCKER_REGISTRY}/${DOCKER_IMAGE_REPO}/$*:$(shell jq -r '.tag_name' ${REPO_INFO}) ${DOCKER_REGISTRY}/${DOCKER_IMAGE_REPO}/$*:latest
	@docker --config=${DOCKER_CONFIG} push ${DOCKER_REGISTRY}/${DOCKER_IMAGE_REPO}/$*:latest

push: push/${UNIT}

clean/%:
	@echo "cleaning up $*"
	@docker rmi -f ${DOCKER_REGISTRY}/${DOCKER_IMAGE_REPO}/$*:$(shell jq -r '.tag_name' ${REPO_INFO})
	@rm -rf ./${UNIT} ./stage ${UNIT}.service ${REPO_INFO}

clean: clean/${UNIT}

.PHONY: all help image push
