#!/usr/bin/env python3
"""Convert input_manifest.json (JSON-LD) to uploadedFiles.json (pipeline format).

Usage:
    python3 scripts/convert_manifest.py generated/input/input_manifest.json
    # writes uploadedFiles.json next to input_manifest.json
"""

import json
import pathlib
import sys


TYPE_MAP = {
    "isSimulationData": "Asset",
    "isMedia": "Image",
    "isDocumentation": "Document",
    "isLicense": "License",
}


def convert(manifest_path: pathlib.Path) -> pathlib.Path:
    """Read a JSON-LD input_manifest and produce uploadedFiles.json.

    Local filenames are resolved to absolute paths so the pipeline can
    locate them regardless of the working directory.
    """
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    input_dir = manifest_path.parent.resolve()

    artifacts = list(manifest.get("hasArtifacts", []))
    lic = manifest.get("hasLicense")
    if lic:
        artifacts.append(lic)

    uploaded = []
    for artifact in artifacts:
        meta = artifact.get("hasFileMetadata", {})
        filepath = meta.get("filePath", "")
        # Resolve local paths to absolute so the pipeline finds them
        if filepath and not filepath.startswith(("http://", "https://")):
            abs_path = input_dir / filepath
            if abs_path.exists():
                filepath = str(abs_path)
        category = (
            artifact.get("hasCategory", {}).get("@id", "").replace("envited-x:", "")
        )
        file_type = TYPE_MAP.get(category, "Document")
        entry = {"filename": filepath, "type": file_type, "category": category}
        did = manifest.get("@id")
        if did:
            entry["did"] = did
        uploaded.append(entry)

    out_path = manifest_path.parent / "uploadedFiles.json"
    out_path.write_text(json.dumps(uploaded, indent=2, ensure_ascii=False) + "\n")
    return out_path


def main() -> None:
    if len(sys.argv) < 2:
        print(f"Usage: {sys.argv[0]} <input_manifest.json>", file=sys.stderr)
        sys.exit(1)

    manifest_path = pathlib.Path(sys.argv[1])
    if not manifest_path.exists():
        sys.exit(f"[ERR] {manifest_path} not found. Stage input files first.")

    out = convert(manifest_path)
    print(f"[OK] Generated {out}")


if __name__ == "__main__":
    main()
