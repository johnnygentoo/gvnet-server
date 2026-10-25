# Hosting

## What the machine needs

A Linux machine, `g++` with C++20, and protobuf. **Nothing else**: no GPU, no copy of a port, no
game files, no PSN account. The server is a single ~700 KB binary that holds its state in memory;
on an idle room it uses a few megabytes and effectively no CPU, because the match itself runs
between the players and never passes through it.

| Distribution | Packages |
|---|---|
| Debian / Ubuntu | `g++ protobuf-compiler libprotobuf-dev` |
| Arch | `gcc protobuf` |
| Fedora | `gcc-c++ protobuf-compiler protobuf-devel` |
| Gentoo | `dev-libs/protobuf` |

## Building

```sh
bash build.sh                      # out/gvnet-server, using the system protobuf
bash build.sh /path/to/pb-build    # or link a CMake protobuf statically
```

The second form is for a machine whose system protobuf is too old or absent. Point it at the build
directory of a CMake protobuf with abseil fetched — shadnet-p2p's `build/` is one — and it links
`libprotobuf.a`, abseil and utf8_range in statically, so the binary carries no protobuf dependency
and can be copied to a machine that has none.

Nothing is installed. The binary can be copied anywhere, and it is the only file that matters.

## Running it

```sh
out/gvnet-server [--bind ADDRESS] [--port N] [--verbose]
```

| Flag | Default | Meaning |
|---|---|---|
| `--bind` | `0.0.0.0` | The address to listen on. |
| `--port` | `31313` | TCP port for sign-in and matchmaking. **UDP is `--port + 1`.** |
| `--verbose` | off | Also logs the commands it answers, including the ones it refuses. |
| `GVNET_WORLDS` | `10` | How many worlds to report, for a game that asks for the world list. |

It logs to standard output, every line prefixed `gvnet:` — sign-ins and sign-outs, matching
contexts, rooms created, searched and joined, each player's address as it is learnt, and any
command that failed with an error.

### Who can reach it: read this part

**The default `--bind` is `0.0.0.0` — every address the machine has.** And the server has
**no password check**: the sign-in takes any name with any password (see
[PROTOCOL.md](PROTOCOL.md#sign-in)). So a default start on a machine with a public address means
anybody on the Internet can sign in under any name, see your rooms and join them.

That is fine between friends and it is not fine as a public service. Pick one:

- **A LAN only.** Bind the LAN address (`--bind 192.168.x.y`) and let your router keep the
  Internet out. Simplest, and what most people want.
- **A VPN.** Bind the machine's Tailscale or WireGuard address. Then only your own devices can
  reach it, wherever they are, and no router port has to be opened — the one good answer for
  friends who are not in your house.
- **A public address behind a firewall** that allows only the addresses of the people you are
  playing with, and nothing else.

Binding `127.0.0.1` makes it reachable only from that one machine, which is what the ports' own
*two players on one PC* mode uses.

Players also need their game's peer-to-peer port, **UDP 3658**, open to each other — the match
goes straight between them. Over a VPN this is already true.

## Several instances on one machine

Rooms are keyed by the game's title id as well as its room id, so instances never confuse one
game's rooms for another's. The ports are nevertheless set up to use one instance per game, with
ports chosen not to collide:

| Server | TCP | UDP | Started by |
|---|---|---|---|
| GODZILLA ([gzport-shadnet](https://github.com/johnnygentoo/gzport-shadnet), a different server) | 31313, 31315 | 31314 | its own container |
| GUNDAM VERSUS | 31323 | 31324 | `bin/gvserver`, `systemd/gvnet-server.service` |
| MAXIBOOST ON | 31333 | 31334 | `bin/mbserver`, `systemd/mbnet-server.service` |

`bin/gvserver` expects the binary at `~/gvnet-server/gvnet-server`; `bin/mbserver` expects
`~/mbnet-server/mbnet-server`. **Copy it under the name the wrapper expects.** Each wrapper finds
its own server by process name, so two instances sharing one name would have each wrapper stop the
other's — that is the whole reason for the second name.

```sh
mkdir -p ~/mbnet-server && cp out/gvnet-server ~/mbnet-server/mbnet-server
bin/mbserver start          # also: stop, restart, toggle, status, log [lines], follow
```

`GVNET_PORT` and `MBNET_PORT` override the port each wrapper uses.

Because rooms are keyed by title, **one instance could serve both games at once** — both ports
would be pointed at the same address and port. That is how it is built, but it has not been tried;
the separate instances above are what has actually been played on.

## Keeping it running

As a systemd **user** service, which needs no root:

```sh
cp systemd/gvnet-server.service ~/.config/systemd/user/
systemctl --user daemon-reload
systemctl --user enable --now gvnet-server
loginctl enable-linger                  # keeps it up with nobody logged in
journalctl --user -u gvnet-server -f    # its log
```

Edit `ExecStart` in the unit to match where you put the binary and which address to bind.

`bin/gvserver start` is the alternative: it detaches the server with `setsid`, so it survives the
shell and an ssh session closing, and writes its log beside the binary (`~/gvnet-server/gvnet.log`,
read it with `bin/gvserver log` or `follow`).

## Updating, and what is lost

Stop it, replace the binary, start it. Rooms and sign-ins live only in memory, so everyone in a
lobby is dropped and has to sign in again — which the games do by themselves — but there is no
database, no state directory and nothing to migrate or back up. A match already running does not
pass through the server and is unaffected.
