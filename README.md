# Scenario Asset Example

Reference repository for onboarding an **OpenSCENARIO Scenario** simulation asset into the [ENVITED-X Dataspace](https://envited-x.net). Use it as a template for your own scenario assets.

All assets conform to [EVES-003](https://ascs-ev.github.io/EVES/EVES-003/eves-003.html).

## Prerequisites

| Tool | Version | Notes |
|------|---------|-------|
| Python | ≥ 3.10 | `python3 --version` |
| Git | ≥ 2.34 | with LFS support (`git lfs install`) |
| Make | any | GNU Make recommended |
| Node.js | ≥ 18 | needed for Markdown linting (`npx markdownlint-cli2`) |
| Podman *(optional)* | ≥ 4.0 | only for `make wizard` |

**macOS:** `brew install python git git-lfs make`

**Ubuntu/Debian:** `sudo apt-get install python3-full python3-venv git git-lfs make`

**Windows:** install [Python](https://python.org/downloads), [Git for Windows](https://git-scm.com) (includes Git Bash + Make). Use Git Bash or PowerShell. For Podman: [Podman Desktop](https://podman-desktop.io).

## Quick Start

```bash
# Clone with submodules
git clone --recurse-submodules https://github.com/ASCS-eV/scenario-asset-example.git
cd scenario-asset-example

# Setup environment
make setup

# Generate asset from input blueprint
make generate

# Validate generated asset
make validate
```

## Asset Creation Flow

### Input → Output

```text
generated/input/                          generated/output/<asset-name>/
├── input_manifest.json    ──┐            ├── manifest_reference.json
├── *.xosc (scenario)        │  make      ├── simulation-data/
├── *.xosc (catalogs)        ├──────→     │   └── *.xosc
├── impression-01.png        │ generate   ├── metadata/
├── docs / readme            │            │   └── scenario_instance.json
└── LICENSE                ──┘            ├── media/
                                          ├── documentation/
                                          ├── validation-reports/
                                          └── <CID>.zip
```

### Two Creation Paths

| | Automated (default) | Wizard-assisted |
|---|---|---|
| **Command** | `make generate` | `make wizard` → `make generate` |
| **How** | Pipeline auto-extracts metadata from `.xosc` + input manifest | SHACL-driven web UI enriches metadata interactively |
| **User action** | Place files in `generated/input/`, run one command | Start wizard at `http://localhost:4200`, fill forms, generate |
| **Best for** | CI/CD, batch processing, reproducible builds | First-time users, complex metadata, manual enrichment |

> **Note:** `make wizard` requires **Podman** and is currently optional/experimental. The wizard may not yet support all asset types — see [sl-5-8-asset-tools](https://github.com/openMSL/sl-5-8-asset-tools) for upstream status.

## Available Make Targets

| Command | Description |
|---------|-------------|
| `make setup` | Create venv, install all dependencies (incl. QC tools) |
| `make generate` | Run full pipeline: `.xosc` → complete asset + zip |
| `make generate clean` | Remove `generated/output/` (preserves input blueprint) |
| `make validate` | Validate generated asset JSON-LD against SHACL shapes |
| `make lint` | Lint everything (JSON-LD validation + Markdown) |
| `make lint-md` | Lint Markdown files only |
| `make format` | Auto-fix Markdown lint issues |
| `make wizard` | Start SD Creation Wizard (requires Podman) |
| `make wizard stop` | Stop wizard containers |
| `make clean` | Remove build artifacts, caches, generated output |
| `make clean all` | Full reset (+ remove venv) |
| `make help` | Show all available commands |

### Debug Logging

```bash
SL58_LOG_MODE=debug make generate
```

### Deterministic Mode (Reproducible Output)

```bash
SL58_DETERMINISTIC=1 make generate
```

Same input files produce identical UUIDs, timestamps, and CID.

## Repository Structure

```text
scenario-asset-example/
├── generated/
│   ├── input/                      ← Pipeline inputs (tracked in git)
│   │   ├── input_manifest.json     ← JSON-LD manifest describing inputs
│   │   ├── *.xosc                  ← OpenSCENARIO files
│   │   ├── *.png                   ← Preview images
│   │   ├── *_readme.txt            ← Documentation
│   │   └── LICENSE                 ← Asset license
│   └── output/                     ← Pipeline output (gitignored)
├── submodules/
│   ├── sl-5-8-asset-tools/         ← Asset creation pipeline
│   │   └── submodules/
│   │       └── ontology-management-base/  ← SHACL + ontologies
│   └── EVES/                       ← EVES specification
├── Makefile                        ← Central command center
├── .pre-commit-config.yaml         ← Pre-commit hooks
├── .github/
│   ├── workflows/release.yml       ← CI/CD pipeline
│   └── copilot-instructions.md     ← AI agent instructions
└── README.md
```

## Metadata & Gaia-X

The pipeline automatically adds [Gaia-X Trust Framework](https://gaia-x.eu/) vocabulary to every generated asset:

- `gx:name`, `gx:license`, `gx:copyrightOwnedBy`, `gx:resourcePolicy`
- These live in closed GX-compliant nodes inside `metadata/scenario_instance.json`
- Domain-specific properties (scenario type, format version, content) use open ENVITED-X wrapper shapes

Users don't need to understand Gaia-X — the pipeline handles compliance automatically.

## Option B — Manual Pipeline (Without Make)

```bash
# Setup
python3 -m venv .venv
source .venv/bin/activate
pip install -r submodules/sl-5-8-asset-tools/requirements.txt
pip install -e submodules/sl-5-8-asset-tools/submodules/ontology-management-base

# Prepare input (converts input_manifest.json to uploadedFiles.json)
python3 scripts/convert_manifest.py generated/input/input_manifest.json

# Generate
cd submodules/sl-5-8-asset-tools && \
python3 -X frozen_modules=off -m asset_extraction.main \
    ../../generated/input/uploadedFiles.json \
    -config configs \
    -out ../../generated/output
```

## FAQ

### How do I create my own Scenario asset?

1. Fork this repository
2. Replace files in `generated/input/` with your `.xosc` scenario, catalogs, images, and docs
3. Update `generated/input/input_manifest.json` to list your files
4. Run `make generate && make validate`
5. Tag a release (`git tag v1.0.0 && git push --tags`) to trigger CI

### Which access roles exist?

| Role | Description |
|------|-------------|
| `isOwner` | Full access — can download the asset |
| `isRegistered` | Access to certain files but no download |
| `isPublic` | Viewing rights to metadata and previews |

### Which SHACL shapes validate scenario metadata?

The [Scenario Ontology](https://github.com/ASCS-eV/ontology-management-base/blob/main/scenario/) from ontology-management-base. Shapes are loaded offline from the `submodules/sl-5-8-asset-tools/submodules/ontology-management-base/` submodule — no internet required for validation.

### How do I enable debug logging?

```bash
SL58_LOG_MODE=debug make generate
```

Shows full subprocess command lines, stdout/stderr, and tracebacks.

### How do I fix stale QC checker packages?

```bash
make clean all
make setup
```

## Release Workflow

The GitHub Actions workflow triggers on version tags (`v*.*.*`):

1. Checks out repository with LFS and recursive submodules
2. Runs `make setup && make generate && make validate`
3. Uploads the pipeline-generated CID-named `.zip` as a GitHub release artifact via `softprops/action-gh-release@v2`

## License

[MPL-2.0](LICENSE)
