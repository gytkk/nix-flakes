import { useEffect, useMemo, useState } from 'react'
import { fetchJobs, fetchRuns, fetchSummary } from './api'
import type { CronJob, CronRun, CronSummary } from './types'

const REFRESH_MS = 15000

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

function statusTone(job: CronJob): 'good' | 'warn' | 'bad' | 'muted' | 'info' {
  if (!job.enabled) return 'muted'
  if (job.state.isRunning) return 'info'
  if ((job.state.lastRunStatus || '').toLowerCase().match(/fail|error/)) return 'bad'
  if ((job.state.lastRunStatus || '').toLowerCase().match(/success|ok|done/)) return 'good'
  return 'warn'
}

function statusLabel(job: CronJob): string {
  if (!job.enabled) return 'disabled'
  if (job.state.isRunning) return 'running'
  return job.state.lastRunStatus || 'unknown'
}

function Badge({ tone, children }: { tone: string; children: string }) {
  return <span className={`badge badge-${tone}`}>{children}</span>
}

function SummaryCard({ label, value, tone = 'default' }: { label: string; value: string | number; tone?: string }) {
  return (
    <div className={`summary-card summary-${tone}`}>
      <div className="summary-label">{label}</div>
      <div className="summary-value">{value}</div>
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
  }, [selectedJob?.jobId])

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

  const sortedJobs = useMemo(() => {
    return [...jobs].sort((a, b) => {
      const score = (job: CronJob) => {
        if (job.state.isRunning) return 0
        if ((job.state.lastRunStatus || '').toLowerCase().match(/fail|error/)) return 1
        if (job.enabled) return 2
        return 3
      }
      return score(a) - score(b) || a.name.localeCompare(b.name)
    })
  }, [jobs])

  return (
    <div className="page-shell">
      <header className="page-header">
        <div>
          <p className="eyebrow">OpenClaw</p>
          <h1>Cron Dashboard</h1>
          <p className="subtle">Read-only dashboard for OpenClaw scheduled jobs, exposed alongside Open WebUI.</p>
        </div>
        <div className="header-actions">
          <a className="ghost-button" href="/">
            Open WebUI
          </a>
          <div className="refresh-pill">refresh {REFRESH_MS / 1000}s</div>
        </div>
      </header>

      {error ? <div className="error-banner">{error}</div> : null}

      <section className="summary-grid">
        <SummaryCard label="Enabled" value={summary?.enabled ?? '—'} tone="good" />
        <SummaryCard label="Disabled" value={summary?.disabled ?? '—'} />
        <SummaryCard label="Running" value={summary?.running ?? '—'} tone="info" />
        <SummaryCard label="Failed last run" value={summary?.failedLastRun ?? '—'} tone="bad" />
        <SummaryCard label="Known upcoming runs" value={summary?.nextDueKnown ?? '—'} tone="warn" />
        <SummaryCard label="Source" value={summary?.source ?? '—'} />
      </section>

      <section className="panel jobs-panel">
        <div className="panel-header">
          <div>
            <h2>Jobs</h2>
            <p>{loading ? 'Loading…' : `${sortedJobs.length} jobs`}</p>
          </div>
          <Badge tone={summary?.schedulerEnabled ? 'good' : 'bad'}>
            {summary?.schedulerEnabled ? 'scheduler enabled' : 'scheduler disabled'}
          </Badge>
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
              {sortedJobs.map((job) => (
                <tr key={job.jobId} onClick={() => {
                  setSelectedJob(job)
                  void loadRuns(job.jobId)
                }}>
                  <td>
                    <div className="job-name">{job.name}</div>
                    <div className="job-id">{job.jobId}</div>
                  </td>
                  <td>{job.schedule.label}</td>
                  <td>{fmtTime(job.state.nextRunAt)}</td>
                  <td>{fmtTime(job.state.lastRunAt)}</td>
                  <td>
                    <Badge tone={statusTone(job)}>{statusLabel(job)}</Badge>
                  </td>
                  <td>{job.sessionTarget}</td>
                  <td>{job.delivery.mode}</td>
                </tr>
              ))}
            </tbody>
          </table>
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
                  {runs.map((run) => (
                    <div key={run.runId || `${run.startedAt}-${run.status}`} className="run-item">
                      <div className="run-head">
                        <Badge tone={String(run.status).match(/fail|error/) ? 'bad' : 'good'}>{run.status}</Badge>
                        <span className="subtle">{fmtTime(run.startedAt)}</span>
                      </div>
                      <div className="run-meta">
                        <span>finished: {fmtTime(run.finishedAt)}</span>
                        <span>delivery: {run.deliveryStatus || '—'}</span>
                      </div>
                      {run.error ? <div className="run-error">{run.error}</div> : null}
                    </div>
                  ))}
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
