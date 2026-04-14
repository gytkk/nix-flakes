import { useEffect, useMemo, useState } from 'react'
import { fetchJobs, fetchRuns, fetchSummary } from './api'
import type { CronJob, CronRun, CronSummary } from './types'

const REFRESH_MS = 15000

type StatusFilter = 'all' | 'running' | 'failed' | 'enabled' | 'disabled'

function fmtTime(value?: string): string {
  if (!value) return '—'
  const date = new Date(value)
  if (Number.isNaN(date.getTime())) return value
  return new Intl.DateTimeFormat(undefined, {
    year: 'numeric',
    month: 'short',
    day: '2-digit',
    hour: '2-digit',
    minute: '2-digit'
  }).format(date)
}

function fmtRelativeTime(value?: string): string {
  if (!value) return 'unknown'
  const date = new Date(value)
  if (Number.isNaN(date.getTime())) return 'unknown'

  const diffMs = date.getTime() - Date.now()
  const absMinutes = Math.round(Math.abs(diffMs) / 60000)

  if (absMinutes < 1) return diffMs >= 0 ? 'due now' : 'just ran'
  if (absMinutes < 60) return diffMs >= 0 ? `in ${absMinutes}m` : `${absMinutes}m ago`

  const absHours = Math.round(absMinutes / 60)
  if (absHours < 48) return diffMs >= 0 ? `in ${absHours}h` : `${absHours}h ago`

  const absDays = Math.round(absHours / 24)
  return diffMs >= 0 ? `in ${absDays}d` : `${absDays}d ago`
}

function isFailed(job: CronJob): boolean {
  return Boolean((job.state.lastRunStatus || '').toLowerCase().match(/fail|error/))
}

function statusTone(job: CronJob): 'good' | 'warn' | 'bad' | 'muted' | 'info' {
  if (!job.enabled) return 'muted'
  if (job.state.isRunning) return 'info'
  if (isFailed(job)) return 'bad'
  if ((job.state.lastRunStatus || '').toLowerCase().match(/success|ok|done/)) return 'good'
  return 'warn'
}

function statusLabel(job: CronJob): string {
  if (!job.enabled) return 'disabled'
  if (job.state.isRunning) return 'running'
  return job.state.lastRunStatus || 'unknown'
}

function matchesFilter(job: CronJob, filter: StatusFilter): boolean {
  switch (filter) {
    case 'running':
      return Boolean(job.state.isRunning)
    case 'failed':
      return isFailed(job)
    case 'enabled':
      return job.enabled
    case 'disabled':
      return !job.enabled
    default:
      return true
  }
}

function Badge({ tone, children }: { tone: string; children: string }) {
  return <span className={`badge badge-${tone}`}>{children}</span>
}

function SummaryCard({ label, value, tone = 'default', helper }: { label: string; value: string | number; tone?: string; helper?: string }) {
  return (
    <div className={`summary-card summary-${tone}`}>
      <div className="summary-label">{label}</div>
      <div className="summary-value">{value}</div>
      {helper ? <div className="summary-helper">{helper}</div> : null}
    </div>
  )
}

