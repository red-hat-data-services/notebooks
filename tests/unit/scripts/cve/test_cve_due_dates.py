from __future__ import annotations

from datetime import date, timedelta
from typing import TYPE_CHECKING

from scripts.cve.cve_due_dates import (
    TrackerInfo,
    extract_cve_id,
    get_linked_issue_keys,
    list_missing_due_dates,
    list_overdue_trackers,
    parse_date,
)

if TYPE_CHECKING:
    from pytest import Subtests


# ── extract_cve_id ────────────────────────────────────────────────────


def test_extract_cve_id(subtests: Subtests) -> None:
    cases = [
        ("CVE-2024-12345", "CVE-2024-12345"),
        ("EMBARGOED CVE-2026-8643 rhoai/odh-workbench: flaw", "CVE-2026-8643"),
        ("some prefix CVE-2023-1 suffix", "CVE-2023-1"),
        ("no cve identifier here", None),
        ("", None),
        ("CVE-without-dash-numbers", None),
    ]
    for text, expected in cases:
        with subtests.test(msg=f"extract_cve_id({text!r})"):
            assert extract_cve_id(text) == expected


# ── parse_date ────────────────────────────────────────────────────────


def test_parse_date(subtests: Subtests) -> None:
    cases = [
        ("2025-06-15", date(2025, 6, 15)),
        ("2024-01-01", date(2024, 1, 1)),
        (None, None),
        ("", None),
        ("not-a-date", None),
        ("06/15/2025", None),  # wrong format
    ]
    for date_str, expected in cases:
        with subtests.test(msg=f"parse_date({date_str!r})"):
            assert parse_date(date_str) == expected


# ── get_linked_issue_keys ─────────────────────────────────────────────


def test_get_linked_issue_keys_outward_blocks() -> None:
    issue = {
        "fields": {
            "issuelinks": [
                {
                    "type": {"name": "Blocks"},
                    "outwardIssue": {"key": "RHOAIENG-100"},
                },
                {
                    "type": {"name": "Blocks"},
                    "outwardIssue": {"key": "RHOAIENG-200"},
                },
            ]
        }
    }
    assert get_linked_issue_keys(issue) == ["RHOAIENG-100", "RHOAIENG-200"]


def test_get_linked_issue_keys_ignores_inward() -> None:
    """Only outwardIssue links are returned."""
    issue = {
        "fields": {
            "issuelinks": [
                {
                    "type": {"name": "Blocks"},
                    "inwardIssue": {"key": "RHOAIENG-100"},
                },
            ]
        }
    }
    assert get_linked_issue_keys(issue) == []


def test_get_linked_issue_keys_filters_by_link_type() -> None:
    issue = {
        "fields": {
            "issuelinks": [
                {
                    "type": {"name": "Blocks"},
                    "outwardIssue": {"key": "RHOAIENG-100"},
                },
                {
                    "type": {"name": "Relates"},
                    "outwardIssue": {"key": "RHOAIENG-200"},
                },
            ]
        }
    }
    assert get_linked_issue_keys(issue, link_type="Relates") == ["RHOAIENG-200"]


def test_get_linked_issue_keys_empty() -> None:
    issue = {"fields": {"issuelinks": []}}
    assert get_linked_issue_keys(issue) == []


def test_get_linked_issue_keys_no_fields() -> None:
    issue = {"fields": {}}
    assert get_linked_issue_keys(issue) == []


# ── TrackerInfo.is_overdue ────────────────────────────────────────────


def test_tracker_is_overdue_past_due() -> None:
    tracker = TrackerInfo(
        key="RHAIENG-1",
        summary="CVE-2024-1234 something",
        due_date=date.today() - timedelta(days=5),
    )
    assert tracker.is_overdue is True


def test_tracker_is_overdue_future_due() -> None:
    tracker = TrackerInfo(
        key="RHAIENG-2",
        summary="CVE-2024-5678 something",
        due_date=date.today() + timedelta(days=5),
    )
    assert tracker.is_overdue is False


