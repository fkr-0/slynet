.PHONY: all lint compile test test-janet test-emacs test-fuzz test-e2e package clean release-verify

JANET ?= janet
ELDEV ?= eldev
VERSION := $(shell sed -n 's/.*:version "\([^"]*\)".*/\1/p' project.janet)
DIST_DIR := dist

all: test

lint:
	@echo "Checking Janet release entrypoints parse and load..."
	@JANET_PATH="$${JANET_PATH}:$(CURDIR)" $(JANET) -e '(import slynet/init) (import slynet/cli) (print "Janet load lint passed")'
	@echo "Running Emacs byte-compiler and documentation linters..."
	$(ELDEV) lint doc re

compile:
	@echo "Byte-compiling Emacs package through Eldev..."
	$(ELDEV) compile

test: test-janet

test-janet:
	@echo "Running all SLYNET Janet tests..."
	JANET_PATH="$${JANET_PATH}:$(CURDIR)" $(JANET) test/run_tests.janet

test-emacs:
	@echo "Running SLYNET Emacs ERT tests through Eldev..."
	$(ELDEV) test --expect 81

test-fuzz:
	@echo "Running extended deterministic transport fuzzing..."
	SLYNET_FUZZ_CASES=10000 $(ELDEV) test \
		slynet-client-frame-parser-property-roundtrip-fragmentation \
		slynet-client-frame-parser-rejects-fuzzed-prefixes \
		slynet-client-rejects-invalid-utf8-and-recovers

test-e2e:
	@echo "Running repeated Emacs/Janet lifecycle verification..."
	@before=$$(pgrep -fc 'janet .*slynet/cli.janet.*--tcp' || true); \
	for run in 1 2 3; do \
		echo "E2E run $$run/3"; \
		$(ELDEV) test slynet-e2e-creates-mrepl-evals-and-closes-live-janet-server \
			slynet-e2e-repeated-sessions-remain-clean \
			slynet-start-server-reports-missing-executable; \
	done; \
	after=$$(pgrep -fc 'janet .*slynet/cli.janet.*--tcp' || true); \
	test "$$before" = "$$after" || { \
		echo "ERROR: leaked SLYNET server process (before=$$before after=$$after)"; \
		exit 1; \
	}

package: clean
	@echo "Building release artifacts for $(VERSION)..."
	@mkdir -p $(DIST_DIR)/slynet-$(VERSION)
	@cp -R slynet bundle project.janet LICENSE README.md CHANGELOG.md \
		$(DIST_DIR)/slynet-$(VERSION)/
	@tar -C $(DIST_DIR) -czf $(DIST_DIR)/slynet-$(VERSION).tar.gz slynet-$(VERSION)
	$(ELDEV) package --output-dir $(DIST_DIR)

clean:
	@echo "Removing generated artifacts..."
	rm -rf $(DIST_DIR) .eldev
	find . -name '*.elc' -o -name '*.jimage' -o -name '*.o' | xargs -r rm -f

release-verify: clean lint test-janet test-emacs test-fuzz compile test-e2e package
	@echo "Verifying release metadata..."
	@test -n "$(VERSION)"
	@grep -q '^;; Version: $(VERSION)$$' emacs/slynet.el
	@grep -q '^;; Version: $(VERSION)$$' emacs/slynet-client.el
	@grep -q '^## \[$(VERSION)\]' CHANGELOG.md
	@git diff --check
	@echo "SLYNET $(VERSION) release verification passed. No tag or publish action performed."
