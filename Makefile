SHELL := /bin/bash
.DEFAULT_GOAL := help

DIST_DIR ?= $(CURDIR)/dist
CHART_DIR ?= $(CURDIR)
TMPDIR ?= /tmp
HELM_REPO ?= $(CURDIR)/charts
LINT_CMD ?= ct lint --config=lint/ct.yaml --lint-conf lint/lintconf.yaml --chart-yaml-schema lint/chart_schema.yaml
PROJECT ?= github.com/zloeber/decendant-chart
CHART ?= $(shell basename "$(CURDIR)")
BIN_PATH := $(CURDIR)/.local/bin
APP_PATH := $(CURDIR)/.local/apps

cr := $(BIN_PATH)/cr

# Import githubtoken file if exists
SECRETS ?= $(CURDIR)/.secrets.env
ifneq (,$(wildcard $(SECRETS)))
include ${SECRETS}
export $(shell sed 's/=.*//' ${SECRETS})
endif

.PHONY: help
help: ## Help
	@grep --no-filename -E '^[a-zA-Z_%/-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'

test: lint unit-test ## lint and unit-test

lint: ## Run ct against chart
	@echo "== Linting Chart..."
	$(LINT_CMD)
	@echo "== Linting Finished"

unit-test: helm-unittest ## Execute Unit Testing
	@echo "== Unit Testing Chart..."
	@helm unittest --color --update-snapshot ./traefik
	@echo "== Unit Tests Finished..."

build: global-requirements dependency $(DIST_DIR) ## Generates an artefact containing the Helm Chart in the distribution directory
	@echo "== Building Chart..."
	@helm package $(CHART_DIR) --destination=$(DIST_DIR)
	@echo "== Building Finished"

dependency: ## Build dependencies
	@echo "== Building chart dependencies..."
	@helm dependency update
	@echo "== Building chart dependencies finished"

# Cleanup leftovers and distribution dir
clean:
	@rm -rf $(DIST_DIR)
	@rm -rf $(HELM_REPO)

$(DIST_DIR):
	@mkdir -p $(DIST_DIR)

## This directory is git-ignored for now,
## and should become a worktree on the branch gh-pages in the future
$(HELM_REPO):
	@mkdir -p $(HELM_REPO)

global-requirements:
	@echo "== Checking global requirements..."
	@command -v helm >/dev/null || ( echo "ERROR: Helm binary not found. Exiting." && exit 1)
	@echo "== Global requirements are met."

lint-requirements: global-requirements
	@echo "== Checking requirements for linting..."
	@command -v ct >/dev/null || ( echo "ERROR: ct binary not found. Exiting." && exit 1)
	@echo "== Requirements for linting are met."

helm-unittest: global-requirements
	@echo "== Checking that plugin helm-unittest is available..."
	@helm plugin list 2>/dev/null | grep unittest >/dev/null || helm plugin install https://github.com/rancher/helm-unittest --debug
	@echo "== plugin helm-unittest is ready"

.PHONY: show
show: ## Show env vars
	@echo "PROJECT: $(PROJECT)"
	@echo "CHART: $(CHART)"
	@echo "DIST_DIR: $(DIST_DIR)"
	@echo "CHART_DIR: $(CHART_DIR)"
	@echo "HELM_REPO: $(HELM_REPO)"
	@echo "LINT_CMD: $(LINT_CMD)"

.PHONY: .dep/githubapps
.dep/githubapps: ## Install githubapp (ghr-installer)
ifeq (,$(wildcard $(APP_PATH)/githubapp))
	@rm -rf $(APP_PATH)
	@mkdir -p $(APP_PATH)
	@git clone https://github.com/zloeber/ghr-installer $(APP_PATH)/githubapp
endif

.PHONY: .dep/cr
.dep/cr: ## Install cr
ifeq (,$(wildcard $(cr)))
	@$(MAKE) --no-print-directory -C $(APP_PATH)/githubapp auto helm/chart-releaser INSTALL_PATH=$(BIN_PATH) PACKAGE_EXE=cr
endif

.PHONY: deps
deps: .dep/githubapps .dep/cr ## Install general dependencies

.PHONY: cr/index
cr/index: deps ## create chart index
	$(cr) index --config .cr-config.yaml

.PHONY: cr/upload
cr/upload: deps ## create chart upload
	$(cr) upload --config .cr-config.yaml
