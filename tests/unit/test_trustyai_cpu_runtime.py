"""Check CPU-only Torch handling without excluding Accelerate on IBM architectures."""

import tomllib
from pathlib import Path

import pytest
from packaging.markers import Marker
from packaging.requirements import Requirement

PROJECT = Path(__file__).resolve().parents[2] / "jupyter/trustyai/ubi9-python-3.12"


@pytest.mark.parametrize("architecture", ["x86_64", "aarch64", "ppc64le", "s390x"])
def test_cpu_runtime_lock_handles_torch_separately_on_ibm(architecture):
    with (PROJECT / "pylock.toml").open("rb") as stream:
        lock = tomllib.load(stream)
    with (PROJECT / "pyproject.toml").open("rb") as stream:
        project = tomllib.load(stream)
    environment = {
        "platform_machine": architecture,
        "sys_platform": "linux",
        "implementation_name": "cpython",
        "python_version": "3.12",
        "python_full_version": "3.12.9",
    }
    active = {
        p["name"]: p["version"]
        for p in lock["packages"]
        if Marker(p.get("marker", "python_version >= '0'")).evaluate(environment)
    }
    ibm = architecture in {"ppc64le", "s390x"}
    if ibm:
        assert "torch" not in active
    else:
        assert active["torch"] == "2.7.1+cpu"
    assert active["accelerate"] == "1.10.1"
    torch_dependencies = {
        "filelock",
        "typing-extensions",
        "setuptools",
        "sympy",
        "mpmath",
        "networkx",
        "jinja2",
        "fsspec",
    }
    assert torch_dependencies <= active.keys()
    assert "triton" not in active
    assert not any(name.startswith("nvidia-") for name in active)

    # Accelerate requires Torch transitively: its override must carry the marker too.
    for dependencies in (project["project"]["dependencies"], project["tool"]["uv"]["override-dependencies"]):
        torch = next(r for entry in dependencies if (r := Requirement(entry)).name == "torch")
        assert str(torch.specifier) == "==2.7.1+cpu"
        assert torch.marker.evaluate(environment) == (not ibm)
    assert project["tool"]["uv"]["pip"]["torch-backend"] == "cpu"
