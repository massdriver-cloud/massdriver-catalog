"""Tooth Fairy Rate Index — an anonymous campaign web app.

Visitors submit a dollar amount and a zip code. The zip code is converted to
a US state immediately and never stored — only the state, the amount, and a
server timestamp are written to Firestore. The app never collects a name,
email, or any other personal identifier.

Storage model (three collections/docs, kept intentionally small):
  - `submissions`      one doc per submission: {state, amount, submitted_at}.
                        Read back only to build the "over time" chart.
  - `aggregates/national`  running {sum, count} for the whole country.
  - `state_totals/<ST>`    running {sum, count} per state.

The running totals are updated with atomic Firestore Increment() field
transforms in the same batch as the submission write, so a submission and
its contribution to both aggregates always land together.
"""

import io
import os
import re
import threading
import time
from collections import defaultdict
from datetime import datetime, timedelta, timezone

from flask import Flask, jsonify, render_template, request
from PIL import Image, ImageDraw, ImageFont
from google.cloud import firestore
from google.cloud.firestore_v1.base_query import FieldFilter

app = Flask(__name__)

PROJECT_ID = os.environ.get("FIRESTORE_PROJECT_ID")
DATABASE_ID = os.environ.get("FIRESTORE_DATABASE") or "(default)"

MIN_AMOUNT = 0.01
MAX_AMOUNT = 100.00
TIMESERIES_WINDOW_DAYS = 180
TIMESERIES_DOC_LIMIT = 5000
STATS_CACHE_SECONDS = 4

ZIP_RE = re.compile(r"^\d{5}$")

# USPS ZIP3 prefix ranges -> state/territory. Used once, on submit, to
# translate a zip code into a state. The zip code itself is discarded right
# after this lookup -- it is never written to Firestore.
ZIP3_RANGES = [
    (5, 5, "NY"), (6, 9, "PR"),
    (10, 27, "MA"), (28, 29, "RI"), (30, 38, "NH"), (39, 49, "ME"),
    (50, 59, "VT"), (60, 69, "CT"), (70, 89, "NJ"),
    (100, 149, "NY"), (150, 196, "PA"), (197, 199, "DE"),
    (200, 205, "DC"), (206, 219, "MD"), (220, 246, "VA"), (247, 268, "WV"),
    (270, 289, "NC"), (290, 299, "SC"),
    (300, 319, "GA"), (320, 349, "FL"), (350, 369, "AL"), (370, 385, "TN"),
    (386, 397, "MS"), (398, 399, "GA"),
    (400, 427, "KY"), (430, 459, "OH"), (460, 479, "IN"), (480, 499, "MI"),
    (500, 528, "IA"), (530, 549, "WI"), (550, 567, "MN"), (570, 577, "SD"),
    (580, 588, "ND"), (590, 599, "MT"),
    (600, 629, "IL"), (630, 658, "MO"), (660, 679, "KS"), (680, 693, "NE"),
    (700, 714, "LA"), (716, 729, "AR"), (730, 749, "OK"), (750, 799, "TX"),
    (800, 816, "CO"), (820, 831, "WY"), (832, 838, "ID"), (840, 847, "UT"),
    (850, 865, "AZ"), (870, 884, "NM"), (889, 898, "NV"),
    (900, 961, "CA"), (962, 968, "HI"),
    (970, 979, "OR"), (980, 994, "WA"),
    (995, 999, "AK"),
]


def zip_to_state(zip_code: str):
    """Map a 5-digit zip code to a two-letter state code, or None if it
    falls outside a range this app recognizes (e.g. a US territory other
    than Puerto Rico, or military/overseas codes)."""
    prefix = int(zip_code[:3])
    for low, high, state in ZIP3_RANGES:
        if low <= prefix <= high:
            return state
    return None


