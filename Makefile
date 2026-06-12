.PHONY: test clean lint core-tests contrib-tests all-tests test-emacs install

# Default Janet executable
JANET ?= janet

# Source directories
SLYNET_SRC_DIR = slynet/slynk_janet
CONTRIB_DIR = $(SLYNET_SRC_DIR)/contrib
TEST_DIR = test

# Source files
CORE_SRC_FILES = $(wildcard $(SLYNET_SRC_DIR)/*.janet)
CONTRIB_SRC_FILES = $(wildcard $(CONTRIB_DIR)/*.janet)

# Test files
CORE_TEST_FILE = $(TEST_DIR)/project_core_tests.janet
BASIC_TEST_FILE = $(TEST_DIR)/basic.janet
SERVER_TEST_FILE = $(TEST_DIR)/server_integration_tests.janet
CONTRIB_TEST_FILE = $(TEST_DIR)/contrib_tests.janet
TEST_RUNNER = $(TEST_DIR)/run_tests.janet

# Default target
all: test

# Run all tests
test: all-tests

# Run tests using the test runner
all-tests:
	@echo "Running all SLYNET tests..."
	$(JANET) $(TEST_RUNNER)

# Run only the core tests
core-tests:
	@echo "Running SLYNET core tests..."
	$(JANET) $(CORE_TEST_FILE)
	$(JANET) $(SERVER_TEST_FILE)
	$(JANET) $(BASIC_TEST_FILE)

# Run only the contrib module tests
contrib-tests:
	@echo "Running SLYNET contrib module tests..."
	$(JANET) $(CONTRIB_TEST_FILE)

# Run Emacs batch ERT tests through Eldev for package-aware load paths.
test-emacs:
	@if ! command -v eldev >/dev/null 2>&1; then \
		echo "SKIP: eldev not available; frontend ERT tests not run"; \
		exit 77; \
	fi
	@echo "Running SLYNET Emacs ERT tests through Eldev..."
	eldev test --expect 28

# Lint Janet code (using janet-format if available)
lint:
	@echo "Linting SLYNET code..."
	@which janet-format > /dev/null && find $(SLYNET_SRC_DIR) -name "*.janet" -exec janet-format -c {} \; || echo "janet-format not found, skipping lint"

# Clean build artifacts
clean:
	@echo "Cleaning up build artifacts..."
	@find . -name "*.jimage" -delete
	@find . -name "*.o" -delete

# Install SLYNET (WIP - to be implemented)
install:
	@echo "Installing SLYNET..."
	@echo "Note: Installation is not yet implemented."
