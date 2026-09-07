import os
from http.server import BaseHTTPRequestHandler, HTTPServer

PORT = int(os.environ.get("PORT", 8080))

PAGE = b"""<!doctype html>
<meta charset="utf-8">
<title>It works</title>
<style>
  body { font: 16px/1.6 system-ui, sans-serif; max-width: 34rem; margin: 5rem auto;
         padding: 0 1.5rem; color: #16181d; }
  h1 { font-size: 1.6rem; margin-bottom: .5rem; }
  p { color: #555; }
</style>
<h1>It works.</h1>
<p>This image was built by the pipeline in this repository and pushed to your registry.
Replace <code>main.py</code> and the <code>Dockerfile</code> with your app.</p>
"""


class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        self.send_response(200)
        self.send_header("Content-Type", "text/html; charset=utf-8")
        self.end_headers()
        self.wfile.write(PAGE)

    def log_message(self, format, *args):
        # The platform captures stdout already; no need to double up per request.
        pass


if __name__ == "__main__":
    HTTPServer(("0.0.0.0", PORT), Handler).serve_forever()
