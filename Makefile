# Makefile for RISC-V Doc Template
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
# This Makefile is designed to automate the process of building and packaging
# the Doc Template for RISC-V Extensions.

DATE ?= $(shell date +%Y-%m-%d)
DOCKER_RUN := docker run --rm -v ${PWD}:/build -w /build \
riscvintl/riscv-docs-base-container-image:latest

# DO NOT SPECIFY A VERSION OR REVMARK HERE! The revision version and mark
# (draft/release/etc) should be marked via the :revnumber: and :revremark: fields
# in the source document itself.
SRC_DIR := ./src
BUILD_DIR := build
HEADER_SOURCE := $(SRC_DIR)/docs-dev-guide.adoc

ASCIIDOCTOR_PDF := asciidoctor-pdf
ASCIIDOCTOR_HTML := asciidoctor
OPTIONS := --trace \
           -a compress \
           -a mathematical-format=svg \
           -a revdate=${DATE} \
           -a pdf-fontsdir=docs-resources/fonts \
           -a pdf-theme=docs-resources/themes/riscv-pdf.yml \
           -D $(BUILD_DIR) \
           --failure-level=WARNING
REQUIRES := --require=asciidoctor-bibtex \
            --require=asciidoctor-diagram \
            --require=asciidoctor-mathematical

.PHONY: all build clean build-container build-no-container

all: build

build:
	@echo "Checking if Docker is available..."
	@if command -v docker >/dev/null 2>&1 ; then \
		echo "Docker is available, building inside Docker container..."; \
		$(MAKE) build-container; \
	else \
		echo "Docker is not available, building without Docker..."; \
		$(MAKE) build-no-container; \
	fi

build-container:
	@echo "Starting build inside Docker container..."
	$(DOCKER_RUN) /bin/sh -c "$(ASCIIDOCTOR_PDF) $(OPTIONS) $(REQUIRES) $(HEADER_SOURCE)"
	$(DOCKER_RUN) /bin/sh -c "$(ASCIIDOCTOR_HTML) $(OPTIONS) $(REQUIRES) $(HEADER_SOURCE)"
	@echo "Build completed successfully inside Docker container."

build-no-container:
	@echo "Starting build..."
	$(ASCIIDOCTOR_PDF) $(OPTIONS) $(REQUIRES) $(HEADER_SOURCE)
	$(ASCIIDOCTOR_HTML) $(OPTIONS) $(REQUIRES) $(HEADER_SOURCE)
	@echo "Build completed successfully."

clean:
	@if command -v docker >/dev/null 2>&1 ; then \
		echo "Cleaning up generated files via Docker..."; \
		$(DOCKER_RUN) /bin/sh -c "rm -rf $(BUILD_DIR)"; \
	else \
		echo "Cleaning up generated files..."; \
		rm -rf $(BUILD_DIR); \
	fi
	@echo "Cleanup completed."
