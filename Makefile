.NOTPARALLEL: release-verify
.PHONY: all lint compile test test-janet test-emacs test-fuzz test-e2e \
	protocol-warning-check protocol-inventory-check release-integrity \
	publication-verify release-artifact-smoke package clean \
	release-verify

JANET ?= janet
ELDEV ?= eldev
# Reuse Eldev's shared package-archive cache without forcing a network refresh.
# Missing cache entries are still fetched normally, so fresh CI remains valid while
# already-prepared developer machines can run the release gate offline.
ELDEV_FLAGS ?= -S '(setq eldev-global-cache-archive-contents-max-age nil)'
VERSION := $(shell sed -n 's/.*:version "\([^"]*\)".*/\1/p' project.janet)
DIST_DIR := dist

all: test

lint:
	@echo "Checking Janet release entrypoints parse and load..."
	@JANET_PATH="$${JANET_PATH}:$(CURDIR)" $(JANET) -e '(import slynet/init) (import slynet/cli) (print "Janet load lint passed")'
	@echo "Running Emacs byte-compiler and documentation linters..."
	$(ELDEV) $(ELDEV_FLAGS) lint doc re

compile:
	@echo "Byte-compiling Emacs package through Eldev..."
	$(ELDEV) $(ELDEV_FLAGS) compile

test: test-janet

test-janet:
	@echo "Running all SLYNET Janet tests..."
	JANET_PATH="$${JANET_PATH}:$(CURDIR)" $(JANET) test/run_tests.janet

test-emacs:
	@echo "Running SLYNET Emacs ERT tests through Eldev..."
	$(ELDEV) $(ELDEV_FLAGS) test --expect 81

test-fuzz:
	@echo "Running extended deterministic transport fuzzing..."
	SLYNET_FUZZ_CASES=10000 $(ELDEV) $(ELDEV_FLAGS) test \
		slynet-client-frame-parser-property-roundtrip-fragmentation \
		slynet-client-frame-parser-rejects-fuzzed-prefixes \
		slynet-client-rejects-invalid-utf8-and-recovers

test-e2e:
	@echo "Running repeated Emacs/Janet lifecycle verification..."
	@before=$$(pgrep -fc 'janet .*slynet/cli.janet.*--tcp' || true); \
	for run in 1 2 3; do \
		echo "E2E run $$run/3"; \
		$(ELDEV) $(ELDEV_FLAGS) test slynet-e2e-creates-mrepl-evals-and-closes-live-janet-server \
			slynet-e2e-repeated-sessions-remain-clean \
			slynet-start-server-reports-missing-executable; \
	done; \
	after=$$(pgrep -fc 'janet .*slynet/cli.janet.*--tcp' || true); \
	test "$$before" = "$$after" || { \
		echo "ERROR: leaked SLYNET server process (before=$$before after=$$after)"; \
		exit 1; \
	}

release-integrity:
	@echo "Checking release metadata and documented direct CLI startup..."
	python3 tools/release_integrity.py

publication-verify:
	@echo "Checking publication-only repository requirements..."
	python3 tools/release_integrity.py --require-remote

protocol-warning-check:
	@echo "Checking protocol warning policy..."
	JANET_PATH="$${JANET_PATH}:$(CURDIR)" $(JANET) tools/protocol_warning_policy.janet --check

protocol-inventory-check:
	@echo "Checking generated protocol inventory freshness..."
	@tmp=$$(mktemp); \
	trap 'rm -f "$$tmp"' EXIT; \
	SLYNET_PROTOCOL_INVENTORY_OUTPUT="$$tmp" JANET_PATH="$${JANET_PATH}:$(CURDIR)" \
		$(JANET) tools/protocol_inventory.janet; \
	cmp -s docs/generated/protocol-inventory.yml "$$tmp" || { \
		echo "ERROR: docs/generated/protocol-inventory.yml is stale; regenerate with janet tools/protocol_inventory.janet"; \
		diff -u docs/generated/protocol-inventory.yml "$$tmp" | head -n 120 || true; \
		exit 1; \
	}

package: clean
	@echo "Building release artifacts for $(VERSION)..."
	@mkdir -p $(DIST_DIR)/slynet-$(VERSION)
	@cp -R slynet bundle docs project.janet LICENSE README.md CHANGELOG.md \
		CONTRIBUTING.md ROADMAP.md SECURITY.md RELEASE_ANNOUNCEMENT.md \
		$(DIST_DIR)/slynet-$(VERSION)/
	@tar -C $(DIST_DIR) -czf $(DIST_DIR)/slynet-$(VERSION).tar.gz slynet-$(VERSION)
	$(ELDEV) $(ELDEV_FLAGS) package --output-dir $(DIST_DIR)

release-artifact-smoke: package
	@echo "Testing extracted Janet and Emacs artifacts together..."
	sh tools/release_artifact_smoke.sh

clean:
	@echo "Removing generated artifacts..."
	rm -rf $(DIST_DIR) .eldev
	find . -name '*.elc' -o -name '*.jimage' -o -name '*.o' | xargs -r rm -f

release-verify: clean release-integrity protocol-warning-check protocol-inventory-check \
	lint test-janet test-emacs test-fuzz compile test-e2e package \
	release-artifact-smoke
	@echo "Verifying release metadata..."
	@test -n "$(VERSION)"
	@grep -q '^;; Version: $(VERSION)$$' emacs/slynet.el
	@grep -q '^;; Version: $(VERSION)$$' emacs/slynet-client.el
	@grep -q '^## \[$(VERSION)\]' CHANGELOG.md
	@git diff --check
	@echo "Writing release evidence and artifact checksums..."
	@SLYNET_RELEASE_GATE_PASSED=1 python3 tools/release_evidence.py
	@echo "SLYNET $(VERSION) release verification passed. No tag or publish action performed."
