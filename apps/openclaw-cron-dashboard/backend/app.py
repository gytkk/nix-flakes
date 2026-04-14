from __future__ import annotations

import json
import os
import subprocess
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

from fastapi import FastAPI, HTTPException, Query
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import FileResponse, HTMLResponse, RedirectResponse
from fastapi.staticfiles import StaticFiles

APP_ROOT = Path(__file__).resolve().parent
FRONTEND_DIST = Path(
    os.environ.get("OPENCLAW_CRON_DASHBOARD_FRONTEND_DIST", str((APP_ROOT.parent / "frontend" / "dist").resolve()))
).expanduser()
STATE_DIR = Path(os.environ.get("OPENCLAW_STATE_DIR", str(Path.home() / ".openclaw"))).expanduser()
CRON_DIR = STATE_DIR / "cron"
RUNS_DIR = CRON_DIR / "runs"
JOBS_FILE = CRON_DIR / "jobs.json"
OPENCLAW_BIN = os.environ.get("OPENCLAW_BIN", "openclaw")
CORS_ALLOW_ORIGINS = [
    origin.strip()
    for origin in os.environ.get("OPENCLAW_CRON_DASHBOARD_CORS", "http://127.0.0.1:8787;https://openwebui.pylv.dev").split(";")
    if origin.strip()
]

