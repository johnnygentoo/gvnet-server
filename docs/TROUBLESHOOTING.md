# Troubleshooting

Start the server with `--verbose` and watch its log; most of these name themselves there.

## The game says it is not signed in to PlayStation Network

The sign-in never got through. In order of likelihood:

1. **Nothing is listening where the game is looking.** Check from the player's machine, not from
   the server: `ss -lntup | grep <port>` on the server, and confirm the game is pointed at
   `<address>:<port>` with the TCP port, not the UDP one.
2. **A firewall between them.** The TCP port *and* the UDP port after it both have to arrive. A LAN
   usually needs nothing; a VPS needs its firewall opened; a VPN sidesteps both.
3. **It is bound somewhere the player cannot reach.** `--bind 127.0.0.1` is that machine only. The
   log's first line says which address it took.
4. **The name.** Empty names are refused. Anything else is accepted, and no password is checked, so
   a "wrong password" is never the cause here.

## A room is never found

- **Both games must be the same game.** Rooms are keyed by title id; a GUNDAM VERSUS room is
  invisible to MAXIBOOST ON and vice versa.
- **Same room type on both sides.** One player creates with a type, the other searches with the
  same one; the search filters on the game's own attributes, so a mismatch returns nothing. In
  MAXIBOOST ON that means *Create Room* with **Room type: 1-on-1** and *Search for Room* with the
  same.
- **Look at the log.** `searched world N: 0 room(s)` means the search arrived and matched nothing —
  a filter mismatch, not a connection problem. No line at all means the search never arrived.
- **Only 20 rooms come back** per search. Not a problem at the scale this is for.

## The room fills up but the match never starts

The owner is waiting for everyone's "Ready". Both games carry that flag as room data, so:

- Watch for `0x1106` room-data events in the log as each player readies up. If one player's flag
  never arrives, that player's game is not sending it — look at that machine, not the server.
- If the flags all arrive and nothing happens, the match is failing to start **peer to peer**,
  which is the next section.

## Everyone is in the room, the match starts, and nobody can see anybody

The match does not go through the server; it goes straight between the players over **UDP 3658**.

- That port has to be open between the players, in both directions.
- Each player's address, as the server learnt it over UDP, is in the log
  (`<name>'s address: <ip>:<port>`). **If that address is not the one the other player can reach,
  this is the fault.** The classic case is a mixed setup where the server is reached over a VPN by
  one player and over the LAN by another: everyone should reach the server the same way.
- Behind two different NATs with no VPN, this generally will not work and is not what the server is
  for. Put everyone on a VPN.

## A player signs in and someone else gets dropped

They are using the same name. The newer sign-in wins and the older connection is closed, by design,
so that a crashed game can come straight back without waiting for a timeout. Give each player their
own name.

## The server was restarted and everyone fell out of the lobby

Expected: rooms live in memory only. The games sign in again by themselves; the lobby has to be
made again. A match that was already running is unaffected, because it was never going through the
server.

## Two servers keep stopping each other

Both were installed under the same binary name. `bin/gvserver` and `bin/mbserver` each find their
server by process name, so the binary has to be copied as `gvnet-server` for one and
`mbnet-server` for the other — see [HOSTING.md](HOSTING.md#several-instances-on-one-machine).

## It will not build

- `protoc: command not found` or protobuf not found by pkg-config: install the protobuf compiler
  **and** its development package (`libprotobuf-dev` on Debian).
- A protobuf too old for the generated code, or none at all: use the second form,
  `bash build.sh /path/to/a/cmake/protobuf/build`, which links it statically.
- Anything else: the build is two commands, `protoc` then one `g++`. Run `bash -x build.sh` and the
  failing one is in plain sight.
