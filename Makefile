# Makefile for RISC-V Documentation Developer Guide
#
# This work is licensed under the Creative Commons Attribution-ShareAlike 4.0
# International License. To view a copy of this license, visit
# http://creativecommons.org/licenses/by-sa/4.0/ or send a letter to
# Creative Commons, PO Box 1866, Mountain View, CA 94042, USA.
#
# SPDX-License-Identifier: CC-BY-SA-4.0
#
# Description:
#
# This Makefile is designed to automate the process of building HTML and PDF
# documentation from AsciiDoc sources.

DATE ?= $(shell date +%Y-%m-%d)
DOCKER_BIN ?= docker
DOCKER_IMG := riscvintl/riscv-docs-base-container-image:latest
ifneq ($(SKIP_DOCKER),true)
	DOCKER_IS_PODMAN = \
		$(shell ! ${DOCKER_BIN} -v 2>&1 | grep podman >/dev/null ; echo $$?)
	ifeq "$(DOCKER_IS_PODMAN)" "1"
		DOCKER_VOL_SUFFIX = :z
	endif

	DOCKER_CMD := \
		${DOCKER_BIN} run --rm \
			-v ${PWD}:/build${DOCKER_VOL_SUFFIX} \
			-w /build \
			${DOCKER_IMG} \
			/bin/sh -c
	DOCKER_QUOTE := "
endif

SRC_DIR := src
BUILD_DIR := build
DOCS := docs-dev-guide.adoc
DOCS_PDF := $(DOCS:%.adoc=%.pdf)
DOCS_HTML := $(DOCS:%.adoc=%.html)

GIT_SHA_DOC := $(SRC_DIR)/git_sha.adoc

XTRA_ADOC_OPTS :=
ASCIIDOCTOR_PDF := asciidoctor-pdf
ASCIIDOCTOR_HTML := asciidoctor

OPTIONS := --trace \
           -a compress \
           -a mathematical-format=svg \
           -a pdf-fontsdir=docs-resources/fonts \
           -a pdf-theme=docs-resources/themes/riscv-pdf.yml \
           $(XTRA_ADOC_OPTS) \
           -D $(BUILD_DIR) \
           --failure-level=ERROR

REQUIRES := --require=asciidoctor-bibtex \
            --require=asciidoctor-diagram \
            --require=asciidoctor-lists \
            --require=asciidoctor-mathematical

DOCS_RESOURCES_CONFIG := docs-resources/global-config.adoc

.PHONY: all build clean build-container build-no-container build-docs check-docs-resources docker-pull-latest

all: build

check-docs-resources:
	@if [ ! -f "$(DOCS_RESOURCES_CONFIG)" ]; then \
		echo "Notice: docs-resources submodule is missing or uninitialized."; \
		if command -v git >/dev/null 2>&1 && [ -d .git ]; then \
			echo "Automatically initializing git submodules..."; \
			git submodule update --init --recursive || { \
				echo "ERROR: Failed to update git submodules automatically."; \
				echo "Please run manually: git submodule update --init --recursive"; \
				exit 1; \
			}; \
		else \
			echo "ERROR: Missing docs-resources directory and git is unavailable."; \
			echo "Please clone submodules or run: git submodule update --init --recursive"; \
			exit 1; \
		fi; \
	fi

# Generate git SHA for tracking commit in builds
$(GIT_SHA_DOC): .FORCE
	echo ":git_sha: $$(git describe --dirty --always)" > $@
.PHONY: .FORCE
.FORCE:	# To force the GIT_SHA_DOC to get rebuilt each time

vpath %.adoc $(SRC_DIR)

build-docs: check-docs-resources $(GIT_SHA_DOC) $(DOCS_PDF) $(DOCS_HTML)

%.pdf: %.adoc
	$(DOCKER_CMD) $(DOCKER_QUOTE) $(ASCIIDOCTOR_PDF) $(OPTIONS) $(REQUIRES) $< $(DOCKER_QUOTE)

%.html: %.adoc
	$(DOCKER_CMD) $(DOCKER_QUOTE) $(ASCIIDOCTOR_HTML) $(OPTIONS) $(REQUIRES) $< $(DOCKER_QUOTE)

build:
	@echo "Checking if Docker is available..."
	@if command -v ${DOCKER_BIN} >/dev/null 2>&1 ; then \
		echo "Docker is available, building inside Docker container..."; \
		$(MAKE) build-container; \
	else \
		echo "Docker is not available, building without Docker..."; \
		$(MAKE) build-no-container; \
	fi

build-container:
	@echo "Starting build inside Docker container..."
	$(MAKE) build-docs
	@echo "Build completed successfully inside Docker container."

build-no-container:
	@echo "Starting build..."
	$(MAKE) SKIP_DOCKER=true build-docs
	@echo "Build completed successfully."

# Update docker image to latest
docker-pull-latest:
	${DOCKER_BIN} pull ${DOCKER_IMG}

clean:
	@echo "Cleaning up generated files..."
	rm -rf $(BUILD_DIR)
	@echo "Cleanup completed."
