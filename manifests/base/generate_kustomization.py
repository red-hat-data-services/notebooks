#!/usr/bin/env -S uv run --project=../..
"""Generate kustomization.yaml for manifests/base/.

Like the "99 bottles" or "12 days of Christmas" kata, the kustomization.yaml
is a highly repetitive file where each stanza follows the same template with
different parameters. This script expresses that pattern as code.

Usage:
    uv run manifests/base/generate_kustomization.py              # write kustomization.yaml
    uv run manifests/base/generate_kustomization.py --check      # verify existing file matches
    uv run manifests/base/generate_kustomization.py --stdout     # print to stdout instead
"""

from __future__ import annotations

import argparse
import sys
from dataclasses import dataclass
from pathlib import Path

from ntb.strings import process_template_with_indents

SCRIPT_DIR = Path(__file__).resolve().parent
OUTPUT_FILE = SCRIPT_DIR / "kustomization.yaml"


# ---------------------------------------------------------------------------
# Data model
# ---------------------------------------------------------------------------


@dataclass
class Workbench:
    """A workbench image: has N and N-1 tags, params + commit replacements."""

    param_key: str  # e.g. "odh-workbench-jupyter-minimal-cpu-py312-ubi9"
    imagestream: str  # e.g. "jupyter-minimal-notebook"
    resource_file: str  # e.g. "jupyter-minimal-notebook-imagestream.yaml"


@dataclass
class Runtime:
    """A runtime image: has only a single tag (N), params replacement only."""

    param_key: str  # e.g. "odh-pipeline-runtime-minimal-cpu-py312-ubi9"
    imagestream: str  # e.g. "runtime-minimal"
    resource_file: str  # e.g. "runtime-minimal-imagestream.yaml"


# Order matters -- it matches the existing kustomization.yaml exactly.
WORKBENCHES: list[Workbench] = [
    Workbench("odh-workbench-jupyter-minimal-cpu-py312-ubi9", "jupyter-minimal-notebook",
              "jupyter-minimal-notebook-imagestream.yaml"),
    Workbench("odh-workbench-jupyter-datascience-cpu-py312-ubi9", "jupyter-datascience-notebook",
              "jupyter-datascience-notebook-imagestream.yaml"),
    Workbench("odh-workbench-jupyter-minimal-cuda-py312-ubi9", "jupyter-minimal-gpu-notebook",
              "jupyter-minimal-gpu-notebook-imagestream.yaml"),
    Workbench("odh-workbench-jupyter-pytorch-cuda-py312-ubi9", "jupyter-pytorch-notebook",
              "jupyter-pytorch-notebook-imagestream.yaml"),
    Workbench("odh-workbench-jupyter-tensorflow-cuda-py312-ubi9", "jupyter-tensorflow-notebook",
              "jupyter-tensorflow-notebook-imagestream.yaml"),
    Workbench("odh-workbench-jupyter-trustyai-cpu-py312-ubi9", "jupyter-trustyai-notebook",
              "jupyter-trustyai-notebook-imagestream.yaml"),
    Workbench("odh-workbench-codeserver-datascience-cpu-py312-ubi9", "code-server-notebook",
              "code-server-notebook-imagestream.yaml"),
    Workbench("odh-workbench-rstudio-minimal-cpu-py312-c9s", "rstudio-notebook", "rstudio-notebook-imagestream.yaml"),
    Workbench("odh-workbench-rstudio-minimal-cuda-py312-c9s", "rstudio-gpu-notebook",
              "rstudio-gpu-notebook-imagestream.yaml"),
    Workbench("odh-workbench-jupyter-minimal-rocm-py312-ubi9", "jupyter-rocm-minimal",
              "jupyter-rocm-minimal-notebook-imagestream.yaml"),
    Workbench("odh-workbench-jupyter-pytorch-rocm-py312-ubi9", "jupyter-rocm-pytorch",
              "jupyter-rocm-pytorch-notebook-imagestream.yaml"),
    Workbench("odh-workbench-jupyter-tensorflow-rocm-py312-ubi9", "jupyter-rocm-tensorflow",
              "jupyter-rocm-tensorflow-notebook-imagestream.yaml"),
    Workbench("odh-workbench-jupyter-pytorch-llmcompressor-cuda-py312-ubi9", "jupyter-pytorch-llmcompressor",
              "jupyter-pytorch-llmcompressor-imagestream.yaml"),
]

# Resource file listing order (matches the existing kustomization.yaml resources section).
RUNTIME_RESOURCE_FILES: list[str] = [
    "runtime-datascience-imagestream.yaml",
    "runtime-minimal-imagestream.yaml",
    "runtime-pytorch-imagestream.yaml",
    "runtime-rocm-pytorch-imagestream.yaml",
    "runtime-rocm-tensorflow-imagestream.yaml",
    "runtime-tensorflow-imagestream.yaml",
    "runtime-pytorch-llmcompressor-imagestream.yaml",
]

