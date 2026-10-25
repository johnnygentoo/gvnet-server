# gvnet-server

A small matching server for the online modes of the **GUNDAM VERSUS** ([gvport](https://github.com/johnnygentoo/gvport))
and **MOBILE SUIT GUNDAM EXTREME VS. MAXIBOOST ON** ([mbport](https://github.com/johnnygentoo/MaxiboostPort))
Linux ports.

Both games' versus modes are online only: they look for other players through PSN matchmaking, and
without a server answering, the port tells the game it is a console not signed in to PlayStation
Network. This is that server — one binary, no game files, no GPU, no PSN. It speaks the protocol of
the ports' own online module (the shadNet client), so the games find each other and then connect
to each other directly.

It is for your own machines and your own friends: a LAN, a home server, or a VPN such as Tailscale
or WireGuard. **See [Who may sign in](#who-may-sign-in) before putting it on a public address.**

## What it does

- **Rooms** (`NpMatching2`): create, search with the games' filters, join, leave, kick, owner
  succession when the owner leaves, room and member data (how both games carry each player's
  "Ready"), and the room events the games expect (`0x1101` joined, `0x1102` left, `0x1103` kicked,
  `0x1106` room data).
- **Signaling**: each player's address and port, over UDP on the port after the TCP one, so the two
  games can open their peer-to-peer connection to each other.
- **Worlds**: 1..n (`GVNET_WORLDS`, 10 by default), plus any world a room is in.

Rooms, members and their data live in memory. Stop the server and they are gone; that is fine,
because a match is set up in seconds and then runs between the players themselves.

## What it does not do

This is a matching server for people who already know each other, not a PSN replacement:

- **No accounts.** Any name signs in, with any password or none.
- **No friends lists.** Everyone signed in is everyone's friend.
- **No scores or rankings.** Every score request is answered "not found".
- **No WebAPI**, no trophies, no title storage, no telemetry. The publisher's servers are never
  contacted, by the server or by the games.

### Who may sign in

Anyone who can reach the port. There is no password check: the sign-in takes any name with any
password. **And the default `--bind` is `0.0.0.0`, every address the machine has** - so a default
start on a machine with a public address lets anybody on the Internet sign in under any name, see
your rooms and join them. Fine between friends, not fine as a public service. The three sane
choices:

- bind it to a **LAN** address and let your router keep it off the Internet;
- bind it to a **Tailscale or WireGuard** address, so only your own devices reach it;
- a public address behind a **firewall** that allows only the addresses you want.

`--bind 127.0.0.1` is that one machine only, which is what the ports' *two players on one PC*
mode uses.

## Build

Needs `g++` (C++20) and protobuf (`protoc` plus pkg-config's `protobuf`). On Debian/Ubuntu:
`apt install g++ protobuf-compiler libprotobuf-dev`; on Arch: `pacman -S gcc protobuf`; on Gentoo:
`emerge dev-libs/protobuf`.

```sh
bash build.sh                  # writes out/gvnet-server
bash build.sh /path/to/build   # or link protobuf statically from a CMake build of it
```

The second form takes the build directory of a CMake protobuf with abseil fetched — shadnet-p2p's,
for instance — and links it in statically, for a machine whose system protobuf is too old.

## Run

```sh
out/gvnet-server --bind 0.0.0.0 --port 31323          # GUNDAM VERSUS' port
out/gvnet-server --bind 0.0.0.0 --port 31333          # MAXIBOOST ON's port
out/gvnet-server --help
```

It listens on TCP at `--port` and UDP at `--port + 1`, and logs sign-ins, rooms and joins to
standard output.

Then on each player's PC, in the port's launcher: **Over the network → join**, with
`<the server's address>:<port>`. (**host** instead starts a server on that PC, for the case where
one of the players hosts.) The games meet in the game's own online menu — PLAY → PLAYER MATCH in
GUNDAM VERSUS, Player Match in MAXIBOOST ON — one creating the room and the others searching for
it with the same room type.

### By hand, or as a service

`bin/gvserver` and `bin/mbserver` start and stop one instance each, detached from your shell so it
survives logging out:

```sh
bin/gvserver toggle | start | stop | restart | status | log [lines] | follow
```

`gvserver` expects the binary at `~/gvnet-server/gvnet-server` on port 31323; `mbserver` expects
`~/mbnet-server/mbnet-server` on port 31333 (`GVNET_PORT` / `MBNET_PORT` change the port). The two
names are not cosmetic: each script finds its own server by the process name, so running two
instances under the same name would have one stop the other.

`systemd/` has the same two as user services:

```sh
cp systemd/gvnet-server.service ~/.config/systemd/user/
systemctl --user daemon-reload && systemctl --user enable --now gvnet-server
loginctl enable-linger                 # keeps it running with nobody logged in
```

### Ports

One machine can host all three of the ports' servers at once:

| Server | TCP | UDP |
|---|---|---|
| GODZILLA ([gzport-shadnet](https://github.com/johnnygentoo/gzport-shadnet)) | 31313, 31315 | 31314 |
| GUNDAM VERSUS (`gvnet-server`) | 31323 | 31324 |
| MAXIBOOST ON (`mbnet-server`) | 31333 | 31334 |

Each player's game also needs its own peer-to-peer port open between the players: UDP 3658.

## Status

**Works, lightly tested.** What has actually been played through it:

- **MAXIBOOST ON**: a 1-on-1 Player Match, twice — two games on one PC, and two PCs on Wi-Fi (an
  RX 580 and an RTX 3050) joined to a server on a third PC. Room created, found, joined, both
  Ready, the battle at 60 FPS with hits landing both ways, and both back in the room when the
  timer ran out.
- **GUNDAM VERSUS**: two games on one PC joined to a server on another PC over the LAN
  (2026-10-18): room found, joined, a 1-on-1 battle started. Also the port's two-players-on-one-PC
  mode, which runs an instance of this server on that PC.

Not tried yet: more than two players, the other room types (Free, Shuffle), Ranked and Casual
Match, the games' own LAN Battle mode, and anything over the Internet rather than a LAN or VPN.

## Documentation

- [docs/HOSTING.md](docs/HOSTING.md) - building it, running it, who can reach it, several instances
  on one machine, keeping it running.
- [docs/PROTOCOL.md](docs/PROTOCOL.md) - what the server really implements: packets, commands,
  errors, room events, member and account ids, the UDP address exchange, and what is deliberately
  missing.
- [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) - symptoms and what each one means.

## Licence

GPL-2.0-or-later. See [LICENSE](LICENSE) and [CREDITS.md](CREDITS.md) — this stands on other
people's work.
