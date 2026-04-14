import type { CronJob, CronRun, CronSummary } from './types'

async function getJson<T>(url: string): Promise<T> {
  const res = await fetch(url, { headers: { Accept: 'application/json' } })
  if (!res.ok) {
    throw new Error(`${res.status} ${res.statusText}`)
  }
  return await res.json()
}

export async function fetchSummary(): Promise<CronSummary> {
  return getJson('/api/openclaw/cron/summary')
}

export async function fetchJobs(): Promise<CronJob[]> {
  const data = await getJson<{ items: CronJob[] }>('/api/openclaw/cron/jobs')
  return data.items
}

export async function fetchRuns(jobId: string): Promise<CronRun[]> {
  const data = await getJson<{ items: CronRun[] }>(`/api/openclaw/cron/jobs/${encodeURIComponent(jobId)}/runs?limit=15`)
  return data.items
}
