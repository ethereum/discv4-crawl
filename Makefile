SHELL := bash
.SHELLFLAGS := -eu -o pipefail -c
.ONESHELL:
MAKEFLAGS += --warn-undefined-variables
MAKEFLAGS += --no-builtin-rules


lint:
	golangci-lint run

lint-fix:
	golangci-lint run --fix

.PHONY: vendor
vendor:
	go mod tidy
	go mod vendor
	go mod download

build-dirs:
	@mkdir -p build

asdf-bootstrap:
	asdf plugin update --all
	asdf plugin-add golang https://github.com/kennyp/asdf-golang.git || true
	asdf plugin-add golangci-lint https://github.com/hypnoglow/asdf-golangci-lint.git || true
	asdf plugin-add ginkgo https://github.com/jimmidyson/asdf-ginkgo.git || true
	NODEJS_CHECK_SIGNATURES=no asdf install

.PHONY: docker
docker:
  # for multiple platform: --platform linux/amd64,linux/arm64
	docker buildx build -t core-harbor.us-east-2.codefi.network/staking/discv4-crawl . --load
