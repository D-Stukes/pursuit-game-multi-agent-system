"""Serve only the portable building reviewer on this computer's loopback interface."""
import argparse
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
import shutil
from urllib.parse import unquote, urlsplit
import webbrowser

ROOT = Path(__file__).resolve().parent
FILES = {
    'index.html': 'text/html; charset=utf-8',
    'viewer.js': 'text/javascript; charset=utf-8',
    'viewer.css': 'text/css; charset=utf-8',
    'scene.json': 'application/json',
    'favicon.svg': 'image/svg+xml',
    'assets/pursuit-building.glb': 'model/gltf-binary',
    'vendor/three.module.js': 'text/javascript; charset=utf-8',
    'vendor/three.core.js': 'text/javascript; charset=utf-8',
    'vendor/controls/OrbitControls.js': 'text/javascript; charset=utf-8',
    'vendor/loaders/GLTFLoader.js': 'text/javascript; charset=utf-8',
    'vendor/utils/BufferGeometryUtils.js': 'text/javascript; charset=utf-8',
    'vendor/environments/RoomEnvironment.js': 'text/javascript; charset=utf-8',
    'vendor/LICENSE.txt': 'text/plain; charset=utf-8',
}
POLICY = (
    "default-src 'self'; script-src 'self' 'unsafe-inline'; "
    "style-src 'self' 'unsafe-inline'; img-src 'self' data: blob:; "
    "connect-src 'self' blob:; object-src 'none'; "
    "frame-ancestors 'none'; base-uri 'none'; form-action 'none'"
)


class Handler(BaseHTTPRequestHandler):
    def do_HEAD(self):
        self.respond(False)

    def do_GET(self):
        self.respond(True)

    def respond(self, body):
        route = unquote(urlsplit(self.path).path)
        relative = 'index.html' if route == '/' else route.removeprefix('/')
        mime = FILES.get(relative)
        if not mime:
            self.send_error(404)
            return
        path = (ROOT / relative).resolve()
        if not path.is_relative_to(ROOT) or not path.is_file():
            self.send_error(404)
            return
        self.send_response(200)
        self.send_header('Content-Type', mime)
        self.send_header('Content-Length', str(path.stat().st_size))
        self.send_header('Cache-Control', 'no-store')
        self.send_header('X-Content-Type-Options', 'nosniff')
        self.send_header('Referrer-Policy', 'no-referrer')
        self.send_header('Content-Security-Policy', POLICY)
        self.end_headers()
        if body:
            try:
                with path.open('rb') as source:
                    shutil.copyfileobj(source, self.wfile)
            except (BrokenPipeError, ConnectionResetError, ConnectionAbortedError):
                pass


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--port', type=int, default=8767)
    parser.add_argument('--open', action='store_true', help='Open your default browser')
    args = parser.parse_args()
    try:
        server = ThreadingHTTPServer(('127.0.0.1', args.port), Handler)
    except OSError as error:
        parser.exit(1, f'Cannot start the review server: {error}\nTry --port 8768.\n')
    url = f'http://127.0.0.1:{server.server_port}/'
    print(f'Pursuit building review: {url}\nPress Ctrl+C to stop.', flush=True)
    if args.open:
        webbrowser.open(url)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()


if __name__ == '__main__':
    main()
