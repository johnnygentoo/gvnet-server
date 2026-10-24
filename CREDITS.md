# Credits

gvnet-server was written for the GUNDAM VERSUS and MAXIBOOST ON Linux ports by
**Johnnygentoo Studios** ([Johnnygentoo](https://github.com/johnnygentoo) and Claude), and it
stands on the work of others.

## The room logic

[**Wozzardman**](https://github.com/Wozzardman) — [shadnet-p2p](https://github.com/Wozzardman/shadnet-p2p),
GPL-2.0-or-later. Its `cmd_matching.cpp` is what this server's room behaviour follows: member ids
(`slot << 4 | counter`), the room events (`0x1101` joined, `0x1102` left, `0x1103` kicked out,
`0x1106` room data), owner succession, slot counts and the search filters. Also
[shadp2p](https://github.com/Wozzardman/shadp2p), the network and PSN libraries of the ports'
online module, whose client this server answers.

## The protocol

`proto/shadnet.proto` is **not ours**. It is the shadNet protocol definition, copied unchanged from
the ports' online module so that the server and the games agree on the wire format:

- Copyright 2019-2026 **rpcsn Project**
- Copyright 2026 **shadNet Project**
- GPL-2.0-or-later

## The ports this serves

- [**deadinside28**](https://github.com/deadinside28) — [bbport](https://github.com/deadinside28/bloodborne_pc),
  the native Bloodborne port that all of this grew from.
- [**ayozetr**](https://github.com/ayozetr) — [bloodborne_linux](https://github.com/ayozetr/bloodborne_linux),
  its Linux fork.
- [**shadPS4**](https://github.com/shadps4-emu/shadPS4) — the PS4 graphics translation the ports'
  renderer derives from.

## Not affiliated

An unofficial fan project, not affiliated with or endorsed by Bandai Namco Entertainment, SOTSU,
SUNRISE, Sony Interactive Entertainment or the shadPS4 project. It contains no game code, no game
data and no console keys, and it never will.
