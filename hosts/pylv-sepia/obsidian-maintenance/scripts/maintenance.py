"""Obsidian maintenance script.

Processes active.md files in an Obsidian vault:
1. Calendar sync: Syncs active events to Google Calendar via gws CLI
2. Tasks: Rolls over past-due dates, archives completed tasks older than 7 days
3. Events: Auto-completes past events, archives completed events older than 7 days
"""

import json
import re
import subprocess
import sys
import traceback
from datetime import date, datetime, timedelta
from pathlib import Path

# Shared patterns
ACTIVE_RE = re.compile(r"^- \[ \] ")
DONE_RE = re.compile(r"^- \[x\] ")
SECTION_HEADER_RE = re.compile(r"^### (\d{4}-\d{2}-\d{2})$")

# Tasks-specific patterns
DUE_RE = re.compile(r"\[due::\s*(\d{4}-\d{2}-\d{2})\]")
COMPLETION_RE = re.compile(r"\[completion::\s*(\d{4}-\d{2}-\d{2})\]")
RECURRENCE_RE = re.compile(r"\[recurrence::|🔁")

# Events-specific patterns
DATE_RE = re.compile(r"\[date::\s*(\d{4}-\d{2}-\d{2})\]")
START_RE = re.compile(r"\[start::\s*(\d{2}:\d{2})\]")
END_RE = re.compile(r"\[end::\s*(\d{2}:\d{2})\]")
TAG_RE = re.compile(r"\s*\[[a-z]+::\s*[^\]]*\]")

TIMEZONE = "Asia/Seoul"
TIMEZONE_OFFSET = "+09:00"

MONTH_NAMES = [
    "",
    "1월",
    "2월",
    "3월",
    "4월",
    "5월",
    "6월",
    "7월",
    "8월",
    "9월",
    "10월",
    "11월",
    "12월",
]


def parse_date(s: str) -> date:
    return date.fromisoformat(s)


# --- Google Calendar sync ---


def parse_event_line(line: str) -> dict | None:
    """Parse an active event line into a structured dict for calendar sync.

    Returns None if the line is not an active uncompleted event or has no date.
    """
    if not ACTIVE_RE.match(line):
        return None
    date_match = DATE_RE.search(line)
    if not date_match:
        return None

    name = ACTIVE_RE.sub("", line)
    name = TAG_RE.sub("", name).strip()

    start_match = START_RE.search(line)
    end_match = END_RE.search(line)

    return {
        "name": name,
        "date": date_match.group(1),
        "start": start_match.group(1) if start_match else None,
        "end": end_match.group(1) if end_match else None,
    }


def event_key(event: dict) -> str:
    """Generate a unique key for an event (name + date)."""
    return f"{event['name']}|{event['date']}"


def build_gcal_request_body(event: dict) -> dict:
    """Build a Google Calendar API event request body.

    All-day events use 'date' fields. Timed events use 'dateTime' fields.
    If start is given but no end, defaults to 1 hour duration.
    """
    body: dict = {"summary": event["name"]}

    if event["start"] is None:
        body["start"] = {"date": event["date"]}
        body["end"] = {"date": event["date"]}
    else:
        start_dt = f"{event['date']}T{event['start']}:00{TIMEZONE_OFFSET}"
        body["start"] = {"dateTime": start_dt, "timeZone": TIMEZONE}

        if event["end"] is not None:
            end_dt = f"{event['date']}T{event['end']}:00{TIMEZONE_OFFSET}"
        else:
            start = datetime.fromisoformat(start_dt)
            end = start + timedelta(hours=1)
            end_dt = end.isoformat()
        body["end"] = {"dateTime": end_dt, "timeZone": TIMEZONE}

    return body


def create_gcal_event(gws_path: str, body: dict) -> str | None:
    """Create a Google Calendar event via gws CLI. Returns event ID or None."""
    result = subprocess.run(
        [
            gws_path,
            "calendar",
            "events",
            "insert",
            "--params",
            json.dumps({"calendarId": "primary"}),
            "--json",
            json.dumps(body),
        ],
        capture_output=True,
        text=True,
        timeout=30,
    )
    if result.returncode != 0:
        print(f"    gws error: {result.stderr.strip()}")
        return None

    response = json.loads(result.stdout)
    return response.get("id")


def update_gcal_event(gws_path: str, event_id: str, body: dict) -> bool:
    """Update an existing Google Calendar event. Returns True on success."""
    result = subprocess.run(
        [
            gws_path,
            "calendar",
            "events",
            "patch",
            "--params",
            json.dumps({"calendarId": "primary", "eventId": event_id}),
            "--json",
            json.dumps(body),
        ],
        capture_output=True,
        text=True,
        timeout=30,
    )
    if result.returncode != 0:
        print(f"    gws error: {result.stderr.strip()}")
        return False
    return True


def load_sync_state(state_path: Path) -> dict:
    """Load calendar sync state from JSON file."""
    if not state_path.exists():
        return {}
    try:
        return json.loads(state_path.read_text(encoding="utf-8"))
    except (json.JSONDecodeError, OSError):
        print("  Warning: corrupt sync state, starting fresh")
        return {}


