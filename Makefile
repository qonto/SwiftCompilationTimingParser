CURRENT_DIR := $(shell pwd)
.PHONY: list tests build build_and_run

list:
	@echo "\n==========================="
	@echo "==    Swift Scripting    =="
	@echo "==========================="
	@echo "==     Commands list     =="
	@echo "==========================="
	@echo "build"
	@echo "build_and_run"
	@echo "tests"

%:
	@:

args = `arg="$(filter-out $@,$(MAKECMDGOALS))" && echo $${arg:-${1}}`


tests:
	@echo "Starting tests..."
	@swift test

build:
	@swift build --configuration release
	@cp -f .build/release/SwiftCompilationTimingParser ./SwiftCompilationTimingParser

build_and_run:
	@make build
	@./SwiftCompilationTimingParser $(args)
