/**
 * Terminal-native notification plugin for OpenCode.
 * Ghostty: OSC 777 — ESC]777;notify;TITLE;MESSAGE BEL
 * Fallback: OSC 9  — ESC]9;TITLE: MESSAGE BEL
 */

import { writeFileSync } from "node:fs"

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

type TerminalType = "ghostty" | "other"

function detectTerminal(): TerminalType {
  const termProgram = (process.env.TERM_PROGRAM ?? "").toLowerCase()
  if (termProgram === "ghostty" || process.env.GHOSTTY_RESOURCES_DIR) {
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

function sendNotification(terminal: TerminalType, title: string, message: string): void {
  try {
    writeFileSync("/dev/tty", buildOscSequence(terminal, title, message))
  } catch {
    // /dev/tty unavailable (e.g. not running in a terminal)
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
    // fall back to default
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
    "tool.execute.before": async (input: { tool: string }) => {
      if (input.tool === "question") {
        sendNotification(terminal, "Question", "OpenCode has a question for you")
      }
    },
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
        case "permission.asked": {
          sendNotification(terminal, "Permission needed", "Waiting for your approval")
          break
        }
      }
    },
  }
}
