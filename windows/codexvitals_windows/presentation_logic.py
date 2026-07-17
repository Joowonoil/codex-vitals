from __future__ import annotations

from datetime import datetime

from .codex_api import AuthBackedIdentity
from .models import AccountUsageSnapshot, StoredAccount, UsageWindowSnapshot, normalize_identifier, utc_now


FIVE_HOUR_SECONDS = 18_000
ONE_WEEK_SECONDS = 604_800


def account_sort_key(
    account: StoredAccount,
    snapshot: AccountUsageSnapshot | None,
) -> tuple[int, int, float, float, str]:
    priority = snapshot.sort_priority if snapshot else 2
    name = account.display_name.casefold()
    if snapshot is None:
        return priority, 1, 0.0, float("inf"), name

    reset_at = snapshot.next_reset_at.timestamp() if snapshot.next_reset_at else float("inf")
    if snapshot.has_usable_quota_now:
        return priority, 0, -snapshot.lowest_remaining_percent, reset_at, name
    return priority, 1, 0.0, reset_at, name


def is_active_account(account: StoredAccount, identity: AuthBackedIdentity | None) -> bool:
    if identity is None:
        return False

    account_subject = normalize_identifier(account.auth_subject)
    identity_subject = normalize_identifier(identity.auth_subject)
    if account_subject and identity_subject and account_subject == identity_subject:
        return True

    account_email = normalize_identifier(account.email_hint)
    identity_email = normalize_identifier(identity.email)
    if account_email and identity_email and account_email == identity_email:
        return True

    return False


def quota_window_slot(window: UsageWindowSnapshot) -> str:
    if window.limit_window_seconds == FIVE_HOUR_SECONDS:
        return "5h"
    if window.limit_window_seconds == ONE_WEEK_SECONDS:
        return "1w"
    return "5h" if window.limit_window_seconds < 86_400 else "1w"


def quota_window_label(window: UsageWindowSnapshot) -> str:
    slot = quota_window_slot(window)
    if window.limit_window_seconds in {FIVE_HOUR_SECONDS, ONE_WEEK_SECONDS}:
        return slot
    return window.short_label


def quota_window_slots(snapshot: AccountUsageSnapshot | None) -> dict[str, UsageWindowSnapshot]:
    if snapshot is None:
        return {}

    slots: dict[str, UsageWindowSnapshot] = {}
    for window in (snapshot.primary_window, snapshot.secondary_window):
        if window is None:
            continue
        slot = quota_window_slot(window)
        existing = slots.get(slot)
        if existing is None or window.limit_window_seconds < existing.limit_window_seconds:
            slots[slot] = window
    return slots


def compact_reset_countdown(reset_at: datetime | None, now: datetime | None = None) -> str:
    if reset_at is None:
        return "--"

    current = now or utc_now()
    if reset_at.tzinfo is not None and current.tzinfo is None:
        current = current.replace(tzinfo=reset_at.tzinfo)
    elif reset_at.tzinfo is None and current.tzinfo is not None:
        reset_at = reset_at.replace(tzinfo=current.tzinfo)

    seconds = max(0, int((reset_at - current).total_seconds()))
    if seconds < 86_400:
        hours, remainder = divmod(seconds, 3600)
        minutes = remainder // 60
        return f"{hours:02d}:{minutes:02d}"

    days, remainder = divmod(seconds, 86_400)
    hours = remainder // 3600
    if days < 7:
        return f"{days}d {hours}h"
    return f"{days}d"
