# Ad Valorem Pocket – multiplayer relay

Browsers can't host a server, so every player (host included) connects out to this
small relay. It hands out room keys like `SJ4-GT7`, caps rooms at 8 players, and
forwards Godot's multiplayer packets between the players in a room.

The game side lives in `Scripts/net/`:
- `relay_peer.gd`: a `MultiplayerPeer` that talks to this relay, so `@rpc`,
  `multiplayer.get_unique_id()`, `MultiplayerSynchronizer` etc. all work as normal.
  The host is peer 1.
- `Network.gd` (autoload `Network`): host/join/leave, the lobby player list, start game.

## Run it on your computer (testing)

Requires Node.js 18+.

```
cd server
npm install
npm start          # listens on ws://localhost:9080
```

When you press Play in the Godot editor, the game connects to `ws://localhost:9080`
automatically. To test with several players on one PC, enable
Debug > Customize Run Instances and run 2–4 instances.

To test with phones on your Wi-Fi, run the game with `-- --relay=ws://<your-PC-IP>:9080`.

## Put it online (free, Render.com)

1. Push this repo to GitHub.
2. On render.com: New > Blueprint > pick the repo. It reads `render.yaml` at the
   repo root and creates the `ad-valorem-relay` web service from this folder.
3. When it's live, copy its URL (e.g. `https://ad-valorem-relay.onrender.com`) and
   put it in `Scripts/net/Network.gd` as `RELAY_URL`, with `wss://` instead of `https://`.

The free plan sleeps after ~15 minutes idle and takes up to a minute to wake. The game
waits up to 75 s and shows "the server may take a moment to wake up".

## Web export for GitHub Pages

- Project > Export > Add > Web. Untick **Thread Support** (GitHub Pages can't send the
  headers threads need). Export as `index.html` into a `docs/` folder (or a `gh-pages` branch).
- GitHub repo > Settings > Pages > deploy from that folder/branch.
- Pages is https, so the relay must be `wss://` (Render provides that automatically).

## Protocol (for reference)

Text frames are JSON control messages:

| direction | message |
|---|---|
| client → relay | `{op:"host"}`, `{op:"join", key}`, `{op:"lock"}`, `{op:"leave"}` |
| relay → client | `{op:"hosted", key, id:1}`, `{op:"joined", key, id, peers:[…]}`, `{op:"peer_joined", id}`, `{op:"peer_left", id}`, `{op:"room_closed"}`, `{op:"error", msg}` |

Binary frames are game packets: a 4-byte little-endian int32 header, then the payload.
Client → relay the header is the target peer (0 = all, −N = all except N); relay → client
it is the sender's peer id.
