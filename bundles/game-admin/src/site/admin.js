/* ---------------------------------------------------------------------------
   Game Admin console.

   No build step, no dependencies. The API address comes from config.js, which
   is written next to this file at deploy time:

       window.GAME_API = "https://xxxx.execute-api.us-east-1.amazonaws.com";

   API contract (fixed):
     GET  /api/admin/players  -> { players: [...] }
     POST /api/admin/player   -> { player }   body: { username, hp?, rocks?,
                                                      sticks?, x?, y?, alive? }
                                              only the fields sent are changed
     POST /api/admin/delete   -> { ok: true } body: { username }
   Errors are 4xx with { "error": "..." }.
--------------------------------------------------------------------------- */

(function () {
  "use strict";

  var REFRESH_MS = 3000; // poll interval
  var TICK_MS = 1000; // clock for relative times
  var STATUS_MS = 4000; // how long a row pill sticks around
  var CONFIRM_MS = 4000; // how long a delete stays armed
  var OVERRIDE_KEY = "gameAdmin.apiOverride";

  // Editable numeric columns, in table order.
  var FIELDS = ["hp", "rocks", "sticks", "x", "y"];

  var el = {
    apiHost: byId("apiHost"),
    conn: byId("conn"),
    connDot: byId("connDot"),
    connText: byId("connText"),
    autoRefresh: byId("autoRefresh"),
    refreshNow: byId("refreshNow"),
    banner: byId("banner"),
    bannerText: byId("bannerText"),
    bannerNote: byId("bannerNote"),
    statPlayers: byId("statPlayers"),
    statAlive: byId("statAlive"),
    statDead: byId("statDead"),
    statRocks: byId("statRocks"),
    statSticks: byId("statSticks"),
    statUpdated: byId("statUpdated"),
    search: byId("search"),
    count: byId("count"),
    dirtyNote: byId("dirtyNote"),
    thead: document.querySelector("thead"),
    tbody: byId("tbody"),
    empty: byId("empty"),
    emptyTitle: byId("emptyTitle"),
    emptySub: byId("emptySub"),
    noconfig: byId("noconfig"),
    overrideForm: byId("overrideForm"),
    overrideUrl: byId("overrideUrl")
  };

  var state = {
    players: [], // last good snapshot from the API
    byName: Object.create(null),
    sortKey: "last_seen",
    sortDir: -1, // 1 asc, -1 desc
    filter: "",
    auto: true,
    error: null,
    lastOk: 0,
    started: false,
    inflight: false
  };

  // username -> { tr, inputs, maxhp, hpbar, hpfill, badge, seen, dot, pill,
  //               buttons, pillTimer, busy }
  var rows = new Map();
  var pollTimer = null;

  function byId(id) {
    return document.getElementById(id);
  }

  /* ------------------------------------------------------------- API base -- */

  function apiBase() {
    var fromConfig =
      typeof window.GAME_API === "string" && window.GAME_API.trim() ? window.GAME_API.trim() : "";
    var override = "";
    try {
      override = window.localStorage.getItem(OVERRIDE_KEY) || "";
    } catch (e) {
      override = "";
    }
    return (fromConfig || override).replace(/\/+$/, "");
  }

  function hostLabel(base) {
    try {
      return new URL(base).host;
    } catch (e) {
      return base;
    }
  }

  /* ----------------------------------------------------------------- HTTP -- */

  function request(path, body) {
    var base = apiBase();
    if (!base) return Promise.reject(new Error("No API address configured"));

    var opts = { method: body ? "POST" : "GET", cache: "no-store" };
    if (body) {
      opts.headers = { "content-type": "application/json" };
      opts.body = JSON.stringify(body);
    }

    return fetch(base + path, opts).then(function (res) {
      return res.text().then(function (text) {
        var data = null;
        if (text) {
          try {
            data = JSON.parse(text);
          } catch (e) {
            data = null;
          }
        }
        if (!res.ok) {
          var msg =
            (data && typeof data.error === "string" && data.error) ||
            "HTTP " + res.status + (res.statusText ? " " + res.statusText : "");
          var err = new Error(msg);
          err.status = res.status;
          throw err;
        }
        if (data === null) throw new Error("API returned a response that was not JSON");
        return data;
      });
    });
  }

  function errText(e) {
    if (!e) return "Unknown error";
    // fetch() rejects with a TypeError for DNS, TLS, CORS and offline failures.
    if (e.name === "TypeError") return "Could not reach the API (network, CORS, or DNS)";
    return e.message || String(e);
  }

  /* ------------------------------------------------------------- players --- */

  function num(v, fallback) {
    var n = Number(v);
    return isFinite(n) ? n : fallback;
  }

  // Tolerate missing or oddly-typed fields so one bad record cannot blank the
  // whole console.
  function normalize(p) {
    p = p || {};
    var hp = num(p.hp, 0);
    var maxRaw = p.max_hp;
    var max_hp = maxRaw === null || maxRaw === undefined || maxRaw === "" ? null : num(maxRaw, null);
    var seen = p.last_seen === null || p.last_seen === undefined ? null : num(p.last_seen, null);
    // Contract says seconds; a millisecond timestamp is accepted too. A zero or
    // missing stamp means the player has never checked in, not 1970.
    if (seen !== null && seen > 1e12) seen = seen / 1000;
    if (seen !== null && seen <= 0) seen = null;

    return {
      username: String(p.username === undefined || p.username === null ? "" : p.username),
      hp: hp,
      max_hp: max_hp,
      rocks: num(p.rocks, 0),
      sticks: num(p.sticks, 0),
      x: num(p.x, 0),
      y: num(p.y, 0),
      alive: typeof p.alive === "boolean" ? p.alive : hp > 0,
      last_seen: seen
    };
  }

  function indexPlayers(list) {
    var map = Object.create(null);
    for (var i = 0; i < list.length; i++) map[list[i].username] = list[i];
    state.players = list;
    state.byName = map;
  }

  function upsertPlayer(p) {
    var existing = state.byName[p.username];
    if (existing) {
      var idx = state.players.indexOf(existing);
      if (idx >= 0) state.players[idx] = p;
      else state.players.push(p);
    } else {
      state.players.push(p);
    }
    state.byName[p.username] = p;
  }

  function removePlayer(username) {
    var p = state.byName[username];
    if (p) {
      var idx = state.players.indexOf(p);
      if (idx >= 0) state.players.splice(idx, 1);
      delete state.byName[username];
    }
  }

  /* ------------------------------------------------------------ polling ---- */

  function schedule() {
    if (pollTimer) clearTimeout(pollTimer);
    pollTimer = setTimeout(tick, REFRESH_MS);
  }

  function tick() {
    if (state.auto && !document.hidden) refresh();
    else schedule();
  }

  function refresh() {
    if (state.inflight) {
      schedule();
      return;
    }
    if (!apiBase()) {
      showNoConfig();
      return;
    }
    state.inflight = true;

    request("/api/admin/players")
      .then(function (data) {
        var raw = data && Array.isArray(data.players) ? data.players : [];
        var list = [];
        for (var i = 0; i < raw.length; i++) {
          var p = normalize(raw[i]);
          if (p.username) list.push(p);
        }
        indexPlayers(list);
        state.error = null;
        state.lastOk = Date.now();
        state.started = true;
      })
      .catch(function (e) {
        state.error = errText(e);
      })
      .then(function () {
        state.inflight = false;
        render();
        schedule();
      });
  }

  /* ------------------------------------------------------------- rendering - */

  function filtered() {
    var q = state.filter.trim().toLowerCase();
    var list = q
      ? state.players.filter(function (p) {
          return p.username.toLowerCase().indexOf(q) !== -1;
        })
      : state.players.slice();

    var key = state.sortKey;
    var dir = state.sortDir;

    list.sort(function (a, b) {
      var r;
      if (key === "username") {
        r = a.username.localeCompare(b.username, undefined, { numeric: true, sensitivity: "base" });
      } else if (key === "alive") {
        r = (a.alive ? 1 : 0) - (b.alive ? 1 : 0);
      } else {
        var av = a[key],
          bv = b[key];
        if (av === null || av === undefined) av = -Infinity;
        if (bv === null || bv === undefined) bv = -Infinity;
        r = av - bv;
      }
      if (r) return r * dir;
      return a.username.localeCompare(b.username);
    });

    return list;
  }

  // The username of the row that currently owns keyboard focus, if any. Rows
  // are never moved or removed while the operator is inside them.
  function focusedUser() {
    var a = document.activeElement;
    if (!a || !el.tbody.contains(a)) return null;
    var tr = a.closest ? a.closest("tr") : null;
    return tr ? tr.dataset.user : null;
  }

  function render() {
    renderStats();
    renderConn();
    renderBanner();
    renderRows();
    renderSortIndicators();
  }

  function renderStats() {
    var total = state.players.length;
    var alive = 0,
      rocks = 0,
      sticks = 0;
    for (var i = 0; i < total; i++) {
      var p = state.players[i];
      if (p.alive) alive++;
      rocks += p.rocks;
      sticks += p.sticks;
    }
    el.statPlayers.textContent = state.started ? fmt(total) : "—";
    el.statAlive.textContent = state.started ? fmt(alive) : "—";
    el.statDead.textContent = state.started ? fmt(total - alive) + " dead" : "";
    el.statRocks.textContent = state.started ? fmt(rocks) : "—";
    el.statSticks.textContent = state.started ? fmt(sticks) : "—";
  }

  function renderConn() {
    var cls, text;
    if (state.error) {
      cls = "down";
      text = "Disconnected";
    } else if (!state.auto) {
      cls = "paused";
      text = "Paused";
    } else if (state.started) {
      cls = "live";
      text = "Live";
    } else {
      cls = "";
      text = "Connecting";
    }
    el.conn.className = "conn " + cls;
    el.connText.textContent = text;
  }

  function renderBanner() {
    if (!state.error) {
      el.banner.hidden = true;
      return;
    }
    el.banner.hidden = false;
    el.bannerText.textContent = state.error;
    el.bannerNote.textContent = state.auto
      ? "Retrying every " +
        Math.round(REFRESH_MS / 1000) +
        "s" +
        (state.players.length ? " — showing the last data received." : ".")
      : "Auto-refresh is paused. Turn it back on or press Refresh now to retry.";
  }

  function renderSortIndicators() {
    var ths = el.thead.querySelectorAll("th.sortable");
    for (var i = 0; i < ths.length; i++) {
      var th = ths[i];
      var on = th.dataset.key === state.sortKey;
      th.classList.toggle("sorted", on);
      th.classList.toggle("desc", on && state.sortDir === -1);
      if (on) th.setAttribute("aria-sort", state.sortDir === 1 ? "ascending" : "descending");
      else th.removeAttribute("aria-sort");
    }
  }

  function renderRows() {
    var list = filtered();
    var seenNames = Object.create(null);
    var i;

    for (i = 0; i < list.length; i++) {
      seenNames[list[i].username] = true;
      var entry = rows.get(list[i].username);
      if (!entry) {
        entry = createRow(list[i].username);
        rows.set(list[i].username, entry);
      }
      if (!entry.tr.parentNode) el.tbody.appendChild(entry.tr); // appending never disturbs focus
      updateRow(entry, list[i]);
    }

    // Drop rows that filtered out, were deleted, or vanished from the API. A row
    // with unsaved edits is only detached, so filtering away and back does not
    // throw the operator's typing on the floor.
    rows.forEach(function (entry, name) {
      if (seenNames[name]) return;
      if (entry.tr.parentNode) entry.tr.parentNode.removeChild(entry.tr);
      if (state.byName[name] && rowChanges(entry)) return;
      if (entry.pillTimer) clearTimeout(entry.pillTimer);
      rows.delete(name);
    });

    // Reordering moves DOM nodes, which drops focus, so skip it while editing.
    // Checked after the removals above, which may have released the focus.
    if (!focusedUser()) reorder(list);

    var shown = list.length;
    var total = state.players.length;
    el.count.textContent = state.started
      ? shown === total
        ? fmt(total) + (total === 1 ? " player" : " players")
        : fmt(shown) + " of " + fmt(total) + " players"
      : "";

    var empty = shown === 0;
    el.empty.hidden = !empty;
    if (empty) {
      if (!state.started) {
        el.emptyTitle.textContent = state.error ? "Could not load players" : "Loading players…";
        el.emptySub.textContent = state.error ? state.error : "";
      } else if (total === 0) {
        el.emptyTitle.textContent = "No players yet";
        el.emptySub.textContent = "Players appear here as soon as they join the game.";
      } else {
        el.emptyTitle.textContent = "No players match that filter";
        el.emptySub.textContent = "Nothing matched “" + state.filter + "”.";
      }
    }

    renderDirtyNote();
  }

  function reorder(list) {
    var ref = el.tbody.firstChild;
    for (var i = 0; i < list.length; i++) {
      var entry = rows.get(list[i].username);
      if (!entry) continue;
      var tr = entry.tr;
      if (tr === ref) {
        ref = ref.nextSibling;
      } else {
        el.tbody.insertBefore(tr, ref);
      }
    }
  }

  var ROW_HTML = [
    '<td class="c-name"><span class="uname"></span></td>',
    '<td class="c-num">',
    '<div class="hpcell"><input type="number" class="num" data-field="hp" step="1" aria-label="HP">',
    '<span class="sep">/</span><span class="maxhp mono"></span></div>',
    '<div class="hpbar"><i></i></div></td>',
    '<td class="c-num"><input type="number" class="num" data-field="rocks" step="1" aria-label="Rocks"></td>',
    '<td class="c-num"><input type="number" class="num" data-field="sticks" step="1" aria-label="Sticks"></td>',
    '<td class="c-num"><input type="number" class="num" data-field="x" step="1" aria-label="X"></td>',
    '<td class="c-num"><input type="number" class="num" data-field="y" step="1" aria-label="Y"></td>',
    '<td class="c-state"><span class="badge"></span></td>',
    '<td class="c-seen"><span class="freshdot"></span><span class="seen mono"></span></td>',
    '<td class="c-actions"><div class="actions">',
    '<button class="btn btn-xs" type="button" data-act="save" disabled>Save</button>',
    '<span class="divider"></span>',
    '<button class="btn btn-xs" type="button" data-act="heal" title="Set HP to max_hp">Heal</button>',
    '<button class="btn btn-xs" type="button" data-act="rocks" title="Add 10 rocks">+10 rocks</button>',
    '<button class="btn btn-xs" type="button" data-act="sticks" title="Add 10 sticks">+10 sticks</button>',
    '<span class="divider"></span>',
    '<button class="btn btn-xs" type="button" data-act="kill" title="Set HP to 0">Kill</button>',
    '<button class="btn btn-xs" type="button" data-act="revive" title="Bring back to life">Revive</button>',
    '<button class="btn btn-xs btn-danger" type="button" data-act="delete" title="Delete this player">Delete</button>',
    '<span class="pill" hidden></span>',
    "</div></td>"
  ].join("");

  function createRow(username) {
    var tr = document.createElement("tr");
    tr.dataset.user = username;
    tr.innerHTML = ROW_HTML; // static markup only; player data is set via textContent

    var entry = {
      tr: tr,
      uname: tr.querySelector(".uname"),
      inputs: {},
      maxhp: tr.querySelector(".maxhp"),
      hpbar: tr.querySelector(".hpbar"),
      hpfill: tr.querySelector(".hpbar i"),
      badge: tr.querySelector(".badge"),
      seen: tr.querySelector(".seen"),
      dot: tr.querySelector(".freshdot"),
      pill: tr.querySelector(".pill"),
      save: tr.querySelector('[data-act="save"]'),
      buttons: tr.querySelectorAll("button"),
      pillTimer: null,
      busy: false
    };

    for (var i = 0; i < FIELDS.length; i++) {
      entry.inputs[FIELDS[i]] = tr.querySelector('input[data-field="' + FIELDS[i] + '"]');
    }

    entry.uname.textContent = username;
    return entry;
  }

  function updateRow(entry, p) {
    entry.tr.classList.toggle("dead", !p.alive);

    for (var i = 0; i < FIELDS.length; i++) {
      var f = FIELDS[i];
      var input = entry.inputs[f];
      var server = String(p[f]);

      // Never touch the field the operator is in.
      if (document.activeElement === input) continue;

      if (input.dataset.dirty === "1") {
        // Unsaved edit: keep what was typed, but move the baseline so a later
        // save still sends the right diff.
        input.dataset.server = server;
        markDirty(input);
      } else if (input.dataset.server !== server || input.value === "") {
        input.value = server;
        input.dataset.server = server;
        markDirty(input);
      }
    }

    entry.maxhp.textContent = p.max_hp === null ? "?" : String(p.max_hp);

    var pct = p.max_hp && p.max_hp > 0 ? Math.max(0, Math.min(1, p.hp / p.max_hp)) : 0;
    entry.hpfill.style.width = (pct * 100).toFixed(1) + "%";
    entry.hpbar.classList.toggle("low", pct <= 0.5 && pct > 0.25);
    entry.hpbar.classList.toggle("crit", pct <= 0.25);

    entry.badge.textContent = p.alive ? "ALIVE" : "DEAD";
    entry.badge.className = "badge " + (p.alive ? "alive" : "deadb");

    entry.tr.querySelector('[data-act="heal"]').disabled = p.max_hp === null || entry.busy;

    paintSeen(entry, p);
    refreshSaveState(entry);
  }

  function paintSeen(entry, p) {
    if (!p || p.last_seen === null) {
      entry.seen.textContent = "never";
      entry.dot.className = "freshdot stale";
      return;
    }
    var age = Date.now() / 1000 - p.last_seen;
    entry.seen.textContent = relative(age);
    entry.dot.className =
      "freshdot " + (age < 15 ? "fresh" : age < 60 ? "recent" : age < 600 ? "" : "stale");
  }

  function relative(seconds) {
    if (seconds < 0) {
      // Clock skew between the browser and the API — do not show "-4s ago".
      if (seconds > -120) return "just now";
      seconds = Math.abs(seconds);
      return "in " + relative(seconds).replace(" ago", "");
    }
    var s = Math.floor(seconds);
    if (s < 1) return "just now";
    if (s < 60) return s + "s ago";
    var m = Math.floor(s / 60);
    if (m < 60) return m + "m " + (s % 60) + "s ago";
    var h = Math.floor(m / 60);
    if (h < 24) return h + "h " + (m % 60) + "m ago";
    var d = Math.floor(h / 24);
    return d + "d " + (h % 24) + "h ago";
  }

  function fmt(n) {
    return String(n).replace(/\B(?=(\d{3})+(?!\d))/g, ",");
  }

  /* ------------------------------------------------------------ dirty state */

  function markDirty(input) {
    var dirty = input.value.trim() !== "" && input.value.trim() !== input.dataset.server;
    input.dataset.dirty = dirty ? "1" : "0";
    input.classList.toggle("dirty", dirty);
  }

  function rowChanges(entry) {
    var changes = {};
    var count = 0;
    for (var i = 0; i < FIELDS.length; i++) {
      var f = FIELDS[i];
      var input = entry.inputs[f];
      var raw = input.value.trim();
      if (raw === "") continue; // blank means "leave this one alone"
      var n = Number(raw);
      if (!isFinite(n)) continue;
      n = Math.round(n);
      if (String(n) !== input.dataset.server) {
        changes[f] = n;
        count++;
      }
    }
    return count ? changes : null;
  }

  function refreshSaveState(entry) {
    // Save only reads as the primary action once there is something to save,
    // otherwise a full table of blue buttons shouts at the operator.
    var has = !!rowChanges(entry);
    entry.save.disabled = entry.busy || !has;
    entry.save.classList.toggle("btn-primary", has);
  }

  function renderDirtyNote() {
    var n = 0;
    rows.forEach(function (entry) {
      if (rowChanges(entry)) n++;
    });
    el.dirtyNote.hidden = n === 0;
    if (n) {
      el.dirtyNote.textContent =
        n + (n === 1 ? " row has" : " rows have") + " unsaved edits — refresh will not overwrite them";
    }
  }

  function revertRow(entry) {
    for (var i = 0; i < FIELDS.length; i++) {
      var input = entry.inputs[FIELDS[i]];
      input.value = input.dataset.server || "";
      markDirty(input);
    }
    refreshSaveState(entry);
    renderDirtyNote();
    status(entry, "info", "Reverted");
  }

  /* ---------------------------------------------------------------- status - */

  function status(entry, kind, text) {
    if (entry.pillTimer) clearTimeout(entry.pillTimer);
    entry.pill.hidden = false;
    entry.pill.className = "pill " + kind;
    entry.pill.textContent = text;
    entry.pill.title = text;
    entry.pillTimer = setTimeout(function () {
      entry.pill.hidden = true;
      entry.pill.textContent = "";
      entry.pillTimer = null;
    }, kind === "err" ? STATUS_MS * 2 : STATUS_MS);
  }

  function setBusy(entry, busy) {
    entry.busy = busy;
    entry.tr.classList.toggle("busy", busy);
    for (var i = 0; i < entry.buttons.length; i++) entry.buttons[i].disabled = busy;
    if (!busy) {
      var p = state.byName[entry.tr.dataset.user];
      entry.tr.querySelector('[data-act="heal"]').disabled = !p || p.max_hp === null;
      refreshSaveState(entry);
    }
  }

  /* ----------------------------------------------------------------- writes */

  // Send a patch for one player. `okLabel` is what the row pill shows on success.
  function patch(entry, changes, okLabel) {
    var username = entry.tr.dataset.user;
    var body = { username: username };
    for (var k in changes) if (Object.prototype.hasOwnProperty.call(changes, k)) body[k] = changes[k];

    setBusy(entry, true);
    status(entry, "info", "Saving…");

    return request("/api/admin/player", body)
      .then(function (data) {
        // Prefer the server's copy. If the response omits `player`, fall back to
        // merging locally and let the next poll correct it.
        var merged;
        if (data && data.player && typeof data.player === "object") {
          merged = normalize(data.player);
          if (!merged.username) merged.username = username;
        } else {
          var current = state.byName[username] || { username: username };
          merged = normalize(Object.assign({}, current, changes));
        }
        upsertPlayer(merged);

        // The values just written are authoritative now: clear the edit state.
        for (var i = 0; i < FIELDS.length; i++) {
          var input = entry.inputs[FIELDS[i]];
          input.value = String(merged[FIELDS[i]]);
          input.dataset.server = String(merged[FIELDS[i]]);
          markDirty(input);
        }

        setBusy(entry, false);
        updateRow(entry, merged);

        // The API may clamp what it was sent (world bounds, no negative counts).
        // Say so rather than letting the number quietly snap to something else.
        var adjusted = false;
        for (var f in changes) {
          if (!Object.prototype.hasOwnProperty.call(changes, f)) continue;
          if (typeof changes[f] === "number" && merged[f] !== changes[f]) adjusted = true;
        }
        status(entry, "ok", adjusted ? okLabel + " — API adjusted the value" : okLabel);

        renderStats();
        renderDirtyNote();
      })
      .catch(function (e) {
        setBusy(entry, false);
        status(entry, "err", errText(e));
      });
  }

  function saveRow(entry) {
    var changes = rowChanges(entry);
    if (!changes) {
      status(entry, "info", "No changes");
      return;
    }
    patch(entry, changes, "Saved");
  }

  function quickAction(entry, act) {
    var username = entry.tr.dataset.user;
    var p = state.byName[username];
    if (!p) {
      status(entry, "err", "Player not loaded yet");
      return;
    }

    switch (act) {
      case "heal":
        if (p.max_hp === null) {
          status(entry, "err", "No max_hp reported for this player");
          return;
        }
        patch(entry, { hp: p.max_hp }, "Healed to " + p.max_hp);
        break;
      case "rocks":
        patch(entry, { rocks: p.rocks + 10 }, "+10 rocks");
        break;
      case "sticks":
        patch(entry, { sticks: p.sticks + 10 }, "+10 sticks");
        break;
      case "kill":
        // alive is sent too in case the API does not derive it from hp.
        patch(entry, { hp: 0, alive: false }, "Killed");
        break;
      case "revive": {
        var body = { alive: true };
        if (p.hp <= 0) body.hp = p.max_hp !== null ? Math.min(1, p.max_hp) : 1;
        patch(entry, body, "Revived");
        break;
      }
    }
  }

  function armDelete(btn) {
    if (btn.dataset.armed === "1") return true;
    btn.dataset.armed = "1";
    btn.dataset.label = btn.textContent;
    btn.textContent = "Confirm?";
    btn.classList.add("confirming");
    btn._disarm = setTimeout(function () {
      disarmDelete(btn);
    }, CONFIRM_MS);
    return false;
  }

  function disarmDelete(btn) {
    if (btn.dataset.armed !== "1") return;
    if (btn._disarm) clearTimeout(btn._disarm);
    btn._disarm = null;
    btn.dataset.armed = "0";
    btn.textContent = btn.dataset.label || "Delete";
    btn.classList.remove("confirming");
  }

  function deleteRow(entry, btn) {
    var username = entry.tr.dataset.user;
    disarmDelete(btn);
    setBusy(entry, true);
    status(entry, "info", "Deleting…");

    request("/api/admin/delete", { username: username })
      .then(function (data) {
        if (data && data.ok === false) throw new Error("API refused the delete");
        removePlayer(username);
        if (entry.pillTimer) clearTimeout(entry.pillTimer);
        if (entry.tr.parentNode) entry.tr.parentNode.removeChild(entry.tr);
        rows.delete(username);
        render();
      })
      .catch(function (e) {
        setBusy(entry, false);
        status(entry, "err", errText(e));
      });
  }

  /* ------------------------------------------------------------------ events */

  el.tbody.addEventListener("input", function (ev) {
    var input = ev.target;
    if (!input.classList || !input.classList.contains("num")) return;
    markDirty(input);
    var entry = rows.get(input.closest("tr").dataset.user);
    if (entry) refreshSaveState(entry);
    renderDirtyNote();
  });

  el.tbody.addEventListener("click", function (ev) {
    var btn = ev.target.closest ? ev.target.closest("button[data-act]") : null;
    if (!btn) return;
    var tr = btn.closest("tr");
    var entry = rows.get(tr.dataset.user);
    if (!entry || entry.busy) return;

    var act = btn.dataset.act;

    // Any other click cancels a pending delete confirmation on this row.
    var del = tr.querySelector('[data-act="delete"]');
    if (del && del !== btn) disarmDelete(del);

    if (act === "save") saveRow(entry);
    else if (act === "delete") {
      if (armDelete(btn)) deleteRow(entry, btn);
    } else quickAction(entry, act);
  });

  el.tbody.addEventListener("keydown", function (ev) {
    var input = ev.target;
    if (!input.classList || !input.classList.contains("num")) return;
    var entry = rows.get(input.closest("tr").dataset.user);
    if (!entry) return;

    if (ev.key === "Enter") {
      ev.preventDefault();
      input.blur();
      saveRow(entry);
    } else if (ev.key === "Escape") {
      ev.preventDefault();
      revertRow(entry);
    }
  });

  el.thead.addEventListener("click", function (ev) {
    var th = ev.target.closest ? ev.target.closest("th.sortable") : null;
    if (!th) return;

    // Rows are never moved while a cell has focus, so step out of the table
    // first — otherwise the click on a header would appear to do nothing.
    // Anything typed stays put; only the cursor is given up.
    var active = document.activeElement;
    if (active && el.tbody.contains(active)) active.blur();

    var key = th.dataset.key;
    if (state.sortKey === key) {
      state.sortDir = -state.sortDir;
    } else {
      state.sortKey = key;
      // Text reads best ascending; counters and timestamps read best descending.
      state.sortDir = key === "username" ? 1 : -1;
    }
    render();
  });

  el.search.addEventListener("input", function () {
    state.filter = el.search.value;
    render();
  });

  el.autoRefresh.addEventListener("change", function () {
    state.auto = el.autoRefresh.checked;
    renderConn();
    renderBanner();
    if (state.auto) refresh();
  });

  el.refreshNow.addEventListener("click", function () {
    refresh();
  });

  document.addEventListener("keydown", function (ev) {
    if (ev.key !== "/" || ev.metaKey || ev.ctrlKey || ev.altKey) return;
    var t = ev.target;
    if (t && (t.tagName === "INPUT" || t.tagName === "TEXTAREA" || t.isContentEditable)) return;
    ev.preventDefault();
    el.search.focus();
    el.search.select();
  });

  // Come back promptly after the tab was in the background.
  document.addEventListener("visibilitychange", function () {
    if (!document.hidden && state.auto) refresh();
  });

  el.overrideForm.addEventListener("submit", function (ev) {
    ev.preventDefault();
    var v = el.overrideUrl.value.trim().replace(/\/+$/, "");
    if (!v) return;
    try {
      window.localStorage.setItem(OVERRIDE_KEY, v);
    } catch (e) {
      /* private browsing: fall through, the value below still applies */
    }
    window.GAME_API = v;
    el.noconfig.hidden = true;
    boot();
  });

  /* -------------------------------------------------------------------- boot */

  function showNoConfig() {
    el.noconfig.hidden = false;
    el.apiHost.textContent = "config.js missing";
    state.error = null;
    renderConn();
    var saved = "";
    try {
      saved = window.localStorage.getItem(OVERRIDE_KEY) || "";
    } catch (e) {
      saved = "";
    }
    if (saved && !el.overrideUrl.value) el.overrideUrl.value = saved;
    el.overrideUrl.focus();
  }

  function boot() {
    var base = apiBase();
    if (!base) {
      render();
      showNoConfig();
      return;
    }
    el.apiHost.textContent = hostLabel(base);
    el.apiHost.title = base;
    render();
    refresh();
  }

  // Relative times keep ticking even while polling is paused.
  setInterval(function () {
    rows.forEach(function (entry, name) {
      paintSeen(entry, state.byName[name]);
    });
    if (state.lastOk) {
      el.statUpdated.textContent = relative((Date.now() - state.lastOk) / 1000);
    } else if (state.started === false && state.error) {
      el.statUpdated.textContent = "never";
    }
  }, TICK_MS);

  boot();
})();
