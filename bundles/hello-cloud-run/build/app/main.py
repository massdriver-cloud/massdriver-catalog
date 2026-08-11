import os
from http.server import BaseHTTPRequestHandler, HTTPServer

PORT = int(os.environ.get("PORT", 8080))


class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        self.send_response(200)
        self.send_header("Content-Type", "text/plain")
        self.end_headers()
        self.wfile.write(b"Hello from Cloud Run. This image was built inside GCP by Cloud Build -- no docker or gcloud required on your machine.\n")

    def log_message(self, format, *args):
        # Cloud Run already captures stdout/stderr from the container; avoid
        # doubling up on every request.
        pass


if __name__ == "__main__":
    HTTPServer(("0.0.0.0", PORT), Handler).serve_forever()
