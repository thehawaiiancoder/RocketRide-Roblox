# Oracle Terminal

A haunted 1990s desktop inside Roblox, where an AI decides what happens
in the room around you.

You sit down at an abandoned office PC. It boots. An entity called Oracle
speaks to you through a fake Windows-style operating system — and it does
not only talk. RocketRide returns a structured decision on every turn, and
that decision physically changes the room: the lights fail, a figure
appears behind you, the camera is forced to turn around, or the exit stops
working.

This is my first programming project.

## What it does

- A full fake OS rendered in Roblox GUI: draggable windows, taskbar, start
  menu, Notepad, My Computer, Recycle Bin, a playable Minesweeper, and
  hidden easter eggs
- A BIOS boot sequence before the desktop appears
- Oracle offers the player a choice; the choice is sent to RocketRide
- RocketRide replies with JSON containing the line to display, a world
  action to run, and a fear value
- The server executes the action in the 3D world, the client handles
  camera and screen effects

## How it uses RocketRide

The pipeline is deliberately small and stateless:

```
Webhook  ->  Game Director prompt  ->  OpenAI  ->  Response
```

The interesting part is the **contract**. The model is not asked for prose.
It is constrained to return exactly this shape:

```json
{
  "screen_text": "You opened it anyway. They always do.",
  "action": "FLICKER_LIGHTS",
  "fear_delta": 15
}
```

`action` must be one of a closed set of eight values:

| Action | Effect in game |
|---|---|
| `FLICKER_LIGHTS` | The ceiling lamp stutters |
| `SPAWN_SHADOW` | A tall silhouette fades in beside the desk |
| `FORCE_TURN` | The camera turns the player around to face what is behind them |
| `SHAKE_ROOM` | The room trembles |
| `CHANGE_SCREEN` | The monitor tears and the reply resolves out of noise |
| `BLACKOUT` | All light dies for three seconds |
| `LOCK_DOOR` | The player can no longer leave the terminal |
| `NONE` | Nothing happens |

Things worth stealing from this repo:

- **Closed enum + server-side validation.** The Lua server re-checks the
  returned action against a whitelist and falls back to `NONE`. The model
  is never trusted to be well behaved.
- **Double decode with a fallback.** The pipeline answer is a JSON string
  inside a JSON response. If either decode fails, the scene shows a
  neutral in-character line instead of breaking.
- **Escalation rules in the prompt.** Early beats are told to use quiet
  actions with low `fear_delta`; the strong ones are reserved for later.
- **World effects run on the server**, never the client, so one player
  cannot fake them.

## Repo layout

```
npc.pipe                                  RocketRide pipeline
src/ServerScriptService/OracleServer...   Room, effects, pipeline calls
src/StarterPlayerScripts/OracleClient...  Fake OS, camera, screen effects
SETUP.md                                  How to run it
```

## Running it

See [SETUP.md](SETUP.md). Short version: you need your own RocketRide
project, your own ngrok tunnel, and Rojo to sync into Roblox Studio.

The webhook URL and project id in this repo are placeholders. Replace them
with your own — see SETUP.md.

## Notes

Demo hotkeys are left enabled in `OracleServer.server.lua`
(`DEBUG_HOTKEYS = true`) so the scene can be triggered manually while
presenting. Set it to `false` for anything public.
