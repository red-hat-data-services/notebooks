from __future__ import annotations

import base64
from datetime import datetime, timedelta, timezone
from typing import TYPE_CHECKING

from scripts.cve.jira_auth import (
    JiraAuthError,
    _basic_auth_header,
    _not_expired,
    _parse_expires_at,
    _pkce_pair,
    get_auth_headers,
)

if TYPE_CHECKING:
    from pytest import MonkeyPatch, Subtests


# ── _basic_auth_header ────────────────────────────────────────────────


def test_basic_auth_header_encodes_correctly() -> None:
    headers = _basic_auth_header("user@example.com", "my-token")
    auth = headers["Authorization"]
    assert auth.startswith("Basic ")
    decoded = base64.b64decode(auth.split(" ", 1)[1]).decode("utf-8")
    assert decoded == "user@example.com:my-token"


def test_basic_auth_header_special_chars() -> None:
    headers = _basic_auth_header("user@example.com", "tok:en+with/specials=")
    decoded = base64.b64decode(headers["Authorization"].split(" ", 1)[1]).decode("utf-8")
    assert decoded == "user@example.com:tok:en+with/specials="


# ── _pkce_pair ────────────────────────────────────────────────────────


def test_pkce_pair_returns_two_strings() -> None:
    verifier, challenge = _pkce_pair()
    assert isinstance(verifier, str)
    assert isinstance(challenge, str)
    assert len(verifier) > 0
    assert len(challenge) > 0


def test_pkce_pair_challenge_differs_from_verifier() -> None:
    verifier, challenge = _pkce_pair()
    assert verifier != challenge


def test_pkce_pair_is_unique() -> None:
    pair1 = _pkce_pair()
    pair2 = _pkce_pair()
    assert pair1[0] != pair2[0]
    assert pair1[1] != pair2[1]


def test_pkce_pair_verifier_is_url_safe() -> None:
    """Verifier should use URL-safe base64 characters only."""
    verifier, _ = _pkce_pair()
    # URL-safe base64 contains only A-Z, a-z, 0-9, -, _
    allowed = set("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_")
    assert set(verifier).issubset(allowed)


# ── _parse_expires_at ─────────────────────────────────────────────────


def test_parse_expires_at_valid_iso(subtests: Subtests) -> None:
    cases = [
        ("2025-06-15T12:00:00+00:00", datetime(2025, 6, 15, 12, 0, 0, tzinfo=timezone.utc)),
        ("2025-06-15T12:00:00", datetime(2025, 6, 15, 12, 0, 0, tzinfo=timezone.utc)),  # naive -> UTC
    ]
    for value, expected in cases:
        with subtests.test(msg=f"_parse_expires_at({value!r})"):
            result = _parse_expires_at(value)
            assert result == expected


def test_parse_expires_at_empty_returns_none() -> None:
    assert _parse_expires_at("") is None


def test_parse_expires_at_invalid_returns_none() -> None:
    assert _parse_expires_at("not-a-date") is None


# ── _not_expired ──────────────────────────────────────────────────────


def test_not_expired_future_token() -> None:
    """Token expiring far in the future is not expired."""
    future = datetime.now(tz=timezone.utc) + timedelta(hours=1)
    assert _not_expired(future) is True


def test_not_expired_past_token() -> None:
    """Token that expired in the past is expired."""
    past = datetime.now(tz=timezone.utc) - timedelta(hours=1)
    assert _not_expired(past) is False


def test_not_expired_within_buffer() -> None:
    """Token expiring within the 60-second buffer is treated as expired."""
    almost_expired = datetime.now(tz=timezone.utc) + timedelta(seconds=30)
    assert _not_expired(almost_expired) is False


def test_not_expired_just_outside_buffer() -> None:
    """Token expiring beyond the 60-second buffer is valid."""
    safe = datetime.now(tz=timezone.utc) + timedelta(seconds=120)
    assert _not_expired(safe) is True


