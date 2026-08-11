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

import os
import re
import threading
import time
from collections import defaultdict
from datetime import datetime, timedelta, timezone

from flask import Flask, jsonify, render_template, request
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
    return render_template(
        "index.html",
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

    cutoff = datetime.now(timezone.utc) - timedelta(days=TIMESERIES_WINDOW_DAYS)
    buckets = defaultdict(lambda: {"sum": 0.0, "count": 0})
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

    timeseries = [
        {"date": day, "average": round(v["sum"] / v["count"], 2), "count": v["count"]}
        for day, v in sorted(buckets.items())
        if v["count"]
    ]

    return {
        "national": {"average": national_average, "count": national_count},
        "states": states,
        "timeseries": timeseries,
    }


if __name__ == "__main__":
    port = int(os.environ.get("PORT", 8080))
    app.run(host="0.0.0.0", port=port)
