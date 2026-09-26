"""Keep online repository definitions from triggering hermetic prefetch."""

from __future__ import annotations

import os
import re
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


@pytest.mark.parametrize("uses_cache", [False, True])
def test_makefile_shared_prefetch_detection(tmp_path: Path, uses_cache: bool) -> None:
    makefile = (ROOT / "Makefile").read_text()
    match = re.search(r"_DOCKERFILE_USES_PREFETCH := \$\(shell (.*?)\)\)", makefile)
    if match is None:
        pytest.skip("This release only mounts component-specific prefetch in Makefile")
    path = tmp_path / "Dockerfile"
    path.write_text(
        "COPY /cachi2/output/deps/pip /wheels\n"
        if uses_cache
        else "COPY prefetch-input/repos/ubi9-security-tools.repo /etc/yum.repos.d/tools.repo\n"
    )
    command = match.group(1).replace("$(2)", '"$DOCKERFILE"')
    result = subprocess.run(
        ["bash", "-c", command],
        env={**os.environ, "DOCKERFILE": str(path)},
        capture_output=True,
        text=True,
        check=False,
    )
    assert (result.stdout.strip() == "yes") == uses_cache
