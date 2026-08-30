import csv
import io
import os
import re
from http.server import BaseHTTPRequestHandler, HTTPServer

import psycopg

PORT = int(os.environ.get("PORT", 8080))

TITLE = 'Tour Dates'
PURPOSE = 'Every confirmed show, so nobody has to ask for the latest spreadsheet.'
TABLE = 'shows'
COLUMNS = [('city', 'text'), ('venue', 'text'), ('show_date', 'date')]          # (name, sql type) in display order, excluding id
SEED = [['Lisbon', 'Coliseu dos Recreios', '2026-09-14'], ['Madrid', 'La Riviera', '2026-09-17'], ['Paris', 'La Cigale', '2026-09-21'], ['Berlin', 'Columbiahalle', '2026-09-24'], ['Amsterdam', 'Paradiso', '2026-09-27'], ['London', 'Roundhouse', '2026-10-02']]

SCHEMA = os.environ.get("DATABASE_SCHEMA")


def dsn():
    host = os.environ.get("DATABASE_HOST")
    if not host or not SCHEMA:
        return None
    return "host={} port={} dbname={} user={} password={} sslmode=require".format(
        host,
        os.environ.get("DATABASE_PORT", "5432"),
        os.environ.get("DATABASE_NAME"),
        os.environ.get("DATABASE_USER"),
        os.environ.get("DATABASE_PASSWORD"),
    )


def qualified():
    # Both halves come from the platform, not from a request, but quoting them
    # keeps this correct if a schema or table name ever needs an odd character.
    return '"{}"."{}"'.format(SCHEMA.replace('"', '""'), TABLE.replace('"', '""'))


def ensure_table(conn):
    cols = ", ".join('"{}" {}'.format(n, t) for n, t in COLUMNS)
    with conn.cursor() as cur:
        cur.execute("CREATE TABLE IF NOT EXISTS {} (id bigserial PRIMARY KEY, {})".format(
            qualified(), cols))
        cur.execute("SELECT count(*) FROM {}".format(qualified()))
        if cur.fetchone()[0] == 0 and SEED:
            insert(cur, SEED)
    conn.commit()


def insert(cur, rows):
    names = ", ".join('"{}"'.format(n) for n, _ in COLUMNS)
    marks = ", ".join(["%s"] * len(COLUMNS))
    cur.executemany(
        "INSERT INTO {} ({}) VALUES ({})".format(qualified(), names, marks), rows)


def fetch(conn):
    with conn.cursor() as cur:
        names = ", ".join('"{}"'.format(n) for n, _ in COLUMNS)
        cur.execute("SELECT id, {} FROM {} ORDER BY id".format(names, qualified()))
        return cur.fetchall()


def esc(v):
    return (str(v) if v is not None else "")\
        .replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")


PAGE = """<!doctype html>
<meta charset="utf-8">
<title>{title}</title>
<style>
  body {{ font: 15px/1.55 system-ui, -apple-system, sans-serif; margin: 0;
         color: #16181d; }}
  .corp {{ background: #16181d; color: #f4f4f5; font-size: 13px; font-weight: 600;
          letter-spacing: .02em; padding: .55rem 1.25rem; display: flex; gap: .5rem;
          align-items: center; }}
  .corp .sep {{ opacity: .45; font-weight: 400; }}
  .corp .app {{ font-weight: 400; opacity: .85; }}
  .wrap {{ max-width: 52rem; margin: 3rem auto; padding: 0 1.25rem; }}
  h1 {{ margin-bottom: .25rem; }}
  .lede {{ color: #555; margin-top: 0; }}
  table {{ border-collapse: collapse; width: 100%; margin: 1.5rem 0; }}
  th, td {{ text-align: left; padding: .5rem .7rem; border-bottom: 1px solid #e4e6ea; }}
  th {{ font-size: .78rem; text-transform: uppercase; letter-spacing: .04em; color: #666; }}
  tr:last-child td {{ border-bottom: 0; }}
  form {{ background: #f6f7f9; border: 1px solid #e4e6ea; border-radius: 8px;
          padding: 1rem 1.1rem; }}
  .meta {{ font-family: ui-monospace, SFMono-Regular, monospace; font-size: .82rem;
           color: #555; background: #f6f7f9; border-radius: 8px; padding: .8rem 1rem; }}
  .warn {{ background: #fff4e5; border: 1px solid #f0c992; border-radius: 8px;
           padding: .8rem 1rem; }}
  button {{ font: inherit; padding: .4rem .9rem; border-radius: 6px; border: 1px solid #b9bec7;
           background: #fff; cursor: pointer; }}
</style>
<div class="corp"><span>🎵 MusiCorp</span><span class="sep">::</span><span class="app">{title}</span></div>
<div class="wrap">
<h1>{title}</h1>
<p class="lede">{purpose}</p>
{body}
<p class="meta">schema <strong>{schema}</strong> &middot; table <strong>{table}</strong>
&middot; signed in as <strong>{user}</strong> &middot; {count} rows</p>
</div>
"""

