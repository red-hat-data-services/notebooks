"""Keep online repository definitions from triggering hermetic prefetch."""

from __future__ import annotations

import os
import shutil
import subprocess
from pathlib import Path

import pytest
import yaml

ROOT = Path(__file__).resolve().parents[1]


@pytest.mark.parametrize(
    ("dockerfile", "component_prefetch", "expected"),
    [
        (
            "COPY prefetch-input/repos/ubi9-security-tools.repo /etc/yum.repos.d/tools.repo\n",
            False,
            "online",
        ),
        ("COPY --from=builder /cachi2/output/deps/pip /wheels\n", False, "prefetch"),
        ("FROM ubi9\n", True, "prefetch"),
    ],
)
def test_workflow_prefetch_detection(tmp_path: Path, dockerfile: str, component_prefetch: bool, expected: str) -> None:
    workflow = yaml.safe_load((ROOT / ".github/workflows/build-notebooks-TEMPLATE.yaml").read_text())
    scripts = [
        step["run"]
        for job in workflow["jobs"].values()
        for step in job.get("steps", [])
        if step.get("name") == "Prefetch hermetic build dependencies"
    ]
    assert len(scripts) == 1
    condition = next(
        line.strip()
        for line in scripts[0].splitlines()
        if line.strip().startswith('if [ -d "$COMPONENT_DIR/prefetch-input" ]')
    )
    component = tmp_path / "component"
    component.mkdir()
    path = component / "Dockerfile"
    path.write_text(dockerfile)
    (tmp_path / "prefetch-input/repos").mkdir(parents=True)
    if component_prefetch:
        (component / "prefetch-input").mkdir()
    result = subprocess.run(
        ["bash", "-c", condition + "\n echo prefetch\nelse\n echo online\nfi"],
        cwd=tmp_path,
        env={**os.environ, "COMPONENT_DIR": str(component), "DOCKERFILE": str(path)},
        capture_output=True,
        text=True,
        check=True,
    )
    assert result.stdout.strip() == expected


@pytest.mark.parametrize(
    ("dockerfile", "uses_cache"),
    [
        ("COPY prefetch-input/repos/ubi9-security-tools.repo /etc/yum.repos.d/tools.repo\n", False),
        ("# npm cache: /cachi2/output/deps/npm\n", False),
        ("  # npm cache: /cachi2/output/deps/npm\n", False),
        ("\t# npm cache: /cachi2/output/deps/npm\n", False),
        ("COPY /cachi2/output/deps/pip /wheels\n", True),
        ("RUN pip install --no-index \\\n    --find-links /cachi2/output/deps/pip example\n", True),
    ],
)
@pytest.mark.parametrize("component_prefetch", [False, True])
def test_makefile_shared_prefetch_detection(
    tmp_path: Path, dockerfile: str, uses_cache: bool, component_prefetch: bool
) -> None:
    makefile = (ROOT / "Makefile").read_text()
    lines = [
        line
        for line in makefile.splitlines()
        if line.startswith(("$(eval _DOCKERFILE_USES_PREFETCH :=", "$(eval PREFETCH_INPUT_DIR :="))
    ]
    assert len(lines) == 2
    component = tmp_path / "component"
    component.mkdir()
    if component_prefetch:
        (component / "prefetch-input").mkdir()
    (tmp_path / "prefetch-input").mkdir()
    path = component / "Dockerfile"
    path.write_text(dockerfile)
    harness = tmp_path / "Makefile"
    harness.write_text(
        "define detect\n" + "\n".join(lines) + "\nendef\n"
        "$(call detect,unused,$(BUILD_DIR)Dockerfile)\n"
        "$(info uses_cache=$(_DOCKERFILE_USES_PREFETCH))\n"
        "$(info input=$(PREFETCH_INPUT_DIR))\n"
        ".PHONY: all\nall:;@:\n"
    )
    result = subprocess.run(
        [shutil.which("gmake") or "make", "-s", "-f", str(harness), f"BUILD_DIR={component}/", f"ROOT_DIR={tmp_path}/"],
        cwd=tmp_path,
        capture_output=True,
        text=True,
        check=True,
    )
    expected_dir = (
        component / "prefetch-input" if component_prefetch else tmp_path / "prefetch-input" if uses_cache else ""
    )
    assert f"uses_cache={'yes' if uses_cache else ''}\n" in result.stdout
    assert f"input={expected_dir}\n" in result.stdout
