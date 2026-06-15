from __future__ import annotations

from typing import TYPE_CHECKING

from scripts.cve import sbom_analyze as sa

if TYPE_CHECKING:
    from pytest import Subtests


# ── Fixtures (in-memory SBOM data) ────────────────────────────────────


def _syft_sbom(artifacts: list[dict] | None = None) -> dict:
    """Build a minimal Syft-format SBOM."""
    return {
        "artifacts": artifacts or [],
        "source": {"name": "quay.io/opendatahub/workbench", "version": "sha256:abc", "type": "image"},
        "distro": {"name": "rhel", "version": "9.4"},
        "descriptor": {"version": "1.4.1"},
        "schema": {"version": "16.0.17"},
        "files": [{"id": "f1"}],
    }


def _spdx_sbom(packages: list[dict] | None = None) -> dict:
    """Build a minimal SPDX-format SBOM."""
    return {
        "spdxVersion": "SPDX-2.3",
        "name": "test-spdx",
        "packages": packages or [],
    }


def _spdx_manifest_box_sbom(components: list[dict] | None = None) -> dict:
    """Build a minimal SPDX manifest-box-format SBOM."""
    return {
        "build_manifest": {"manifest": {"components": components or []}},
        "build_component": "odh-trustyai",
        "build_completed_at": "2025-01-01T00:00:00Z",
    }


def _syft_artifact(
    name: str = "lodash",
    version: str = "4.17.21",
    pkg_type: str = "npm",
    purl: str = "pkg:npm/lodash@4.17.21",
    locations: list[dict] | None = None,
    found_by: str = "javascript-cataloger",
) -> dict:
    return {
        "name": name,
        "version": version,
        "type": pkg_type,
        "purl": purl,
        "foundBy": found_by,
        "locations": locations or [{"path": "/app/node_modules/lodash/package.json"}],
    }


def _spdx_package(
    name: str = "lodash",
    version: str = "4.17.21",
    purl: str = "pkg:npm/lodash@4.17.21",
    source_info: str = "",
) -> dict:
    pkg: dict = {
        "name": name,
        "versionInfo": version,
        "externalRefs": [
            {"referenceType": "purl", "referenceLocator": purl},
        ],
    }
    if source_info:
        pkg["sourceInfo"] = source_info
    return pkg


# ── detect_sbom_format ─────────────────────────────────────────────────


def test_detect_sbom_format_syft() -> None:
    assert sa.detect_sbom_format({"artifacts": []}) == "syft"


def test_detect_sbom_format_spdx() -> None:
    assert sa.detect_sbom_format({"spdxVersion": "SPDX-2.3"}) == "spdx"


def test_detect_sbom_format_spdx_packages_only() -> None:
    assert sa.detect_sbom_format({"packages": []}) == "spdx"


def test_detect_sbom_format_spdx_manifest_box() -> None:
    sbom = _spdx_manifest_box_sbom()
    assert sa.detect_sbom_format(sbom) == "spdx-manifest-box"


def test_detect_sbom_format_unknown() -> None:
    assert sa.detect_sbom_format({}) == "unknown"


# ── extract_purl_type ──────────────────────────────────────────────────


def test_extract_purl_type(subtests: Subtests) -> None:
    cases = [
        ("pkg:npm/lodash@4.17.21", "npm"),
        ("pkg:golang/github.com/go-chi/chi@5.0.0", "golang"),
        ("pkg:pypi/requests@2.31.0", "pypi"),
        ("pkg:rpm/rhel/openssl@3.0.7", "rpm"),
        ("", "unknown"),
        ("no-pkg-prefix", "unknown"),
    ]
    for purl, expected in cases:
        with subtests.test(msg=f"extract_purl_type({purl!r})"):
            assert sa.extract_purl_type(purl) == expected


# ── get_components_from_sbom ───────────────────────────────────────────


def test_get_components_syft() -> None:
    art = _syft_artifact()
    sbom = _syft_sbom([art])
    components = sa.get_components_from_sbom(sbom)
    assert len(components) == 1
    assert components[0]["name"] == "lodash"


def test_get_components_spdx() -> None:
    pkg = _spdx_package()
    sbom = _spdx_sbom([pkg])
    components = sa.get_components_from_sbom(sbom)
    assert len(components) == 1
    assert components[0]["name"] == "lodash"


def test_get_components_manifest_box() -> None:
    comp = {"name": "trustyai-lib", "versionInfo": "1.0.0"}
    sbom = _spdx_manifest_box_sbom([comp])
    components = sa.get_components_from_sbom(sbom)
    assert len(components) == 1
    assert components[0]["name"] == "trustyai-lib"


def test_get_components_unknown_returns_empty() -> None:
    assert sa.get_components_from_sbom({}) == []


# ── normalize_component ───────────────────────────────────────────────


def test_normalize_component_syft() -> None:
    art = _syft_artifact()
    norm = sa.normalize_component(art, "syft")
    assert norm["name"] == "lodash"
    assert norm["version"] == "4.17.21"
    assert norm["type"] == "npm"
    assert norm["foundBy"] == "javascript-cataloger"
    assert "/app/node_modules/lodash/package.json" in norm["locations"]
    assert norm["purl"] == "pkg:npm/lodash@4.17.21"
    assert norm["sourceInfo"] is None


def test_normalize_component_spdx_with_source_info() -> None:
    pkg = _spdx_package(
        source_info="acquired package info from installed node module manifest file: /jupyter/utils/addons/pnpm-lock.yaml",
    )
    norm = sa.normalize_component(pkg, "spdx")
    assert norm["name"] == "lodash"
    assert norm["version"] == "4.17.21"
    assert norm["type"] == "npm"
    assert "/jupyter/utils/addons/pnpm-lock.yaml" in norm["locations"]


