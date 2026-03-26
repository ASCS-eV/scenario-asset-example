# Makefile for scenario-asset-example
# Build command center for common development tasks

# Allow parent makefiles to override the venv path/tooling.
# NOTE: VENV must be a relative path — the root Makefile prefixes it with CURDIR
# when delegating to this submodule.
VENV ?= .venv

# Submodule path aliases (hide deep paths)
ASSET_TOOLS := submodules/sl-5-8-asset-tools
OMB         := $(ASSET_TOOLS)/submodules/ontology-management-base

# OS detection for cross-platform support (Windows vs Unix)
ifeq ($(OS),Windows_NT)
    SHELL            := sh
    VENV_BIN         := $(VENV)/Scripts
    PYTHON           ?= $(VENV_BIN)/python.exe
    BOOTSTRAP_PYTHON ?= python
    ACTIVATE_SCRIPT  := $(VENV_BIN)/activate
    ACTIVATE_HINT    := use the activation script under $(VENV_BIN) for your shell
else
    VENV_BIN         := $(VENV)/bin
    PYTHON           ?= $(VENV_BIN)/python3
    BOOTSTRAP_PYTHON ?= python3
    ACTIVATE_SCRIPT  := $(VENV_BIN)/activate
    ACTIVATE_HINT    := source $(ACTIVATE_SCRIPT)
endif

# Generated asset directory
GENERATED_DIR := generated
GEN_INPUT     := $(GENERATED_DIR)/input
GEN_OUTPUT    := $(GENERATED_DIR)/output
GEN_CONFIGS   := $(ASSET_TOOLS)/configs

# ── Subcommand support ───────────────────────────────────────────────
# Enables:  make generate clean,  make wizard stop
SUBCMD = $(word 2,$(MAKECMDGOALS))

# ── Guards ───────────────────────────────────────────────────────────
define check_dev_setup
	@"$(PYTHON)" -c "True" 2>/dev/null || { \
		echo ""; \
		echo "[ERR] Development environment not set up."; \
		echo "  Run:  make setup"; \
		echo ""; \
		exit 1; \
	}
endef

.PHONY: all setup install lint format validate generate clean wizard help

# Default target
all: lint validate

# ── Setup & Install ──────────────────────────────────────────────────

setup: $(ACTIVATE_SCRIPT)
	@echo "[INFO] Installing asset-tools pipeline dependencies..."
	@"$(PYTHON)" -m pip install -r "$(ASSET_TOOLS)/requirements.txt" --quiet
	@echo "[INFO] Installing ontology-management-base (editable)..."
	@"$(PYTHON)" -m pip install -e "$(OMB)" --quiet
	@echo "[INFO] Installing pre-commit..."
	@"$(PYTHON)" -m pip install pre-commit --quiet
	@echo "[INFO] Installing quality checker packages (--no-deps to avoid upstream lxml/numpy constraints)..."
	@"$(PYTHON)" -m pip install poetry-core --quiet 2>/dev/null || true
	@"$(PYTHON)" -m pip install --no-deps \
		"asam-qc-baselib@git+https://github.com/asam-ev/qc-baselib-py@v1.1.0" \
		"asam-qc-openscenarioxml@git+https://github.com/asam-ev/qc-openscenarioxml@v1.0.0"
	@"$(PYTHON)" -m pre_commit install --allow-missing-config >/dev/null 2>&1 || true
	@echo "[OK] Setup complete. Activate with: $(ACTIVATE_HINT)"

$(PYTHON):
	@echo "[INFO] Creating virtual environment at $(VENV)..."
	@"$(BOOTSTRAP_PYTHON)" -m venv "$(VENV)"
	@"$(PYTHON)" -m pip install --upgrade pip

$(ACTIVATE_SCRIPT): $(PYTHON)
	@touch "$(ACTIVATE_SCRIPT)"

install: setup
	@echo "[OK] Install complete"

# ── Lint & Format ────────────────────────────────────────────────────
# Root repo has no Python files -- lint validates JSON-LD asset data.

lint: validate lint-md

lint-md:
	@echo "[INFO] Linting Markdown..."
	@npx --yes markdownlint-cli2 "README.md" "CONTRIBUTING.md"
	@echo "[OK] Markdown lint passed"

format: format-md

format-md:
	@echo "[INFO] Formatting Markdown..."
	@npx --yes markdownlint-cli2 --fix "README.md" "CONTRIBUTING.md"
	@echo "[OK] Markdown format complete"

# ── Validate ─────────────────────────────────────────────────────────
# Validates JSON-LD files for every generated asset in the output directory.

