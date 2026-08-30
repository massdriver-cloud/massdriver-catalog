import os
from http.server import BaseHTTPRequestHandler, HTTPServer

PORT = int(os.environ.get("PORT", 8080))

PAGE = """<!doctype html>
<meta charset="utf-8">
<title>Fan Signups</title>
<style>
  body {{ font: 16px/1.6 system-ui, sans-serif; max-width: 40rem; margin: 4rem auto; padding: 0 1rem; }}
  dt {{ font-weight: 600; margin-top: .75rem; }}
  dd {{ margin: 0; font-family: ui-monospace, monospace; }}
  .muted {{ color: #666; }}
</style>
<h1>Fan Signups</h1>
<p>Collects mailing list signups from events.</p>
<dl>
  <dt>Database</dt><dd>{database}</dd>
  <dt>My schema</dt><dd>{schema}</dd>
  <dt>Signed in as</dt><dd>{user}</dd>
</dl>
<p class="muted">Replace this with the real app. The database connection above is already
wired up, and everything this app writes lands in its own schema.</p>
"""


class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        body = PAGE.format(
            database=os.environ.get("DATABASE_NAME", "not connected"),
            schema=os.environ.get("DATABASE_SCHEMA", "not connected"),
            user=os.environ.get("DATABASE_USER", "not connected"),
        )
        self.send_response(200)
        self.send_header("Content-Type", "text/html; charset=utf-8")
        self.end_headers()
        self.wfile.write(body.encode("utf-8"))

    def log_message(self, format, *args):
        # Cloud Run already captures stdout/stderr from the container; avoid
        # doubling up on every request.
        pass


if __name__ == "__main__":
    HTTPServer(("0.0.0.0", PORT), Handler).serve_forever()
