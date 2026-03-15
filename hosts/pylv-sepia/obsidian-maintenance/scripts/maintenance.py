"""Obsidian maintenance script.

Processes active.md files in an Obsidian vault:
1. Tasks: Rolls over past-due dates, archives completed tasks older than 7 days
2. Events: Auto-completes past events, archives completed events older than 7 days
"""

import re
import sys
import traceback
from datetime import date, timedelta
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
    if len(sys.argv) != 2:
        print(f"Usage: {sys.argv[0]} <vault-path>", file=sys.stderr)
        sys.exit(1)

    vault_path = Path(sys.argv[1])
    today = date.today()
    cutoff = today - timedelta(days=7)

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