# --- State names and URL slugs ----------------------------------------------
# Every state that ZIP3_RANGES can produce needs a name and a slug, or it
# would have data but no landing page.
STATE_NAMES = {
    "AL": "Alabama", "AK": "Alaska", "AZ": "Arizona", "AR": "Arkansas",
    "CA": "California", "CO": "Colorado", "CT": "Connecticut", "DE": "Delaware",
    "DC": "District of Columbia", "FL": "Florida", "GA": "Georgia", "HI": "Hawaii",
    "ID": "Idaho", "IL": "Illinois", "IN": "Indiana", "IA": "Iowa",
    "KS": "Kansas", "KY": "Kentucky", "LA": "Louisiana", "ME": "Maine",
    "MD": "Maryland", "MA": "Massachusetts", "MI": "Michigan", "MN": "Minnesota",
    "MS": "Mississippi", "MO": "Missouri", "MT": "Montana", "NE": "Nebraska",
    "NV": "Nevada", "NH": "New Hampshire", "NJ": "New Jersey", "NM": "New Mexico",
    "NY": "New York", "NC": "North Carolina", "ND": "North Dakota", "OH": "Ohio",
    "OK": "Oklahoma", "OR": "Oregon", "PA": "Pennsylvania", "PR": "Puerto Rico",
    "RI": "Rhode Island", "SC": "South Carolina", "SD": "South Dakota",
    "TN": "Tennessee", "TX": "Texas", "UT": "Utah", "VT": "Vermont",
    "VA": "Virginia", "WA": "Washington", "WV": "West Virginia",
    "WI": "Wisconsin", "WY": "Wyoming",
}


def _slugify(name: str) -> str:
    return name.lower().replace(" ", "-")


ABBR_TO_SLUG = {abbr: _slugify(name) for abbr, name in STATE_NAMES.items()}
SLUG_TO_ABBR = {slug: abbr for abbr, slug in ABBR_TO_SLUG.items()}

# A state page stays out of the search index until it has real data behind it.
# Fifty near-identical pages with one report each read as thin content, and
# that can hurt the whole domain. The page still works for a direct visit or
# a shared link -- it just carries a noindex tag until it crosses this line.
INDEX_MIN_REPORTS = 5

# Reserved top-level paths, so a future route can never be shadowed by a
# state slug (and vice versa).
RESERVED_PATHS = {"api", "og", "static", "security.html", "sitemap.xml", "robots.txt"}


def base_url() -> str:
    """Absolute origin for canonical and Open Graph URLs. Social scrapers
    reject relative image URLs, so these must be absolute."""
    configured = os.environ.get("SITE_BASE_URL", "").strip().rstrip("/")
    if configured:
        return configured
    proto = request.headers.get("X-Forwarded-Proto", "https")
    return f"{proto}://{request.host}"


# --- Firestore client -------------------------------------------------------
# Lazily created so the module imports cleanly even before env vars are set
# (e.g. during a container build step that doesn't run the app).
_db = None
_db_lock = threading.Lock()


def get_db():
    global _db
    if _db is None:
        with _db_lock:
            if _db is None:
                _db = firestore.Client(project=PROJECT_ID, database=DATABASE_ID)
    return _db


# --- Tiny in-process cache for /api/stats -----------------------------------
# Several browser tabs poll this endpoint every few seconds; a short cache
# keeps read volume against Firestore flat regardless of how many viewers are
# watching at once. Each Cloud Run instance keeps its own cache -- fine here,
# since staleness is bounded to a few seconds either way.
_cache_lock = threading.Lock()
_cache = {"payload": None, "expires_at": 0.0}


def invalidate_cache():
    with _cache_lock:
        _cache["expires_at"] = 0.0


# Optional browser analytics. Unset unless a project key was configured, in which
# case the template renders no analytics script at all.
POSTHOG_PROJECT_KEY = os.environ.get("POSTHOG_PROJECT_KEY", "").strip()
POSTHOG_API_HOST = os.environ.get("POSTHOG_API_HOST", "https://g.massdriver.cloud").strip()


@app.route("/")
def index():
    # The state grid is drawn client-side from /api/stats, which a crawler does
    # not execute. Pass the same links through the server-rendered HTML so the
    # state pages are reachable without JavaScript.
    stats = get_stats()
    links = sorted(
        (
            {"name": STATE_NAMES[a], "slug": ABBR_TO_SLUG[a],
             "average": r["average"], "count": r["count"]}
            for a, r in stats["states"].items()
            if a in STATE_NAMES
        ),
        key=lambda s: s["name"],
    )
    return render_template(
        "index.html",
        state_links=links,
        base=base_url(),
        posthog_key=POSTHOG_PROJECT_KEY,
        posthog_host=POSTHOG_API_HOST,
    )


@app.route("/security.html")
def security():
    # Static record of the deploy-time policy scan, for security/compliance review.
    # Intentionally not generated at request time: it documents a specific pair of
    # deployments (named on the page) and must not silently appear to describe a
    # newer one. Update it when the scan results actually change.
    return render_template("security.html")


@app.route("/healthz")
def healthz():
    return "ok"


