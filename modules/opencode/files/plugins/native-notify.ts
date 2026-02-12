/**
 * Native macOS notification plugin for OpenCode.
 * Uses osascript directly — no external dependencies required.
 * Suppresses notifications when Ghostty is focused.
 */

import { exec } from "node:child_process"
import { promisify } from "node:util"

const execAsync = promisify(exec)

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

const TERMINAL_PROCESS_NAME = "Ghostty"

const SOUNDS = {
  idle: "Glass",
  error: "Basso",
  permission: "Submarine",
  question: "Submarine",
} as const

async function runOsascript(script: string): Promise<string | null> {
  try {
    const { stdout } = await execAsync(`osascript -e '${script}'`)
    return stdout.trim() || null
  } catch {
    return null
  }
}

async function isTerminalFocused(): Promise<boolean> {
  const frontmost = await runOsascript(
    'tell application "System Events" to get name of first application process whose frontmost is true',
  )
  if (!frontmost) return false
  return frontmost.toLowerCase() === TERMINAL_PROCESS_NAME.toLowerCase()
}

async function sendNotification(
  title: string,
  message: string,
  sound: string,
): Promise<void> {
  if (await isTerminalFocused()) return

  const safeTitle = title.replace(/"/g, '\\"')
  const safeMessage = message.replace(/"/g, '\\"')

  await runOsascript(
    `display notification "${safeMessage}" with title "${safeTitle}" sound name "${sound}"`,
  )
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
    // fall back to default
  }
  return "Task"
}

async function handleSessionIdle(
  client: OpencodeClient,
  sessionID: string,
): Promise<void> {
  const sessionTitle = await getSessionTitle(client, sessionID)
  await sendNotification("Ready for review", sessionTitle, SOUNDS.idle)
}

async function handleSessionError(
  client: OpencodeClient,
  sessionID: string,
  errorMessage?: string,
): Promise<void> {
  const sessionTitle = await getSessionTitle(client, sessionID)
  const message = errorMessage
    ? `${sessionTitle}: ${errorMessage}`
    : sessionTitle
  await sendNotification("Error occurred", message, SOUNDS.error)
}

async function handlePermissionAsked(): Promise<void> {
  await sendNotification(
    "Permission needed",
    "OpenCode is waiting for your approval",
    SOUNDS.permission,
  )
}

async function handleQuestionAsked(): Promise<void> {
  await sendNotification(
    "Question",
    "OpenCode has a question for you",
    SOUNDS.question,
  )
}

export const NativeNotifyPlugin = async ({
  client,
}: {
  client: OpencodeClient
}) => {
  return {
    "tool.execute.before": async (input: { tool: string }) => {
      if (input.tool === "question") {
        await handleQuestionAsked()
      }
    },
    event: async ({ event }: { event: Event }): Promise<void> => {
      switch (event.type) {
        case "session.idle": {
          const sessionID = event.properties.sessionID as string | undefined
          if (sessionID) {
            await handleSessionIdle(client, sessionID)
          }
          break
        }
        case "session.error": {
          const sessionID = event.properties.sessionID as string | undefined
          const error = event.properties.error
          const errorMessage =
            typeof error === "string" ? error : error ? String(error) : undefined
          if (sessionID) {
            await handleSessionError(client, sessionID, errorMessage)
          }
          break
        }
        case "permission.asked": {
          await handlePermissionAsked()
          break
        }
      }
    },
  }
}