# ── get_auth_headers (env-var paths only, no OAuth flow) ─────────────


def test_get_auth_headers_basic_auth_from_env(monkeypatch: MonkeyPatch) -> None:
    """Method 1a: JIRA_EMAIL + JIRA_API_TOKEN => Basic auth header."""
    monkeypatch.setenv("JIRA_EMAIL", "user@redhat.com")
    monkeypatch.setenv("JIRA_API_TOKEN", "my-api-token")
    monkeypatch.delenv("JIRA_TOKEN", raising=False)
    monkeypatch.delenv("JIRA_OAUTH_CLIENT_SECRET", raising=False)

    headers = get_auth_headers("https://redhat.atlassian.net")
    assert "Authorization" in headers
    assert headers["Authorization"].startswith("Basic ")
    decoded = base64.b64decode(headers["Authorization"].split(" ", 1)[1]).decode("utf-8")
    assert decoded == "user@redhat.com:my-api-token"


def test_get_auth_headers_bearer_from_env(monkeypatch: MonkeyPatch) -> None:
    """Method 2: JIRA_TOKEN => Bearer header."""
    monkeypatch.delenv("JIRA_EMAIL", raising=False)
    monkeypatch.delenv("JIRA_API_TOKEN", raising=False)
    monkeypatch.setenv("JIRA_TOKEN", "legacy-bearer-token")
    monkeypatch.delenv("JIRA_OAUTH_CLIENT_SECRET", raising=False)

    headers = get_auth_headers("https://issues.redhat.com")
    assert headers == {"Authorization": "Bearer legacy-bearer-token"}


def test_get_auth_headers_raises_when_only_email(monkeypatch: MonkeyPatch) -> None:
    """Setting JIRA_EMAIL without JIRA_API_TOKEN raises JiraAuthError."""
    monkeypatch.setenv("JIRA_EMAIL", "user@redhat.com")
    monkeypatch.delenv("JIRA_API_TOKEN", raising=False)
    monkeypatch.delenv("JIRA_TOKEN", raising=False)
    monkeypatch.delenv("JIRA_OAUTH_CLIENT_SECRET", raising=False)

    try:
        get_auth_headers("https://redhat.atlassian.net")
        assert False, "Expected JiraAuthError"
    except JiraAuthError as exc:
        assert "JIRA_EMAIL" in str(exc)
        assert "JIRA_API_TOKEN" in str(exc)


def test_get_auth_headers_raises_when_only_token(monkeypatch: MonkeyPatch) -> None:
    """Setting JIRA_API_TOKEN without JIRA_EMAIL raises JiraAuthError."""
    monkeypatch.delenv("JIRA_EMAIL", raising=False)
    monkeypatch.setenv("JIRA_API_TOKEN", "my-api-token")
    monkeypatch.delenv("JIRA_TOKEN", raising=False)
    monkeypatch.delenv("JIRA_OAUTH_CLIENT_SECRET", raising=False)

    try:
        get_auth_headers("https://redhat.atlassian.net")
        assert False, "Expected JiraAuthError"
    except JiraAuthError as exc:
        assert "JIRA_EMAIL" in str(exc)


def test_get_auth_headers_raises_when_no_creds(monkeypatch: MonkeyPatch) -> None:
    """No credentials set at all raises JiraAuthError."""
    monkeypatch.delenv("JIRA_EMAIL", raising=False)
    monkeypatch.delenv("JIRA_API_TOKEN", raising=False)
    monkeypatch.delenv("JIRA_TOKEN", raising=False)
    monkeypatch.delenv("JIRA_OAUTH_CLIENT_SECRET", raising=False)

    try:
        get_auth_headers("https://redhat.atlassian.net")
        assert False, "Expected JiraAuthError"
    except JiraAuthError as exc:
        assert "No Jira authentication credentials found" in str(exc)
