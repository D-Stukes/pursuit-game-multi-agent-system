"""Loopback-only NPC service. Run: python -m backend.server [--port 8765]."""
import argparse
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json
import os
from pathlib import Path
import threading

from .npc_agents import CallBudget, DialogueError, MAX_BODY, NPCDialogue, make_client


def settings(path=None, environ=None):
    values = {}
    path = Path(path) if path else Path(__file__).with_name('.env')
    if path.is_file():
        for line in path.read_text(encoding='utf-8').splitlines():
            line = line.strip()
            if not line or line.startswith('#') or '=' not in line:
                continue
            key, value = line.split('=', 1)
            if key.strip() in ('ANTHROPIC_API_KEY', 'ANTHROPIC_MODEL', 'NPC_MAX_MODEL_CALLS'):
                values[key.strip()] = value.strip().strip('\"\'')
    for key in ('ANTHROPIC_API_KEY', 'ANTHROPIC_MODEL', 'NPC_MAX_MODEL_CALLS'):
        value = (os.environ if environ is None else environ).get(key)
        if value is not None:
            values[key] = value
    total = int(values.get('NPC_MAX_MODEL_CALLS', '60'))
    if not 1 <= total <= 500:
        raise ValueError('NPC_MAX_MODEL_CALLS must be between 1 and 500')
    return values.get('ANTHROPIC_API_KEY', ''), values.get('ANTHROPIC_MODEL', 'claude-haiku-5-5'), total


def create_server(service, port=8765):
    slots = threading.BoundedSemaphore(2)

    class Handler(BaseHTTPRequestHandler):
        protocol_version = 'HTTP/1.1'

        def log_message(self, *_args):
            pass  # No request bodies, prompts, provider errors or keys in logs.

        def _send(self, status, payload):
            body = json.dumps(payload).encode('utf-8')
            try:
                self.send_response(status)
                self.send_header('Content-Type', 'application/json')
                self.send_header('Content-Length', str(len(body)))
                self.send_header('Cache-Control', 'no-store')
                self.send_header('Connection', 'close')
                self.end_headers()
                self.wfile.write(body)
            except (BrokenPipeError, ConnectionResetError):
                pass
            self.close_connection = True

        def _local(self):
            actual_port = self.server.server_address[1]
            if self.headers.get('Host') not in (f'127.0.0.1:{actual_port}', f'localhost:{actual_port}') or self.headers.get('Origin'):
                self._send(403, {'error': 'local_game_client_only'})
                return False
            return True

        def do_GET(self):
            if not self._local(): return
            if self.path != '/health':
                self._send(404, {'error': 'not_found'}); return
            self._send(200, {'schema': 1, 'service': 'pursuit-npc', 'provider_ready': service.client is not None})

        def do_POST(self):
            if not self._local(): return
            if self.path != '/v1/npc/turn':
                self._send(404, {'error': 'not_found'}); return
            try:
                size = int(self.headers.get('Content-Length', '0'))
            except ValueError:
                size = 0
            if not 0 < size <= MAX_BODY or self.headers.get('Content-Type', '').split(';')[0] != 'application/json':
                self._send(400, {'error': 'invalid_request'}); return
            if not slots.acquire(blocking=False):
                self._send(429, {'error': 'service_busy'}); return
            try:
                self.connection.settimeout(3)
                payload = json.loads(self.rfile.read(size))
                self._send(200, service.reply(payload))
            except (ValueError, TimeoutError) as error:
                code = str(error) if isinstance(error, DialogueError) else 'invalid_request'
                status = 400 if code in ('invalid_request', 'unknown_npc', 'unknown_topic') else 503
                self._send(status, {'error': code})
            finally:
                slots.release()

    server = ThreadingHTTPServer(('127.0.0.1', port), Handler)
    server.daemon_threads = True
    return server


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--port', type=int, default=8765)
    args = parser.parse_args()
    key, model, total = settings()
    service = NPCDialogue(make_client(key), model=model, budget=CallBudget(total))
    server = create_server(service, args.port)
    print(f'NPC service listening on 127.0.0.1:{server.server_address[1]}; provider configured: {bool(key)}', flush=True)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()
        if service.client: service.client.close()


if __name__ == '__main__':
    main()