# Replacement block order (matches the existing kustomization.yaml replacements section).
RUNTIMES: list[Runtime] = [
    Runtime("odh-pipeline-runtime-minimal-cpu-py312-ubi9", "runtime-minimal", "runtime-minimal-imagestream.yaml"),
    Runtime("odh-pipeline-runtime-datascience-cpu-py312-ubi9", "runtime-datascience",
            "runtime-datascience-imagestream.yaml"),
    Runtime("odh-pipeline-runtime-pytorch-cuda-py312-ubi9", "runtime-pytorch", "runtime-pytorch-imagestream.yaml"),
    Runtime("odh-pipeline-runtime-pytorch-rocm-py312-ubi9", "runtime-rocm-pytorch",
            "runtime-rocm-pytorch-imagestream.yaml"),
    Runtime("odh-pipeline-runtime-tensorflow-cuda-py312-ubi9", "runtime-tensorflow",
            "runtime-tensorflow-imagestream.yaml"),
    Runtime("odh-pipeline-runtime-tensorflow-rocm-py312-ubi9", "runtime-rocm-tensorflow",
            "runtime-rocm-tensorflow-imagestream.yaml"),
    Runtime("odh-pipeline-runtime-pytorch-llmcompressor-cuda-py312-ubi9", "runtime-pytorch-llmcompressor",
            "runtime-pytorch-llmcompressor-imagestream.yaml"),
]


# ---------------------------------------------------------------------------
# YAML generation
# ---------------------------------------------------------------------------


def _replacement_block(
    field_path_key: str,
    configmap_name: str,
    target_field: str,
    imagestream_name: str,
) -> str:
    """One replacement stanza."""
    # language=yaml
    return process_template_with_indents(t"""\
  - source:
      fieldPath: data.{field_path_key}
      kind: ConfigMap
      name: {configmap_name}
      version: v1
    targets:
      - fieldPaths:
          - {target_field}
        select:
          group: image.openshift.io
          kind: ImageStream
          name: {imagestream_name}
          version: v1""")


def _workbench_params_replacements(wb: Workbench) -> list[str]:
    """N and N-1 image-params replacements for a workbench."""
    return [
        _replacement_block(f"{wb.param_key}-n", "notebook-image-params", "spec.tags.0.from.name", wb.imagestream),
        _replacement_block(f"{wb.param_key}-n-1", "notebook-image-params", "spec.tags.1.from.name", wb.imagestream),
    ]


def _workbench_commit_replacements(wb: Workbench) -> list[str]:
    """N and N-1 commit-hash replacements for a workbench."""
    annotation = "spec.tags.{idx}.annotations.[opendatahub.io/notebook-build-commit]"
    return [
        _replacement_block(f"{wb.param_key}-commit-n", "notebook-image-commithash", annotation.format(idx=0),
                           wb.imagestream),
        _replacement_block(f"{wb.param_key}-commit-n-1", "notebook-image-commithash", annotation.format(idx=1),
                           wb.imagestream),
    ]


def _runtime_params_replacement(rt: Runtime) -> str:
    """Single image-params replacement for a runtime (N only)."""
    return _replacement_block(f"{rt.param_key}-n", "notebook-image-params", "spec.tags.0.from.name", rt.imagestream)


def generate() -> str:
    """Produce the full kustomization.yaml content."""
    resource_lines = "".join(f"  - {wb.resource_file}\n" for wb in WORKBENCHES)
    resource_lines += "".join(f"  - {rf}\n" for rf in RUNTIME_RESOURCE_FILES)
    resources = resource_lines.rstrip("\n")

    replacement_blocks: list[str] = []

    # 1) Workbench image-params (N and N-1) for all workbenches
    for wb in WORKBENCHES:
        replacement_blocks.extend(_workbench_params_replacements(wb))

    # 2) Workbench commit-hash (N and N-1) for all workbenches
    for wb in WORKBENCHES:
        replacement_blocks.extend(_workbench_commit_replacements(wb))

    # 3) Runtime image-params (N only) for all runtimes
    for rt in RUNTIMES:
        replacement_blocks.append(_runtime_params_replacement(rt))

    # language=yaml
    return process_template_with_indents(t"""\
---
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
{resources}

configMapGenerator:
  - envs:
      - params.env
      - params-latest.env
    name: notebook-image-params
  - envs:
      - commit.env
      - commit-latest.env
    name: notebook-image-commithash
generatorOptions:
  disableNameSuffixHash: true

labels:
  - includeSelectors: true
    pairs:
      component.opendatahub.io/name: notebooks
      opendatahub.io/component: "true"
replacements:
{"\n".join(replacement_blocks)}
""")


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    group = parser.add_mutually_exclusive_group()
    group.add_argument("--check", action="store_true",
                       help="Verify existing kustomization.yaml matches generated output")
    group.add_argument("--stdout", action="store_true", help="Print to stdout instead of writing to file")
    args = parser.parse_args()

    content = generate()

    if args.check:
        existing = OUTPUT_FILE.read_text()
        if existing == content:
            print("OK: kustomization.yaml is up to date.")
        else:
            print("MISMATCH: kustomization.yaml differs from generated output.", file=sys.stderr)
            _print_first_difference(existing, content)
            sys.exit(1)
    elif args.stdout:
        sys.stdout.write(content)
    else:
        OUTPUT_FILE.write_text(content)
        print(f"Wrote {OUTPUT_FILE}")


def _print_first_difference(existing: str, generated: str) -> None:
    """Print a diagnostic showing the first line that differs."""
    existing_lines = existing.splitlines()
    generated_lines = generated.splitlines()
    for i, (e, g) in enumerate(zip(existing_lines, generated_lines), 1):
        if e != g:
            print(f"  First difference at line {i}:", file=sys.stderr)
            print(f"    existing:  {e!r}", file=sys.stderr)
            print(f"    generated: {g!r}", file=sys.stderr)
            return
    shorter, longer = (
        ("existing", "generated")
        if len(existing_lines) < len(generated_lines)
        else ("generated", "existing")
    )
    print(f"  {shorter} has {abs(len(existing_lines) - len(generated_lines))} fewer lines than {longer}",
          file=sys.stderr)


if __name__ == "__main__":
    main()