app = FastAPI(title="OpenClaw Cron Dashboard", version="0.1.0")
app.add_middleware(
    CORSMiddleware,
    allow_origins=CORS_ALLOW_ORIGINS,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@dataclass
class CommandResult:
    ok: bool
    data: Any | None = None
    error: str | None = None
    source: str | None = None


def utc_now_iso() -> str:
    return datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")


def parse_json_text(text: str) -> Any:
    text = text.strip()
    if not text:
        return None
    return json.loads(text)


def run_openclaw_json(args: list[str]) -> CommandResult:
    command = [OPENCLAW_BIN, *args, "--json"]
    try:
        completed = subprocess.run(
            command,
            check=True,
            capture_output=True,
            text=True,
            timeout=20,
            env=os.environ.copy(),
        )
    except FileNotFoundError:
        return CommandResult(ok=False, error=f"command not found: {OPENCLAW_BIN}")
    except subprocess.CalledProcessError as exc:
        stderr = (exc.stderr or "").strip() or (exc.stdout or "").strip()
        return CommandResult(ok=False, error=stderr or f"command failed: {' '.join(command)}")
    except subprocess.TimeoutExpired:
        return CommandResult(ok=False, error=f"timeout running: {' '.join(command)}")

    try:
        return CommandResult(ok=True, data=parse_json_text(completed.stdout), source="cli")
    except Exception as exc:  # noqa: BLE001
        return CommandResult(ok=False, error=f"invalid json from CLI: {exc}")


def safe_read_json(path: Path, default: Any) -> Any:
    if not path.exists():
        return default
    try:
        return json.loads(path.read_text())
    except Exception:  # noqa: BLE001
        return default


def read_jsonl(path: Path, limit: int | None = None) -> list[dict[str, Any]]:
    if not path.exists():
        return []

    items: list[dict[str, Any]] = []
    for line in path.read_text().splitlines():
        line = line.strip()
        if not line:
            continue
        try:
            item = json.loads(line)
        except Exception:  # noqa: BLE001
            continue
        if isinstance(item, dict):
            items.append(item)

    if limit is not None:
        return items[-limit:]
    return items


def as_items(value: Any) -> list[Any]:
    if isinstance(value, list):
        return value
    if isinstance(value, dict):
        if isinstance(value.get("items"), list):
            return value["items"]
        if isinstance(value.get("jobs"), list):
            return value["jobs"]
        if isinstance(value.get("runs"), list):
            return value["runs"]
    return []


def first(*values: Any) -> Any:
    for value in values:
        if value is None:
            continue
        if isinstance(value, str) and not value.strip():
            continue
        return value
    return None


def to_bool(value: Any, default: bool = False) -> bool:
    if isinstance(value, bool):
        return value
    if isinstance(value, (int, float)):
        return bool(value)
    if isinstance(value, str):
        lowered = value.strip().lower()
        if lowered in {"1", "true", "yes", "on", "enabled"}:
            return True
        if lowered in {"0", "false", "no", "off", "disabled"}:
            return False
    return default


def schedule_label(schedule: dict[str, Any]) -> str:
    kind = first(schedule.get("kind"), schedule.get("type"), "unknown")
    if kind == "cron":
        expr = first(schedule.get("expr"), schedule.get("cron"), "?")
        tz = schedule.get("tz")
        return f"{expr} ({tz})" if tz else str(expr)
    if kind == "every":
        every_ms = first(schedule.get("everyMs"), schedule.get("intervalMs"))
        return f"Every {every_ms}ms" if every_ms is not None else "Every interval"
    if kind == "at":
        at = first(schedule.get("at"), schedule.get("time"), "?")
        return f"At {at}"
    return str(kind)


def normalize_run(run: dict[str, Any]) -> dict[str, Any]:
    status = first(
        run.get("status"),
        run.get("state"),
        run.get("result"),
        run.get("outcome"),
        "unknown",
    )
    return {
        "runId": first(run.get("runId"), run.get("id"), run.get("taskId")),
        "status": status,
        "startedAt": first(run.get("startedAt"), run.get("started_at"), run.get("createdAt")),
        "finishedAt": first(run.get("finishedAt"), run.get("finished_at"), run.get("endedAt"), run.get("completedAt")),
        "deliveryStatus": first(run.get("deliveryStatus"), run.get("delivery_status")),
        "error": first(run.get("error"), run.get("message"), run.get("summary")),
        "sessionKey": first(run.get("sessionKey"), run.get("session_key")),
        "raw": run,
    }


def normalize_job(job: dict[str, Any]) -> dict[str, Any]:
    schedule = job.get("schedule") if isinstance(job.get("schedule"), dict) else {}
    delivery = job.get("delivery") if isinstance(job.get("delivery"), dict) else {}
    state = job.get("state") if isinstance(job.get("state"), dict) else {}
    payload = job.get("payload") if isinstance(job.get("payload"), dict) else {}

    enabled = to_bool(first(job.get("enabled"), state.get("enabled")), default=True)
    last_run_status = first(
        state.get("lastRunStatus"),
        state.get("last_status"),
        job.get("lastRunStatus"),
    )

    return {
        "jobId": first(job.get("jobId"), job.get("id"), job.get("name")),
        "name": first(job.get("name"), job.get("jobId"), job.get("id"), "Unnamed job"),
        "enabled": enabled,
        "schedule": {
            "kind": first(schedule.get("kind"), schedule.get("type"), "unknown"),
            "expr": first(schedule.get("expr"), schedule.get("cron")),
            "tz": schedule.get("tz"),
            "everyMs": first(schedule.get("everyMs"), schedule.get("intervalMs")),
            "at": first(schedule.get("at"), schedule.get("time")),
            "label": first(schedule.get("label"), schedule_label(schedule)),
        },
        "sessionTarget": first(job.get("sessionTarget"), job.get("session"), payload.get("sessionTarget"), "unknown"),
        "payload": {
            "kind": first(payload.get("kind"), "unknown"),
            "message": first(payload.get("message"), payload.get("text"), payload.get("systemEvent")),
            "model": payload.get("model"),
            "thinking": payload.get("thinking"),
        },
        "delivery": {
            "mode": first(delivery.get("mode"), job.get("deliveryMode"), "none"),
            "channel": first(delivery.get("channel"), delivery.get("provider")),
            "to": first(delivery.get("to"), delivery.get("target")),
            "bestEffort": to_bool(delivery.get("bestEffort"), default=False),
        },
        "state": {
            "nextRunAt": first(state.get("nextRunAt"), state.get("next_run_at"), job.get("nextRunAt")),
            "lastRunAt": first(state.get("lastRunAt"), state.get("last_run_at"), job.get("lastRunAt")),
            "lastRunStatus": last_run_status,
            "lastDeliveryStatus": first(state.get("lastDeliveryStatus"), state.get("last_delivery_status")),
            "isRunning": to_bool(first(state.get("isRunning"), state.get("running"), False), default=False),
        },
        "raw": job,
    }


def load_jobs_from_files() -> list[dict[str, Any]]:
    jobs = safe_read_json(JOBS_FILE, default=[])
    return as_items(jobs)


def load_runs_from_file(job_id: str, limit: int = 20) -> list[dict[str, Any]]:
    return read_jsonl(RUNS_DIR / f"{job_id}.jsonl", limit=limit)


def get_jobs() -> tuple[list[dict[str, Any]], str, dict[str, Any] | None]:
    cli_jobs = run_openclaw_json(["cron", "list"])
    if cli_jobs.ok:
        cli_status = run_openclaw_json(["cron", "status"])
        raw_status = cli_status.data if cli_status.ok and isinstance(cli_status.data, dict) else None
        return as_items(cli_jobs.data), "cli", raw_status

    jobs = load_jobs_from_files()
    return jobs, "file", None


def get_runs(job_id: str, limit: int = 20) -> tuple[list[dict[str, Any]], str]:
    cli_runs = run_openclaw_json(["cron", "runs", "--id", job_id, "--limit", str(limit)])
    if cli_runs.ok:
        return as_items(cli_runs.data), "cli"
    return load_runs_from_file(job_id, limit=limit), "file"


def summarize_jobs(jobs: list[dict[str, Any]], raw_status: dict[str, Any] | None) -> dict[str, Any]:
    normalized = [normalize_job(job) for job in jobs]
    enabled = sum(1 for job in normalized if job["enabled"])
    disabled = sum(1 for job in normalized if not job["enabled"])
    running = sum(1 for job in normalized if job["state"]["isRunning"])
    failed_last_run = sum(1 for job in normalized if str(job["state"]["lastRunStatus"] or "").lower() in {"failed", "error", "errored"})
    due_soon = sum(1 for job in normalized if job["enabled"] and job["state"]["nextRunAt"])

    scheduler_enabled = True
    if raw_status:
        scheduler_enabled = to_bool(first(raw_status.get("enabled"), raw_status.get("schedulerEnabled"), True), default=True)

    return {
        "schedulerEnabled": scheduler_enabled,
        "enabled": enabled,
        "disabled": disabled,
        "running": running,
        "failedLastRun": failed_last_run,
        "nextDueKnown": due_soon,
        "generatedAt": utc_now_iso(),
    }


@app.get("/")
def root() -> RedirectResponse:
    return RedirectResponse(url="/apps/openclaw-cron/", status_code=307)


@app.get("/health")
def health() -> dict[str, Any]:
    jobs, source, _ = get_jobs()
    return {
        "ok": True,
        "source": source,
        "jobs": len(jobs),
        "generatedAt": utc_now_iso(),
    }


@app.get("/api/openclaw/cron/summary")
def cron_summary() -> dict[str, Any]:
    jobs, source, raw_status = get_jobs()
    summary = summarize_jobs(jobs, raw_status)
    summary["source"] = source
    summary["rawStatus"] = raw_status
    return summary


@app.get("/api/openclaw/cron/jobs")
def cron_jobs() -> dict[str, Any]:
    jobs, source, raw_status = get_jobs()
    items = [normalize_job(job) for job in jobs]
    return {
        "items": items,
        "count": len(items),
        "source": source,
        "rawStatus": raw_status,
        "generatedAt": utc_now_iso(),
    }


@app.get("/api/openclaw/cron/jobs/{job_id}/runs")
def cron_job_runs(job_id: str, limit: int = Query(default=20, ge=1, le=200)) -> dict[str, Any]:
    jobs, _, _ = get_jobs()
    known_ids = {normalize_job(job)["jobId"] for job in jobs}
    if job_id not in known_ids and not (RUNS_DIR / f"{job_id}.jsonl").exists():
        raise HTTPException(status_code=404, detail=f"Unknown job id: {job_id}")

    runs, source = get_runs(job_id, limit=limit)
    return {
        "jobId": job_id,
        "items": [normalize_run(run) for run in runs],
        "count": len(runs),
        "source": source,
        "generatedAt": utc_now_iso(),
    }


@app.get("/apps/openclaw-cron")
@app.get("/apps/openclaw-cron/")
def dashboard_index() -> HTMLResponse | FileResponse:
    index_file = FRONTEND_DIST / "index.html"
    if index_file.exists():
        return FileResponse(index_file)
    return HTMLResponse(
        """
<!doctype html>
<html lang=\"en\">
  <head>
    <meta charset=\"utf-8\" />
    <meta name=\"viewport\" content=\"width=device-width, initial-scale=1\" />
    <title>OpenClaw Cron Dashboard</title>
    <style>
      body { font-family: Inter, system-ui, sans-serif; margin: 0; background: #0b1120; color: #e5e7eb; }
      main { max-width: 720px; margin: 72px auto; padding: 24px; }
      .card { background: #111827; border: 1px solid #1f2937; border-radius: 16px; padding: 24px; }
      code { background: #0f172a; padding: 2px 6px; border-radius: 6px; }
      a { color: #93c5fd; }
    </style>
  </head>
  <body>
    <main>
      <div class=\"card\">
        <h1>OpenClaw Cron Dashboard</h1>
        <p>The FastAPI bridge is running, but the React/Vite frontend hasn't been built yet.</p>
        <p>Expected static bundle path: <code>{frontend_dist}</code></p>
        <p>API is ready at <a href=\"/api/openclaw/cron/summary\">/api/openclaw/cron/summary</a>.</p>
      </div>
    </main>
  </body>
</html>
        """.strip().format(frontend_dist=FRONTEND_DIST)
    )


frontend_assets = FRONTEND_DIST / "assets"
if frontend_assets.exists():
    app.mount("/apps/openclaw-cron/assets", StaticFiles(directory=frontend_assets), name="openclaw-cron-assets")
