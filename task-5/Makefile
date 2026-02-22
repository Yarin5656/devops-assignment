SERVICE ?=
TAG ?= local

.PHONY: lint test scan build ci-all

lint:
	@test -n "$(SERVICE)" || (echo "Usage: make lint SERVICE=<service-dir>" && exit 1)
	bash shared/ci/lint.sh "$(SERVICE)"

test:
	@test -n "$(SERVICE)" || (echo "Usage: make test SERVICE=<service-dir>" && exit 1)
	bash shared/ci/test.sh "$(SERVICE)"

scan:
	@test -n "$(SERVICE)" || (echo "Usage: make scan SERVICE=<service-dir>" && exit 1)
	bash shared/ci/scan.sh "$(SERVICE)"

build:
	@test -n "$(SERVICE)" || (echo "Usage: make build SERVICE=<service-dir> TAG=<tag>" && exit 1)
	bash shared/ci/build.sh "$(SERVICE)" "$(TAG)"

ci-all:
	bash shared/ci/lint.sh user-service
	bash shared/ci/lint.sh transaction-service
	bash shared/ci/lint.sh notification-service
	bash shared/ci/test.sh user-service
	bash shared/ci/test.sh transaction-service
	bash shared/ci/test.sh notification-service