def save_sync_state(state_path: Path, state: dict) -> None:
    """Save calendar sync state to JSON file."""
    state_path.write_text(
        json.dumps(state, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )


def event_changed(event: dict, stored: dict) -> bool:
    """Check if event's start/end differs from stored state."""
    return event["start"] != stored.get("start") or event["end"] != stored.get("end")


def sync_events_to_gcal(vault_path: Path, gws_path: str) -> None:
    """Sync active events to Google Calendar via gws CLI.

    Iterates all active events, creates new ones, updates changed ones.
    Individual failures are logged but do not stop other events.
    """
    events_dir = vault_path / "personal" / "events"
    active_file = events_dir / "active.md"
    state_path = events_dir / ".gcal-sync.json"

    if not active_file.exists():
        print("Google Calendar: events/active.md not found, skipping sync")
        return

    state = load_sync_state(state_path)
    lines = active_file.read_text(encoding="utf-8").splitlines()

    active_keys: set[str] = set()
    created = 0
    updated = 0

    for line in lines:
        event = parse_event_line(line)
        if event is None:
            continue

        key = event_key(event)
        active_keys.add(key)

        if key not in state:
            try:
                body = build_gcal_request_body(event)
                gcal_id = create_gcal_event(gws_path, body)
                if gcal_id:
                    state[key] = {
                        "gcal_id": gcal_id,
                        "start": event["start"],
                        "end": event["end"],
                    }
                    created += 1
                    print(f"  Created: {event['name']} -> {gcal_id}")
            except Exception as e:
                print(f"  Failed to create '{event['name']}': {e}")

        elif event_changed(event, state[key]):
            try:
                body = build_gcal_request_body(event)
                if update_gcal_event(gws_path, state[key]["gcal_id"], body):
                    state[key]["start"] = event["start"]
                    state[key]["end"] = event["end"]
                    updated += 1
                    print(f"  Updated: {event['name']}")
            except Exception as e:
                print(f"  Failed to update '{event['name']}': {e}")

    # Remove state entries for events no longer in active.md
    state = {k: v for k, v in state.items() if k in active_keys}

    save_sync_state(state_path, state)
    print(f"Google Calendar: {created} created, {updated} updated")


# --- Shared archive functions ---


def insert_into_archive(
    sections: dict[str, list[str]], date_key: str, line: str
) -> None:
    """Insert a line into the archive sections under date_key."""
    sections.setdefault(date_key, []).append(line)


def write_archive_file(
    archive_path: Path,
    year: int,
    month: int,
    new_sections: dict[str, list[str]],
) -> int:
    """Write or append items to a monthly archive file."""
    archive_path.parent.mkdir(parents=True, exist_ok=True)
    existing_sections: dict[str, list[str]] = {}
    header = ""

    if archive_path.exists():
        lines = archive_path.read_text(encoding="utf-8").splitlines()
        current_section = ""
        for line in lines:
            sm = SECTION_HEADER_RE.match(line)
            if line.startswith("# "):
                header = line
            elif sm:
                current_section = sm.group(1)
                existing_sections.setdefault(current_section, [])
            elif DONE_RE.match(line) and current_section:
                existing_sections[current_section].append(line)
    else:
        header = f"# {year}년 {MONTH_NAMES[month]} 완료"

    # Merge new sections into existing
    count = 0
    for date_key, items in new_sections.items():
        existing_sections.setdefault(date_key, [])
        existing_sections[date_key].extend(items)
        count += len(items)

    # Write sorted output
    sorted_dates = sorted(existing_sections.keys())
    out_lines = [header, ""]
    for d in sorted_dates:
        out_lines.append(f"### {d}")
        out_lines.extend(existing_sections[d])
        out_lines.append("")

    archive_path.write_text("\n".join(out_lines), encoding="utf-8")
    return count


def clean_empty_sections(lines: list[str]) -> list[str]:
    """Remove section headers that have no item lines below them."""
    result: list[str] = []
    i = 0
    while i < len(lines):
        sm = SECTION_HEADER_RE.match(lines[i])
        if sm:
            has_items = False
            j = i + 1
            while j < len(lines):
                if SECTION_HEADER_RE.match(lines[j]):
                    break
                if lines[j].startswith("- ["):
                    has_items = True
                    break
                j += 1
            if has_items:
                result.append(lines[i])
            else:
                i += 1
                while i < len(lines) and lines[i].strip() == "":
                    i += 1
                continue
        else:
            result.append(lines[i])
        i += 1

    # Clean up consecutive blank lines (max 1)
    cleaned: list[str] = []
    for line in result:
        if line.strip() == "" and cleaned and cleaned[-1].strip() == "":
            continue
        cleaned.append(line)

    # Ensure trailing newline
    if cleaned and cleaned[-1].strip() != "":
        cleaned.append("")

    return cleaned


def archive_items(
    base_dir: Path,
    archive_map: dict[tuple[int, int], dict[str, list[str]]],
    label: str,
) -> None:
    """Write archived items to monthly files."""
    for (year, month), sections in archive_map.items():
        archive_path = base_dir / str(year) / f"{month:02d}.md"
        count = write_archive_file(archive_path, year, month, sections)
        print(f"  Archived {count} {label} -> {archive_path}")


# --- Tasks processing ---


def rollover_due_date(line: str, today: date) -> str:
    """Replace past due date with today's date on active tasks."""
    if not ACTIVE_RE.match(line):
        return line
    if RECURRENCE_RE.search(line):
        return line
    m = DUE_RE.search(line)
    if not m:
        return line
    due = parse_date(m.group(1))
    if due < today:
        before = line[: m.start(1)]
        after = line[m.end(1) :]
        return before + today.isoformat() + after
    return line


def should_archive_task(line: str, cutoff: date) -> date | None:
    """Return completion date if task should be archived, else None."""
    if not DONE_RE.match(line):
        return None
    m = COMPLETION_RE.search(line)
    if not m:
        return None
    comp = parse_date(m.group(1))
    if comp <= cutoff:
        return comp
    return None


def process_tasks(vault_path: Path, today: date, cutoff: date) -> None:
    """Process tasks: rollover due dates and archive old completed tasks."""
    todos_dir = vault_path / "personal" / "todos"
    active_file = todos_dir / "active.md"

    if not active_file.exists():
        print(f"todos/active.md not found at {active_file}, skipping")
        return

    lines = active_file.read_text(encoding="utf-8").splitlines()

    new_lines: list[str] = []
    archive_map: dict[tuple[int, int], dict[str, list[str]]] = {}
    rollover_count = 0
    archive_count = 0

    for line in lines:
        comp_date = should_archive_task(line, cutoff)
        if comp_date is not None:
            key = (comp_date.year, comp_date.month)
            date_key = comp_date.isoformat()
            archive_map.setdefault(key, {})
            insert_into_archive(archive_map[key], date_key, line)
            archive_count += 1
            continue

        updated = rollover_due_date(line, today)
        if updated != line:
            rollover_count += 1
        new_lines.append(updated)

    new_lines = clean_empty_sections(new_lines)
    archive_items(todos_dir, archive_map, "tasks")
    active_file.write_text("\n".join(new_lines), encoding="utf-8")

    print(f"Tasks: {rollover_count} rolled over, {archive_count} archived")


# --- Events processing ---


def complete_past_event(line: str, today: date) -> str:
    """Replace active checkbox with completed checkbox on past events."""
    if not ACTIVE_RE.match(line):
        return line
    m = DATE_RE.search(line)
    if not m:
        return line
    event_date = parse_date(m.group(1))
    if event_date < today:
        return ACTIVE_RE.sub("- [x] ", line, count=1)
    return line


def should_archive_event(line: str, cutoff: date) -> date | None:
    """Return event date if event should be archived, else None."""
    if not DONE_RE.match(line):
        return None
    m = DATE_RE.search(line)
    if not m:
        return None
    event_date = parse_date(m.group(1))
    if event_date <= cutoff:
        return event_date
    return None


def process_events(vault_path: Path, today: date, cutoff: date) -> None:
    """Process events: auto-complete past events and archive old ones."""
    events_dir = vault_path / "personal" / "events"
    active_file = events_dir / "active.md"

    if not active_file.exists():
        print(f"events/active.md not found at {active_file}, skipping")
        return

    lines = active_file.read_text(encoding="utf-8").splitlines()

    new_lines: list[str] = []
    archive_map: dict[tuple[int, int], dict[str, list[str]]] = {}
    completion_count = 0
    archive_count = 0

    for line in lines:
        updated = complete_past_event(line, today)
        if updated != line:
            completion_count += 1

        event_date = should_archive_event(updated, cutoff)
        if event_date is not None:
            key = (event_date.year, event_date.month)
            date_key = event_date.isoformat()
            archive_map.setdefault(key, {})
            insert_into_archive(archive_map[key], date_key, updated)
            archive_count += 1
            continue

        new_lines.append(updated)

    new_lines = clean_empty_sections(new_lines)
    archive_items(events_dir, archive_map, "events")
    active_file.write_text("\n".join(new_lines), encoding="utf-8")

    print(f"Events: {completion_count} auto-completed, {archive_count} archived")


# --- Main ---


def main() -> None:
    if len(sys.argv) < 2:
        print(f"Usage: {sys.argv[0]} <vault-path> [gws-path]", file=sys.stderr)
        sys.exit(1)

    vault_path = Path(sys.argv[1])
    gws_path = sys.argv[2] if len(sys.argv) > 2 else None
    today = date.today()
    cutoff = today - timedelta(days=7)

    # Calendar sync (fault-tolerant: failure does not affect maintenance)
    if gws_path:
        try:
            sync_events_to_gcal(vault_path, gws_path)
        except Exception:
            traceback.print_exc()
            print("Google Calendar sync failed, continuing with maintenance")
    else:
        print("gws not provided, skipping calendar sync")

    failed = False
    for processor in [process_tasks, process_events]:
        try:
            processor(vault_path, today, cutoff)
        except Exception:
            traceback.print_exc()
            failed = True

    if failed:
        sys.exit(1)


if __name__ == "__main__":
    main()
