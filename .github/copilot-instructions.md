# Scenario Asset Example — Copilot Instructions

## Project Overview

This is a **reference asset repository** for onboarding OpenSCENARIO scenario data into the ENVITED-X Dataspace. Users stage input files in `generated/input/`, then `make generate` runs the sl-5-8 pipeline to produce a complete, EVES-003-conformant asset in `generated/output/`.

Assets follow the [EVES-003](https://ascs-ev.github.io/EVES/EVES-003/eves-003.html) specification.

## Asset Creation Flow

### Input → Output

Users provide an OpenSCENARIO `.xosc` file and an `input_manifest.json` (plus optional images, docs, LICENSE) in `generated/input/`. The pipeline auto-extracts metadata, runs quality checks, and packages everything into an EVES-003 asset in `generated/output/`.

### Two Paths

1. **Automated (default):** `make generate` — pipeline auto-extracts all metadata from the `.xosc` and input manifest. No user interaction needed.
2. **Wizard-assisted (optional, experimental):** `make wizard` starts a SHACL-driven web UI (Podman containers, requires Podman ≥ 4.0) at `http://localhost:4200` for interactively enriching metadata. Users can also edit `input_manifest.json` and `metadata/scenario_instance.json` by hand as an alternative to the wizard.

### Gaia-X Integration

The pipeline adds [Gaia-X Trust Framework](https://gaia-x.eu/) vocabulary to every asset (`gx:name`, `gx:license`, `gx:copyrightOwnedBy`, `gx:resourcePolicy`) inside `metadata/scenario_instance.json`. These properties live in closed GX-compliant nodes, while domain-specific properties (scenario type, format version, content) go in open ENVITED-X wrapper shapes. Users don't need to understand Gaia-X — the pipeline handles compliance automatically.

## Repository Structure

- `generated/input/` — Staged pipeline inputs (manifest, `.xosc` files, media, docs)
- `generated/output/` — Pipeline output: complete EVES-003 asset ready for validation and release
- `submodules/sl-5-8-asset-tools/` — Asset creation and processing tools (git submodule from [openMSL/sl-5-8-asset-tools](https://github.com/openMSL/sl-5-8-asset-tools))
  - `submodules/ontology-management-base/` — Nested submodule: SHACL shapes, OWL ontologies, JSON-LD contexts, and Python validation tools (from [ASCS-eV/ontology-management-base](https://github.com/ASCS-eV/ontology-management-base))
- `submodules/EVES/` — The [EVES specification](https://ascs-ev.github.io/EVES/EVES-003/eves-003.html) defining Simulation Asset structure

## Setup and Validation

```bash
make setup
make validate
```

All commands are exposed via `make` targets — run `make help` for the full list.

## Linting (pre-commit hooks)

Configured in `.pre-commit-config.yaml` — all hooks delegate to `make` targets.

## Key Conventions

### Asset Structure (EVES-003)

Every asset must contain: `simulation-data/`, `metadata/`, `media/`, `documentation/`, and a `manifest_reference.json` at the root. Optional: `validation-reports/`.

### JSON-LD Metadata

- `manifest_reference.json` — Content registry linking all asset files with access roles (`isOwner`, `isRegistered`, `isPublic`) and categories (`isSimulationData`, `isMetadata`, `isMedia`, etc.)
- `metadata/scenario_instance.json` — Domain-specific metadata (format, content, quantity, quality, data source, georeference) conforming to the Scenario SHACL shapes from ontology-management-base

Both files use typed `@value`/`@type` pairs for literals and reference ontologies via `@context` prefixes like `scenario:`, `manifest:`, `envited-x:`, `georeference:`, `gx:`.

### Submodules

Two direct submodules:

- `submodules/sl-5-8-asset-tools` — Asset creation and processing tools (which contains `ontology-management-base` as a nested submodule)
- `submodules/EVES` — The [EVES specification](https://ascs-ev.github.io/EVES/EVES-003/eves-003.html) that defines the structure and requirements for Simulation Assets in the ENVITED-X Dataspace

After cloning, initialize with:

```bash
make setup
```

### Commits

This project uses [DCO sign-off](CONTRIBUTING.md). All commits require `Signed-off-by` — use `git commit -s`. Do **not** add `Co-authored-by: Copilot` trailers.

## Release Workflow

The GitHub Actions workflow (`.github/workflows/release.yml`) triggers on version tags (`v*.*.*`), runs `make setup && make generate && make validate`, and uploads the pipeline-generated CID-named `.zip` as a GitHub release artifact.
