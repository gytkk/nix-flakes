# openclaw-cron-dashboard

Read-only OpenClaw cron dashboard intended to sit next to Open WebUI.

## Shape

- **backend/** — FastAPI bridge that reads OpenClaw cron data
- **frontend/** — React + Vite dashboard UI
- **hosts/pylv-onyx/openclaw-cron-dashboard.nix** — NixOS service + nginx wiring

## URLs

When the host module is enabled:

- `/admin/openclaw-cron` → lightweight entry route from the Open WebUI side
- `/apps/openclaw-cron/` → actual dashboard UI
- `/api/openclaw/cron/summary`
- `/api/openclaw/cron/jobs`
- `/api/openclaw/cron/jobs/:jobId/runs`

## Data source strategy

The bridge tries, in order:

1. `openclaw cron ... --json`
2. fallback reads from `~/.openclaw/cron/jobs.json`
3. fallback run history reads from `~/.openclaw/cron/runs/*.jsonl`

That keeps the dashboard usable even if direct CLI access is incomplete.

## Local frontend dev

```bash
cd apps/openclaw-cron-dashboard/frontend
npm install
npm run dev
```

Vite proxies `/api/openclaw/cron/*` to `http://127.0.0.1:18813`.

## Local backend dev

```bash
cd apps/openclaw-cron-dashboard/backend
uvicorn app:app --reload --host 127.0.0.1 --port 18813
```

Useful environment variables:

- `OPENCLAW_BIN`
- `OPENCLAW_STATE_DIR`
- `OPENCLAW_CRON_DASHBOARD_CORS`
- `OPENCLAW_CRON_DASHBOARD_FRONTEND_DIST`

## UI goals

- feels like a small embedded admin app, not a chat tool result
- highlights failures/running jobs first
- exposes recent runs in a side drawer
- stays read-only for now