def test_tracker_is_overdue_no_due_date() -> None:
    tracker = TrackerInfo(key="RHAIENG-3", summary="CVE-2024-9999 something")
    assert tracker.is_overdue is False


# ── TrackerInfo.days_overdue ──────────────────────────────────────────


def test_tracker_days_overdue_positive() -> None:
    tracker = TrackerInfo(
        key="RHAIENG-1",
        summary="CVE test",
        due_date=date.today() - timedelta(days=10),
    )
    assert tracker.days_overdue == 10


def test_tracker_days_overdue_not_overdue_returns_zero() -> None:
    tracker = TrackerInfo(
        key="RHAIENG-2",
        summary="CVE test",
        due_date=date.today() + timedelta(days=3),
    )
    assert tracker.days_overdue == 0


def test_tracker_days_overdue_no_due_date_returns_zero() -> None:
    tracker = TrackerInfo(key="RHAIENG-3", summary="CVE test")
    assert tracker.days_overdue == 0


# ── TrackerInfo.needs_due_date_sync ──────────────────────────────────


def test_tracker_needs_sync_no_due_date_but_child_has() -> None:
    tracker = TrackerInfo(
        key="RHAIENG-1",
        summary="CVE test",
        due_date=None,
        earliest_child_due_date=date(2025, 7, 1),
    )
    assert tracker.needs_due_date_sync is True


def test_tracker_needs_sync_has_due_date() -> None:
    tracker = TrackerInfo(
        key="RHAIENG-2",
        summary="CVE test",
        due_date=date(2025, 7, 1),
        earliest_child_due_date=date(2025, 7, 1),
    )
    assert tracker.needs_due_date_sync is False


def test_tracker_needs_sync_no_child_due_date() -> None:
    tracker = TrackerInfo(
        key="RHAIENG-3",
        summary="CVE test",
        due_date=None,
        earliest_child_due_date=None,
    )
    assert tracker.needs_due_date_sync is False


# ── list_overdue_trackers ────────────────────────────────────────────


def test_list_overdue_trackers_filters_and_sorts() -> None:
    trackers = [
        TrackerInfo(key="A", summary="a", due_date=date.today() - timedelta(days=2)),
        TrackerInfo(key="B", summary="b", due_date=date.today() + timedelta(days=5)),
        TrackerInfo(key="C", summary="c", due_date=date.today() - timedelta(days=10)),
        TrackerInfo(key="D", summary="d"),  # no due date
    ]
    result = list_overdue_trackers(trackers)
    assert len(result) == 2
    # Most overdue first
    assert result[0].key == "C"
    assert result[1].key == "A"


def test_list_overdue_trackers_empty() -> None:
    trackers = [
        TrackerInfo(key="A", summary="a", due_date=date.today() + timedelta(days=1)),
    ]
    assert list_overdue_trackers(trackers) == []


# ── list_missing_due_dates ───────────────────────────────────────────


def test_list_missing_due_dates_filters_and_sorts() -> None:
    trackers = [
        TrackerInfo(key="A", summary="a", due_date=None, earliest_child_due_date=date(2025, 8, 1)),
        TrackerInfo(key="B", summary="b", due_date=date(2025, 6, 1)),  # has due date
        TrackerInfo(key="C", summary="c", due_date=None, earliest_child_due_date=date(2025, 7, 1)),
        TrackerInfo(key="D", summary="d", due_date=None, earliest_child_due_date=None),  # no child
    ]
    result = list_missing_due_dates(trackers)
    assert len(result) == 2
    # Sorted by earliest child due date ascending
    assert result[0].key == "C"
    assert result[1].key == "A"


def test_list_missing_due_dates_empty() -> None:
    trackers = [
        TrackerInfo(key="A", summary="a", due_date=date(2025, 6, 1)),
    ]
    assert list_missing_due_dates(trackers) == []
