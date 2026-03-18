from __future__ import annotations

import json
import subprocess
import time
from functools import partial
from http import HTTPStatus
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import urlparse

REPO_ROOT = Path(__file__).resolve().parent.parent
WEB_ROOT = REPO_ROOT / "web"
ENGINE_BIN = REPO_ROOT / ".lake" / "build" / "bin" / (
    "connect4-engine.exe" if __import__("os").name == "nt" else "connect4-engine"
)

MOVES: list[int] = []
OPTIMAL_TIMEOUT_SEC = 2.5
FALLBACK_DEPTHS = [9, 7, 5]
FALLBACK_TIMEOUT_SEC = 2.0
EARLY_GAME_PLY_THRESHOLD = 14
EARLY_GAME_DEPTHS = [6, 7, 8, 9, 10, 11]
EARLY_GAME_BUDGET_SEC = 4.0
LATE_GAME_BUDGET_SEC = 3.0
PER_DEPTH_MAX_SEC = 1.25


def run_engine(
    moves: list[int],
    depth_override: int | None = None,
    timeout_sec: float | None = None,
) -> dict:
    move_args = [str(m) for m in moves]
    depth_args = ["--depth", str(depth_override)] if depth_override is not None else []
    if ENGINE_BIN.exists():
      cmd = [str(ENGINE_BIN), *depth_args, *move_args]
    else:
      cmd = ["lake", "exe", "connect4-engine", *depth_args, *move_args]

    try:
        result = subprocess.run(
            cmd,
            cwd=REPO_ROOT,
            text=True,
            capture_output=True,
            check=False,
            timeout=timeout_sec,
        )
    except subprocess.TimeoutExpired:
        return {
            "ok": False,
            "timeout": True,
            "error": f"engine timed out after {timeout_sec}s",
        }

    if result.returncode != 0:
        return {
            "ok": False,
            "error": (result.stderr.strip() or result.stdout.strip() or "engine failed"),
        }

    try:
        parsed = json.loads(result.stdout.strip())
    except json.JSONDecodeError as exc:
        return {"ok": False, "error": f"invalid engine JSON: {exc}"}

    if "ok" not in parsed:
        return {"ok": False, "error": "engine response missing ok"}

    return parsed


def iterative_best_state(moves: list[int], depths: list[int], budget_sec: float) -> dict | None:
    deadline = time.monotonic() + budget_sec
    best: dict | None = None

    for depth in depths:
        remaining = deadline - time.monotonic()
        if remaining <= 0.10:
            break
        timeout = min(PER_DEPTH_MAX_SEC, remaining)
        candidate = run_engine(moves, depth_override=depth, timeout_sec=timeout)

        if candidate.get("ok"):
            candidate["searchMode"] = f"iterative-depth-{depth}"
            best = candidate
            continue

        if candidate.get("timeout"):
            break

    return best


def response_state(include_moves: bool = True, prefer_optimal: bool = True) -> dict:
    if not prefer_optimal:
        state = run_engine(MOVES, depth_override=0, timeout_sec=1.0)
        if state.get("ok"):
            state["searchMode"] = "state-only"
        else:
            state = run_engine(MOVES)
    else:
        base = run_engine(MOVES, depth_override=0, timeout_sec=1.0)
        if not base.get("ok"):
            state = base
        elif base.get("result") != "ongoing" or base.get("turn") != "yellow":
            base["searchMode"] = "state-only"
            state = base
        else:
            is_early = len(MOVES) <= EARLY_GAME_PLY_THRESHOLD
            if is_early:
                iter_state = iterative_best_state(MOVES, EARLY_GAME_DEPTHS, EARLY_GAME_BUDGET_SEC)
                if iter_state is not None:
                    state = iter_state
                else:
                    state = run_engine(MOVES, depth_override=5, timeout_sec=1.5)
            else:
                state = run_engine(MOVES, timeout_sec=OPTIMAL_TIMEOUT_SEC)
                if state.get("ok"):
                    state["searchMode"] = "optimal"
                elif state.get("timeout"):
                    iter_state = iterative_best_state(MOVES, FALLBACK_DEPTHS, LATE_GAME_BUDGET_SEC)
                    if iter_state is not None:
                        state = iter_state

            if not state.get("ok"):
                emergency = run_engine(MOVES, depth_override=3, timeout_sec=None)
                if emergency.get("ok"):
                    emergency["searchMode"] = "fallback-depth-3"
                    state = emergency
                else:
                    minimal = run_engine(MOVES, depth_override=0, timeout_sec=None)
                    if minimal.get("ok"):
                        legal = minimal.get("legalMoves", [])
                        minimal["bestMove"] = legal[0] if legal else None
                        minimal["searchMode"] = "fallback-first-legal"
                        state = minimal
                    else:
                        state = emergency

    if include_moves and state.get("ok"):
        state["moveHistory"] = MOVES
    return state


