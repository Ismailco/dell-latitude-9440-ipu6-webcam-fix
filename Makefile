PREFIX ?= /usr/local

.PHONY: bootstrap doctor install uninstall test

bootstrap:
	./scripts/bootstrap-arch.sh

doctor:
	./scripts/doctor.sh

install:
	./scripts/install.sh

uninstall:
	./scripts/uninstall.sh

test:
	./scripts/test-camera.sh
