"""Obsidian Tasks maintenance script.

Processes todos/active.md in an Obsidian vault:
1. Rolls over past-due dates on active tasks to today
2. Archives completed tasks older than 7 days to monthly files
"""

import re
import sys
from datetime import date, timedelta
from pathlib import Path

DUE_RE = re.compile(r"\[due::\s*(\d{4}-\d{2}-\d{2})\]")
COMPLETION_RE = re.compile(r"\[completion::\s*(\d{4}-\d{2}-\d{2})\]")
ACTIVE_TASK_RE = re.compile(r"^- \[ \] ")
DONE_TASK_RE = re.compile(r"^- \[x\] ")
SECTION_HEADER_RE = re.compile(r"^### (\d{4}-\d{2}-\d{2})$")
RECURRENCE_RE = re.compile(r"\[recurrence::|🔁")

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


def rollover_due_date(line: str, today: date) -> str:
    """Replace past due date with today's date on active tasks."""
    if not ACTIVE_TASK_RE.match(line):
        return line
    if RECURRENCE_RE.search(line):
        return line
    m = DUE_RE.search(line)
    if not m:
        return line
    due = parse_date(m.group(1))
    if due < today:
        before = line[:m.start(1)]
        after = line[m.end(1):]
        return before + today.isoformat() + after
    return line


def should_archive(line: str, cutoff: date) -> date | None:
    """Return completion date if task should be archived, else None."""
    if not DONE_TASK_RE.match(line):
        return None
    m = COMPLETION_RE.search(line)
    if not m:
        return None
    comp = parse_date(m.group(1))
    if comp <= cutoff:
        return comp
    return None


def insert_into_archive(
    sections: dict[str, list[str]], date_key: str, task_line: str
) -> None:
    """Insert a task into the archive sections under date_key."""
    sections.setdefault(date_key, []).append(task_line)


def write_archive_file(
    archive_path: Path,
    year: int,
    month: int,
    new_sections: dict[str, list[str]],
) -> int:
    """Write or append tasks to a monthly archive file."""
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
            elif DONE_TASK_RE.match(line) and current_section:
                existing_sections[current_section].append(line)
    else:
        header = f"# {year}년 {MONTH_NAMES[month]} 완료"

    # Merge new sections into existing
    count = 0
    for date_key, tasks in new_sections.items():
        existing_sections.setdefault(date_key, [])
        existing_sections[date_key].extend(tasks)
        count += len(tasks)

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
    """Remove section headers that have no task lines below them."""
    result: list[str] = []
    i = 0
    while i < len(lines):
        sm = SECTION_HEADER_RE.match(lines[i])
        if sm:
            # Look ahead for task lines before next section header or end
            has_tasks = False
            j = i + 1
            while j < len(lines):
                if SECTION_HEADER_RE.match(lines[j]):
                    break
                if lines[j].startswith("- ["):
                    has_tasks = True
                    break
                j += 1
            if has_tasks:
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
    todos_dir = vault_path / "personal" / "todos"
    active_file = todos_dir / "active.md"

    if not active_file.exists():
        print(f"active.md not found at {active_file}, skipping")
        return

    today = date.today()
    cutoff = today - timedelta(days=7)

    lines = active_file.read_text(encoding="utf-8").splitlines()

    new_lines: list[str] = []
    # archive_tasks: {(year, month): {date_key: [task_lines]}}
    archive_tasks: dict[tuple[int, int], dict[str, list[str]]] = {}
    rollover_count = 0
    archive_count = 0

    for line in lines:
        # Check if completed task should be archived
        comp_date = should_archive(line, cutoff)
        if comp_date is not None:
            key = (comp_date.year, comp_date.month)
            date_key = comp_date.isoformat()
            archive_tasks.setdefault(key, {})
            insert_into_archive(archive_tasks[key], date_key, line)
            archive_count += 1
            continue

        # Rollover due dates on active tasks
        updated = rollover_due_date(line, today)
        if updated != line:
            rollover_count += 1
        new_lines.append(updated)

    # Clean empty sections from active.md
    new_lines = clean_empty_sections(new_lines)

    # Write archives first to prevent task loss on failure
    for (year, month), sections in archive_tasks.items():
        archive_path = todos_dir / str(year) / f"{month:02d}.md"
        count = write_archive_file(archive_path, year, month, sections)
        print(f"  Archived {count} tasks -> {archive_path}")

    # Write updated active.md only after archives succeed
    active_file.write_text("\n".join(new_lines), encoding="utf-8")

    print(
        f"Done: {rollover_count} rolled over,"
        f" {archive_count} archived"
    )


if __name__ == "__main__":
    main()
