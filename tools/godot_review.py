"""Reuse the developer-only Godot review harness through its local file channel."""
from contextlib import contextmanager
import json
import math
import os
from pathlib import Path
import time
import uuid


def directory(root):
    return Path(root)/'godot/.godot/playtest'


def process_alive(pid):
    if type(pid) is not int or pid <= 0:
        return False
    if os.name == 'nt':
        import ctypes
        from ctypes import wintypes
        kernel = ctypes.WinDLL('kernel32', use_last_error=True)
        kernel.OpenProcess.argtypes = [wintypes.DWORD, wintypes.BOOL, wintypes.DWORD]
        kernel.OpenProcess.restype = wintypes.HANDLE
        kernel.WaitForSingleObject.argtypes = [wintypes.HANDLE, wintypes.DWORD]
        kernel.CloseHandle.argtypes = [wintypes.HANDLE]
        handle = kernel.OpenProcess(0x00100000, False, pid)  # SYNCHRONIZE, no write access.
        if not handle:
            return ctypes.get_last_error() == 5  # Access denied is not proof of exit.
        try:
            return kernel.WaitForSingleObject(handle, 0) == 258  # WAIT_TIMEOUT.
        finally:
            kernel.CloseHandle(handle)
    try:
        os.kill(pid, 0)
        return True
    except ProcessLookupError:
        return False
    except PermissionError:
        return True


@contextmanager
def file_lock(path):
    """OS-owned locks survive stale files, but release when their owner exits."""
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open('a+b') as lock:
        if lock.tell() == 0:
            lock.write(b'0'); lock.flush()
        lock.seek(0)
        try:
            if os.name == 'nt':
                import msvcrt
                msvcrt.locking(lock.fileno(), msvcrt.LK_NBLCK, 1)
            else:
                import fcntl
                fcntl.flock(lock.fileno(), fcntl.LOCK_EX | fcntl.LOCK_NB)
        except OSError:
            raise RuntimeError('A review launch or command already owns this channel; reuse the existing session.') from None
        try:
            yield
        finally:
            lock.seek(0)
            if os.name == 'nt':
                msvcrt.locking(lock.fileno(), msvcrt.LK_UNLCK, 1)
            else:
                fcntl.flock(lock.fileno(), fcntl.LOCK_UN)


def read_report(root):
    try:
        report = json.loads((directory(root)/'review-result.json').read_text(encoding='utf-8'))
        return report if isinstance(report, dict) else {}
    except (FileNotFoundError, json.JSONDecodeError):
        return {}


@contextmanager
def review_session(root):
    with file_lock(directory(root)/'review-session.lock'):
        report = read_report(root)
        if process_alive(report.get('engine_pid')):
            raise RuntimeError('The previous Godot review process is still running. Use --review-status; do not start a second window.')
        yield


def validate_request(request):
    if not isinstance(request, dict):
        raise ValueError('Review request must be a JSON object.')
    steps = request.get('steps', [request])
    if not isinstance(steps, list) or not 1 <= len(steps) <= 32:
        raise ValueError('Review steps must contain 1 to 32 objects.')
    vectors = {'feet': 3, 'camera': 3, 'target': 3, 'look': 2, 'walk_to': 3, 'size': 2}
    numbers = {'yaw', 'pitch', 'zoom', 'visual_yaw', 'fov', 'ortho_size', 'wait'}
    flags = {'hint', 'lift', 'await_lift', 'debug', 'menu', 'cutaway', 'ortho', 'resume'}
    for step in steps:
        if not isinstance(step, dict) or set(step) - (set(vectors) | numbers | flags | {'action', 'capture'}):
            raise ValueError('Review step contains unknown fields or is not an object.')
        action = step.get('action', 'inspect')
        if not isinstance(action, str) or action not in {'status', 'inspect', 'reset', 'reload', 'course_playthrough', 'npc_routines'}:
            raise ValueError('Unknown review action. Use status, inspect, reset or an explicit fixed playthrough fixture.')
        if action in {'course_playthrough', 'npc_routines'} and (len(steps) != 1 or set(step) != {'action'}):
            raise ValueError(action+' resets the review world and must be its own request.')
        for key, length in vectors.items():
            if key in step and (not isinstance(step[key], list) or len(step[key]) != length or any(type(n) not in (int, float) or not math.isfinite(n) for n in step[key])):
                raise ValueError(f'{key} must contain {length} finite numbers.')
        for key in numbers & step.keys():
            if type(step[key]) not in (int, float) or not math.isfinite(step[key]):
                raise ValueError(f'{key} must be a finite number.')
        if not 0 <= step.get('wait', .2) <= 5:
            raise ValueError('Review wait must be between 0 and 5 seconds.')
        if 'size' in step and (any(type(n) is not int for n in step['size']) or not 800 <= step['size'][0] <= 3840 or not 600 <= step['size'][1] <= 2160):
            raise ValueError('Review viewport must be between 800x600 and 3840x2160.')
        if any(type(step[key]) is not bool for key in flags & step.keys()):
            raise ValueError('Review flags must be true or false.')
        capture = step.get('capture', 'review.png')
        if not isinstance(capture, str) or not capture.endswith('.png') or any(c in capture for c in '/\\:*?"<>|') or capture in {'.png', '..png'}:
            raise ValueError('Capture must be a PNG filename without a directory.')
    if 'steps' in request and set(request) != {'steps'}:
        raise ValueError('A multi-step review request must contain only steps.')


def send_request(root, request, timeout=30):
    validate_request(request)
    if not math.isfinite(timeout) or not 0 < timeout <= 120:
        raise ValueError('Review timeout must be greater than zero and at most 120 seconds.')
    channel = directory(root)
    with file_lock(channel/'review-request.lock'):
        session = read_report(root)
        if not process_alive(session.get('engine_pid')) or not session.get('session_id'):
            raise RuntimeError('No live review session. Start python tools/run_game.py --live-review once.')
        if not session.get('ready') or session.get('busy'):
            raise RuntimeError('The review session is starting or busy. Wait for its current work; no second engine was started.')
        command = channel/'review-command.json'
        if command.exists():
            raise RuntimeError('A review command is pending; it was not overwritten.')
        request_id = uuid.uuid4().hex
        payload = dict(request, session_id=session['session_id'], request_id=request_id)
        temporary = channel/f'review-command-{request_id}.tmp'
        temporary.write_text(json.dumps(payload, allow_nan=False), encoding='utf-8')
        temporary.replace(command)
        deadline = time.monotonic()+timeout
        while time.monotonic() < deadline:
            report = read_report(root)
            if report.get('session_id') and report['session_id'] != session['session_id']:
                raise RuntimeError('The review session changed while waiting; this result was not accepted.')
            if report.get('request_id') == request_id and not report.get('busy'):
                if report.get('error'):
                    raise RuntimeError(report['error'])
                return report
            if not process_alive(session['engine_pid']):
                raise RuntimeError('The review process exited before returning a result.')
            time.sleep(.05)
        raise RuntimeError('Godot review did not respond before the timeout. It was left running; inspect its log/debugger rather than starting another window.')
