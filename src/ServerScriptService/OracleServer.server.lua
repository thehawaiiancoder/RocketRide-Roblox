local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

----------------------------------------------------------------
-- ROOM LIGHTING (global)
----------------------------------------------------------------

Lighting.Brightness = 0.5
Lighting.Ambient = Color3.fromRGB(8, 8, 12)
Lighting.OutdoorAmbient = Color3.fromRGB(8, 8, 12)
Lighting.FogColor = Color3.fromRGB(5, 5, 8)
Lighting.FogStart = 10
Lighting.FogEnd = 45

local colorCorrection = Instance.new("ColorCorrectionEffect")
colorCorrection.TintColor = Color3.fromRGB(210, 220, 235)
colorCorrection.Saturation = -0.2
colorCorrection.Parent = Lighting

local bloom = Instance.new("BloomEffect")
bloom.Intensity = 0.6
bloom.Size = 24
bloom.Threshold = 1.2
bloom.Parent = Lighting

----------------------------------------------------------------
-- ROOM: abandoned office
----------------------------------------------------------------

local ROOM_SIZE = Vector3.new(24, 10, 24)
local roomFolder = Instance.new("Folder")
roomFolder.Name = "AbandonedOffice"
roomFolder.Parent = workspace

local function makePart(name, size, cframe, color, material, transparency)
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.Size = size
	part.CFrame = cframe
	part.BrickColor = color
	part.Material = material or Enum.Material.Concrete
	part.Transparency = transparency or 0
	part.Parent = roomFolder
	return part
end

makePart("Floor", Vector3.new(ROOM_SIZE.X, 1, ROOM_SIZE.Z), CFrame.new(0, 0, 0), BrickColor.new("Dark stone grey"), Enum.Material.Concrete)
makePart("Ceiling", Vector3.new(ROOM_SIZE.X, 1, ROOM_SIZE.Z), CFrame.new(0, ROOM_SIZE.Y, 0), BrickColor.new("Really black"), Enum.Material.Concrete)
makePart("WallNorth", Vector3.new(ROOM_SIZE.X, ROOM_SIZE.Y, 1), CFrame.new(0, ROOM_SIZE.Y / 2, ROOM_SIZE.Z / 2), BrickColor.new("Dark stone grey"))
makePart("WallSouth", Vector3.new(ROOM_SIZE.X, ROOM_SIZE.Y, 1), CFrame.new(0, ROOM_SIZE.Y / 2, -ROOM_SIZE.Z / 2), BrickColor.new("Dark stone grey"))
makePart("WallEast", Vector3.new(1, ROOM_SIZE.Y, ROOM_SIZE.Z), CFrame.new(ROOM_SIZE.X / 2, ROOM_SIZE.Y / 2, 0), BrickColor.new("Dark stone grey"))
makePart("WallWest", Vector3.new(1, ROOM_SIZE.Y, ROOM_SIZE.Z), CFrame.new(-ROOM_SIZE.X / 2, ROOM_SIZE.Y / 2, 0), BrickColor.new("Dark stone grey"))

-- Flickering ceiling lamp
local lampHolder = makePart("LampHolder", Vector3.new(2, 0.3, 0.6), CFrame.new(0, ROOM_SIZE.Y - 0.6, 0), BrickColor.new("Really black"), Enum.Material.Metal)
local flickerLight = Instance.new("PointLight")
flickerLight.Brightness = 1.2
flickerLight.Range = 22
flickerLight.Color = Color3.fromRGB(200, 210, 220)
flickerLight.Parent = lampHolder

local BASE_BRIGHTNESS = 1.2

-- Ambient flicker stays out of the way during scripted effects
local effectLock = false

-- The ambient flicker only ever writes Brightness.
-- Scripted effects kill the lamp through Enabled, so the two
-- can never override each other.
task.spawn(function()
	while true do
		task.wait(math.random(2, 6))
		if not effectLock then
			local flickers = math.random(1, 4)
			for _ = 1, flickers do
				if effectLock then break end
				flickerLight.Brightness = 0.1
				task.wait(0.05)
				if effectLock then break end
				flickerLight.Brightness = BASE_BRIGHTNESS
				task.wait(math.random(1, 3) / 20)
			end
			if not effectLock then
				flickerLight.Brightness = BASE_BRIGHTNESS
			end
		end
	end
end)

