import os
from http.server import BaseHTTPRequestHandler, HTTPServer

import psycopg

PORT = int(os.environ.get("PORT", 8080))

# The one table this site was granted. It reads and never writes, and the login it
# uses cannot reach anything else in the database.
SOURCE = os.environ.get("BORROWED_READ", "").split(",")[0].strip()


def dsn():
    host = os.environ.get("BORROWED_HOST")
    if not host or not SOURCE:
        return None
    return "host={} port={} dbname={} user={} password={} sslmode=require".format(
        host,
        os.environ.get("BORROWED_PORT", "5432"),
        os.environ.get("BORROWED_NAME"),
        os.environ.get("BORROWED_USER"),
        os.environ.get("BORROWED_PASSWORD"),
    )


def fetch():
    schema, _, table = SOURCE.partition(".")
    with psycopg.connect(dsn(), connect_timeout=8) as conn:
        with conn.cursor() as cur:
            cur.execute('SELECT name, genre FROM "{}"."{}" ORDER BY name'.format(
                schema.replace('"', '""'), table.replace('"', '""')))
            return cur.fetchall()


def esc(v):
    return (str(v) if v is not None else "") \
        .replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")


PAGE = """<!doctype html>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>MusiCorp — Artists</title>
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Fraunces:opsz,wght@9..144,400;9..144,600&family=Inter+Tight:wght@400;500;600&display=swap">
<style>
  :root {{
    --ground: #0E0D12; --surface: #17161D; --rule: #2A2833;
    --ink: #F2F0F5; --ink-2: #B5B1C0; --muted: #7C7789;
    --accent: #E8B44F;
  }}
  * {{ box-sizing: border-box; }}
  body {{ margin: 0; background: var(--ground); color: var(--ink);
         font-family: "Inter Tight", system-ui, sans-serif; line-height: 1.6; }}
  .bar {{ background: #000; color: #EDEBF2; font-size: 13px; font-weight: 600;
         letter-spacing: .02em; padding: .55rem 1.5rem; display: flex; gap: .5rem; }}
  .bar .sep {{ opacity: .4; font-weight: 400; }}
  .bar .app {{ font-weight: 400; opacity: .8; }}
  .wrap {{ max-width: 68rem; margin: 0 auto; padding: 0 1.5rem 6rem; }}
  header.hero {{ padding: 6.5rem 0 3.5rem; border-bottom: 1px solid var(--rule); }}
  .eyebrow {{ font-size: 12px; letter-spacing: .18em; text-transform: uppercase;
             color: var(--accent); margin: 0 0 1.2rem; font-weight: 600; }}
  h1 {{ font-family: "Fraunces", Georgia, serif; font-weight: 400;
       font-size: clamp(3rem, 9vw, 6rem); line-height: .96; letter-spacing: -.02em;
       margin: 0 0 1.4rem; text-wrap: balance; }}
  h1 em {{ font-style: italic; color: var(--accent); }}
  .lede {{ font-size: clamp(1.05rem, 2vw, 1.3rem); color: var(--ink-2);
          max-width: 46ch; margin: 0; }}
  .roster {{ display: grid; grid-template-columns: repeat(auto-fill, minmax(220px, 1fr));
            gap: 1px; background: var(--rule); border: 1px solid var(--rule);
            margin: 3.5rem 0 0; }}
  .act {{ background: var(--surface); padding: 2rem 1.6rem 1.7rem;
         display: flex; flex-direction: column; gap: .45rem; min-height: 11rem;
         justify-content: flex-end; }}
  .act .name {{ font-family: "Fraunces", Georgia, serif; font-size: 1.5rem;
               line-height: 1.1; letter-spacing: -.01em; }}
  .act .genre {{ font-size: 12px; letter-spacing: .14em; text-transform: uppercase;
                color: var(--accent); font-weight: 600; }}
  .count {{ margin: 2.5rem 0 0; font-size: 13px; color: var(--muted);
           letter-spacing: .04em; }}
  .warn {{ margin: 3rem 0 0; padding: 1rem 1.2rem; border: 1px solid var(--rule);
          border-left: 3px solid var(--accent); background: var(--surface);
          color: var(--ink-2); font-size: 14px; }}
  footer {{ margin-top: 5rem; padding-top: 1.6rem; border-top: 1px solid var(--rule);
           font-size: 12.5px; color: var(--muted); }}
</style>
<div class="bar"><span>\U0001F3B5 MusiCorp</span><span class="sep">::</span><span class="app">Artists</span></div>
<div class="wrap">
  <header class="hero">
    <p class="eyebrow">Roster</p>
    <h1>The artists we <em>work with</em>.</h1>
    <p class="lede">Every act on the MusiCorp roster, from the people who look after them.</p>
  </header>
  {body}
  <footer>{footer}</footer>
</div>
"""


class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        try:
            rows = fetch()
            cards = "".join(
                '<div class="act"><span class="genre">{}</span>'
                '<span class="name">{}</span></div>'.format(esc(g), esc(n))
                for n, g in rows)
            body = '<div class="roster">{}</div><p class="count">{} acts</p>'.format(
                cards, len(rows))
            footer = "Read-only. This site can see names and genres, and nothing else."
        except Exception as e:  # noqa: BLE001
            body = '<p class="warn">The roster is not available right now.</p>'
            footer = esc(e)

        self.send_response(200)
        self.send_header("Content-Type", "text/html; charset=utf-8")
        self.end_headers()
        self.wfile.write(PAGE.format(body=body, footer=footer).encode("utf-8"))

    def log_message(self, format, *args):
        # Cloud Run already captures stdout/stderr from the container.
        pass


if __name__ == "__main__":
    HTTPServer(("0.0.0.0", PORT), Handler).serve_forever()
