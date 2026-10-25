# What the server implements

This describes the server as it is written, so that someone reading the code — or pointing another
game at it — knows what is real and what is a stub. The wire format is the shadNet client's, in
`proto/shadnet.proto`; the room behaviour follows
[shadnet-p2p](https://github.com/Wozzardman/shadnet-p2p)'s `cmd_matching.cpp`.

## Transport

- **TCP** on `--port`: length-framed packets, each one a type, a command number, a request id and a
  protobuf body. The four types are request, reply, notification and server info; the server sends
  a reply to every request and notifications when something happens to a room.
- **UDP** on `--port + 1`: the address exchange, below.

Every reply begins with a one-byte error code, and the body follows only when that code is 0.

## Sign-in

`Login` takes a name (`npid`) and a title id. **The password is not looked at.** Any name signs in;
an empty name is refused as malformed. What the server does with the name:

- If that name is already signed in on another connection, the older connection is **taken out of
  its room and closed**, and the new one takes over. This is what makes a crashed game able to come
  straight back.
- The name gets an **account id derived from itself** — FNV-1a of the name, offset into
  `0x100000000`, stepped on if it collides. The same name therefore gets the same id every time, on
  any run of the server, so the games' per-account data (title user storage, saves keyed by the
  account) stays with the player no matter what order people sign in.

`Create` is accepted so that a game that wants to make an account can, and `GetToken` answers with
`gvnet-<name>`. There are no stored accounts behind either.

Any command other than `Login` or `Create` before a sign-in is refused with `Unauthorized` (23).

## Commands

**Implemented** — these do what the games need:

| Command | № | Notes |
|---|---|---|
| `Login` | 0 | Above. |
| `Terminate` | 1 | Shuts the connection down. |
| `GetServerFeatures` | 12 | Answers "matching2 enabled". |
| `GetToken` | 39 | A token derived from the name. |
| `ContextStart` / `ContextStop` | 100 / 106 | The matching context; stopping it leaves the room. |
| `CreateRoom` | 101 | Slots, flags, the password mask, groups and the search attributes. |
| `JoinRoom` | 102 | Leaves another room first if the player was in one. |
| `LeaveRoom` | 103 | |
| `SearchRoom` | 104 | Filtered; see below. |
| `RequestSignalingInfos` | 105 | The other player's address, from the UDP exchange. |
| `SetUserInfo` | 107 | |
| `SetRoomDataInternal` | 108 | Where a game keeps its lobby state, "Ready" included. |
| `SetRoomDataExternal` | 109 | What a searching game sees without joining. |
| `KickoutRoomMember` | 110 | Owner only; anyone else gets `Unauthorized`. |
| `GetWorldInfoList` | 111 | Worlds 1..`GVNET_WORLDS`, plus any world a room is in. |
| `GetRoomDataExternalList` | 112 | |
| `GetUserInfoList` | 113 | |
| `GetRoomMemberDataExternalList` | 114 | |
| `SendRoomMessage` | 115 | Relayed to the room. |

**Accepted and ignored** — answered with success and no effect, because the games send them and
nothing here needs them: `SetClientVersion` (13), `SetAppearOffline` (40), `AddFriend` (8),
`RemoveFriend` (9), `AddBlock` (10), `RemoveBlock` (11).

**Answered "not found"** — the whole scoreboard range, 30 to 38 (`GetBoardInfos` through
`GetScoreGameDataByAccId`). The games ask, get "no such score", and carry on. Nothing is ranked
and nothing is recorded.

Anything else is refused as `Invalid` (2). `--verbose` logs each of these, which is the way to find
out what a new game wants.

### Errors

The codes are the client's own: `0` none, `1` malformed, `2` invalid, `3` invalid input, `14` no
such room, `15` already in the room, `16` room full, `23` unauthorized, `26` not found, `27`
blocked. A failure other than "not found" is logged with the command number.

## Rooms

- Keyed by **(title id, room id)**, so two different games on one server never see each other's
  rooms.
- **Member ids are `slot << 4 | counter`**, slots 1 to 64 — shadnet-p2p's scheme, which the games
  rely on.
- The **owner** is whoever created the room; when the owner leaves, the next member becomes owner.
  Only the owner may kick, and a kicked player is told so with status `0xFF000019`.
- **Flags** carried as the games expect them: full (`0x20000000`), hidden (`0x10000000`), NAT
  restriction (`0x04000000`), and owner on a member (`0x80000000`).
- **Search** filters by world, by lobby when no world is given, and by the games' attribute slots
  (the integer attributes `0x4C`–`0x53`, the search binary attribute `0x54`, and the external and
  internal binary attributes `0x55`–`0x58`). It returns at most **20** rooms, from
  `range_filter_start`, with the total alongside so the game can page.

### Room events

Sent as notifications to the room's members:

| Event | № | Cause |
|---|---|---|
| Member joined | `0x1101` | server (4) |
| Member left | `0x1102` | leave (1) or kickout (2) |
| Kicked out | `0x1103` | kickout (2) |
| Room data internal changed | `0x1106` | server (4) |

A disconnection is a leave: the player is taken out of the room, the event goes to the others, and
everyone still signed in is told that player went offline.

## The UDP address exchange

Each game sends a small packet to `--port + 1`: `ff ff ff ff`, command `0x01`, then its online id
in 16 bytes. The server replies with **the address and port it saw that packet come from**, and
remembers them for that name. `RequestSignalingInfos` then hands that pair to the other player, who
now knows where to send its peer-to-peer traffic.

This is the same idea as STUN's, done in one packet, and it is why the server has to be reachable
over UDP as well as TCP. It also means the address a player is given is the address the *server*
saw — so on a VPN, everyone should reach the server over the VPN, or the addresses handed out will
be the wrong side of it.

## What is deliberately missing

No accounts, no passwords, no friends (everyone is everyone's friend), no scores, no WebAPI, no
trophies, no title storage on the server, no telemetry, and no persistence of any kind: stop the
server and the rooms are gone. The publisher's servers are never contacted.