----------------------------------------------------------------
-- OLD PC ON THE DESK
----------------------------------------------------------------

local pcFolder = Instance.new("Model")
pcFolder.Name = "RetroPC"
pcFolder.Parent = workspace

local DESK_CENTER = Vector3.new(0, 2, -ROOM_SIZE.Z / 2 + 2.2)

local desk = makePart("Desk", Vector3.new(6, 0.3, 2.6), CFrame.new(DESK_CENTER), BrickColor.new("Reddish brown"), Enum.Material.WoodPlanks)
local deskLegL = makePart("DeskLegL", Vector3.new(0.2, 2, 0.2), CFrame.new(DESK_CENTER + Vector3.new(-2.8, -1.15, 1.1)), BrickColor.new("Really black"), Enum.Material.Metal)
local deskLegR = makePart("DeskLegR", Vector3.new(0.2, 2, 0.2), CFrame.new(DESK_CENTER + Vector3.new(2.8, -1.15, 1.1)), BrickColor.new("Really black"), Enum.Material.Metal)
deskLegL.Parent = pcFolder
deskLegR.Parent = pcFolder
desk.Parent = pcFolder

local towerCF = CFrame.new(DESK_CENTER + Vector3.new(-2.2, -1.35, -0.4))
local tower = makePart("Tower", Vector3.new(1.1, 1.9, 1.8), towerCF, BrickColor.new("Cool yellow"), Enum.Material.SmoothPlastic)
tower.Parent = pcFolder

local driveSlot = makePart("DriveSlot", Vector3.new(0.9, 0.15, 0.05), towerCF * CFrame.new(0, 0.5, -0.93), BrickColor.new("Really black"), Enum.Material.SmoothPlastic)
driveSlot.Parent = pcFolder

local powerLightPart = makePart("PowerLight", Vector3.new(0.08, 0.08, 0.05), towerCF * CFrame.new(-0.4, -0.7, -0.93), BrickColor.new("Bright green"), Enum.Material.Neon)
powerLightPart.Parent = pcFolder
local powerGlow = Instance.new("PointLight")
powerGlow.Color = Color3.fromRGB(80, 255, 120)
powerGlow.Range = 3
powerGlow.Brightness = 1
powerGlow.Parent = powerLightPart

local monitorCF = CFrame.new(DESK_CENTER + Vector3.new(0.6, 1.0, -0.2), DESK_CENTER + Vector3.new(0.6, 1.0, -0.2) + Vector3.new(0, 0, 1))

local monitorBack = makePart("MonitorBack", Vector3.new(1.9, 1.7, 1.8), monitorCF * CFrame.new(0, 0, 0.3), BrickColor.new("Cool yellow"), Enum.Material.SmoothPlastic)
monitorBack.Parent = pcFolder

local monitorFront = makePart("MonitorFront", Vector3.new(1.9, 1.7, 0.3), monitorCF * CFrame.new(0, 0, -0.75), BrickColor.new("Cool yellow"), Enum.Material.SmoothPlastic)
monitorFront.Parent = pcFolder

local screen = makePart("Screen", Vector3.new(1.5, 1.2, 0.05), monitorCF * CFrame.new(0, 0, -0.93), BrickColor.new("Really black"), Enum.Material.SmoothPlastic)
screen.Parent = pcFolder

local screenGlow = Instance.new("SurfaceLight")
screenGlow.Face = Enum.NormalId.Front
screenGlow.Color = Color3.fromRGB(80, 160, 200)
screenGlow.Brightness = 0.4
screenGlow.Range = 6
screenGlow.Parent = screen

local keyboard = makePart("Keyboard", Vector3.new(1.6, 0.12, 0.55), CFrame.new(DESK_CENTER + Vector3.new(0.6, 0.22, 0.9)), BrickColor.new("Institutional white"), Enum.Material.SmoothPlastic)
keyboard.Parent = pcFolder

local mouse = makePart("Mouse", Vector3.new(0.35, 0.15, 0.5), CFrame.new(DESK_CENTER + Vector3.new(1.7, 0.24, 0.9)), BrickColor.new("Institutional white"), Enum.Material.SmoothPlastic)
mouse.Parent = pcFolder

