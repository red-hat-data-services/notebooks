from __future__ import annotations

import os
import subprocess
from pathlib import Path

import pytest

BUILD_SCRIPT = Path(__file__).resolve().parents[1] / "jupyter/trustyai/ubi9-python-3.12/build_pyarrow.sh"


def test_pillow_source_build_does_not_link_epel_only_libraries() -> None:
    """ppc64le/s390x Pillow must not DT_NEEDED libimagequant.so.0 or libraqm.so.0."""
    script = BUILD_SCRIPT.with_name("devel_env_setup.sh").read_text()
    dockerfile = BUILD_SCRIPT.with_name("Dockerfile.konflux.cpu").read_text()
    assert "libimagequant-devel" not in script
    assert "libraqm-devel" not in script
    assert "--config-setting imagequant=disable" in script
    assert "--config-setting raqm=disable" in script
    assert "pillow:imagequant=disable" in dockerfile
    assert "pillow:raqm=disable" in dockerfile
    assert "--reinstall-package pillow" in dockerfile
    runtime = dockerfile.split("FROM ${BASE_IMAGE} AS cpu-base", maxsplit=1)[1]
    # After pylock, ppc64le reinstalls the auditwheel-repaired wheels (Pillow
    # among them) and checks that the bundled pillow.libs directory is present.
    assert "pip install --no-deps --force-reinstall /wheelsdir/*.whl" in runtime
    assert 'p / "pillow.libs"' in runtime


def test_runtime_consumes_wheels_without_bootstrapping_arrow_build_dependencies() -> None:
    dockerfile = BUILD_SCRIPT.with_name("Dockerfile.konflux.cpu").read_text()
    builder, runtime = dockerfile.split("FROM ${BASE_IMAGE} AS cpu-base", maxsplit=1)
    assert "uv pip install 'cython" in builder
    for build_dependency in ("libcst", "scikit-build-core", "setuptools_scm", "uv pip install 'cython"):
        assert build_dependency not in runtime
    locked_install = next(line for line in runtime.splitlines() if "--requirements=./pylock.toml" in line)
    assert "--cache-dir /root/.cache/uv" in locked_install


@pytest.mark.parametrize("failed_phase", ["-S", "--build", "--install"])
def test_arrow_native_failure_stops_before_wheel_build(tmp_path: Path, failed_phase: str) -> None:
    """A native failure must not be hidden by a later successful Python command."""
    bin_dir = tmp_path / "bin"
    bin_dir.mkdir()
    source_dir = tmp_path / "arrow"
    (source_dir / "python").mkdir(parents=True)
    calls = tmp_path / "calls"
    commands = {
        "python": "exit 0\n",
        "uv": 'echo "uv $1" >> "$BUILD_CALLS"\n',
        "cmake": ('echo "cmake $1" >> "$BUILD_CALLS"\nif [ "$1" = "$FAILED_PHASE" ]; then exit 17; fi\n'),
    }
    for name, body in commands.items():
        executable = bin_dir / name
        executable.write_text("#!/bin/sh\n" + body)
        executable.chmod(0o755)

    result = subprocess.run(
        ["bash", str(BUILD_SCRIPT), str(source_dir), str(tmp_path / "wheels")],
        env={
            **os.environ,
            "PATH": f"{bin_dir}{os.pathsep}{os.environ['PATH']}",
            "BUILD_CALLS": str(calls),
            "FAILED_PHASE": failed_phase,
            "MAX_JOBS": "1",
        },
        capture_output=True,
        text=True,
        check=False,
    )

    assert result.returncode == 17, result.stderr
    assert calls.read_text().splitlines()[-1] == f"cmake {failed_phase}"
    assert "uv build" not in calls.read_text()
