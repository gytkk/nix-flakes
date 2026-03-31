/**
 * Terminal-native notification plugin for OpenCode.
 * Ghostty: OSC 777 — ESC]777;notify;TITLE;MESSAGE BEL
 * WSL:     PowerShell toast via Windows notification API
 * Fallback: OSC 9  — ESC]9;TITLE: MESSAGE BEL
 */

import { writeFileSync } from "node:fs"
import { execFile, execFileSync } from "node:child_process"

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

type TerminalType = "ghostty" | "wsl" | "other"

const NOTIFICATION_DEDUP_WINDOW_MS = 15000
const recentNotifications = new Map<string, number>()

function hasGhosttyInParentProcessTree(): boolean {
  if (process.platform !== "darwin") {
    return false
  }

  let currentPid = process.pid
  for (let depth = 0; depth < 8 && currentPid > 1; depth += 1) {
    try {
      const command = execFileSync("ps", ["-o", "comm=", "-p", String(currentPid)], {
        encoding: "utf8",
      }).trim().toLowerCase()
      if (command.includes("ghostty")) {
        return true
      }

      const parentPidRaw = execFileSync("ps", ["-o", "ppid=", "-p", String(currentPid)], {
        encoding: "utf8",
      }).trim()
      const parentPid = Number.parseInt(parentPidRaw, 10)
      if (!Number.isFinite(parentPid) || parentPid <= 1 || parentPid === currentPid) {
        break
      }
      currentPid = parentPid
    } catch {
      break
    }
  }

  return false
}

function hasRunningGhosttyApp(): boolean {
  if (process.platform !== "darwin") {
    return false
  }

  try {
    const result = execFileSync(
      "osascript",
      ["-e", 'if application "Ghostty" is running then return "true"'],
      { encoding: "utf8" },
    ).trim().toLowerCase()
    return result === "true"
  } catch {
    return false
  }
}

function detectTerminal(): TerminalType {
  const termProgram = (process.env.TERM_PROGRAM ?? "").toLowerCase()
  const term = (process.env.TERM ?? "").toLowerCase()

  if (
    termProgram === "ghostty"
    || termProgram === "xterm-ghostty"
    || term === "xterm-ghostty"
    || process.env.GHOSTTY_RESOURCES_DIR
  ) {
    return "ghostty"
  }
  if (process.env.WSL_DISTRO_NAME) {
    return "wsl"
  }
  if (hasGhosttyInParentProcessTree()) {
    return "ghostty"
  }
  if (hasRunningGhosttyApp()) {
    return "ghostty"
  }
  return "other"
}

function buildOscSequence(terminal: TerminalType, title: string, message: string): string {
  const safeTitle = title.replace(/[;\x07\x1b]/g, "")
  const safeMessage = message.replace(/[;\x07\x1b]/g, "")
  if (terminal === "ghostty") {
    return `\x1b]777;notify;${safeTitle};${safeMessage}\x07`
  }
  return `\x1b]9;${safeTitle}: ${safeMessage}\x07`
}

function sendWslToast(title: string, message: string): void {
  const safeTitle = title.replace(/'/g, "''").replace(/`/g, "``")
  const safeMessage = message.replace(/'/g, "''").replace(/`/g, "``")
  const script = [
    "[Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime] | Out-Null",
    "[Windows.Data.Xml.Dom.XmlDocument, Windows.Data.Xml.Dom.XmlDocument, ContentType = WindowsRuntime] | Out-Null",
    `$xml = '<toast><visual><binding template="ToastText02"><text id="1">${safeTitle}</text><text id="2">${safeMessage}</text></binding></visual></toast>'`,
    "$doc = [Windows.Data.Xml.Dom.XmlDocument]::new()",
    "$doc.LoadXml($xml)",
    '$notifier = [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier("OpenCode")',
    "$notifier.Show([Windows.UI.Notifications.ToastNotification]::new($doc))",
  ].join("; ")

  execFile("powershell.exe", ["-NoProfile", "-NonInteractive", "-Command", script], { timeout: 10000 }, () => {})
}

function sendMacOsNotification(title: string, message: string): void {
  execFile(
    "osascript",
    [
      "-e",
      `display notification ${JSON.stringify(message)} with title ${JSON.stringify(title)}`,
    ],
    { timeout: 10000 },
    () => {},
  )
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

  recentNotifications.set(key, now)
  return true
}

function sendNotification(terminal: TerminalType, title: string, message: string): void {
  const dedupKey = `${terminal}:${title}:${message}`
  if (!shouldSendNotification(dedupKey)) {
    return
  }

  if (terminal === "wsl") {
    sendWslToast(title, message)
    return
  }
  if (process.platform === "darwin" && terminal !== "ghostty") {
    sendMacOsNotification(title, message)
    return
  }
  try {
    writeFileSync("/dev/tty", buildOscSequence(terminal, title, message))
  } catch {
    return
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
    const messages = response.body
    const firstUserMessage = messages.find(
      (m: SessionMessage) => m.role === "user",
    )
    if (firstUserMessage?.parts) {
      const textPart = firstUserMessage.parts.find(
        (p: { type: string; content?: string }) => p.type === "text",
      )
      if (textPart?.content) {
        const content = textPart.content.trim()
        return content.length > 80 ? content.slice(0, 77) + "..." : content
      }
    }
  } catch {
    return "Task"
  }
  return "Task"
}

export const NativeNotifyPlugin = async ({
  client,
}: {
  client: OpencodeClient
}) => {
  const terminal = detectTerminal()

  return {
    event: async ({ event }: { event: Event }): Promise<void> => {
      switch (event.type) {
        case "session.idle": {
          const sessionID = event.properties.sessionID as string | undefined
          if (sessionID) {
            const title = await getSessionTitle(client, sessionID)
            sendNotification(terminal, "Ready for review", title)
          }
          break
        }
        case "session.error": {
          const sessionID = event.properties.sessionID as string | undefined
          const error = event.properties.error
          const errorMsg =
            typeof error === "string" ? error : error ? String(error) : undefined
          if (sessionID) {
            const title = await getSessionTitle(client, sessionID)
            const message = errorMsg ? `${title}: ${errorMsg}` : title
            sendNotification(terminal, "Error occurred", message)
          }
          break
        }
      }
    },
  }
}
