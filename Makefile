PREFIX ?= /usr/local

.PHONY: doctor install uninstall test

doctor:
	./scripts/doctor.sh

install:
	./scripts/install.sh

uninstall:
	./scripts/uninstall.sh

test:
	./scripts/test-camera.sh