@app.route("/api/submit", methods=["POST"])
def submit():
    data = request.get_json(silent=True) or {}
    zip_code = str(data.get("zip_code", "")).strip()
    amount_raw = data.get("amount")

    if not ZIP_RE.match(zip_code):
        return jsonify(error="Enter a 5-digit US zip code."), 400

    try:
        amount = float(amount_raw)
    except (TypeError, ValueError):
        return jsonify(error="Enter a dollar amount."), 400

    if amount != amount or amount in (float("inf"), float("-inf")):
        return jsonify(error="Enter a real dollar amount."), 400

    if amount < MIN_AMOUNT or amount > MAX_AMOUNT:
        return jsonify(
            error=f"Enter an amount between ${MIN_AMOUNT:.2f} and ${MAX_AMOUNT:.0f}."
        ), 400

    state = zip_to_state(zip_code)
    if not state:
        return jsonify(error="That zip code isn't recognized."), 400

    amount = round(amount, 2)
    # zip_code goes out of scope here and is never referenced again -- only
    # the derived state, the amount, and a server timestamp get written.

    db = get_db()
    batch = db.batch()

    submission_ref = db.collection("submissions").document()
    batch.set(submission_ref, {
        "state": state,
        "amount": amount,
        "submitted_at": firestore.SERVER_TIMESTAMP,
    })

    national_ref = db.collection("aggregates").document("national")
    batch.set(national_ref, {
        "sum": firestore.Increment(amount),
        "count": firestore.Increment(1),
    }, merge=True)

    state_ref = db.collection("state_totals").document(state)
    batch.set(state_ref, {
        "sum": firestore.Increment(amount),
        "count": firestore.Increment(1),
    }, merge=True)

    batch.commit()
    invalidate_cache()

    return jsonify(ok=True, state=state)


@app.route("/api/stats")
def stats():
    now = time.time()
    with _cache_lock:
        if _cache["payload"] is not None and now < _cache["expires_at"]:
            return jsonify(_cache["payload"])

    payload = build_stats()

    with _cache_lock:
        _cache["payload"] = payload
        _cache["expires_at"] = time.time() + STATS_CACHE_SECONDS

    return jsonify(payload)


def get_stats():
    """Cached stats for server-rendered pages. Shares the cache with
    /api/stats so a crawler sweeping 50 state pages causes no extra reads."""
    now = time.time()
    with _cache_lock:
        if _cache["payload"] is not None and now < _cache["expires_at"]:
            return _cache["payload"]

    payload = build_stats()

    with _cache_lock:
        _cache["payload"] = payload
        _cache["expires_at"] = time.time() + STATS_CACHE_SECONDS

    return payload


def build_stats():
    db = get_db()

    national_doc = db.collection("aggregates").document("national").get()
    national = national_doc.to_dict() or {}
    national_count = int(national.get("count", 0) or 0)
    national_sum = float(national.get("sum", 0.0) or 0.0)
    national_average = round(national_sum / national_count, 2) if national_count else None

    states = {}
    for doc in db.collection("state_totals").stream():
        d = doc.to_dict() or {}
        count = int(d.get("count", 0) or 0)
        total = float(d.get("sum", 0.0) or 0.0)
        if count:
            states[doc.id] = {"average": round(total / count, 2), "count": count}

    # Rank states by average, highest first. Ties share the lower rank number,
    # so two states at $5.00 are both "#1" and the next is "#3".
    ranked = sorted(states.items(), key=lambda kv: -kv[1]["average"])
    previous_average = None
    for position, (abbr, row) in enumerate(ranked, start=1):
        if previous_average is not None and row["average"] == previous_average:
            row["rank"] = ranked[position - 2][1]["rank"]
        else:
            row["rank"] = position
        previous_average = row["average"]

    cutoff = datetime.now(timezone.utc) - timedelta(days=TIMESERIES_WINDOW_DAYS)
    buckets = defaultdict(lambda: {"sum": 0.0, "count": 0})
    state_buckets = defaultdict(lambda: defaultdict(lambda: {"sum": 0.0, "count": 0}))
    query = (
        db.collection("submissions")
        .where(filter=FieldFilter("submitted_at", ">=", cutoff))
        .order_by("submitted_at")
        .limit(TIMESERIES_DOC_LIMIT)
    )
    for doc in query.stream():
        d = doc.to_dict() or {}
        ts = d.get("submitted_at")
        if ts is None:
            continue
        amount = float(d.get("amount", 0.0) or 0.0)
        day = ts.strftime("%Y-%m-%d")
        buckets[day]["sum"] += amount
        buckets[day]["count"] += 1
        abbr = d.get("state")
        if abbr:
            sb = state_buckets[abbr][day]
            sb["sum"] += amount
            sb["count"] += 1

    def series(raw):
        return [
            {"date": day, "average": round(v["sum"] / v["count"], 2), "count": v["count"]}
            for day, v in sorted(raw.items())
            if v["count"]
        ]

    return {
        "national": {"average": national_average, "count": national_count},
        "states": states,
        "timeseries": series(buckets),
        "state_timeseries": {abbr: series(raw) for abbr, raw in state_buckets.items()},
    }