FORM = """
<form method="post" action="/upload" enctype="multipart/form-data">
  <strong>Add rows from a CSV</strong>
  <p style="margin:.4rem 0 .8rem">Columns, in order: <code>{cols}</code>. A header row is
  skipped if the first cell matches the first column name.</p>
  <input type="file" name="file" accept=".csv,text/csv" required>
  <button type="submit">Upload</button>
</form>
"""


def render(conn, note=""):
    rows = fetch(conn)
    head = "".join("<th>{}</th>".format(esc(n)) for n, _ in COLUMNS)
    body_rows = "".join(
        "<tr>" + "".join("<td>{}</td>".format(esc(c)) for c in r[1:]) + "</tr>"
        for r in rows)
    table = "<table><tr>{}</tr>{}</table>".format(head, body_rows)
    form = FORM.format(cols=", ".join(n for n, _ in COLUMNS))
    return PAGE.format(
        title=TITLE, purpose=PURPOSE, body=note + table + form,
        schema=SCHEMA, table=TABLE, count=len(rows),
        user=os.environ.get("DATABASE_USER", "-"))


def unconfigured(err=None):
    msg = "This app has no database connection yet."
    if err:
        msg = "Could not reach the database: {}".format(esc(err))
    return PAGE.format(
        title=TITLE, purpose=PURPOSE,
        body='<p class="warn">{}</p>'.format(msg),
        schema=SCHEMA or "-", table=TABLE, count=0,
        user=os.environ.get("DATABASE_USER", "-"))


def parse_multipart(body, content_type):
    m = re.search(r"boundary=(.+)$", content_type)
    if not m:
        return None
    boundary = ("--" + m.group(1).strip('"')).encode()
    for part in body.split(boundary):
        if b"filename=" not in part:
            continue
        split = part.split(b"\r\n\r\n", 1)
        if len(split) == 2:
            return split[1].rstrip(b"\r\n--")
    return None


class Handler(BaseHTTPRequestHandler):
    def _send(self, code, html):
        self.send_response(code)
        self.send_header("Content-Type", "text/html; charset=utf-8")
        self.end_headers()
        self.wfile.write(html.encode("utf-8"))

    def do_GET(self):
        if self.path not in ("/", "/index.html"):
            self._send(404, unconfigured("no such page"))
            return
        conn_str = dsn()
        if not conn_str:
            self._send(200, unconfigured())
            return
        try:
            with psycopg.connect(conn_str, connect_timeout=8) as conn:
                ensure_table(conn)
                self._send(200, render(conn))
        except Exception as e:  # noqa: BLE001 - surface the reason in the page
            self._send(200, unconfigured(e))

    def do_POST(self):
        if self.path != "/upload":
            self._send(404, unconfigured("no such page"))
            return
        conn_str = dsn()
        if not conn_str:
            self._send(200, unconfigured())
            return
        try:
            length = int(self.headers.get("Content-Length", 0))
            raw = parse_multipart(self.rfile.read(length),
                                  self.headers.get("Content-Type", ""))
            added = 0
            with psycopg.connect(conn_str, connect_timeout=8) as conn:
                ensure_table(conn)
                if raw:
                    reader = csv.reader(io.StringIO(raw.decode("utf-8", "replace")))
                    rows = [r[:len(COLUMNS)] for r in reader if any(c.strip() for c in r)]
                    if rows and rows[0] and rows[0][0].strip().lower() == COLUMNS[0][0]:
                        rows = rows[1:]
                    rows = [r + [""] * (len(COLUMNS) - len(r)) for r in rows]
                    if rows:
                        with conn.cursor() as cur:
                            insert(cur, rows)
                        conn.commit()
                        added = len(rows)
                note = '<p class="meta">Added {} row(s).</p>'.format(added)
                self._send(200, render(conn, note))
        except Exception as e:  # noqa: BLE001
            self._send(200, unconfigured(e))

    def log_message(self, format, *args):
        # Cloud Run already captures stdout/stderr from the container.
        pass


if __name__ == "__main__":
    HTTPServer(("0.0.0.0", PORT), Handler).serve_forever()
