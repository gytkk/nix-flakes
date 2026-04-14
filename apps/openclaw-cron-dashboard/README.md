# OpenClaw Cron Dashboard

Small read-only dashboard for OpenClaw cron jobs.

## Stack

- Backend: FastAPI
- Frontend: React + Vite
- Reverse proxy: nginx under the existing Open WebUI origin

## Routes

- `/api/openclaw/cron/summary`
- `/api/openclaw/cron/jobs`
- `/api/openclaw/cron/jobs/:id/runs`
- `/apps/openclaw-cron/`
- `/admin/openclaw-cron` → redirects to `/apps/openclaw-cron/`

## Notes

The FastAPI bridge prefers `openclaw cron ... --json` and falls back to reading
`~/.openclaw/cron/jobs.json` plus run logs if CLI JSON output is unavailable.

The active backend entrypoint is `backend/app.py` and the active frontend entrypoint
is `frontend/src/main.tsx`.

Nix builds the frontend bundle from `frontend/package-lock.json` and injects the
final dist path into the backend with `OPENCLAW_CRON_FRONTEND_DIST`.

The backend serves a fallback HTML page only when the configured frontend dist path
is missing.
