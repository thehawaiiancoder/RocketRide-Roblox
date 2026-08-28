# Running this project

## You will need

- A RocketRide account and the local engine
- An OpenAI API key
- [ngrok](https://ngrok.com) with a reserved static domain (free tier gives one)
- [Rojo](https://rojo.space) and Roblox Studio

## 1. Pipeline

1. Copy `npc.pipe` into your RocketRide project folder.
2. Replace `"project_id": "YOUR-PROJECT-ID"` with your own project id.
3. Set the environment variable `ROCKETRIDE_OPENAI_KEY` to your OpenAI key.
   Do not put the key in the file.

## 2. Tunnel

Start the RocketRide engine first, note the port it listens on, then:

```
ngrok http --url=YOUR-DOMAIN.ngrok-free.dev PORT
```

## 3. Roblox

1. In `src/ServerScriptService/OracleServer.server.lua`, set `WEBHOOK_URL`
   to your own domain and project id.
2. In Roblox Studio open **Game Settings > Security** and enable
   **Allow HTTP Requests**.
3. Add a secret named `ROCKETRIDE_PUBLIC_AUTH` containing your RocketRide
   auth key. The code reads it with `HttpService:GetSecret` so the key
   never appears in source.
4. Run `rojo serve` in the project folder and connect from the Rojo plugin.
5. Press Play, walk to the PC, press **E**.

## Demo hotkeys

While seated at the terminal:

| Key | Action |
|---|---|
| 1 | Flicker lights |
| 2 | Spawn shadow |
| 3 | Force turn around |
| 4 | Shake room |
| 5 | Screen glitch |
| 6 | Blackout |
| 7 | Lock the exit |
| 0 | Unlock the exit |
| H | Show / hide the key list |
| J | Hide the debug status line |

Set `DEBUG_HOTKEYS = false` in the server script before publishing.