class Connect4Handler(SimpleHTTPRequestHandler):
    def _log_api_response(self, route: str, payload: dict, status: HTTPStatus = HTTPStatus.OK) -> None:
        print(f"[{route}] status={int(status)} response={json.dumps(payload, separators=(',', ':'))}")

    def _read_json_body(self) -> dict | None:
        try:
            length = int(self.headers.get("Content-Length", "0"))
        except ValueError:
            return None
        body = self.rfile.read(length).decode("utf-8") if length > 0 else "{}"
        try:
            return json.loads(body)
        except json.JSONDecodeError:
            return None

    def _send_json(self, payload: dict, status: HTTPStatus = HTTPStatus.OK) -> None:
        encoded = json.dumps(payload).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(encoded)))
        self.end_headers()
        self.wfile.write(encoded)

    def do_GET(self) -> None:
        parsed = urlparse(self.path)
        if parsed.path == "/api/state":
            payload = response_state()
            self._log_api_response("GET /api/state", payload)
            self._send_json(payload)
            return
        super().do_GET()

    def do_POST(self) -> None:
        global MOVES

        parsed = urlparse(self.path)

        if parsed.path == "/api/new":
            MOVES = []
            payload = response_state(prefer_optimal=False)
            self._log_api_response("POST /api/new", payload)
            self._send_json(payload)
            return

        if parsed.path == "/api/play":
            payload = self._read_json_body()
            if payload is None or not isinstance(payload.get("col"), int):
                err = {"ok": False, "error": "body must be JSON with integer field 'col'"}
                self._log_api_response("POST /api/play", err, HTTPStatus.BAD_REQUEST)
                self._send_json(err, HTTPStatus.BAD_REQUEST)
                return

            col = payload["col"]
            pre = response_state(include_moves=False, prefer_optimal=False)
            if not pre.get("ok"):
                self._log_api_response("POST /api/play", pre, HTTPStatus.INTERNAL_SERVER_ERROR)
                self._send_json(pre, HTTPStatus.INTERNAL_SERVER_ERROR)
                return

            if pre.get("result") != "ongoing":
                err = {"ok": False, "error": "game already finished"}
                self._log_api_response("POST /api/play", err, HTTPStatus.CONFLICT)
                self._send_json(err, HTTPStatus.CONFLICT)
                return

            if col not in pre.get("legalMoves", []):
                err = {"ok": False, "error": "illegal move"}
                self._log_api_response("POST /api/play", err, HTTPStatus.CONFLICT)
                self._send_json(err, HTTPStatus.CONFLICT)
                return

            MOVES = [*MOVES, col]
            after_human = response_state(include_moves=False, prefer_optimal=True)
            if not after_human.get("ok"):
                self._log_api_response("POST /api/play", after_human, HTTPStatus.INTERNAL_SERVER_ERROR)
                self._send_json(after_human, HTTPStatus.INTERNAL_SERVER_ERROR)
                return

            ai_move = None
            if after_human.get("result") == "ongoing":
                best = after_human.get("bestMove")
                if isinstance(best, int):
                    MOVES = [*MOVES, best]
                    ai_move = best

            out = response_state()
            if out.get("ok"):
                out["aiMove"] = ai_move
                out["humanMove"] = col
                out["aiSearchMode"] = after_human.get("searchMode")
                out["aiSearchDepth"] = after_human.get("searchDepth")
            self._log_api_response("POST /api/play", out)
            self._send_json(out)
            return

        err = {"ok": False, "error": "not found"}
        self._log_api_response(f"{self.command} {parsed.path}", err, HTTPStatus.NOT_FOUND)
        self._send_json(err, HTTPStatus.NOT_FOUND)


def main() -> None:
    handler = partial(Connect4Handler, directory=str(WEB_ROOT))
    server = ThreadingHTTPServer(("127.0.0.1", 8000), handler)
    print("Serving Connect4 at http://127.0.0.1:8000")
    print("API endpoints: POST /api/new, GET /api/state, POST /api/play")
    server.serve_forever()


if __name__ == "__main__":
    main()
