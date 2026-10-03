#!/usr/bin/env node
// mario-clone online relay (v1.9, stage 2 of the network co-op).
//
// Mario's game opens a room and gets a 4-letter code; Luigi's game joins
// with that code. From then on the relay just passes every binary message
// from one side to the other (the game itself runs on Mario's device, see
// net_host.gd / net_client.gd). Text frames are the small JSON control
// protocol:
//   game -> relay  {"op":"host","v":"1.9.0"}            open a room
//                  {"op":"join","code":"K7QM","v":"1.9.0"}
//   relay -> game  {"op":"room","code":"K7QM"}          (host)
//                  {"op":"joined"}                       both: partner is there
//                  {"op":"left"}                         partner went away
//                  {"op":"error","msg":"..."}           then the socket closes
// Since 2026-10-03 (relay 2.0, tetris v1.1 versus) the relay serves the whole series: "host"/"join"
// carry the game ("g": "tetris", …; none = "mario-clone") and a code only
// opens a room of the same game.
// A room lives as long as Mario's connection; Luigi may leave and join
// again. Limits: message size, rooms, idle connections (ping/pong).
//
// Run:  PORT=8765 node relay.js      (needs the "ws" package: npm install)

"use strict";
const http = require("http");
const { WebSocketServer } = require("ws");

const PORT = parseInt(process.env.PORT || "8765", 10);
const MAX_MSG = 1024 * 1024;        // 1 MB per message
const MAX_ROOMS = 200;
// no digits that look like letters in the game's pixel font (5/S, 2/Z,
// 8/B, 6/G, 0/O, 1/I) — the game maps a typed lookalike to the letter
const CODE_CHARS = "ABCDEFGHJKLMNPQRSTUVWXYZ3479";
const PING_MS = 20000;

const rooms = new Map();            // code -> {host, guest}

function log(...a) {
  console.log(new Date().toISOString(), ...a);
}

function newCode() {
  for (let tries = 0; tries < 1000; tries++) {
    let c = "";
    for (let i = 0; i < 4; i++) c += CODE_CHARS[Math.floor(Math.random() * CODE_CHARS.length)];
    if (!rooms.has(c)) return c;
  }
  return null;
}

function gameOf(m) {
  return String(m.g || "mario-clone").slice(0, 32);
}

function send(ws, obj) {
  if (ws && ws.readyState === ws.OPEN) ws.send(JSON.stringify(obj));
}

function fail(ws, msg) {
  send(ws, { op: "error", msg });
  ws.close(4000, msg.slice(0, 100));
}

// plain HTTP answer for a quick check in the browser
const server = http.createServer((req, res) => {
  res.writeHead(200, { "Content-Type": "text/plain" });
  res.end(`mario-clone relay ok, ${rooms.size} room(s)\n`);
});

const wss = new WebSocketServer({ server, maxPayload: MAX_MSG });

wss.on("connection", (ws, req) => {
  ws.alive = true;
  ws.role = null;
  ws.room = null;
  ws.on("pong", () => { ws.alive = true; });

  ws.on("message", (data, isBinary) => {
    if (isBinary) {
      // game data: straight to the partner
      const r = ws.room && rooms.get(ws.room);
      if (!r) return;
      const other = ws.role === "host" ? r.guest : r.host;
      if (other && other.readyState === other.OPEN) other.send(data, { binary: true });
      return;
    }
    let m;
    try { m = JSON.parse(data.toString()); } catch { return fail(ws, "bad message"); }
    if (ws.role) return;                       // already placed
    if (m.op === "host") {
      if (rooms.size >= MAX_ROOMS) return fail(ws, "The server is full, try again later.");
      const code = newCode();
      if (!code) return fail(ws, "No free room code.");
      rooms.set(code, { host: ws, guest: null, v: String(m.v || ""), g: gameOf(m) });
      ws.role = "host";
      ws.room = code;
      send(ws, { op: "room", code });
      log("room", code, "opened", gameOf(m), req.socket.remoteAddress);
    } else if (m.op === "join") {
      const code = String(m.code || "").toUpperCase().trim();
      const r = rooms.get(code);
      if (!r || r.g !== gameOf(m)) return fail(ws, `There is no game with the code ${code}.`);
      if (r.guest && r.guest.readyState === r.guest.OPEN)
        return fail(ws, r.g === "mario-clone" ? "Luigi is already playing in that game." : "Someone is already playing in that game.");
      r.guest = ws;
      ws.role = "guest";
      ws.room = code;
      send(ws, { op: "joined" });
      send(r.host, { op: "joined" });
      log("room", code, "joined");
    } else {
      fail(ws, "unknown request");
    }
  });

  ws.on("close", () => {
    const r = ws.room && rooms.get(ws.room);
    if (!r) return;
    if (ws.role === "host" && r.host === ws) {
      rooms.delete(ws.room);
      if (r.guest) fail(r.guest, r.g === "mario-clone" ? "Mario ended the online game." : "Your opponent ended the game.");
      log("room", ws.room, "closed");
    } else if (ws.role === "guest" && r.guest === ws) {
      r.guest = null;
      send(r.host, { op: "left" });
      log("room", ws.room, "guest left");
    }
  });

  ws.on("error", () => {});
});

// drop connections that stopped answering
setInterval(() => {
  for (const ws of wss.clients) {
    if (!ws.alive) { ws.terminate(); continue; }
    ws.alive = false;
    ws.ping();
  }
}, PING_MS);

server.listen(PORT, () => log(`relay listening on port ${PORT}`));