local papers = makePart("Papers", Vector3.new(0.8, 0.15, 1), CFrame.new(DESK_CENTER + Vector3.new(-2.4, 0.22, 0.6)), BrickColor.new("Institutional white"), Enum.Material.SmoothPlastic)
papers.Parent = pcFolder

----------------------------------------------------------------
-- SOUND
----------------------------------------------------------------

local hum = Instance.new("Sound")
hum.Name = "ComputerHum"
hum.SoundId = "rbxassetid://97293342453669"
hum.Looped = true
hum.Volume = 0.15
hum.Parent = tower
hum:Play()

----------------------------------------------------------------
-- INTERACTION
----------------------------------------------------------------

local prompt = Instance.new("ProximityPrompt")
prompt.ActionText = "Use Computer"
prompt.ObjectText = "Old PC"
prompt.KeyboardKeyCode = Enum.KeyCode.E
prompt.HoldDuration = 0
prompt.MaxActivationDistance = 8
prompt.ClickablePrompt = false
prompt.Parent = screen

----------------------------------------------------------------
-- REMOTE EVENTS
----------------------------------------------------------------

local function makeEvent(name)
	local ev = Instance.new("RemoteEvent")
	ev.Name = name
	ev.Parent = ReplicatedStorage
	return ev
end

local openUIEvent = makeEvent("OracleOpenUI")
local closeUIEvent = makeEvent("OracleCloseUI")
local askEvent = makeEvent("OracleAsk")
local answerEvent = makeEvent("OracleAnswer")

-- Scene-specific events
local sceneChoiceEvent = makeEvent("OracleSceneChoice")   -- client -> server: player choice
local debugEvent = makeEvent("OracleDebugAction")        -- client -> server: demo hotkey
local sceneEvent = makeEvent("OracleScene")               -- server -> client: text + action
local lockEvent = makeEvent("OracleLock")                 -- server -> client: lock the exit

prompt.Triggered:Connect(function(player)
	prompt.Enabled = false
	openUIEvent:FireClient(player, screen)
end)

closeUIEvent.OnServerEvent:Connect(function(player)
	prompt.Enabled = true
end)

----------------------------------------------------------------
-- CALLING ROCKETRIDE
----------------------------------------------------------------

-- Put your own address here: ngrok domain + project_id from your npc.pipe
-- The auth key does NOT go here. It lives in Secrets;
-- see HttpService:GetSecret below.
local WEBHOOK_URL = "https://YOUR-DOMAIN.ngrok-free.dev/webhook/YOUR-PROJECT-ID/webhook_1"

local function callRocketRide(body)
	local secret = HttpService:GetSecret("ROCKETRIDE_PUBLIC_AUTH")
	local fullUrl = secret:AddPrefix(WEBHOOK_URL .. "?auth=")

	local success, result = pcall(function()
		return HttpService:RequestAsync({
			Url = fullUrl,
			Method = "POST",
			Headers = { ["Content-Type"] = "text/plain" },
			Body = body,
		})
	end)

	if not (success and result and result.Success) then
		return false, "RocketRide is currently unavailable."
	end

	local ok, data = pcall(function()
		return HttpService:JSONDecode(result.Body)
	end)

	if ok and data and data.data and data.data.objects and data.data.objects.body
		and data.data.objects.body.answers and data.data.objects.body.answers[1] then
		return true, data.data.objects.body.answers[1]
	end

	return false, "Something went wrong."
end

----------------------------------------------------------------
-- PARSING THE DIRECTOR REPLY (second JSONDecode + validation)
----------------------------------------------------------------

local VALID_ACTIONS = {
	FLICKER_LIGHTS = true,
	SPAWN_SHADOW = true,
	FORCE_TURN = true,
	SHAKE_ROOM = true,
	LOCK_DOOR = true,
	CHANGE_SCREEN = true,
	BLACKOUT = true,
	NONE = true,
}

-- The model sometimes wraps JSON in code fences; strip them
local function stripCodeFences(text)
	text = string.gsub(text, "^%s*```%a*%s*", "")
	text = string.gsub(text, "%s*```%s*$", "")
	return text
end

