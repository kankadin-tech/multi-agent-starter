#!/usr/bin/env python3
"""_run.py — call_worker.sh의 timeout 러너 폴백(coreutils timeout/gtimeout 부재 시).
사용: _run.py <timeout_s> <cmd> [args...]
stdin/stdout/stderr를 그대로 통과시키고, 자식 종료코드를 그대로 반환.
timeout 초과 시 프로세스 그룹 종료(TERM→KILL) 후 exit 124. 결정적(레이스 없음)."""
import os
import signal
import subprocess
import sys


def main() -> int:
    if len(sys.argv) < 3:
        sys.stderr.write("usage: _run.py <timeout_s> <cmd> [args...]\n")
        return 64
    timeout = float(sys.argv[1])
    cmd = sys.argv[2:]
    try:
        proc = subprocess.Popen(cmd, start_new_session=True)  # 자식 프로세스 그룹 분리
    except FileNotFoundError:
        return 127
    try:
        return proc.wait(timeout=timeout)
    except subprocess.TimeoutExpired:
        _kill_group(proc.pid, signal.SIGTERM)
        try:
            return proc.wait(timeout=5) or 124
        except subprocess.TimeoutExpired:
            _kill_group(proc.pid, signal.SIGKILL)
            return 124


def _kill_group(pid: int, sig: int) -> None:
    try:
        os.killpg(os.getpgid(pid), sig)
    except (ProcessLookupError, PermissionError):
        pass


if __name__ == "__main__":
    sys.exit(main())
