"""Exercise the wheel prefetch script against transient and permanent HTTP failures."""

from __future__ import annotations

import hashlib
import shutil
import subprocess
import threading
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[1]
SCRIPT = Path("scripts/lockfile-generators/create-requirements-lockfile.sh")
PAYLOAD = b"wheel download fixture\n"


@pytest.mark.parametrize(
    ("statuses", "valid_hash", "cached", "success", "requests"),
    [
        ((503, 503, 200), True, None, True, 3),
        ((429, 200), True, None, True, 2),
        ((503,), True, None, False, 4),
        ((404,), True, None, False, 1),
        ((200,), False, None, False, 1),
        ((503,), True, PAYLOAD, True, 0),
        ((200,), True, b"partial download", True, 1),
    ],
)
def test_wheel_download(
    tmp_path: Path,
    statuses: tuple[int, ...],
    valid_hash: bool,
    cached: bytes | None,
    success: bool,
    requests: int,
) -> None:
    if shutil.which("wget") is None:
        pytest.skip("wheel prefetch requires wget")

    attempts: list[int] = []

    class Handler(BaseHTTPRequestHandler):
        def do_GET(self) -> None:
            status = statuses[min(len(attempts), len(statuses) - 1)]
            attempts.append(status)
            self.send_response(status)
            self.send_header("Content-Length", str(len(PAYLOAD)))
            self.end_headers()
            self.wfile.write(PAYLOAD)

        def log_message(self, format: str, *args: object) -> None:
            pass

    server = ThreadingHTTPServer(("127.0.0.1", 0), Handler)
    thread = threading.Thread(target=server.serve_forever, daemon=True)
    thread.start()
    try:
        helpers = tmp_path / SCRIPT.parent / "helpers"
        helpers.mkdir(parents=True)
        shutil.copyfile(ROOT / SCRIPT, tmp_path / SCRIPT)
        converter = "pylock-to-requirements.py"
        shutil.copyfile(ROOT / SCRIPT.parent / "helpers" / converter, helpers / converter)
        # Isolate downloading from dependency resolution; retain the real converter and wget.
        (tmp_path / "scripts/pylocks_generator.py").touch()
        wrapper = tmp_path / "uv"
        wrapper.write_text("#!/bin/sh\nexit 0\n")
        wrapper.chmod(0o755)
        project = tmp_path / "fixture"
        (project / "uv.lock.d").mkdir(parents=True)
        (project / "build-args").mkdir()
        (project / "build-args/konflux.cpu.conf").touch()
        (project / "pyproject.toml").touch()
        digest = hashlib.sha256(PAYLOAD if valid_hash else b"different content").hexdigest()
        url = f"http://127.0.0.1:{server.server_port}/fixture-1.0-py3-none-any.whl"
        (project / "uv.lock.d/pylock.cpu.toml").write_text(
            'lock-version = "1.0"\n[[packages]]\nname = "fixture"\nversion = "1.0"\n'
            f'wheels = [{{url = "{url}", hashes = {{sha256 = "{digest}"}}}}]\n'
        )
        output = tmp_path / "cachi2/output/deps/pip/fixture-1.0-py3-none-any.whl"
        if cached is not None:
            output.parent.mkdir(parents=True)
            output.write_bytes(cached)
        result = subprocess.run(
            ["bash", str(SCRIPT), "--pyproject-toml", "fixture/pyproject.toml", "--download"],
            cwd=tmp_path,
            capture_output=True,
            text=True,
            timeout=30,
            check=False,
        )
        assert (result.returncode == 0) == success, result.stdout + result.stderr
        assert len(attempts) == requests
        if success:
            assert output.read_bytes() == PAYLOAD
        else:
            assert not output.exists(), "Failed or corrupt downloads must not remain cached"
    finally:
        server.shutdown()
        server.server_close()
        thread.join(timeout=5)