# --- Open Graph share card --------------------------------------------------
# Drawn with Pillow rather than a headless browser: a browser would add
# hundreds of MB to the image and seconds to a cold start, and this card is
# only type and rectangles.
OG_W, OG_H = 1200, 630
_OG_PAGE = (249, 249, 247)
_OG_SURFACE = (252, 252, 251)
_OG_INK = (11, 11, 11)
_OG_SECOND = (82, 81, 78)
_OG_MUTED = (137, 135, 129)
_OG_SERIES = (42, 120, 214)
_OG_BORDER = (225, 224, 217)

_FONT_CANDIDATES = {
    "bold": [
        "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
        "/System/Library/Fonts/Supplemental/Arial Bold.ttf",
    ],
    "regular": [
        "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf",
        "/System/Library/Fonts/Supplemental/Arial.ttf",
    ],
}
_font_cache = {}


def _font(weight, size):
    key = (weight, size)
    if key not in _font_cache:
        loaded = None
        for path in _FONT_CANDIDATES[weight]:
            try:
                loaded = ImageFont.truetype(path, size)
                break
            except OSError:
                continue
        _font_cache[key] = loaded or ImageFont.load_default()
    return _font_cache[key]


def render_og_card(view):
    img = Image.new("RGB", (OG_W, OG_H), _OG_PAGE)
    d = ImageDraw.Draw(img)

    pad = 48
    d.rounded_rectangle([pad, pad, OG_W - pad, OG_H - pad], radius=28,
                        fill=_OG_SURFACE, outline=_OG_BORDER, width=2)

    x = pad + 56
    y = pad + 46
    d.text((x, y), "TOOTH FAIRY RATE INDEX", font=_font("regular", 25), fill=_OG_MUTED)
    y += 46
    d.text((x, y), view["name"], font=_font("bold", 52), fill=_OG_SECOND)
    y += 70

    if view["average"] is None:
        d.text((x, y), "No reports yet", font=_font("bold", 92), fill=_OG_INK)
        d.text((x, y + 130), "Be the first to add one.",
               font=_font("regular", 32), fill=_OG_SECOND)
        return _png_bytes(img)

    amount = f"${view['average']:,.2f}"
    f_amount = _font("bold", 140)
    d.text((x, y), amount, font=f_amount, fill=_OG_INK)
    box = d.textbbox((x, y), amount, font=f_amount)
    d.text((box[2] + 20, box[3] - 44), "per tooth", font=_font("regular", 31), fill=_OG_MUTED)
    y = box[3] + 30

    national = view["national"]
    content_bottom = y
    if national:
        bar_w = OG_W - 2 * pad - 112
        bar_h = 14
        d.rounded_rectangle([x, y, x + bar_w, y + bar_h], radius=7, fill=_OG_BORDER)
        frac = min(view["average"] / (national * 2), 1.0)
        if frac > 0.02:
            d.rounded_rectangle([x, y, x + int(bar_w * frac), y + bar_h],
                                radius=7, fill=_OG_SERIES)
        mid = x + bar_w // 2
        d.rectangle([mid - 2, y - 9, mid + 2, y + bar_h + 9], fill=_OG_SECOND)
        y += bar_h + 22
        word = "above" if view["delta"] >= 0 else "below"
        note = f"${abs(view['delta']):,.2f} {word} the national average of ${national:,.2f}"
        f_note = _font("regular", 25)
        d.text((x, y), note, font=f_note, fill=_OG_SECOND)
        content_bottom = d.textbbox((x, y), note, font=f_note)[3]

    # Place the footer rule below whatever the body actually ended up needing,
    # so a font with different metrics cannot push the note into the rule.
    f_small = _font("regular", 25)
    rule_y = max(content_bottom + 26, OG_H - pad - 78)
    fy = rule_y + 16
    d.line([x, rule_y, OG_W - pad - 56, rule_y], fill=_OG_BORDER, width=2)
    if view["rank"]:
        d.text((x, fy), f"#{view['rank']} of {view['ranked_total']} states",
               font=f_small, fill=_OG_SECOND)
    reports = f"{view['count']:,} report{'s' if view['count'] != 1 else ''}"
    rb = d.textbbox((0, 0), reports, font=f_small)
    d.text((OG_W - pad - 56 - (rb[2] - rb[0]), fy), reports, font=f_small, fill=_OG_MUTED)

    return _png_bytes(img)


