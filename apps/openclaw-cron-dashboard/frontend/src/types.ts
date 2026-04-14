export type CronSummary = {
  schedulerEnabled: boolean
  enabled: number
  disabled: number
  running: number
  failedLastRun: number
  nextDueKnown: number
  generatedAt: string
  source: string
}

export type CronJob = {
  jobId: string
  name: string
  enabled: boolean
  sessionTarget: string
  schedule: {
    kind: string
    expr?: string
    tz?: string
    everyMs?: number
    at?: string
    label: string
  }
  payload: {
    kind: string
    message?: string
    model?: string
    thinking?: string
  }
  delivery: {
    mode: string
    channel?: string
    to?: string
    bestEffort?: boolean
  }
  state: {
    nextRunAt?: string
    lastRunAt?: string
    lastRunStatus?: string
    lastDeliveryStatus?: string
    isRunning?: boolean
  }
}

export type CronRun = {
  runId?: string
  status: string
  startedAt?: string
  finishedAt?: string
  deliveryStatus?: string
  error?: string
  sessionKey?: string
}
