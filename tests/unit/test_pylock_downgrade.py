"""Regression coverage for the narrowly approved Elyra downgrade."""

from contextlib import nullcontext

import pytest

from tests import test_pylock_downgrade as downgrade


@pytest.mark.parametrize(
    ("baseline", "current", "package", "image", "should_fail"),
    [
        ("5.0.0", "4.3.2", "odh-elyra", "pytorch+llmcompressor", False),
        ("5.0.0", "4.3.2", "odh_elyra", "pytorch+llmcompressor", False),
        ("4.3.2", "4.3.1", "odh-elyra", "pytorch+llmcompressor", True),
        ("5.0.0", "4.3.1", "odh-elyra", "pytorch+llmcompressor", True),
        ("5.0.1", "4.3.2", "odh-elyra", "pytorch+llmcompressor", True),
        ("5.0.0", "4.3.2", "odh-elyra", "pytorch", True),
        ("5.0.0", "4.3.2", "jupyterlab", "pytorch+llmcompressor", True),
    ],
)
def test_downgrade_exception(tmp_path, monkeypatch, baseline, current, package, image, should_fail):
    """Exercise the complete check with isolated baseline and current lock data."""
    (tmp_path / ".git").mkdir()
    lock = tmp_path / f"jupyter/{image}/ubi9-python-3.12/uv.lock.d/pylock.cuda.toml"
    lock.parent.mkdir(parents=True)
    lock.write_text(f'[[packages]]\nname = "{package}"\nversion = "{current}"\n')
    monkeypatch.setattr(downgrade, "PROJECT_ROOT", tmp_path)
    monkeypatch.setattr(downgrade, "_resolve_base_ref", lambda: "baseline")
    monkeypatch.setattr(downgrade, "_iter_image_pyproject_pylock_files", lambda: [lock])
    monkeypatch.setattr(
        downgrade, "_git_show_text", lambda *_: f'[[packages]]\nname = "{package}"\nversion = "{baseline}"\n'
    )
    monkeypatch.setenv("NOTEBOOKS_DOWNGRADE_CHECK", "1")

    class Subtests:
        def test(self, **kwargs):
            return nullcontext()

    with pytest.raises(pytest.fail.Exception, match="Tracked package downgrade") if should_fail else nullcontext():
        downgrade.test_pylock_tracked_packages_not_downgraded_vs_git_base(Subtests())
