import { writeFileSync } from "node:fs"
import { execFile } from "node:child_process"

interface Event {
  type: string
  properties: Record<string, unknown>
}

interface SessionMessage {
  role: string
  parts?: Array<{ type: string; content?: string }>
}

interface OpencodeClient {
  session: {
    messages: (args: {
      params: { sessionID: string }
    }) => Promise<{ body: SessionMessage[] }>
  }
}

interface NotificationPayload {
  dedupKey: string
  title: string
  message: string
}

const NOTIFICATION_DEDUP_WINDOW_MS = 15000
const recentNotifications = new Map<string, number>()

function getString(value: unknown): string | undefined {
  return typeof value === "string" && value.length > 0 ? value : undefined
}

function normalizeWhitespace(value: string): string {
  return value.replace(/[\x00-\x1f\x7f]+/g, " ").replace(/\s+/g, " ").trim()
}

function isGhosttyTerminal(): boolean {
  const termProgram = (process.env.TERM_PROGRAM ?? "").toLowerCase()
  const term = (process.env.TERM ?? "").toLowerCase()

  return (
    termProgram === "ghostty"
    || termProgram === "xterm-ghostty"
    || term === "xterm-ghostty"
    || Boolean(process.env.GHOSTTY_RESOURCES_DIR)
  )
}

function isInsideZellij(): boolean {
  return Boolean(process.env.ZELLIJ || process.env.ZELLIJ_SESSION_NAME)
}

function sanitizeOscText(value: string): string {
  return normalizeWhitespace(value.replace(/[\x1b\x07]/g, ""))
}

function formatGhosttyText(title: string, message: string): string {
  return sanitizeOscText(`OpenCode: ${title} — ${message}`)
}

function shouldSendNotification(key: string): boolean {
  const now = Date.now()

  for (const [existingKey, timestamp] of recentNotifications.entries()) {
    if (now - timestamp > NOTIFICATION_DEDUP_WINDOW_MS) {
      recentNotifications.delete(existingKey)
    }
  }

  const lastSentAt = recentNotifications.get(key)
  if (typeof lastSentAt === "number" && now - lastSentAt < NOTIFICATION_DEDUP_WINDOW_MS) {
    return false
  }

  return true
}

function markNotificationSent(key: string): void {
  recentNotifications.set(key, Date.now())
}

function writeGhosttyDesktopNotification(title: string, message: string): boolean {
  const text = formatGhosttyText(title, message)
  if (!text) {
    return false
  }

  try {
    writeFileSync("/dev/tty", `\x1b]9;${text}\x1b\\`)
    return true
  } catch {
    return false
  }
}

function sendMacOsNotification(title: string, message: string): boolean {
  try {
    execFile(
      "osascript",
      [
        "-e",
        `display notification ${JSON.stringify(message)} with title ${JSON.stringify(title)}`,
      ],
      { timeout: 10000 },
      () => {},
    )
    return true
  } catch {
    return false
  }
}

function escapeXml(value: string): string {
  return value
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&apos;")
}

function sendWslToast(title: string, message: string): boolean {
  const safeTitle = escapeXml(normalizeWhitespace(title)).replace(/'/g, "''").replace(/`/g, "``")
  const safeMessage = escapeXml(normalizeWhitespace(message)).replace(/'/g, "''").replace(/`/g, "``")
  const script = [
    "[Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime] | Out-Null",
    "[Windows.Data.Xml.Dom.XmlDocument, Windows.Data.Xml.Dom.XmlDocument, ContentType = WindowsRuntime] | Out-Null",
    `$xml = '<toast><visual><binding template="ToastText02"><text id="1">${safeTitle}</text><text id="2">${safeMessage}</text></binding></visual></toast>'`,
    "$doc = [Windows.Data.Xml.Dom.XmlDocument]::new()",
    "$doc.LoadXml($xml)",
    '$notifier = [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier("OpenCode")',
    "$notifier.Show([Windows.UI.Notifications.ToastNotification]::new($doc))",
  ].join("; ")

  try {
    execFile("powershell.exe", ["-NoProfile", "-NonInteractive", "-Command", script], { timeout: 10000 }, () => {})
    return true
  } catch {
    return false
  }
}

function deliverNotification(dedupKey: string, title: string, message: string): void {
  if (!shouldSendNotification(dedupKey)) {
    return
  }

  if (process.env.WSL_DISTRO_NAME) {
    if (sendWslToast(title, message)) {
      markNotificationSent(dedupKey)
    }
    return
  }

  if (process.platform === "darwin") {
    if (isGhosttyTerminal() && !isInsideZellij() && writeGhosttyDesktopNotification(title, message)) {
      markNotificationSent(dedupKey)
      return
    }

    if (sendMacOsNotification(title, message)) {
      markNotificationSent(dedupKey)
    }
    return
  }

  if (writeGhosttyDesktopNotification(title, message)) {
    markNotificationSent(dedupKey)
  }
}

async function getSessionTitle(
  client: OpencodeClient,
  sessionID: string,
): Promise<string> {
  try {
    const response = await client.session.messages({
      params: { sessionID },
    })
    const firstUserMessage = response.body.find((message) => message.role === "user")
    const textPart = firstUserMessage?.parts?.find((part) => part.type === "text")
    const content = getString(textPart?.content)

    if (!content) {
      return "Task"
    }

    const normalizedContent = normalizeWhitespace(content)
    return normalizedContent.length > 80 ? `${normalizedContent.slice(0, 77)}...` : normalizedContent
  } catch {
    return "Task"
  }
}

async function buildNotificationPayload(
  client: OpencodeClient,
  event: Event,
): Promise<NotificationPayload | null> {
  const sessionID = getString(event.properties.sessionID)
  if (!sessionID) {
    return null
  }

  const sessionTitle = await getSessionTitle(client, sessionID)

  if (event.type === "session.idle") {
    return {
      dedupKey: `${sessionID}:idle`,
      title: "Ready for review",
      message: sessionTitle,
    }
  }

  if (event.type === "session.error") {
    const errorMessage = getString(event.properties.error)

    return {
      dedupKey: `${sessionID}:error:${normalizeWhitespace(errorMessage ?? "")}`,
      title: "Error occurred",
      message: errorMessage ? `${sessionTitle}: ${normalizeWhitespace(errorMessage)}` : sessionTitle,
    }
  }

  return null
}

export const NativeNotifyPlugin = async ({
  client,
}: {
  client: OpencodeClient
}) => ({
  event: async ({ event }: { event: Event }): Promise<void> => {
    const payload = await buildNotificationPayload(client, event)
    if (!payload) {
      return
    }

    deliverNotification(payload.dedupKey, payload.title, payload.message)
  },
})