export function App() {
  const [summary, setSummary] = useState<CronSummary | null>(null)
  const [jobs, setJobs] = useState<CronJob[]>([])
  const [selectedJob, setSelectedJob] = useState<CronJob | null>(null)
  const [runs, setRuns] = useState<CronRun[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)
  const [runsLoading, setRunsLoading] = useState(false)
  const [refreshToken, setRefreshToken] = useState(0)
  const [search, setSearch] = useState('')
  const [statusFilter, setStatusFilter] = useState<StatusFilter>('all')
  const [lastUpdated, setLastUpdated] = useState<string | null>(null)

  useEffect(() => {
    let cancelled = false

    async function loadAll() {
      try {
        setError(null)
        const [nextSummary, nextJobs] = await Promise.all([fetchSummary(), fetchJobs()])
        if (cancelled) return
        setSummary(nextSummary)
        setJobs(nextJobs)
        setLoading(false)
        setLastUpdated(new Date().toISOString())

        if (selectedJob) {
          const stillExists = nextJobs.find((job) => job.jobId === selectedJob.jobId)
          if (stillExists) {
            setSelectedJob(stillExists)
            void loadRuns(stillExists.jobId)
          } else {
            setSelectedJob(null)
            setRuns([])
          }
        }
      } catch (err) {
        if (cancelled) return
        setLoading(false)
        setError(err instanceof Error ? err.message : String(err))
      }
    }

    void loadAll()
    const timer = window.setInterval(loadAll, REFRESH_MS)
    return () => {
      cancelled = true
      window.clearInterval(timer)
    }
  }, [refreshToken, selectedJob?.jobId])

  async function loadRuns(jobId: string) {
    setRunsLoading(true)
    try {
      setRuns(await fetchRuns(jobId))
    } catch (err) {
      setError(err instanceof Error ? err.message : String(err))
    } finally {
      setRunsLoading(false)
    }
  }

  const visibleJobs = useMemo(() => {
    const query = search.trim().toLowerCase()

    return [...jobs]
      .filter((job) => matchesFilter(job, statusFilter))
      .filter((job) => {
        if (!query) return true
        return [job.name, job.jobId, job.schedule.label, job.sessionTarget, job.delivery.mode]
          .join(' ')
          .toLowerCase()
          .includes(query)
      })
      .sort((a, b) => {
        const score = (job: CronJob) => {
          if (job.state.isRunning) return 0
          if (isFailed(job)) return 1
          if (job.enabled) return 2
          return 3
        }
        return score(a) - score(b) || a.name.localeCompare(b.name)
      })
  }, [jobs, search, statusFilter])

  return (
    <div className="page-shell">
      <header className="page-header">
        <div>
          <p className="eyebrow">OpenClaw</p>
          <h1>Cron Dashboard</h1>
          <p className="subtle">Read-only dashboard for scheduled jobs, mounted next to Open WebUI.</p>
        </div>
        <div className="header-actions">
          <div className="refresh-pill">auto refresh {REFRESH_MS / 1000}s</div>
          <div className="refresh-pill">updated {fmtRelativeTime(lastUpdated || undefined)}</div>
          <button className="ghost-button" onClick={() => setRefreshToken((value) => value + 1)}>
            Refresh now
          </button>
          <a className="ghost-button" href="/">
            Open WebUI
          </a>
        </div>
      </header>

      {error ? <div className="error-banner">{error}</div> : null}

      <section className="summary-grid">
        <SummaryCard label="Enabled" value={summary?.enabled ?? '—'} tone="good" />
        <SummaryCard label="Disabled" value={summary?.disabled ?? '—'} />
        <SummaryCard label="Running" value={summary?.running ?? '—'} tone="info" />
        <SummaryCard label="Failed last run" value={summary?.failedLastRun ?? '—'} tone="bad" />
        <SummaryCard label="Known upcoming runs" value={summary?.nextDueKnown ?? '—'} tone="warn" />
        <SummaryCard label="Source" value={summary?.source ?? '—'} helper={summary?.schedulerEnabled ? 'scheduler enabled' : 'scheduler disabled'} />
      </section>

      <section className="panel jobs-panel">
        <div className="panel-header panel-header-stack">
          <div>
            <h2>Jobs</h2>
            <p>{loading ? 'Loading…' : `${visibleJobs.length} visible · ${jobs.length} total`}</p>
          </div>

          <div className="toolbar">
            <input
              className="search-input"
              type="search"
              placeholder="Search jobs, schedule, delivery…"
              value={search}
              onChange={(event) => setSearch(event.target.value)}
            />

            <div className="filter-row">
              {(['all', 'running', 'failed', 'enabled', 'disabled'] as StatusFilter[]).map((filter) => (
                <button
                  key={filter}
                  className={`filter-chip ${statusFilter === filter ? 'filter-chip-active' : ''}`}
                  onClick={() => setStatusFilter(filter)}
                >
                  {filter}
                </button>
              ))}
            </div>
          </div>
        </div>

        <div className="table-wrap">
          <table>
            <thead>
              <tr>
                <th>Name</th>
                <th>Schedule</th>
                <th>Next run</th>
                <th>Last run</th>
                <th>Status</th>
                <th>Session</th>
                <th>Delivery</th>
              </tr>
            </thead>
            <tbody>
              {visibleJobs.map((job) => {
                const selected = selectedJob?.jobId === job.jobId
                return (
                  <tr
                    key={job.jobId}
                    className={selected ? 'row-selected' : ''}
                    onClick={() => {
                      setSelectedJob(job)
                      void loadRuns(job.jobId)
                    }}
                  >
                    <td>
                      <div className="job-name">{job.name}</div>
                      <div className="job-id">{job.jobId}</div>
                    </td>
                    <td>
                      <div>{job.schedule.label}</div>
                      {job.schedule.expr ? <div className="job-id">{job.schedule.expr}</div> : null}
                    </td>
                    <td>
                      <div>{fmtTime(job.state.nextRunAt)}</div>
                      <div className="job-id">{fmtRelativeTime(job.state.nextRunAt)}</div>
                    </td>
                    <td>
                      <div>{fmtTime(job.state.lastRunAt)}</div>
                      <div className="job-id">{fmtRelativeTime(job.state.lastRunAt)}</div>
                    </td>
                    <td>
                      <Badge tone={statusTone(job)}>{statusLabel(job)}</Badge>
                    </td>
                    <td>{job.sessionTarget}</td>
                    <td>{job.delivery.mode}</td>
                  </tr>
                )
              })}
            </tbody>
          </table>

          {!loading && !visibleJobs.length ? <div className="empty-state empty-state-table">No jobs match the current filters.</div> : null}
        </div>
      </section>

      <aside className={`drawer ${selectedJob ? 'drawer-open' : ''}`}>
        <div className="drawer-card">
          <div className="drawer-header">
            <div>
              <p className="eyebrow">Job detail</p>
              <h2>{selectedJob?.name ?? 'Select a job'}</h2>
            </div>
            <button className="ghost-button" onClick={() => setSelectedJob(null)}>
              Close
            </button>
          </div>

          {selectedJob ? (
            <>
              <div className="detail-grid">
                <div>
                  <span className="detail-label">Schedule</span>
                  <div>{selectedJob.schedule.label}</div>
                </div>
                <div>
                  <span className="detail-label">Delivery</span>
                  <div>{selectedJob.delivery.mode}</div>
                </div>
                <div>
                  <span className="detail-label">Payload</span>
                  <div>{selectedJob.payload.kind}</div>
                </div>
                <div>
                  <span className="detail-label">Model</span>
                  <div>{selectedJob.payload.model || 'default'}</div>
                </div>
                <div>
                  <span className="detail-label">Next run</span>
                  <div>{fmtTime(selectedJob.state.nextRunAt)}</div>
                </div>
                <div>
                  <span className="detail-label">Last run</span>
                  <div>{fmtTime(selectedJob.state.lastRunAt)}</div>
                </div>
              </div>

              <div className="message-box">{selectedJob.payload.message || 'No payload preview available.'}</div>

              <div className="runs-section">
                <div className="panel-header compact">
                  <div>
                    <h3>Recent runs</h3>
                    <p>{runsLoading ? 'Loading…' : `${runs.length} items`}</p>
                  </div>
                </div>
                <div className="runs-list">
                  {runs.map((run) => {
                    const failed = Boolean(String(run.status).match(/fail|error/i))
                    return (
                      <div key={run.runId || `${run.startedAt}-${run.status}`} className="run-item">
                        <div className="run-head">
                          <Badge tone={failed ? 'bad' : 'good'}>{run.status}</Badge>
                          <span className="subtle">{fmtTime(run.startedAt)}</span>
                        </div>
                        <div className="run-meta">
                          <span>finished: {fmtTime(run.finishedAt)}</span>
                          <span>delivery: {run.deliveryStatus || '—'}</span>
                          <span>session: {run.sessionKey || '—'}</span>
                        </div>
                        {run.error ? <div className="run-error">{run.error}</div> : null}
                      </div>
                    )
                  })}
                  {!runs.length && !runsLoading ? <div className="empty-state">No run history found.</div> : null}
                </div>
              </div>
            </>
          ) : (
            <div className="empty-state">Click a job row to inspect recent runs.</div>
          )}
        </div>
      </aside>
    </div>
  )
}
