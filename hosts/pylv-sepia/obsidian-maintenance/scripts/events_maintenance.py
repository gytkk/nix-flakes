"""Obsidian Events maintenance script.

Processes personal/events/active.md in an Obsidian vault:
1. Auto-completes past events on active items
2. Archives completed events older than 7 days to monthly files
"""

import re
import sys
from datetime import date, timedelta
from pathlib import Path

DATE_RE = re.compile(r"\[date::\s*(\d{4}-\d{2}-\d{2})\]")
ACTIVE_EVENT_RE = re.compile(r"^- \[ \] ")
DONE_EVENT_RE = re.compile(r"^- \[x\] ")
SECTION_HEADER_RE = re.compile(r"^### (\d{4}-\d{2}-\d{2})$")

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


def complete_past_event(line: str, today: date) -> str:
    """Replace active checkbox with completed checkbox on past events."""
    if not ACTIVE_EVENT_RE.match(line):
        return line
    m = DATE_RE.search(line)
    if not m:
        return line
    event_date = parse_date(m.group(1))
    if event_date < today:
        return ACTIVE_EVENT_RE.sub("- [x] ", line, count=1)
    return line


def should_archive(line: str, cutoff: date) -> date | None:
    """Return event date if event should be archived, else None."""
    if not DONE_EVENT_RE.match(line):
        return None
    m = DATE_RE.search(line)
    if not m:
        return None
    event_date = parse_date(m.group(1))
    if event_date <= cutoff:
        return event_date
    return None


def insert_into_archive(
    sections: dict[str, list[str]], date_key: str, event_line: str
) -> None:
    """Insert an event into the archive sections under date_key."""
    sections.setdefault(date_key, []).append(event_line)


def write_archive_file(
    archive_path: Path,
    year: int,
    month: int,
    new_sections: dict[str, list[str]],
) -> int:
    """Write or append events to a monthly archive file."""
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
            elif DONE_EVENT_RE.match(line) and current_section:
                existing_sections[current_section].append(line)
    else:
        header = f"# {year}년 {MONTH_NAMES[month]} 완료"

    # Merge new sections into existing
    count = 0
    for date_key, events in new_sections.items():
        existing_sections.setdefault(date_key, [])
        existing_sections[date_key].extend(events)
        count += len(events)

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
    """Remove section headers that have no event lines below them."""
    result: list[str] = []
    i = 0
    while i < len(lines):
        sm = SECTION_HEADER_RE.match(lines[i])
        if sm:
            # Look ahead for event lines before next section header or end
            has_events = False
            j = i + 1
            while j < len(lines):
                if SECTION_HEADER_RE.match(lines[j]):
                    break
                if lines[j].startswith("- ["):
                    has_events = True
                    break
                j += 1
            if has_events:
                result.append(lines[i])
            else:
                # Skip the header and any blank lines after it
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


def main() -> None:
    if len(sys.argv) != 2:
        print(f"Usage: {sys.argv[0]} <vault-path>", file=sys.stderr)
        sys.exit(1)

    vault_path = Path(sys.argv[1])
    events_dir = vault_path / "personal" / "events"
    active_file = events_dir / "active.md"

    if not active_file.exists():
        print(f"active.md not found at {active_file}, skipping")
        return

    today = date.today()
    cutoff = today - timedelta(days=7)

    lines = active_file.read_text(encoding="utf-8").splitlines()

    new_lines: list[str] = []
    # archive_events: {(year, month): {date_key: [event_lines]}}
    archive_events: dict[tuple[int, int], dict[str, list[str]]] = {}
    completion_count = 0
    archive_count = 0

    for line in lines:
        # Auto-complete past events on active items
        updated = complete_past_event(line, today)
        if updated != line:
            completion_count += 1

        # Check if completed event should be archived
        event_date = should_archive(updated, cutoff)
        if event_date is not None:
            key = (event_date.year, event_date.month)
            date_key = event_date.isoformat()
            archive_events.setdefault(key, {})
            insert_into_archive(archive_events[key], date_key, updated)
            archive_count += 1
            continue

        new_lines.append(updated)

    # Clean empty sections from active.md
    new_lines = clean_empty_sections(new_lines)

    # Write archives first to prevent event loss on failure
    for (year, month), sections in archive_events.items():
        archive_path = events_dir / str(year) / f"{month:02d}.md"
        count = write_archive_file(archive_path, year, month, sections)
        print(f"  Archived {count} events -> {archive_path}")

    # Write updated active.md only after archives succeed
    active_file.write_text("\n".join(new_lines), encoding="utf-8")

    print(
        f"Done: {completion_count} auto-completed,"
        f" {archive_count} archived"
    )


if __name__ == "__main__":
    main()