def _png_bytes(img):
    buf = io.BytesIO()
    img.save(buf, format="PNG", optimize=True)
    return buf.getvalue()


def state_view(abbr):
    """Everything a state page and its share card need."""
    stats = get_stats()
    row = stats["states"].get(abbr) or {}
    count = int(row.get("count", 0) or 0)
    national = stats["national"]["average"]

    peers = sorted(
        (
            {
                "abbr": a,
                "name": STATE_NAMES[a],
                "slug": ABBR_TO_SLUG[a],
                "average": r["average"],
                "count": r["count"],
                "rank": r.get("rank"),
            }
            for a, r in stats["states"].items()
            if a in STATE_NAMES
        ),
        key=lambda s: -s["average"],
    )

    return {
        "abbr": abbr,
        "name": STATE_NAMES[abbr],
        "slug": ABBR_TO_SLUG[abbr],
        "average": row.get("average"),
        "count": count,
        "rank": row.get("rank"),
        "ranked_total": len(stats["states"]),
        "national": national,
        "delta": None if (national is None or row.get("average") is None)
        else round(row["average"] - national, 2),
        "timeseries": stats.get("state_timeseries", {}).get(abbr, []),
        "indexable": count >= INDEX_MIN_REPORTS,
        "highest": peers[:5],
        "lowest": list(reversed(peers[-5:])) if len(peers) > 5 else [],
    }


@app.route("/<slug>")
def state_page(slug):
    if slug in RESERVED_PATHS:
        return not_found(None)
    abbr = SLUG_TO_ABBR.get(slug.lower())
    if not abbr:
        return not_found(None)
    view = state_view(abbr)
    return render_template(
        "state.html",
        s=view,
        base=base_url(),
        posthog_key=POSTHOG_PROJECT_KEY,
        posthog_host=POSTHOG_API_HOST,
    )


@app.route("/og/<slug>.png")
def og_image(slug):
    abbr = SLUG_TO_ABBR.get(slug.lower())
    if not abbr:
        return not_found(None)
    view = state_view(abbr)
    png = render_og_card(view)
    response = app.response_class(png, mimetype="image/png")
    # Social scrapers refetch often. Cache for an hour, and let the count in
    # the ETag bust it whenever the number a visitor would share actually moves.
    response.headers["Cache-Control"] = "public, max-age=3600"
    response.headers["ETag"] = f'"{abbr}-{view["count"]}-{view["average"]}"'
    return response


@app.route("/sitemap.xml")
def sitemap():
    root = base_url()
    stats = get_stats()
    urls = [f"<url><loc>{root}/</loc><priority>1.0</priority></url>"]
    for abbr, row in sorted(stats["states"].items()):
        # Only list pages that carry enough data to deserve indexing.
        if abbr in ABBR_TO_SLUG and int(row.get("count", 0) or 0) >= INDEX_MIN_REPORTS:
            urls.append(
                f"<url><loc>{root}/{ABBR_TO_SLUG[abbr]}</loc><priority>0.8</priority></url>"
            )
    body = (
        '<?xml version="1.0" encoding="UTF-8"?>\n'
        '<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">\n'
        + "\n".join(urls)
        + "\n</urlset>\n"
    )
    return app.response_class(body, mimetype="application/xml")


@app.route("/robots.txt")
def robots():
    body = f"User-agent: *\nAllow: /\nSitemap: {base_url()}/sitemap.xml\n"
    return app.response_class(body, mimetype="text/plain")


@app.errorhandler(404)
def not_found(_e):
    stats = get_stats()
    known = sorted(
        (
            {"name": STATE_NAMES[a], "slug": ABBR_TO_SLUG[a], "average": r["average"]}
            for a, r in stats["states"].items()
            if a in STATE_NAMES
        ),
        key=lambda s: s["name"],
    )
    return render_template("404.html", states=known, base=base_url()), 404


if __name__ == "__main__":
    port = int(os.environ.get("PORT", 8080))
    app.run(host="0.0.0.0", port=port)