local function parseDirectorReply(raw)
	if type(raw) ~= "string" then
		return nil
	end

	local cleaned = stripCodeFences(raw)

	local ok, data = pcall(function()
		return HttpService:JSONDecode(cleaned)
	end)

	if not ok or type(data) ~= "table" then
		return nil
	end

	local screenText = data.screen_text
	if type(screenText) ~= "string" or #screenText == 0 then
		return nil
	end
	if #screenText > 300 then
		screenText = string.sub(screenText, 1, 300)
	end

	local action = data.action
	if type(action) ~= "string" or not VALID_ACTIONS[action] then
		action = "NONE"
	end

	local fear = tonumber(data.fear_delta) or 0
	fear = math.clamp(math.floor(fear), 0, 25)

	return {
		screen_text = screenText,
		action = action,
		fear_delta = fear,
	}
end

----------------------------------------------------------------
-- WORLD ACTIONS
----------------------------------------------------------------

local lockedPlayers = {}

local function actFlickerLights()
	effectLock = true
	for _ = 1, 12 do
		flickerLight.Brightness = 0.05
		task.wait(0.04)
		flickerLight.Brightness = BASE_BRIGHTNESS * 1.4
		task.wait(0.05)
	end
	flickerLight.Brightness = BASE_BRIGHTNESS
	effectLock = false
end

local function actBlackout()
	effectLock = true

	-- Remember global lighting so it can be restored exactly
	local savedBrightness = Lighting.Brightness
	local savedAmbient = Lighting.Ambient
	local savedOutdoor = Lighting.OutdoorAmbient

	-- Enabled rather than Brightness: the ambient flicker only writes
	-- Brightness and so cannot switch the lamp back on by accident
	flickerLight.Enabled = false
	screenGlow.Enabled = false
	powerGlow.Enabled = false

	-- Without this the room stays grey because of global lighting
	Lighting.Brightness = 0
	Lighting.Ambient = Color3.fromRGB(0, 0, 0)
	Lighting.OutdoorAmbient = Color3.fromRGB(0, 0, 0)

	task.wait(3)

	Lighting.Brightness = savedBrightness
	Lighting.Ambient = savedAmbient
	Lighting.OutdoorAmbient = savedOutdoor

	powerGlow.Enabled = true
	screenGlow.Enabled = true
	flickerLight.Enabled = true
	flickerLight.Brightness = BASE_BRIGHTNESS

	effectLock = false
end

-- TWO SHADOW SPOTS. Both at floor level; the figure is built up from the feet.
-- BEHIND: behind the player, seen during FORCE_TURN
-- SIDE:   beside the desk, in frame while the player faces the monitor
-- The second CFrame.new argument turns the figure to face the desk.
local FLOOR_Y = -1.5

local SHADOW_BEHIND = CFrame.new(
	DESK_CENTER + Vector3.new(0, FLOOR_Y, 7.5),
	DESK_CENTER + Vector3.new(0, FLOOR_Y, 0)
)

local SHADOW_SIDE = CFrame.new(
	DESK_CENTER + Vector3.new(-5.5, FLOOR_Y, 2.5),
	DESK_CENTER + Vector3.new(0.6, FLOOR_Y, 0)
)

----------------------------------------------------------------
-- THE SILHOUETTE
-- Around 6.7 studs tall: clearly taller than the player, still fits the room.
-- All offsets are measured from the feet, so it always stands on the floor.
----------------------------------------------------------------

local SHADOW_BUILD = {
	-- name,           size,                            offset from the feet
	{ "LegLeft",      Vector3.new(0.50, 2.80, 0.60),   Vector3.new(-0.32, 1.40, 0) },
	{ "LegRight",     Vector3.new(0.50, 2.80, 0.60),   Vector3.new(0.32, 1.40, 0) },
	{ "Hips",         Vector3.new(1.20, 0.60, 0.75),   Vector3.new(0, 3.05, 0) },
	{ "Torso",        Vector3.new(1.45, 1.90, 0.80),   Vector3.new(0, 4.30, 0) },
	{ "Shoulders",    Vector3.new(2.05, 0.55, 0.80),   Vector3.new(0, 5.35, 0) },
	{ "ArmLeft",      Vector3.new(0.42, 2.40, 0.48),   Vector3.new(-1.00, 4.20, 0) },
	{ "ArmRight",     Vector3.new(0.42, 2.40, 0.48),   Vector3.new(1.00, 4.20, 0) },
	{ "Neck",         Vector3.new(0.38, 0.35, 0.38),   Vector3.new(0, 5.75, 0) },
}