def test_normalize_component_spdx_no_purl() -> None:
    pkg = {"name": "unknown-pkg", "versionInfo": "0.1", "externalRefs": []}
    norm = sa.normalize_component(pkg, "spdx")
    assert norm["type"] == "unknown"
    assert norm["purl"] is None


def test_normalize_component_unknown_format() -> None:
    comp = {"name": "something"}
    norm = sa.normalize_component(comp, "other")
    assert norm["name"] == "something"
    assert norm["version"] is None
    assert norm["type"] == "unknown"
    assert norm["locations"] == []


# ── find_package ──────────────────────────────────────────────────────


def test_find_package_case_insensitive() -> None:
    sbom = _syft_sbom([_syft_artifact(name="Lodash")])
    results = sa.find_package(sbom, "lodash", case_insensitive=True)
    assert len(results) == 1
    assert results[0]["name"] == "Lodash"


def test_find_package_case_sensitive_no_match() -> None:
    sbom = _syft_sbom([_syft_artifact(name="Lodash")])
    results = sa.find_package(sbom, "lodash", case_insensitive=False)
    assert len(results) == 0


def test_find_package_case_sensitive_exact_match() -> None:
    sbom = _syft_sbom([_syft_artifact(name="lodash")])
    results = sa.find_package(sbom, "lodash", case_insensitive=False)
    assert len(results) == 1


def test_find_package_substring_match() -> None:
    sbom = _syft_sbom([
        _syft_artifact(name="lodash"),
        _syft_artifact(name="lodash.merge"),
        _syft_artifact(name="express"),
    ])
    results = sa.find_package(sbom, "lodash")
    assert len(results) == 2


def test_find_package_no_match() -> None:
    sbom = _syft_sbom([_syft_artifact(name="express")])
    results = sa.find_package(sbom, "nonexistent")
    assert results == []


def test_find_package_in_spdx() -> None:
    sbom = _spdx_sbom([_spdx_package(name="requests", version="2.31.0", purl="pkg:pypi/requests@2.31.0")])
    results = sa.find_package(sbom, "requests")
    assert len(results) == 1
    assert results[0]["version"] == "2.31.0"


# ── find_packages_at_path ────────────────────────────────────────────


def test_find_packages_at_path_via_locations() -> None:
    sbom = _syft_sbom([
        _syft_artifact(name="lodash", locations=[{"path": "/jupyter/node_modules/lodash/package.json"}]),
        _syft_artifact(name="express", locations=[{"path": "/other/node_modules/express/package.json"}]),
    ])
    results = sa.find_packages_at_path(sbom, "/jupyter/")
    assert len(results) == 1
    assert results[0]["name"] == "lodash"


def test_find_packages_at_path_via_source_info() -> None:
    pkg = _spdx_package(
        name="pip",
        purl="pkg:pypi/pip@23.0",
        source_info="acquired package info from: /usr/lib/python3.11/site-packages/pip",
    )
    sbom = _spdx_sbom([pkg])
    results = sa.find_packages_at_path(sbom, "/usr/lib/python3.11/")
    assert len(results) == 1
    assert results[0]["name"] == "pip"


def test_find_packages_at_path_no_match() -> None:
    sbom = _syft_sbom([_syft_artifact(name="lodash", locations=[{"path": "/app/node_modules/lodash"}])])
    results = sa.find_packages_at_path(sbom, "/nonexistent/")
    assert results == []


# ── get_sbom_info ────────────────────────────────────────────────────


def test_get_sbom_info_syft() -> None:
    sbom = _syft_sbom([_syft_artifact()])
    info = sa.get_sbom_info(sbom)
    assert info["format"] == "syft"
    assert info["source_name"] == "quay.io/opendatahub/workbench"
    assert info["distro"] == "rhel"
    assert info["distro_version"] == "9.4"
    assert info["artifact_count"] == 1
    assert info["file_count"] == 1


def test_get_sbom_info_spdx() -> None:
    sbom = _spdx_sbom([_spdx_package()])
    info = sa.get_sbom_info(sbom)
    assert info["format"] == "spdx"
    assert info["spdx_version"] == "SPDX-2.3"
    assert info["name"] == "test-spdx"
    assert info["package_count"] == 1


def test_get_sbom_info_manifest_box() -> None:
    sbom = _spdx_manifest_box_sbom([{"name": "a"}])
    info = sa.get_sbom_info(sbom)
    assert info["format"] == "spdx (manifest-box)"
    assert info["build_component"] == "odh-trustyai"
    assert info["component_count"] == 1


def test_get_sbom_info_unknown() -> None:
    info = sa.get_sbom_info({})
    assert info == {"format": "unknown"}


# ── summarize_by_type ────────────────────────────────────────────────


def test_summarize_by_type_syft() -> None:
    sbom = _syft_sbom([
        _syft_artifact(name="lodash", pkg_type="npm"),
        _syft_artifact(name="express", pkg_type="npm"),
        _syft_artifact(name="requests", pkg_type="python"),
    ])
    summary = sa.summarize_by_type(sbom)
    assert summary["npm"] == 2
    assert summary["python"] == 1
    # Sorted descending by count — npm first
    keys = list(summary.keys())
    assert keys[0] == "npm"


def test_summarize_by_type_empty() -> None:
    sbom = _syft_sbom([])
    summary = sa.summarize_by_type(sbom)
    assert summary == {}


def test_summarize_by_type_spdx() -> None:
    sbom = _spdx_sbom([
        _spdx_package(name="pip", purl="pkg:pypi/pip@23.0"),
        _spdx_package(name="openssl", purl="pkg:rpm/rhel/openssl@3.0"),
    ])
    summary = sa.summarize_by_type(sbom)
    assert summary["pypi"] == 1
    assert summary["rpm"] == 1
