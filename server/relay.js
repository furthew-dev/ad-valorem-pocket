// Ad Valorem Pocket – room relay server.
//
// Browsers can't accept incoming connections, so every player (host included) connects
// out to this relay. The host asks for a room and gets a key like "SJ4-GT7"; others join
// with that key. After that the relay just forwards Godot multiplayer packets between
// the peers in a room. It knows nothing about the game itself.
//
// Protocol
//   Text frames (JSON) are control messages:
//     client -> relay  {op:"host"} | {op:"join", key} | {op:"lock"} | {op:"unlock"}
//     relay -> client  {op:"hosted", key, id:1}
//                      {op:"joined", key, id, peers:[ids]}
//                      {op:"peer_joined", id} | {op:"peer_left", id}
//                      {op:"room_closed"} | {op:"error", msg}
//   Binary frames are game packets: 4-byte little-endian int32 header + payload.
//     client -> relay  header = target peer (0 = everyone, -N = everyone except N)
//     relay -> client  header = sender peer id

const http = require("http");
const { WebSocketServer } = require("ws");

const PORT = Number(process.env.PORT) || 9080;
const MAX_PLAYERS = 8;
const MAX_PACKET = 64 * 1024;
const KEY_ALPHABET = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"; // no 0/O or 1/I mix-ups

const rooms = new Map(); // key -> { peers: Map<id, ws>, locked: bool }

function makeKey() {
  let key;
  do {
    const pick = () => KEY_ALPHABET[Math.floor(Math.random() * KEY_ALPHABET.length)];
    key = `${pick()}${pick()}${pick()}-${pick()}${pick()}${pick()}`;
  } while (rooms.has(key));
  return key;
}

function makePeerId(room) {
  let id;
  do {
    id = 2 + Math.floor(Math.random() * 2147483640); // Godot peer ids: positive int32, 1 = host
  } while (room.peers.has(id));
  return id;
}

// Accepts "sj4gt7", "SJ4 GT7", "sj4-gt7" ...
function normalizeKey(raw) {
  const clean = String(raw || "").toUpperCase().replace(/[^A-Z0-9]/g, "");
  return clean.length === 6 ? `${clean.slice(0, 3)}-${clean.slice(3)}` : clean;
}

function send(ws, obj) {
  if (ws.readyState === ws.OPEN) ws.send(JSON.stringify(obj));
}

function broadcast(room, obj, exceptId = 0) {
  for (const [id, peer] of room.peers) if (id !== exceptId) send(peer, obj);
}

function leaveRoom(ws) {
  const { roomKey, peerId } = ws;
  const room = rooms.get(roomKey);
  ws.roomKey = null;
  ws.peerId = 0;
  if (!room) return;
  room.peers.delete(peerId);
  if (peerId === 1) {
    // Host left: the room is over for everyone.
    broadcast(room, { op: "room_closed" });
    rooms.delete(roomKey);
    console.log(`room ${roomKey} closed`);
  } else {
    broadcast(room, { op: "peer_left", id: peerId });
  }
}

function handleControl(ws, msg) {
  switch (msg.op) {
    case "host": {
      if (ws.roomKey) leaveRoom(ws);
      const key = makeKey();
      rooms.set(key, { peers: new Map([[1, ws]]), locked: false });
      ws.roomKey = key;
      ws.peerId = 1;
      send(ws, { op: "hosted", key, id: 1 });
      console.log(`room ${key} opened`);
      return;
    }
    case "join": {
      if (ws.roomKey) leaveRoom(ws);
      const key = normalizeKey(msg.key);
      const room = rooms.get(key);
      if (!room) return send(ws, { op: "error", msg: "Room not found. Check the key." });
      if (room.locked) return send(ws, { op: "error", msg: "That game has already started." });
      if (room.peers.size >= MAX_PLAYERS) return send(ws, { op: "error", msg: "That room is full (8 players)." });
      const id = makePeerId(room);
      const existing = [...room.peers.keys()];
      room.peers.set(id, ws);
      ws.roomKey = key;
      ws.peerId = id;
      send(ws, { op: "joined", key, id, peers: existing });
      broadcast(room, { op: "peer_joined", id }, id);
      return;
    }
    case "lock":
    case "unlock": {
      const room = rooms.get(ws.roomKey);
      if (room && ws.peerId === 1) room.locked = msg.op === "lock";
      return;
    }
    case "leave":
      return leaveRoom(ws);
    default:
      send(ws, { op: "error", msg: `Unknown op: ${msg.op}` });
  }
}

function handlePacket(ws, data) {
  const room = rooms.get(ws.roomKey);
  if (!room || data.length < 4 || data.length > MAX_PACKET) return;
  const target = data.readInt32LE(0);
  const out = Buffer.from(data); // copy, then stamp the sender id into the header
  out.writeInt32LE(ws.peerId, 0);
  if (target > 0) {
    const peer = room.peers.get(target);
    if (peer && peer.readyState === peer.OPEN) peer.send(out);
    return;
  }
  const excluded = -target; // 0 when target is 0
  for (const [id, peer] of room.peers) {
    if (id === ws.peerId || id === excluded) continue;
    if (peer.readyState === peer.OPEN) peer.send(out);
  }
}

// Plain HTTP answers health checks (Render pings "/").
const server = http.createServer((req, res) => {
  res.writeHead(200, { "Content-Type": "text/plain" });
  res.end(`Ad Valorem relay OK - ${rooms.size} room(s)\n`);
});

const wss = new WebSocketServer({ server, maxPayload: MAX_PACKET });

wss.on("connection", (ws) => {
  ws.roomKey = null;
  ws.peerId = 0;
  ws.isAlive = true;
  ws.on("pong", () => (ws.isAlive = true));
  ws.on("message", (data, isBinary) => {
    if (isBinary) return handlePacket(ws, data);
    let msg;
    try {
      msg = JSON.parse(data.toString());
    } catch {
      return send(ws, { op: "error", msg: "Bad message" });
    }
    handleControl(ws, msg);
  });
  ws.on("close", () => leaveRoom(ws));
});

// Drop connections that stop answering (phone locked, tab closed...).
setInterval(() => {
  for (const ws of wss.clients) {
    if (!ws.isAlive) {
      ws.terminate();
      continue;
    }
    ws.isAlive = false;
    ws.ping();
  }
}, 20000);

server.listen(PORT, () => console.log(`Relay listening on port ${PORT}`));