local function createShadow(spot)
	local model = Instance.new("Model")
	model.Name = "Shadow"

	local parts = {}

	local function addPart(name, size, offset, shape)
		local p = Instance.new("Part")
		p.Name = name
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		p.Size = size
		p.CFrame = spot * CFrame.new(offset)
		p.Color = Color3.new(0, 0, 0)
		p.Material = Enum.Material.SmoothPlastic
		p.Transparency = 1
		if shape then
			p.Shape = shape
		end
		p.Parent = model
		table.insert(parts, p)
		return p
	end

	for _, piece in ipairs(SHADOW_BUILD) do
		addPart(piece[1], piece[2], piece[3])
	end

	-- A ball head, otherwise the silhouette reads as a mannequin
	addPart("Head", Vector3.new(1.00, 1.00, 1.00), Vector3.new(0, 6.25, 0), Enum.PartType.Ball)

	-- Eyes: dim, they do not light the room
	local eyes = {}
	for _, dx in ipairs({ -0.22, 0.22 }) do
		local eye = Instance.new("Part")
		eye.Name = "Eye"
		eye.Anchored = true
		eye.CanCollide = false
		eye.CanQuery = false
		eye.CanTouch = false
		eye.CastShadow = false
		eye.Size = Vector3.new(0.10, 0.12, 0.06)
		eye.CFrame = spot * CFrame.new(dx, 6.32, -0.46)
		eye.Color = Color3.fromRGB(150, 25, 20)
		eye.Material = Enum.Material.Neon
		eye.Transparency = 1
		eye.Parent = model
		table.insert(eyes, eye)
	end

	model.Parent = workspace
	return model, parts, eyes
end

local function fadeShadow(parts, from, to, steps, stepWait)
	for i = 1, steps do
		local alpha = from + (to - from) * (i / steps)
		for _, p in ipairs(parts) do
			p.Transparency = alpha
		end
		task.wait(stepWait)
	end
end

local function actSpawnShadow(player, holdTime, spot)
	local shadow, parts, eyes = createShadow(spot or SHADOW_SIDE)

	task.spawn(function()
		-- Fade in
		fadeShadow(parts, 1, 0.03, 18, 0.03)
		fadeShadow(eyes, 1, 0.15, 6, 0.04)

		task.wait(holdTime or 2.5)

		-- Fade out, the eyes go last
		fadeShadow(parts, 0.03, 1, 18, 0.03)
		fadeShadow(eyes, 0.15, 1, 8, 0.03)

		shadow:Destroy()
	end)

	return shadow
end

-- Forced turn: the shadow appears early and lingers, because the
-- client camera takes about a second to swing around.
local function actForceTurn(player)
	-- During a forced turn the shadow must stand BEHIND the player
	actSpawnShadow(player, 4.5, SHADOW_BEHIND)
end

local function actLockDoor(player)
	-- There is no door in the room, so we lock the player at the terminal.
	-- Escape and Shut Down stop working for the rest of the scene.
	lockedPlayers[player.UserId] = true
	lockEvent:FireClient(player, true)
end

local function runAction(player, action)
	if action == "FLICKER_LIGHTS" then
		task.spawn(actFlickerLights)
	elseif action == "BLACKOUT" then
		task.spawn(actBlackout)
	elseif action == "SPAWN_SHADOW" then
		task.spawn(function() actSpawnShadow(player) end)
	elseif action == "FORCE_TURN" then
		task.spawn(function() actForceTurn(player) end)
	elseif action == "LOCK_DOOR" then
		actLockDoor(player)
	end
	-- CHANGE_SCREEN and SHAKE_ROOM run on the client:
	-- the action is sent along with the text
	-- NONE: do nothing
end

----------------------------------------------------------------
-- SCENE STATE
----------------------------------------------------------------

local playerFear = {}
local lastSceneTime = {}

