/* Rock & Stick — arena client.
 *
 * Plain ES2017. No build step, no dependencies, nothing loaded from a CDN.
 * The API address comes from config.js (window.GAME_API), which is written at
 * deploy time and loaded by index.html before this file.
 */
(function () {
  "use strict";

  /* ------------------------------------------------------------ constants */

  var WORLD_W = 1000;
  var WORLD_H = 600;

  var ROCK_RANGE = 400;
  var STICK_RANGE = 60;

  var KEY_SPEED = 260; // world units per second while a movement key is held
  var MOVE_MIN_GAP = 140; // ms between /api/move calls
  var MOVE_SETTLE = 700; // ms of no movement before we trust the server's position
  var POLL_MS = 500; // /api/state interval, also the server side heartbeat
  var TIMEOUT_MS = 8000;
  var DEATH_RETURN_MS = 8000;
  var MAX_LOG = 60;

  var NAME_RE = /^[A-Za-z0-9_-]{2,16}$/;

  /* ------------------------------------------------------------------ dom */

  function $(id) {
    return document.getElementById(id);
  }

  var el = {
    loginScreen: $("loginScreen"),
    loginForm: $("loginForm"),
    username: $("username"),
    loginError: $("loginError"),
    playBtn: $("playBtn"),
    playBtnLabel: $("playBtnLabel"),
    configWarning: $("configWarning"),

    gameScreen: $("gameScreen"),
    field: $("field"),
    canvas: $("canvas"),
    netChip: $("netChip"),

    status: $("status"),
    statusText: $("statusText"),
    whoami: $("whoami"),
    whoamiName: $("whoamiName"),

    hpFill: $("hpFill"),
    hpText: $("hpText"),
    rocksText: $("rocksText"),
    sticksText: $("sticksText"),
    playersText: $("playersText"),
    alivePill: $("alivePill"),

    targetEmpty: $("targetEmpty"),
    targetBody: $("targetBody"),
    targetName: $("targetName"),
    targetSwatch: $("targetSwatch"),
    targetDist: $("targetDist"),
    targetHp: $("targetHp"),
    chipRock: $("chipRock"),
    chipStick: $("chipStick"),
    clearTargetBtn: $("clearTargetBtn"),

    btnThrow: $("btnThrow"),
    btnSwing: $("btnSwing"),
    btnCycle: $("btnCycle"),

    log: $("log"),

    deathOverlay: $("deathOverlay"),
    deathKicker: $("deathKicker"),
    deathMessage: $("deathMessage"),
    deathCountdown: $("deathCountdown"),
    respawnBtn: $("respawnBtn")
  };

  var ctx = el.canvas.getContext("2d");

  /* ---------------------------------------------------------------- state */

  var S = {
    inGame: false,
    username: "",
    you: null, // last player object the server sent us
    others: new Map(), // username -> { p, rx, ry, hue, seen }
    target: null, // username of the selected target
    intent: { x: WORLD_W / 2, y: WORLD_H / 2 }, // where we are trying to be
    render: { x: WORLD_W / 2, y: WORLD_H / 2 }, // where we are drawn right now
    items: [], // rocks and sticks lying on the ground, from the server
    moveDirty: false,
    lastMoveSent: 0,
    sentPos: { x: 0, y: 0 },
    keys: new Set(),
    online: true,
    failures: 0,
    busy: false, // an action request is in flight
    pings: [], // click markers
    hits: [], // attack flashes
    pollTimer: null,
    pollInFlight: false,
    sawState: false,
    deathTimer: null,
    ended: false
  };

  var view = { w: 1, h: 1, dpr: 1, scale: 1, ox: 0, oy: 0 };

  /* ---------------------------------------------------------------- utils */

  function clamp(v, lo, hi) {
    return v < lo ? lo : v > hi ? hi : v;
  }

  function dist(ax, ay, bx, by) {
    var dx = ax - bx;
    var dy = ay - by;
    return Math.sqrt(dx * dx + dy * dy);
  }

  function num(v, fallback) {
    return typeof v === "number" && isFinite(v) ? v : fallback;
  }

  function hueFor(name) {
    var h = 2166136261;
    for (var i = 0; i < name.length; i++) {
      h ^= name.charCodeAt(i);
      h = (h * 16777619) >>> 0;
    }
    // 300 evenly spread hues, with the 130-190 mint band lifted out of the way
    // so no other player can be mistaken for you.
    var hue = h % 300;
    return hue < 130 ? hue : hue + 60;
  }

  function nowMs() {
    return performance.now();
  }

  function clockLabel() {
    var d = new Date();
    return (
      String(d.getHours()).padStart(2, "0") + ":" + String(d.getMinutes()).padStart(2, "0")
    );
  }

  /* ------------------------------------------------------------------ api */

  function ApiError(message, status, network) {
    this.name = "ApiError";
    this.message = message;
    this.status = status || 0;
    this.network = !!network;
  }
  ApiError.prototype = Object.create(Error.prototype);

  function apiBase() {
    // Dev escape hatch: ?api=https://... lets you point a local copy of this
    // page at a running API. Deployments always use config.js.
    try {
      var q = new URLSearchParams(location.search).get("api");
      if (q && /^https:\/\/|^http:\/\/localhost(:\d+)?(\/|$)/i.test(q)) {
        return q.trim().replace(/\/+$/, "");
      }
    } catch (e) {
      /* URLSearchParams missing, ignore */
    }
    var base = typeof window.GAME_API === "string" ? window.GAME_API.trim() : "";
    return base.replace(/\/+$/, "");
  }

  function haveApi() {
    return apiBase().length > 0;
  }

  function api(path, body) {
    var base = apiBase();
    if (!base) {
      return Promise.reject(
        new ApiError("The game server address is not configured (config.js did not load).", 0)
      );
    }

    var controller = new AbortController();
    var timer = setTimeout(function () {
      controller.abort();
    }, TIMEOUT_MS);

    return fetch(base + path, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(body),
      cache: "no-store",
      signal: controller.signal
    })
      .catch(function () {
        throw new ApiError(
          controller.signal.aborted
            ? "The game server took too long to answer."
            : "Cannot reach the game server.",
          0,
          true
        );
      })
      .then(function (res) {
        return res.text().then(
          function (text) {
            return { res: res, text: text };
          },
          function () {
            return { res: res, text: "" };
          }
        );
      })
      .then(function (r) {
        var data = null;
        if (r.text) {
          try {
            data = JSON.parse(r.text);
          } catch (e) {
            data = null;
          }
        }
        if (!r.res.ok) {
          var msg =
            (data && (data.error || data.message)) || "The server said no (" + r.res.status + ").";
          throw new ApiError(String(msg), r.res.status);
        }
        if (!data || typeof data !== "object") {
          throw new ApiError("The server sent something we could not read.", r.res.status);
        }
        return data;
      })
      .then(
        function (data) {
          clearTimeout(timer);
          return data;
        },
        function (err) {
          clearTimeout(timer);
          throw err;
        }
      );
  }

  /* ------------------------------------------------------------------ log */

  function addLog(text, kind) {
    if (!text) return;
    var li = document.createElement("li");
    if (kind) li.className = "is-" + kind;

    var t = document.createElement("span");
    t.className = "log-time";
    t.textContent = clockLabel();

    var body = document.createElement("span");
    body.className = "log-text";
    body.textContent = String(text);

    li.appendChild(t);
    li.appendChild(body);
    el.log.appendChild(li);

    while (el.log.childElementCount > MAX_LOG) {
      el.log.removeChild(el.log.firstElementChild);
    }
    el.log.scrollTop = el.log.scrollHeight;
  }

  function clearLog() {
    el.log.textContent = "";
  }

  /* --------------------------------------------------------------- status */

  function setStatus(kind, text) {
    el.status.className = "status " + kind;
    el.statusText.textContent = text;
  }

  function setOnline(ok) {
    if (ok === S.online) return;
    S.online = ok;
    if (ok) {
      setStatus("is-live", "Connected");
      el.netChip.hidden = true;
    } else {
      setStatus("is-down", "Reconnecting…");
      el.netChip.hidden = !S.inGame;
    }
  }

  /* ----------------------------------------------------------- view sizing */

  function resize() {
    var rect = el.canvas.getBoundingClientRect();
    var w = Math.max(1, rect.width);
    var h = Math.max(1, rect.height);
    var dpr = Math.min(window.devicePixelRatio || 1, 2);

    view.w = w;
    view.h = h;
    view.dpr = dpr;

    // The world is letterboxed inside whatever box CSS gave us, so the aspect
    // ratio is always right even if the layout rounds a pixel off.
    view.scale = Math.min(w / WORLD_W, h / WORLD_H);
    view.ox = (w - WORLD_W * view.scale) / 2;
    view.oy = (h - WORLD_H * view.scale) / 2;

    var bw = Math.round(w * dpr);
    var bh = Math.round(h * dpr);
    if (el.canvas.width !== bw || el.canvas.height !== bh) {
      el.canvas.width = bw;
      el.canvas.height = bh;
    }
  }

  function sx(worldX) {
    return view.ox + worldX * view.scale;
  }

  function sy(worldY) {
    return view.oy + worldY * view.scale;
  }

  function toWorld(clientX, clientY) {
    var rect = el.canvas.getBoundingClientRect();
    var px = clientX - rect.left;
    var py = clientY - rect.top;
    return {
      x: clamp((px - view.ox) / view.scale, 0, WORLD_W),
      y: clamp((py - view.oy) / view.scale, 0, WORLD_H)
    };
  }

  /* --------------------------------------------------------------- players */

  function normalizePlayer(p) {
    if (!p || typeof p !== "object" || typeof p.username !== "string") return null;
    return {
      username: p.username,
      x: clamp(num(p.x, 0), 0, WORLD_W),
      y: clamp(num(p.y, 0), 0, WORLD_H),
      hp: num(p.hp, 0),
      max_hp: Math.max(1, num(p.max_hp, 20)),
      rocks: Math.max(0, num(p.rocks, 0)),
      sticks: Math.max(0, num(p.sticks, 0)),
      alive: p.alive !== false
    };
  }

  function targetPlayer() {
    if (!S.target) return null;
    var o = S.others.get(S.target);
    return o ? o.p : null;
  }

  function myPos() {
    // The intent is our best guess at where the server currently has us: it is
    // either confirmed or about to be sent.
    return S.intent;
  }

  function rangeTo(p) {
    if (!p) return Infinity;
    var me = myPos();
    return dist(me.x, me.y, p.x, p.y);
  }

  function canThrow() {
    var t = targetPlayer();
    return !!(S.you && S.you.rocks > 0 && t && t.alive && rangeTo(t) <= ROCK_RANGE);
  }

  function canSwing() {
    var t = targetPlayer();
    return !!(S.you && S.you.sticks > 0 && t && t.alive && rangeTo(t) <= STICK_RANGE);
  }

  function selectTarget(name) {
    if (name === S.target) return;
    S.target = name || null;
    if (name) addLog("Targeting " + name + ".", null);
    syncHud(true);
  }

  function cycleTarget() {
    var me = myPos();
    var list = [];
    S.others.forEach(function (o) {
      if (o.p.alive) list.push(o.p);
    });
    if (!list.length) {
      addLog("Nobody else is out here.", null);
      return;
    }
    list.sort(function (a, b) {
      return dist(me.x, me.y, a.x, a.y) - dist(me.x, me.y, b.x, b.y);
    });
    var idx = 0;
    if (S.target) {
      for (var i = 0; i < list.length; i++) {
        if (list[i].username === S.target) {
          idx = (i + 1) % list.length;
          break;
        }
      }
    }
    selectTarget(list[idx].username);
  }

  /* ------------------------------------------------------ applying updates */

  function applyYou(p, opts) {
    var next = normalizePlayer(p);
    if (!next) return;
    opts = opts || {};

    var prev = S.you;
    S.you = next;

    if (prev && next.hp < prev.hp) {
      addLog("You took " + (prev.hp - next.hp) + " damage.", "hurt");
      S.hits.push({ x: S.render.x, y: S.render.y, t: nowMs(), self: true });
    }

    if (opts.snap) {
      S.intent.x = next.x;
      S.intent.y = next.y;
      S.render.x = next.x;
      S.render.y = next.y;
    } else if (opts.fromMove) {
      // The server answered the exact move we asked for. If it put us anywhere
      // other than where we asked, it is right and we are wrong.
      if (dist(next.x, next.y, S.sentPos.x, S.sentPos.y) > 8) {
        S.intent.x = next.x;
        S.intent.y = next.y;
      }
    } else if (!S.moveDirty && nowMs() - S.lastMoveSent > MOVE_SETTLE) {
      // Nothing in flight, so the server position is the truth.
      S.intent.x = next.x;
      S.intent.y = next.y;
    }

    if (!next.alive || next.hp <= 0) {
      endSession("died", "");
      return;
    }
    syncHud(true);
  }

  function applyPlayers(list) {
    var seen = nowMs();
    var incoming = new Map();

    if (Array.isArray(list)) {
      for (var i = 0; i < list.length; i++) {
        var p = normalizePlayer(list[i]);
        if (!p || p.username === S.username) continue;
        incoming.set(p.username, p);
      }
    }

    // Departures and deaths.
    S.others.forEach(function (o, name) {
      var next = incoming.get(name);
      if (!next) {
        addLog(name + " left the field.", null);
        S.others.delete(name);
        if (S.target === name) selectTarget(null);
        return;
      }
      if (o.p.alive && !next.alive) {
        addLog(name + " is down.", "kill");
      }
      if (next.hp < o.p.hp) {
        S.hits.push({ x: o.rx, y: o.ry, t: seen, self: false });
      }
      o.p = next;
      o.seen = seen;
    });

    // Arrivals. The first batch is everybody who was already here, so it is
    // announced as one line instead of one line each.
    var arrivals = [];
    incoming.forEach(function (p, name) {
      if (S.others.has(name)) return;
      S.others.set(name, { p: p, rx: p.x, ry: p.y, hue: hueFor(name), seen: seen });
      arrivals.push(name);
    });

    if (arrivals.length) {
      if (S.sawState) {
        for (var a = 0; a < arrivals.length; a++) addLog(arrivals[a] + " joined.", null);
      } else {
        addLog(
          "Already here: " + arrivals.slice(0, 8).join(", ") +
            (arrivals.length > 8 ? " and " + (arrivals.length - 8) + " more" : "") + ".",
          null
        );
      }
    }
    S.sawState = true;

    if (S.target && !S.others.has(S.target)) selectTarget(null);
  }

  /* --------------------------------------------------------------- polling */

  function schedulePoll(delay) {
    if (!S.inGame) return;
    clearTimeout(S.pollTimer);
    S.pollTimer = setTimeout(poll, delay == null ? POLL_MS : delay);
  }

  function poll() {
    if (!S.inGame || S.pollInFlight) {
      schedulePoll();
      return;
    }
    S.pollInFlight = true;

    api("/api/state", { username: S.username })
      .then(function (data) {
        S.pollInFlight = false;
        if (!S.inGame) return;
        S.failures = 0;
        setOnline(true);

        applyPlayers(data.players);
        S.items = Array.isArray(data.items) ? data.items : [];

        var mine = data.you;
        if (!mine && Array.isArray(data.players)) {
          for (var i = 0; i < data.players.length; i++) {
            if (data.players[i] && data.players[i].username === S.username) {
              mine = data.players[i];
              break;
            }
          }
        }
        if (mine) {
          applyYou(mine);
        } else {
          endSession("gone", "The server no longer knows about you.");
          return;
        }
        syncHud(true);
        schedulePoll();
      })
      .catch(function (err) {
        S.pollInFlight = false;
        if (!S.inGame) return;

        var retryable = err.network || err.status === 408 || err.status === 429;
        if (!retryable && err.status >= 400 && err.status < 500) {
          // Any other 4xx means the server will not talk to us any more
          // (unknown player, dead player), so there is nothing to retry.
          endSession("gone", err.message);
          return;
        }

        S.failures++;
        if (S.failures >= 2) setOnline(false);
        schedulePoll(Math.min(2500, 400 + S.failures * 250));
      });
  }

  /* --------------------------------------------------------------- actions */

  function reportError(err) {
    var msg = err && err.message ? err.message : "Something went wrong.";
    if (err && err.network) {
      setOnline(false);
      return;
    }
    addLog(msg, "error");
  }

  function sendMove(force) {
    if (!S.inGame || !S.you) return;
    var t = nowMs();
    if (!force && t - S.lastMoveSent < MOVE_MIN_GAP) return;
    if (!S.moveDirty) return;

    S.moveDirty = false;
    S.lastMoveSent = t;
    S.sentPos.x = Math.round(S.intent.x);
    S.sentPos.y = Math.round(S.intent.y);

    api("/api/move", { username: S.username, x: S.sentPos.x, y: S.sentPos.y })
      .then(function (data) {
        setOnline(true);
        S.failures = 0;
        if (data.you) applyYou(data.you, { fromMove: true });
        reportPickups(data.picked);
      })
      .catch(reportError);
  }

  function moveTo(x, y) {
    if (!S.inGame) return;
    S.intent.x = clamp(x, 0, WORLD_W);
    S.intent.y = clamp(y, 0, WORLD_H);
    S.moveDirty = true;
    sendMove(true);
  }

  // Rocks and sticks are collected by walking over them, so the only thing to
  // do here is tell the player what they just swept up.
  function reportPickups(picked) {
    if (!picked) return;
    var got = [];
    if (picked.rock) got.push(picked.rock + " rock" + (picked.rock > 1 ? "s" : ""));
    if (picked.stick) got.push(picked.stick + " stick" + (picked.stick > 1 ? "s" : ""));
    if (!got.length) return;
    addLog("Picked up " + got.join(" and ") + ".", null);
    syncHud(true);
  }

  function attack(weapon) {
    if (!S.inGame || S.busy) return;
    var t = targetPlayer();
    if (!t) {
      addLog("Pick a target first.", "error");
      return;
    }
    var ok = weapon === "rock" ? canThrow() : canSwing();
    if (!ok) {
      var reach = weapon === "rock" ? ROCK_RANGE : STICK_RANGE;
      var have = S.you ? (weapon === "rock" ? S.you.rocks : S.you.sticks) : 0;
      addLog(
        have <= 0
          ? "You have no " + weapon + "s."
          : "Too far — " + weapon + " reaches " + reach + " units.",
        "error"
      );
      return;
    }

    S.busy = true;
    var targetName = t.username;

    api("/api/attack", { username: S.username, target: targetName, weapon: weapon })
      .then(function (data) {
        setOnline(true);
        S.hits.push({ x: t.x, y: t.y, t: nowMs(), self: false });

        if (data.you) applyYou(data.you);
        if (data.target) {
          var np = normalizePlayer(data.target);
          if (np && S.others.has(np.username)) {
            S.others.get(np.username).p = np;
          }
        }

        var line =
          data.message ||
          "You hit " + targetName + " with a " + weapon + " for " + num(data.damage, 0) + ".";
        addLog(line, data.killed ? "kill" : "hit");
        if (data.broke) addLog("Your stick snapped.", null);
        if (data.killed) addLog(targetName + " is dead.", "kill");
      })
      .catch(reportError)
      .then(function () {
        S.busy = false;
        syncHud(true);
      });
  }

  /* ------------------------------------------------------------------ hud */

  var hudSig = "";

  function syncHud(force) {
    var you = S.you;
    var t = targetPlayer();
    var d = t ? rangeTo(t) : -1;
    var throwOk = canThrow();
    var swingOk = canSwing();

    var sig = [
      you ? you.hp : "-",
      you ? you.max_hp : "-",
      you ? you.rocks : "-",
      you ? you.sticks : "-",
      you ? you.alive : "-",
      S.others.size,
      S.target || "-",
      t ? t.hp + "/" + t.max_hp : "-",
      d >= 0 ? Math.round(d) : "-",
      throwOk,
      swingOk
    ].join("|");

    if (!force && sig === hudSig) return;
    hudSig = sig;

    if (you) {
      var ratio = clamp(you.hp / you.max_hp, 0, 1);
      el.hpFill.style.width = (ratio * 100).toFixed(1) + "%";
      el.hpFill.className = "hp-fill" + (ratio <= 0.25 ? " is-low" : ratio <= 0.6 ? " is-mid" : "");
      el.hpText.textContent = you.hp + " / " + you.max_hp;
      el.rocksText.textContent = String(you.rocks);
      el.sticksText.textContent = String(you.sticks);
      el.alivePill.textContent = you.alive ? (ratio <= 0.35 ? "hurt" : "alive") : "dead";
      el.alivePill.className =
        "pill" + (!you.alive ? " is-dead" : ratio <= 0.35 ? " is-hurt" : "");
    }
    el.playersText.textContent = String(S.others.size + (S.you ? 1 : 0));

    if (t) {
      el.targetEmpty.hidden = true;
      el.targetBody.hidden = false;
      el.clearTargetBtn.hidden = false;
      el.targetName.textContent = t.username;
      var o = S.others.get(t.username);
      el.targetSwatch.style.background = "hsl(" + (o ? o.hue : 0) + " 72% 62%)";
      el.targetDist.textContent = Math.round(d) + "u";
      el.targetHp.textContent = t.hp + " / " + t.max_hp;
      el.chipRock.className = "chip" + (d <= ROCK_RANGE ? " is-on" : "");
      el.chipStick.className = "chip" + (d <= STICK_RANGE ? " is-on" : "");
    } else {
      el.targetEmpty.hidden = false;
      el.targetBody.hidden = true;
      el.clearTargetBtn.hidden = true;
    }

    el.btnThrow.disabled = !throwOk;
    el.btnSwing.disabled = !swingOk;
    el.btnThrow.title = throwOk
      ? "Throw a rock at " + S.target
      : !S.you || S.you.rocks <= 0
        ? "You have no rocks"
        : !t
          ? "No target selected"
          : "Out of range (rocks reach " + ROCK_RANGE + ")";
    el.btnSwing.title = swingOk
      ? "Swing a stick at " + S.target
      : !S.you || S.you.sticks <= 0
        ? "You have no sticks"
        : !t
          ? "No target selected"
          : "Out of range (sticks reach " + STICK_RANGE + ")";
  }

  /* --------------------------------------------------------------- drawing */

  var specks = (function () {
    var out = [];
    var seed = 20260810;
    function rnd() {
      seed = (seed * 1103515245 + 12345) & 0x7fffffff;
      return seed / 0x7fffffff;
    }
    for (var i = 0; i < 110; i++) {
      out.push({ x: rnd() * WORLD_W, y: rnd() * WORLD_H, r: 0.7 + rnd() * 1.9, a: 0.03 + rnd() * 0.07 });
    }
    return out;
  })();

  function roundRect(c, x, y, w, h, r) {
    var rr = Math.min(r, w / 2, h / 2);
    c.beginPath();
    c.moveTo(x + rr, y);
    c.arcTo(x + w, y, x + w, y + h, rr);
    c.arcTo(x + w, y + h, x, y + h, rr);
    c.arcTo(x, y + h, x, y, rr);
    c.arcTo(x, y, x + w, y, rr);
    c.closePath();
  }

  function label(c, text, x, y, size, color) {
    c.font = "600 " + size + "px " + "system-ui, -apple-system, 'Segoe UI', Roboto, sans-serif";
    c.textAlign = "center";
    c.textBaseline = "alphabetic";

    // Keep the name inside the field rather than letting the clip shave it off
    // when somebody stands against an edge.
    var half = c.measureText(text).width / 2 + 4;
    var left = view.ox + half;
    var right = view.ox + WORLD_W * view.scale - half;
    if (right > left) x = clamp(x, left, right);

    c.lineWidth = 3;
    c.lineJoin = "round";
    c.strokeStyle = "rgba(3,6,10,0.78)";
    c.strokeText(text, x, y);
    c.fillStyle = color;
    c.fillText(text, x, y);
  }

  function hpBar(c, cx, y, w, ratio) {
    var h = Math.max(3, Math.round(w * 0.11));
    var x = cx - w / 2;
    c.fillStyle = "rgba(3,6,10,0.72)";
    roundRect(c, x - 1, y - 1, w + 2, h + 2, (h + 2) / 2);
    c.fill();
    c.fillStyle =
      ratio <= 0.25 ? "#f87171" : ratio <= 0.6 ? "#fbbf24" : "#4ade80";
    var fw = Math.max(0, w * ratio);
    if (fw > 0.5) {
      roundRect(c, x, y, fw, h, h / 2);
      c.fill();
    }
  }

  function drawBlob(c, p, rx, ry, opts) {
    var s = view.scale;
    var x = sx(rx);
    var y = sy(ry);
    var r = Math.max(8, 15 * s);
    var alive = p.alive;

    // shadow
    c.fillStyle = "rgba(0,0,0,0.36)";
    c.beginPath();
    c.ellipse(x, y + r * 0.72, r * 0.95, r * 0.34, 0, 0, Math.PI * 2);
    c.fill();

    var hue = opts.hue;
    var base = alive ? "hsl(" + hue + " 70% 58%)" : "hsl(" + hue + " 12% 42%)";
    var light = alive ? "hsl(" + hue + " 92% 76%)" : "hsl(" + hue + " 12% 55%)";

    if (opts.isSelf && alive) {
      c.save();
      c.shadowColor = "rgba(94,234,212,0.55)";
      c.shadowBlur = 18 * Math.max(0.6, s);
    }

    var g = c.createRadialGradient(x - r * 0.35, y - r * 0.4, r * 0.15, x, y, r);
    g.addColorStop(0, light);
    g.addColorStop(1, base);
    c.fillStyle = g;
    c.beginPath();
    c.arc(x, y, r, 0, Math.PI * 2);
    c.fill();

    if (opts.isSelf && alive) c.restore();

    c.lineWidth = opts.isSelf ? Math.max(2, 2.4 * s) : Math.max(1, 1.4 * s);
    c.strokeStyle = opts.isSelf ? "rgba(255,255,255,0.92)" : "rgba(0,0,0,0.42)";
    c.stroke();

    if (!alive) {
      c.strokeStyle = "rgba(255,255,255,0.5)";
      c.lineWidth = Math.max(1.5, 2 * s);
      var k = r * 0.42;
      c.beginPath();
      c.moveTo(x - k, y - k);
      c.lineTo(x + k, y + k);
      c.moveTo(x + k, y - k);
      c.lineTo(x - k, y + k);
      c.stroke();
    }

    // target ring
    if (opts.isTarget) {
      c.save();
      c.setLineDash([5, 4]);
      c.lineDashOffset = -(nowMs() / 55) % 18;
      c.strokeStyle = "#f5b544";
      c.lineWidth = Math.max(1.6, 2 * s);
      c.beginPath();
      c.arc(x, y, r + Math.max(5, 7 * s), 0, Math.PI * 2);
      c.stroke();
      c.restore();
    }

    // Name plate above the blob, flipped below it for anyone stood against the
    // top edge so the clip does not shave it off.
    var fs = clamp(13 * s, 10, 13.5);
    var bw = Math.max(28, 46 * s);
    var barH = Math.max(3, Math.round(bw * 0.11));
    var pad = Math.max(6, 8 * s);
    var flip = y - r - pad - fs - 6 < view.oy;
    var barY = flip ? y + r + pad : y - r - pad;

    hpBar(c, x, barY, bw, clamp(p.hp / p.max_hp, 0, 1));
    label(
      c,
      p.username + (opts.isSelf ? "  (you)" : ""),
      x,
      flip ? barY + barH + fs + 3 : barY - Math.max(5, 6 * s),
      fs,
      opts.isSelf ? "#c9f7ec" : alive ? "#e8eef7" : "#93a3b8"
    );
  }

  function draw() {
    var s = view.scale;
    var t = nowMs();

    ctx.setTransform(view.dpr, 0, 0, view.dpr, 0, 0);
    ctx.clearRect(0, 0, view.w, view.h);

    var fx = view.ox;
    var fy = view.oy;
    var fw = WORLD_W * s;
    var fh = WORLD_H * s;

    ctx.save();
    roundRect(ctx, fx, fy, fw, fh, 12);
    ctx.clip();

    var g = ctx.createLinearGradient(fx, fy, fx, fy + fh);
    g.addColorStop(0, "#101927");
    g.addColorStop(0.55, "#0b131d");
    g.addColorStop(1, "#080e16");
    ctx.fillStyle = g;
    ctx.fillRect(fx, fy, fw, fh);

    // grid
    ctx.lineWidth = 1;
    ctx.strokeStyle = "rgba(148,163,184,0.055)";
    ctx.beginPath();
    for (var gx = 100; gx < WORLD_W; gx += 100) {
      var px = Math.round(sx(gx)) + 0.5;
      ctx.moveTo(px, fy);
      ctx.lineTo(px, fy + fh);
    }
    for (var gy = 100; gy < WORLD_H; gy += 100) {
      var py = Math.round(sy(gy)) + 0.5;
      ctx.moveTo(fx, py);
      ctx.lineTo(fx + fw, py);
    }
    ctx.stroke();

    // ground texture
    for (var i = 0; i < specks.length; i++) {
      var sp = specks[i];
      ctx.fillStyle = "rgba(148,163,184," + sp.a.toFixed(3) + ")";
      ctx.beginPath();
      ctx.arc(sx(sp.x), sy(sp.y), sp.r * Math.max(0.6, s), 0, Math.PI * 2);
      ctx.fill();
    }

    var me = S.you;
    var tgt = targetPlayer();

    // range rings around you
    if (me && me.alive) {
      var mx = sx(S.render.x);
      var my = sy(S.render.y);

      ctx.save();
      ctx.setLineDash([3, 7]);
      ctx.strokeStyle = "rgba(94,234,212,0.13)";
      ctx.lineWidth = 1;
      ctx.beginPath();
      ctx.arc(mx, my, ROCK_RANGE * s, 0, Math.PI * 2);
      ctx.stroke();
      ctx.restore();

      ctx.strokeStyle = "rgba(94,234,212,0.2)";
      ctx.lineWidth = 1;
      ctx.beginPath();
      ctx.arc(mx, my, STICK_RANGE * s, 0, Math.PI * 2);
      ctx.stroke();

      // where we are walking to
      if (dist(S.render.x, S.render.y, S.intent.x, S.intent.y) > 6) {
        var ix = sx(S.intent.x);
        var iy = sy(S.intent.y);
        ctx.strokeStyle = "rgba(94,234,212,0.35)";
        ctx.setLineDash([4, 5]);
        ctx.beginPath();
        ctx.moveTo(mx, my);
        ctx.lineTo(ix, iy);
        ctx.stroke();
        ctx.setLineDash([]);
        ctx.beginPath();
        ctx.arc(ix, iy, Math.max(3, 4 * s), 0, Math.PI * 2);
        ctx.stroke();
      }

      // line to target
      if (tgt) {
        var o = S.others.get(tgt.username);
        var tx = sx(o ? o.rx : tgt.x);
        var ty = sy(o ? o.ry : tgt.y);
        var d = rangeTo(tgt);
        var inAny = d <= ROCK_RANGE;
        ctx.save();
        ctx.setLineDash([6, 5]);
        ctx.lineDashOffset = -(t / 45) % 22;
        ctx.strokeStyle = inAny ? "rgba(245,181,68,0.55)" : "rgba(248,113,113,0.4)";
        ctx.lineWidth = Math.max(1, 1.4 * s);
        ctx.beginPath();
        ctx.moveTo(mx, my);
        ctx.lineTo(tx, ty);
        ctx.stroke();
        ctx.restore();

        label(
          ctx,
          Math.round(d) + "u",
          (mx + tx) / 2,
          (my + ty) / 2 - 4,
          clamp(11 * s, 9, 12),
          inAny ? "#f8dfae" : "#fca5a5"
        );
      }
    }

    // click pings
    for (var pi = S.pings.length - 1; pi >= 0; pi--) {
      var ping = S.pings[pi];
      var age = (t - ping.t) / 620;
      if (age >= 1) {
        S.pings.splice(pi, 1);
        continue;
      }
      ctx.strokeStyle = "rgba(94,234,212," + (0.55 * (1 - age)).toFixed(3) + ")";
      ctx.lineWidth = Math.max(1, 2 * s * (1 - age));
      ctx.beginPath();
      ctx.arc(sx(ping.x), sy(ping.y), (6 + 26 * age) * Math.max(0.6, s), 0, Math.PI * 2);
      ctx.stroke();
    }

    // hit flashes
    for (var hi = S.hits.length - 1; hi >= 0; hi--) {
      var hit = S.hits[hi];
      var hage = (t - hit.t) / 480;
      if (hage >= 1) {
        S.hits.splice(hi, 1);
        continue;
      }
      ctx.strokeStyle =
        (hit.self ? "rgba(248,113,113," : "rgba(245,181,68,") + (0.75 * (1 - hage)).toFixed(3) + ")";
      ctx.lineWidth = Math.max(1.5, 3 * s * (1 - hage));
      ctx.beginPath();
      ctx.arc(sx(hit.x), sy(hit.y), (10 + 30 * hage) * Math.max(0.6, s), 0, Math.PI * 2);
      ctx.stroke();
    }

    // ground items, drawn under everyone so nobody is hidden by litter
    for (var gi = 0; gi < S.items.length; gi++) {
      var g = S.items[gi];
      var gx = sx(g.x);
      var gy = sy(g.y);
      var gs = Math.max(0.6, s);
      // A gentle bob so fresh litter catches the eye.
      var bob = Math.sin(t / 420 + (g.x + g.y)) * 1.6 * gs;

      ctx.save();
      ctx.translate(gx, gy + bob);

      ctx.fillStyle = "rgba(0,0,0,0.28)";
      ctx.beginPath();
      ctx.ellipse(0, 5 * gs, 6 * gs, 2.4 * gs, 0, 0, Math.PI * 2);
      ctx.fill();

      if (g.type === "stick") {
        ctx.strokeStyle = "#a97142";
        ctx.lineWidth = Math.max(1.6, 2.6 * gs);
        ctx.lineCap = "round";
        ctx.beginPath();
        ctx.moveTo(-6 * gs, 3 * gs);
        ctx.lineTo(6 * gs, -3 * gs);
        ctx.stroke();
      } else {
        ctx.fillStyle = "#8d94a3";
        ctx.strokeStyle = "rgba(232,238,248,0.35)";
        ctx.lineWidth = Math.max(1, 1.2 * gs);
        ctx.beginPath();
        ctx.moveTo(-5 * gs, 1 * gs);
        ctx.lineTo(-2 * gs, -4 * gs);
        ctx.lineTo(3 * gs, -4 * gs);
        ctx.lineTo(5 * gs, 0);
        ctx.lineTo(1 * gs, 4 * gs);
        ctx.closePath();
        ctx.fill();
        ctx.stroke();
      }
      ctx.restore();
    }

    // other players, far to near so the closest draw on top
    var list = [];
    S.others.forEach(function (o) {
      list.push(o);
    });
    list.sort(function (a, b) {
      return a.ry - b.ry;
    });
    for (var li = 0; li < list.length; li++) {
      var oo = list[li];
      drawBlob(ctx, oo.p, oo.rx, oo.ry, {
        hue: oo.hue,
        isSelf: false,
        isTarget: S.target === oo.p.username
      });
    }

    if (me) {
      drawBlob(ctx, me, S.render.x, S.render.y, { hue: 168, isSelf: true, isTarget: false });
    }

    ctx.restore();

    // frame
    roundRect(ctx, fx + 0.5, fy + 0.5, fw - 1, fh - 1, 12);
    ctx.strokeStyle = "rgba(148,163,184,0.18)";
    ctx.lineWidth = 1;
    ctx.stroke();
  }

  /* ------------------------------------------------------------- main loop */

  var lastFrame = 0;
  var hudAccum = 0;

  function frame(ts) {
    requestAnimationFrame(frame);
    if (!S.inGame) return;

    var dt = lastFrame ? Math.min(0.06, (ts - lastFrame) / 1000) : 0.016;
    lastFrame = ts;

    step(dt);
    draw();

    hudAccum += dt;
    if (hudAccum > 0.1) {
      hudAccum = 0;
      syncHud(false);
    }
  }

  function step(dt) {
    // keyboard movement moves the intent, the server hears about it on a timer
    var dx = 0;
    var dy = 0;
    if (S.keys.has("left")) dx -= 1;
    if (S.keys.has("right")) dx += 1;
    if (S.keys.has("up")) dy -= 1;
    if (S.keys.has("down")) dy += 1;

    if ((dx || dy) && S.you && S.you.alive) {
      var len = Math.sqrt(dx * dx + dy * dy) || 1;
      S.intent.x = clamp(S.intent.x + (dx / len) * KEY_SPEED * dt, 0, WORLD_W);
      S.intent.y = clamp(S.intent.y + (dy / len) * KEY_SPEED * dt, 0, WORLD_H);
      S.moveDirty = true;
    }

    if (S.moveDirty) sendMove(false);

    // smoothing: server positions are the truth, we just glide toward them
    var k = 1 - Math.exp(-dt * 13);
    if (dist(S.render.x, S.render.y, S.intent.x, S.intent.y) > 260) {
      S.render.x = S.intent.x;
      S.render.y = S.intent.y;
    } else {
      S.render.x += (S.intent.x - S.render.x) * k;
      S.render.y += (S.intent.y - S.render.y) * k;
    }

    var ko = 1 - Math.exp(-dt * 7);
    S.others.forEach(function (o) {
      if (dist(o.rx, o.ry, o.p.x, o.p.y) > 300) {
        o.rx = o.p.x;
        o.ry = o.p.y;
      } else {
        o.rx += (o.p.x - o.rx) * ko;
        o.ry += (o.p.y - o.ry) * ko;
      }
    });
  }

  /* ------------------------------------------------------------ input: mouse */

  el.canvas.addEventListener(
    "pointerdown",
    function (e) {
      if (!S.inGame || S.ended) return;
      e.preventDefault();
      el.canvas.focus({ preventScroll: true });

      var w = toWorld(e.clientX, e.clientY);
      var px = sx(w.x);
      var py = sy(w.y);

      // did we hit somebody?
      var hitName = null;
      var best = Infinity;
      var grab = Math.max(20, 15 * view.scale + 10);
      S.others.forEach(function (o) {
        var d = dist(px, py, sx(o.rx), sy(o.ry));
        if (d < grab && d < best) {
          best = d;
          hitName = o.p.username;
        }
      });

      if (hitName) {
        selectTarget(hitName === S.target ? null : hitName);
        return;
      }

      S.pings.push({ x: w.x, y: w.y, t: nowMs() });
      moveTo(w.x, w.y);
    },
    { passive: false }
  );

  /* --------------------------------------------------------- input: keyboard */

  var KEYMAP = {
    KeyW: "up",
    ArrowUp: "up",
    KeyS: "down",
    ArrowDown: "down",
    KeyA: "left",
    ArrowLeft: "left",
    KeyD: "right",
    ArrowRight: "right"
  };

  function typingInField(e) {
    var t = e.target;
    return t && (t.tagName === "INPUT" || t.tagName === "TEXTAREA" || t.isContentEditable);
  }

  window.addEventListener("keydown", function (e) {
    if (!S.inGame || typingInField(e)) return;
    if (e.metaKey || e.ctrlKey || e.altKey) return;

    var dir = KEYMAP[e.code];
    if (dir) {
      e.preventDefault();
      S.keys.add(dir);
      return;
    }

    switch (e.code) {
      case "KeyF":
        e.preventDefault();
        attack("rock");
        break;
      case "KeyG":
        e.preventDefault();
        attack("stick");
        break;
      case "KeyQ":
        e.preventDefault();
        cycleTarget();
        break;
      case "Escape":
        selectTarget(null);
        break;
      default:
        break;
    }
  });

  window.addEventListener("keyup", function (e) {
    var dir = KEYMAP[e.code];
    if (dir) {
      S.keys.delete(dir);
      // Push the final position as soon as the key is released so the server
      // does not sit on a stale spot until the next tick.
      if (S.moveDirty) sendMove(true);
    }
  });

  window.addEventListener("blur", function () {
    S.keys.clear();
  });

  /* --------------------------------------------------------------- buttons */

  el.btnThrow.addEventListener("click", function () {
    attack("rock");
  });
  el.btnSwing.addEventListener("click", function () {
    attack("stick");
  });
  el.btnCycle.addEventListener("click", cycleTarget);
  el.clearTargetBtn.addEventListener("click", function () {
    selectTarget(null);
  });

  /* ------------------------------------------------------------ login flow */

  function showLoginError(msg) {
    if (!msg) {
      el.loginError.hidden = true;
      el.loginError.textContent = "";
      return;
    }
    el.loginError.hidden = false;
    el.loginError.textContent = msg;
  }

  function setPlayBusy(busy) {
    el.playBtn.disabled = busy || !haveApi();
    el.playBtnLabel.textContent = busy ? "Joining…" : "Play";
  }

  el.loginForm.addEventListener("submit", function (e) {
    e.preventDefault();
    var name = el.username.value.trim();

    if (!NAME_RE.test(name)) {
      showLoginError(
        "That name will not work. Use 2 to 16 letters, numbers, hyphens or underscores."
      );
      el.username.focus();
      return;
    }
    if (!haveApi()) {
      showLoginError("There is no game server configured for this page yet.");
      return;
    }

    showLoginError("");
    setPlayBusy(true);
    setStatus("is-idle", "Connecting…");

    api("/api/login", { username: name })
      .then(function (data) {
        var p = normalizePlayer(data.player || data.you);
        if (!p) throw new ApiError("The server did not send back a player.", 0);
        try {
          localStorage.setItem("rs.username", p.username);
        } catch (err) {
          /* private browsing, no matter */
        }
        startSession(p);
      })
      .catch(function (err) {
        setPlayBusy(false);
        setStatus("is-idle", "Not connected");
        showLoginError(err && err.message ? err.message : "Could not join.");
      });
  });

  /* -------------------------------------------------------------- sessions */

  function startSession(player) {
    S.inGame = true;
    S.ended = false;
    S.username = player.username;
    S.you = player;
    S.others.clear();
    S.target = null;
    S.keys.clear();
    S.pings.length = 0;
    S.hits.length = 0;
    S.failures = 0;
    S.online = true;
    S.busy = false;
    S.sawState = false;
    S.moveDirty = false;
    S.lastMoveSent = 0;
    S.intent.x = player.x;
    S.intent.y = player.y;
    S.render.x = player.x;
    S.render.y = player.y;

    clearLog();
    el.loginScreen.hidden = true;
    el.gameScreen.hidden = false;
    el.deathOverlay.hidden = true;
    el.netChip.hidden = true;
    el.whoami.hidden = false;
    el.whoamiName.textContent = player.username;
    setStatus("is-live", "Connected");
    setPlayBusy(false);
    setActionsEnabled(true);

    addLog("You dropped into the field as " + player.username + ".", null);
    addLog("Pick up a rock (R) or a stick (T) to have something to fight with.", null);

    resize();
    syncHud(true);
    poll();
  }

  function setActionsEnabled(on) {
    el.btnCycle.disabled = !on;
    if (!on) {
      el.btnThrow.disabled = true;
      el.btnSwing.disabled = true;
    }
  }

  function endSession(reason, message) {
    if (S.ended) return;
    S.ended = true;
    S.inGame = false;
    clearTimeout(S.pollTimer);
    S.keys.clear();
    setActionsEnabled(false);

    var died = reason === "died";
    el.deathKicker.textContent = died ? "You died" : "Disconnected";
    el.deathKicker.style.color = died ? "" : "#f8dfae";
    el.deathMessage.textContent =
      message || (died ? "Somebody out there had better aim." : "The session ended.");
    el.deathOverlay.hidden = false;
    el.netChip.hidden = true;
    setStatus("is-idle", died ? "Dead" : "Disconnected");

    addLog(died ? "You died." : "Session ended: " + (message || "disconnected"), "hurt");

    var left = Math.round(DEATH_RETURN_MS / 1000);
    el.deathCountdown.textContent = "Back to login in " + left + "s";
    clearInterval(S.deathTimer);
    S.deathTimer = setInterval(function () {
      left--;
      if (left <= 0) {
        clearInterval(S.deathTimer);
        toLogin();
      } else {
        el.deathCountdown.textContent = "Back to login in " + left + "s";
      }
    }, 1000);
  }

  function toLogin() {
    clearInterval(S.deathTimer);
    clearTimeout(S.pollTimer);
    S.inGame = false;
    S.you = null;
    S.others.clear();
    S.target = null;

    el.deathOverlay.hidden = true;
    el.gameScreen.hidden = true;
    el.loginScreen.hidden = false;
    el.whoami.hidden = true;
    setStatus("is-idle", "Not connected");
    setPlayBusy(false);
    showLoginError("");
    el.username.value = S.username || el.username.value;
    el.username.focus();
    el.username.select();
  }

  el.respawnBtn.addEventListener("click", toLogin);

  /* ------------------------------------------------------------------ init */

  function init() {
    if (!haveApi()) {
      el.configWarning.hidden = false;
      el.playBtn.disabled = true;
      setStatus("is-idle", "No server configured");
    } else {
      setStatus("is-idle", "Ready");
    }

    try {
      var saved = localStorage.getItem("rs.username");
      if (saved && NAME_RE.test(saved)) el.username.value = saved;
    } catch (e) {
      /* ignore */
    }

    el.username.focus();

    if (window.ResizeObserver) {
      new ResizeObserver(function () {
        resize();
      }).observe(el.field);
    }
    window.addEventListener("resize", resize);
    window.addEventListener("orientationchange", function () {
      setTimeout(resize, 120);
    });

    // Coming back to a backgrounded tab: poll immediately so the heartbeat and
    // the board catch up straight away.
    document.addEventListener("visibilitychange", function () {
      if (!document.hidden && S.inGame) schedulePoll(0);
    });

    resize();
    requestAnimationFrame(frame);
  }

  init();
})();