validate:
	$(call check_dev_setup)
	@"$(PYTHON)" -c "\
import pathlib, sys; \
out = pathlib.Path('$(GEN_OUTPUT)'); \
dirs = sorted(d for d in out.iterdir() if d.is_dir()) if out.exists() else []; \
sys.exit('[SKIP] No generated asset found (run: make generate)') if not dirs else None; \
bad = [str(d) for d in dirs if not [p for p in [d / 'manifest_reference.json', d / 'metadata' / 'scenario_instance.json'] if p.exists()]]; \
sys.exit('[ERR] No manifest or metadata found in: ' + ', '.join(bad)) if bad else None; \
all_paths = [str(p) for d in dirs for p in [d / 'manifest_reference.json', d / 'metadata' / 'scenario_instance.json'] if p.exists()]; \
print(' '.join(all_paths)); \
" > .validate_paths 2>&1 && \
	"$(PYTHON)" -m src.tools.validators.validation_suite \
		--run check-data-conformance \
		--data-paths $$(cat .validate_paths) \
		--artifacts "$(OMB)/artifacts" && \
	rm -f .validate_paths && \
	echo "[OK] Validation complete" || \
	{ cat .validate_paths 2>/dev/null; rm -f .validate_paths; exit 1; }

# ── Generate (full pipeline) ─────────────────────────────────────────

generate:
ifeq ($(SUBCMD),clean)
	@echo "[INFO] Removing generated/output/ directory..."
	@"$(PYTHON)" -c "import shutil; shutil.rmtree('$(GEN_OUTPUT)', ignore_errors=True)"
	@echo "[OK] Generated output removed (input/ blueprint preserved)"
else
	$(call check_dev_setup)
	@echo "[INFO] Preparing pipeline input..."
	@"$(PYTHON)" scripts/convert_manifest.py "$(GEN_INPUT)/input_manifest.json"
	@echo "[INFO] Running asset extraction pipeline..."
	@cd "$(ASSET_TOOLS)" && "$(CURDIR)/$(PYTHON)" -X frozen_modules=off -m asset_extraction.main \
		"$(CURDIR)/$(GEN_INPUT)/uploadedFiles.json" \
		-config "$(CURDIR)/$(GEN_CONFIGS)" \
		-out "$(CURDIR)/$(GEN_OUTPUT)"
	@echo ""
	@echo "[OK] Asset generated in $(GEN_OUTPUT)/"
endif

# ── Wizard (SD Creation Wizard frontend + API) ───────────────────────

wizard:
	@echo "[INFO] SD Creation Wizard is not yet available for this asset type."
	@echo "  See: https://github.com/openMSL/sl-5-8-asset-tools for upstream status."

# ── Clean ────────────────────────────────────────────────────────────

clean:
ifneq ($(firstword $(MAKECMDGOALS)),generate)
ifeq ($(SUBCMD),all)
	@echo "[INFO] Cleaning everything..."
	@rm -rf build/ dist/ .pytest_cache/ .mypy_cache/ "$(GEN_OUTPUT)"
	@rm -rf *.egg-info
	@rm -f *.zip .validate_paths
	@rm -f "$(GEN_INPUT)/uploadedFiles.json"
	@echo "[INFO] Removing virtual environment..."
	@rm -rf "$(VENV)"
	@echo "[OK] Full clean complete -- run 'make setup' to reinitialise"
else
	@echo "[INFO] Cleaning..."
	@rm -rf build/ dist/ .pytest_cache/ .mypy_cache/ "$(GEN_OUTPUT)"
	@rm -rf *.egg-info
	@rm -f *.zip .validate_paths
	@rm -f "$(GEN_INPUT)/uploadedFiles.json"
	@echo "[OK] Cleaned"
endif
else
	@:
endif

# ── Help ─────────────────────────────────────────────────────────────

help:
	@echo "scenario-asset-example -- Available Commands"
	@echo ""
	@echo "  make setup                   Create venv and install all dependencies (incl. QC tools)"
	@echo "  make install                 Install packages"
	@echo ""
	@echo "  make generate                Run full pipeline: .xosc -> generated/ asset + zip"
	@echo "  make generate clean          Remove generated/output/ directory"
	@echo ""
	@echo "  make lint                    Lint (validates asset JSON-LD + Markdown)"
	@echo "  make lint-md                 Lint Markdown files only"
	@echo "  make format                  Auto-fix Markdown lint issues"
	@echo "  make validate                Validate generated/output/ asset against SHACL"
	@echo ""
	@echo "  make clean                   Remove all build artifacts, caches, and generated/"
	@echo "  make clean all               Clean + remove venv (full reset)"
	@echo ""
	@echo "Debug logging:"
	@echo "  SL58_LOG_MODE=debug make generate"
	@echo "  Shows full subprocess command lines, stdout/stderr, and tracebacks."
	@echo ""
	@echo "Deterministic mode (reproducible output):"
	@echo "  SL58_DETERMINISTIC=1 make generate"
	@echo "  Same input files produce identical UUIDs, timestamps, and CID."

# ── Catch-all for subcommand arguments ───────────────────────────────
ifneq ($(filter setup generate clean install,$(firstword $(MAKECMDGOALS))),)
%:
	@:
endif