sceneChoiceEvent.OnServerEvent:Connect(function(player, choice)
	if typeof(choice) ~= "string" or #choice == 0 or #choice > 120 then
		return
	end

	-- Spam guard: at most one choice every 3 seconds
	local now = tick()
	local last = lastSceneTime[player.UserId]
	if last and (now - last) < 3 then
		return
	end
	lastSceneTime[player.UserId] = now

	local ok, raw = callRocketRide(choice)

	local result = ok and parseDirectorReply(raw) or nil

	if not result then
		-- Fallback: the scene must not break if the model returns garbage
		warn("[Oracle] could not parse director reply:", tostring(raw))
		sceneEvent:FireClient(player, "The connection stutters. Ask me again.", "NONE")
		return
	end

	playerFear[player.UserId] = (playerFear[player.UserId] or 0) + result.fear_delta
	print(string.format("[Oracle] %s -> %s | action=%s fear=%d",
		player.Name, choice, result.action, playerFear[player.UserId]))

	runAction(player, result.action)
	sceneEvent:FireClient(player, result.screen_text, result.action)
end)

----------------------------------------------------------------
-- FREE-FORM QUESTION (older mode, still functional)
----------------------------------------------------------------

local lastRequestTime = {}

askEvent.OnServerEvent:Connect(function(player, question)
	if typeof(question) ~= "string" then
		return
	end

	if #question == 0 or #question > 300 then
		answerEvent:FireClient(player, false, "Question must be 1-300 characters.")
		return
	end

	local now = tick()
	local last = lastRequestTime[player.UserId]
	if last and (now - last) < 5 then
		answerEvent:FireClient(player, false, "Please wait a moment before asking again.")
		return
	end
	lastRequestTime[player.UserId] = now

	local ok, raw = callRocketRide(question)

	if not ok then
		answerEvent:FireClient(player, false, raw)
		return
	end

	-- The director answers in JSON, so pull screen_text out here too
	local parsed = parseDirectorReply(raw)
	if parsed then
		runAction(player, parsed.action)
		answerEvent:FireClient(player, true, parsed.screen_text)
	else
		answerEvent:FireClient(player, true, raw)
	end
end)

----------------------------------------------------------------
-- BLOCK THE EXIT WHILE THE PLAYER IS LOCKED IN
----------------------------------------------------------------

closeUIEvent.OnServerEvent:Connect(function(player)
	if lockedPlayers[player.UserId] then
		-- Player is locked in: do not restore the ProximityPrompt
		lockEvent:FireClient(player, true)
	end
end)

----------------------------------------------------------------
-- DEMO HOTKEYS
--
-- IMPORTANT: set DEBUG_HOTKEYS = false before any public release.
-- Otherwise any player can trigger the effects themselves.
----------------------------------------------------------------

local DEBUG_HOTKEYS = true

-- Demo lines so a keypress looks like a real Oracle beat
local DEBUG_LINES = {
	FLICKER_LIGHTS = "The light answers to me now.",
	SPAWN_SHADOW = "Something is standing behind you.",
	FORCE_TURN = "Turn around.",
	SHAKE_ROOM = "The room does not like that question.",
	CHANGE_SCREEN = "I am rewriting what you see.",
	BLACKOUT = "Let me hold the dark for a moment.",
	LOCK_DOOR = "The door was closed before you sat down.",
	NONE = "I am still here.",
}

debugEvent.OnServerEvent:Connect(function(player, action)
	if not DEBUG_HOTKEYS then
		return
	end
	if typeof(action) ~= "string" then
		return
	end

	-- Separate command: release the exit lock after demoing LOCK_DOOR
	if action == "UNLOCK" then
		lockedPlayers[player.UserId] = nil
		lockEvent:FireClient(player, false)
		prompt.Enabled = true
		print("[Oracle][debug] exit unlocked for", player.Name)
		return
	end

	if not VALID_ACTIONS[action] then
		return
	end

	print("[Oracle][debug] hotkey:", action)
	runAction(player, action)
	sceneEvent:FireClient(player, DEBUG_LINES[action] or "...", action)
end)

Players.PlayerRemoving:Connect(function(player)
	playerFear[player.UserId] = nil
	lastSceneTime[player.UserId] = nil
	lastRequestTime[player.UserId] = nil
	lockedPlayers[player.UserId] = nil
end)
