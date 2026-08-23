from __future__ import annotations

import json
import logging
import os
import subprocess
import threading
from pathlib import Path
from typing import Any

logger = logging.getLogger(__name__)
_active_processes: set[subprocess.Popen[bytes]] = set()
_process_lock = threading.Lock()


def _recorder() -> str:
    return os.environ.get(
        "AGENT_SESSION_RECORD_BIN",
        str(Path.home() / ".local/bin/agent-session-record"),
    )


def _wait_for_process(process: subprocess.Popen[bytes]) -> None:
    try:
        process.wait()
    finally:
        with _process_lock:
            _active_processes.discard(process)


def _emit(event: str, payload: dict[str, Any]) -> None:
    with _process_lock:
        for child in tuple(_active_processes):
            if child.poll() is not None:
                _active_processes.discard(child)
    try:
        process = subprocess.Popen(
            [_recorder(), "hook", "hermes", event],
            stdin=subprocess.PIPE,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            start_new_session=True,
            close_fds=True,
        )
        with _process_lock:
            _active_processes.add(process)
        threading.Thread(
            target=_wait_for_process,
            args=(process,),
            daemon=True,
        ).start()
        if process.stdin is not None:
            process.stdin.write(
                (json.dumps(payload, ensure_ascii=False) + "\n").encode("utf-8")
            )
            process.stdin.close()
    except (BrokenPipeError, OSError, TypeError, ValueError) as error:
        logger.warning("agent-session-record %s hook failed: %s", event, error)
        return


def _on_session_end(
    session_id: str = "",
    completed: bool = True,
    interrupted: bool = False,
    model: str = "",
    platform: str = "",
    **_: Any,
) -> None:
    if not session_id:
        return
    _emit(
        "session-end",
        {
            "session_id": session_id,
            "hook_event_name": "on_session_end",
            "completed": completed,
            "interrupted": interrupted,
            "model": model,
            "platform": platform,
        },
    )


def _on_session_finalize(
    session_id: str = "", platform: str = "", **_: Any
) -> None:
    if not session_id:
        return
    _emit(
        "session-finalize",
        {
            "session_id": session_id,
            "hook_event_name": "on_session_finalize",
            "platform": platform,
        },
    )


def register(ctx: Any) -> None:
    ctx.register_hook("on_session_end", _on_session_end)
    ctx.register_hook("on_session_finalize", _on_session_finalize)
