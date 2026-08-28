local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

local openUIEvent = ReplicatedStorage:WaitForChild("OracleOpenUI")
local closeUIEvent = ReplicatedStorage:WaitForChild("OracleCloseUI")
local askEvent = ReplicatedStorage:WaitForChild("OracleAsk")
local answerEvent = ReplicatedStorage:WaitForChild("OracleAnswer")
local sceneChoiceEvent = ReplicatedStorage:WaitForChild("OracleSceneChoice")
local sceneEvent = ReplicatedStorage:WaitForChild("OracleScene")
local lockEvent = ReplicatedStorage:WaitForChild("OracleLock")
local debugEvent = ReplicatedStorage:WaitForChild("OracleDebugAction")

-- Player is locked at the terminal (LOCK_DOOR action)
local isLocked = false
lockEvent.OnClientEvent:Connect(function(locked)
	isLocked = locked and true or false
end)

local RED = Color3.fromRGB(249, 56, 34)
local DARK = Color3.fromRGB(23, 19, 16)
local LIGHT = Color3.fromRGB(235, 236, 231)

-- Username shown in the in-game interface.
-- Not taken from the Roblox account; set it here.
local OS_USER_NAME = "LIBA"

local swayConnection = nil
local currentScreenPart = nil
local computerBaseCFrame = nil

-- While a camera effect runs, the sway MUST stay silent,
-- otherwise it resets the camera every frame and the tween is invisible.
local cameraBusy = false

-- Client effects reachable directly from the hotkeys
local clientEffects = {}

-- On-screen status line (assigned inside buildDesktopOS)
local setDebugStatus = function() end

-- Generation counter for the character-by-character text reveal.
-- Every new answer bumps it, so an unfinished reveal of the
-- previous answer stops itself instead of overwriting fresh text.
local scrambleToken = 0

-- Hides the OS so the room becomes visible (assigned in buildDesktopOS).
-- Without this, world effects happen BEHIND the fullscreen desktop
-- and the player simply never sees them.
local revealRoom = function() end

----------------------------------------------------------------
-- CROSSHAIR (created early so the camera functions can control it)
----------------------------------------------------------------

local crosshairGui = Instance.new("ScreenGui")
crosshairGui.Name = "Crosshair"
crosshairGui.IgnoreGuiInset = true
crosshairGui.ResetOnSpawn = false
crosshairGui.Parent = player:WaitForChild("PlayerGui")

local dot = Instance.new("Frame")
dot.Size = UDim2.new(0, 4, 0, 4)
dot.AnchorPoint = Vector2.new(0.5, 0.5)
dot.Position = UDim2.new(0.5, 0, 0.5, 0)
dot.BackgroundColor3 = Color3.new(1, 1, 1)
dot.BackgroundTransparency = 0.2
dot.BorderSizePixel = 0
dot.Parent = crosshairGui
Instance.new("UICorner", dot).CornerRadius = UDim.new(1, 0)

local function setCrosshairVisible(visible)
	dot.Visible = visible
end

----------------------------------------------------------------
-- CHARACTER VISIBILITY
--
-- At the terminal the camera sits exactly where the character stands.
-- Without hiding the body, looking around shows the player their own insides.
-- The engine periodically resets LocalTransparencyModifier,
-- so we reapply it every frame while the player is at the terminal.
----------------------------------------------------------------

local characterHidden = false
local hideEnforcer = nil

local function applyCharacterTransparency()
	local character = player.Character
	if not character then
		return
	end
	local value = characterHidden and 1 or 0
	for _, obj in ipairs(character:GetDescendants()) do
		if obj:IsA("BasePart") or obj:IsA("Decal") then
			obj.LocalTransparencyModifier = value
		end
	end
end

local function setCharacterHidden(hidden)
	characterHidden = hidden
	applyCharacterTransparency()

	if hidden then
		if not hideEnforcer then
			hideEnforcer = RunService.RenderStepped:Connect(applyCharacterTransparency)
		end
	elseif hideEnforcer then
		hideEnforcer:Disconnect()
		hideEnforcer = nil
		applyCharacterTransparency()
	end
end

----------------------------------------------------------------
-- BUILDING THE FAKE OS SHOWN ON THE MONITOR
----------------------------------------------------------------

local function buildDesktopOS()
	----------------------------------------------------------------
	-- PALETTE
	----------------------------------------------------------------

	local C = {
		titleTop = Color3.fromRGB(46, 138, 246),
		titleMid = Color3.fromRGB(16, 96, 220),
		titleBot = Color3.fromRGB(8, 62, 186),
		titleOffTop = Color3.fromRGB(150, 178, 216),
		titleOffMid = Color3.fromRGB(118, 150, 196),
		titleOffBot = Color3.fromRGB(96, 128, 176),
		barTop = Color3.fromRGB(44, 136, 248),
		barBot = Color3.fromRGB(10, 62, 182),
		trayTop = Color3.fromRGB(26, 156, 232),
		trayBot = Color3.fromRGB(14, 104, 198),
		greenTop = Color3.fromRGB(130, 216, 94),
		greenMid = Color3.fromRGB(76, 176, 48),
		greenBot = Color3.fromRGB(34, 122, 20),
		orangeTop = Color3.fromRGB(255, 174, 90),
		orangeBot = Color3.fromRGB(224, 108, 28),
		face = Color3.fromRGB(236, 233, 216),
		faceHi = Color3.fromRGB(252, 251, 246),
		field = Color3.fromRGB(255, 255, 255),
		border = Color3.fromRGB(128, 130, 120),
		borderDark = Color3.fromRGB(82, 84, 76),
		skyTop = Color3.fromRGB(98, 174, 246),
		skyBot = Color3.fromRGB(22, 98, 194),
		hillLight = Color3.fromRGB(130, 208, 76),
		hillMid = Color3.fromRGB(92, 178, 56),
		hillDark = Color3.fromRGB(54, 142, 38),
		selBlue = Color3.fromRGB(49, 106, 197),
		text = Color3.fromRGB(20, 20, 20),
	}

	----------------------------------------------------------------
	-- HELPERS
	----------------------------------------------------------------

	local function newFrame(parent, size, pos, color, z)
		local f = Instance.new("Frame")
		f.Size = size
		f.Position = pos or UDim2.new(0, 0, 0, 0)
		f.BackgroundColor3 = color or C.face
		f.BorderSizePixel = 0
		if z then f.ZIndex = z end
		f.Parent = parent
		return f
	end

	local function corner(inst, r)
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(0, r or 6)
		c.Parent = inst
		return c
	end

	local function stroke(inst, color, thickness, transparency)
		local s = Instance.new("UIStroke")
		s.Color = color or C.border
		s.Thickness = thickness or 1
		s.Transparency = transparency or 0
		s.Parent = inst
		return s
	end

	local function gradient(inst, colors, rotation)
		local g = Instance.new("UIGradient")
		local kp = {}
		for i, col in ipairs(colors) do
			table.insert(kp, ColorSequenceKeypoint.new((i - 1) / (#colors - 1), col))
		end
		g.Color = ColorSequence.new(kp)
		g.Rotation = rotation or 90
		g.Parent = inst
		return g
	end

	-- Glossy highlight over an element (top half is lighter)
	local function gloss(parent, heightScale, strength)
		local g = newFrame(parent, UDim2.new(1, 0, heightScale or 0.5, 0), UDim2.new(0, 0, 0, 0), Color3.new(1, 1, 1))
		g.BackgroundTransparency = 0
		local grad = Instance.new("UIGradient")
		grad.Rotation = 90
		grad.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, strength or 0.62),
			NumberSequenceKeypoint.new(1, 1),
		})
		grad.Parent = g
		return g
	end

	-- Soft shadow built from nested translucent frames (no image assets)
	local function dropShadow(target, layers, spread)
		layers = layers or 5
		spread = spread or 3
		for i = layers, 1, -1 do
			local sh = Instance.new("Frame")
			sh.Size = UDim2.new(1, i * spread * 2, 1, i * spread * 2)
			sh.Position = UDim2.new(0, -i * spread, 0, -i * spread + 2)
			sh.BackgroundColor3 = Color3.new(0, 0, 0)
			sh.BackgroundTransparency = 1 - (0.05 / i)
			sh.BorderSizePixel = 0
			sh.ZIndex = 0
			sh.Parent = target
			corner(sh, 10)
		end
	end

	-- Sunken field, like an XP text box
	local function sunken(inst)
		stroke(inst, C.borderDark, 1, 0.25)
		local inner = Instance.new("Frame")
		inner.Size = UDim2.new(1, -2, 1, -2)
		inner.Position = UDim2.new(0, 1, 0, 1)
		inner.BackgroundTransparency = 1
		inner.Parent = inst
		stroke(inner, Color3.new(1, 1, 1), 1, 0.55)
	end

	local function label(parent, size, pos, text, textSize, font, color, align)
		local l = Instance.new("TextLabel")
		l.Size = size
		l.Position = pos
		l.BackgroundTransparency = 1
		l.Text = text
		l.TextSize = textSize or 14
		l.Font = font or Enum.Font.Gotham
		l.TextColor3 = color or C.text
		l.TextXAlignment = align or Enum.TextXAlignment.Left
		l.TextYAlignment = Enum.TextYAlignment.Top
		l.Parent = parent
		return l
	end

	local function shadowLabel(parent, size, pos, text, textSize, font)
		local holder = Instance.new("Frame")
		holder.Size = size
		holder.Position = pos
		holder.BackgroundTransparency = 1
		holder.Parent = parent

		local back = label(holder, UDim2.new(1, 0, 1, 0), UDim2.new(0, 1, 0, 1), text, textSize, font, Color3.new(0, 0, 0))
		back.TextTransparency = 0.55
		back.TextYAlignment = Enum.TextYAlignment.Center

		local front = label(holder, UDim2.new(1, 0, 1, 0), UDim2.new(0, 0, 0, 0), text, textSize, font, Color3.new(1, 1, 1))
		front.TextYAlignment = Enum.TextYAlignment.Center

		return holder, front
	end

	-- Raised XP-style button
	local function xpButton(parent, size, pos, text, colors, textSize)
		local btn = Instance.new("TextButton")
		btn.Size = size
		btn.Position = pos
		btn.BackgroundColor3 = colors[1]
		btn.BorderSizePixel = 0
		btn.Text = ""
		btn.AutoButtonColor = false
		btn.Parent = parent
		corner(btn, 5)
		gradient(btn, colors, 90)
		stroke(btn, Color3.new(1, 1, 1), 1, 0.55)
		gloss(btn, 0.45, 0.7)

		local txt = label(btn, UDim2.new(1, 0, 1, 0), UDim2.new(0, 0, 0, 0), text, textSize or 15,
			Enum.Font.GothamBold, Color3.new(1, 1, 1), Enum.TextXAlignment.Center)
		txt.TextYAlignment = Enum.TextYAlignment.Center

		btn.MouseEnter:Connect(function()
			btn.BackgroundTransparency = 0.1
		end)
		btn.MouseLeave:Connect(function()
			btn.BackgroundTransparency = 0
		end)

		return btn, txt
	end

	-- Grey button, like the ones in XP dialogs
	local function greyButton(parent, size, pos, text)
		local btn = Instance.new("TextButton")
		btn.Size = size
		btn.Position = pos
		btn.BackgroundColor3 = C.face
		btn.BorderSizePixel = 0
		btn.Text = text
		btn.TextSize = 14
		btn.Font = Enum.Font.Gotham
		btn.TextColor3 = C.text
		btn.AutoButtonColor = false
		btn.Parent = parent
		corner(btn, 4)
		gradient(btn, { C.faceHi, C.face }, 90)
		stroke(btn, C.border, 1, 0)

		btn.MouseEnter:Connect(function()
			btn.BackgroundColor3 = Color3.fromRGB(250, 248, 236)
		end)
		btn.MouseLeave:Connect(function()
			btn.BackgroundColor3 = C.face
		end)
		return btn
	end

	-- Small "RR" logo icon
	local function rrIcon(parent, size, pos, textSize)
		local box = newFrame(parent, size, pos, Color3.fromRGB(235, 236, 231))
		corner(box, 5)
		gradient(box, { Color3.new(1, 1, 1), Color3.fromRGB(214, 217, 210) }, 90)
		stroke(box, Color3.fromRGB(190, 192, 186), 1, 0)
		local l = label(box, UDim2.new(1, 0, 1, 0), UDim2.new(0, 0, 0, 0), "", textSize or 12,
			Enum.Font.GothamBold, C.text, Enum.TextXAlignment.Center)
		l.RichText = true
		l.Text = '<font color="rgb(23,19,16)">R</font><font color="rgb(249,56,34)">R</font>'
		l.TextYAlignment = Enum.TextYAlignment.Center
		return box
	end

	-- Simple coloured glyph icon for the other programs
	local function glyphIcon(parent, size, pos, symbol, bgColor, textSize)
		local box = newFrame(parent, size, pos, bgColor)
		corner(box, 5)
		gradient(box, { bgColor:Lerp(Color3.new(1, 1, 1), 0.35), bgColor }, 90)
		stroke(box, Color3.new(1, 1, 1), 1, 0.5)
		local l = label(box, UDim2.new(1, 0, 1, 0), UDim2.new(0, 0, 0, 0), symbol, textSize or 20,
			Enum.Font.GothamBold, Color3.new(1, 1, 1), Enum.TextXAlignment.Center)
		l.TextYAlignment = Enum.TextYAlignment.Center
		return box
	end

	----------------------------------------------------------------
	-- ROOT: desktop, sky, hills
	----------------------------------------------------------------

	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "RocketRideOS"
	screenGui.IgnoreGuiInset = true
	screenGui.DisplayOrder = 10
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screenGui.ResetOnSpawn = false
	screenGui.Parent = player:WaitForChild("PlayerGui")

	local desktop = newFrame(screenGui, UDim2.new(1, 0, 1, 0), UDim2.new(0, 0, 0, 0), C.skyTop, 1)
	desktop.ClipsDescendants = true
	gradient(desktop, { C.skyTop, C.skyBot }, 90)

	-- Clouds
	local function cloud(x, y, scale)
		local holder = newFrame(desktop, UDim2.new(0, 110 * scale, 0, 30 * scale), UDim2.new(x, 0, y, 0), Color3.new(1, 1, 1), 1)
		holder.BackgroundTransparency = 0.12
		corner(holder, 100)
		local p1 = newFrame(holder, UDim2.new(0, 52 * scale, 0, 40 * scale), UDim2.new(0, 16 * scale, 0, -18 * scale), Color3.new(1, 1, 1))
		p1.BackgroundTransparency = 0.12
		corner(p1, 100)
		local p2 = newFrame(holder, UDim2.new(0, 38 * scale, 0, 30 * scale), UDim2.new(0, 56 * scale, 0, -12 * scale), Color3.new(1, 1, 1))
		p2.BackgroundTransparency = 0.12
		corner(p2, 100)
	end
	cloud(0.14, 0.09, 1.0)
	cloud(0.52, 0.05, 1.35)
	cloud(0.78, 0.15, 0.75)

	-- Hills: real circles, mostly pushed below the bottom edge
	local function hill(widthPx, xScale, yScale, color)
		local h = newFrame(desktop, UDim2.new(0, widthPx, 0, widthPx), UDim2.new(xScale, 0, yScale, 0), color, 1)
		corner(h, math.floor(widthPx / 2))
		return h
	end
	hill(1500, 0.42, 0.66, C.hillDark)
	hill(1900, -0.28, 0.72, C.hillMid)
	local frontHill = hill(2400, 0.05, 0.80, C.hillLight)
	gradient(frontHill, { C.hillLight, C.hillDark }, 90)

	----------------------------------------------------------------
	-- TASKBAR (created early: windows attach their buttons to it)
	----------------------------------------------------------------

	local TASKBAR_H = 40

	local taskbar = newFrame(desktop, UDim2.new(1, 0, 0, TASKBAR_H), UDim2.new(0, 0, 1, -TASKBAR_H), C.barTop, 1000)
	gradient(taskbar, { C.barTop, C.barBot }, 90)
	local tbGloss = newFrame(taskbar, UDim2.new(1, 0, 0, 4), UDim2.new(0, 0, 0, 0), Color3.new(1, 1, 1))
	tbGloss.BackgroundTransparency = 0.45

	-- Start button
	local startBtn = Instance.new("TextButton")
	startBtn.Size = UDim2.new(0, 104, 0, 32)
	startBtn.Position = UDim2.new(0, 3, 0, 4)
	startBtn.BackgroundColor3 = C.greenTop
	startBtn.BorderSizePixel = 0
	startBtn.Text = ""
	startBtn.AutoButtonColor = false
	startBtn.Parent = taskbar
	corner(startBtn, 15)
	gradient(startBtn, { C.greenTop, C.greenMid, C.greenBot }, 90)
	stroke(startBtn, Color3.new(1, 1, 1), 1, 0.5)
	gloss(startBtn, 0.5, 0.65)

	-- Four-square flag
	local flag = newFrame(startBtn, UDim2.new(0, 17, 0, 17), UDim2.new(0, 11, 0.5, -8), Color3.new(1, 1, 1))
	flag.BackgroundTransparency = 1
	local flagColors = {
		Color3.fromRGB(248, 96, 66), Color3.fromRGB(142, 212, 82),
		Color3.fromRGB(78, 168, 250), Color3.fromRGB(255, 208, 58),
	}
	local flagPos = {
		UDim2.new(0, 0, 0, 0), UDim2.new(0, 9, 0, 0),
		UDim2.new(0, 0, 0, 9), UDim2.new(0, 9, 0, 9),
	}
	for i = 1, 4 do
		local sq = newFrame(flag, UDim2.new(0, 7, 0, 7), flagPos[i], flagColors[i])
		corner(sq, 1)
	end

	local _, startText = shadowLabel(startBtn, UDim2.new(0, 60, 1, 0), UDim2.new(0, 34, 0, 0), "start", 17, Enum.Font.GothamBold)

	startBtn.MouseEnter:Connect(function() startBtn.BackgroundTransparency = 0.12 end)
	startBtn.MouseLeave:Connect(function() startBtn.BackgroundTransparency = 0 end)

	-- Area holding buttons of open windows
	local taskButtons = newFrame(taskbar, UDim2.new(1, -350, 1, -8), UDim2.new(0, 116, 0, 4), Color3.new(1, 1, 1))
	taskButtons.BackgroundTransparency = 1
	local tbLayout = Instance.new("UIListLayout")
	tbLayout.FillDirection = Enum.FillDirection.Horizontal
	tbLayout.Padding = UDim.new(0, 4)
	tbLayout.SortOrder = Enum.SortOrder.LayoutOrder
	tbLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	tbLayout.Parent = taskButtons

	-- System tray (right side)
	local tray = newFrame(taskbar, UDim2.new(0, 130, 1, -8), UDim2.new(1, -134, 0, 4), C.trayTop)
	gradient(tray, { C.trayTop, C.trayBot }, 90)
	corner(tray, 3)
	local trayDiv = newFrame(tray, UDim2.new(0, 1, 1, -8), UDim2.new(0, 0, 0, 4), Color3.fromRGB(10, 70, 160))
	local trayDivHi = newFrame(tray, UDim2.new(0, 1, 1, -8), UDim2.new(0, 1, 0, 4), Color3.new(1, 1, 1))
	trayDivHi.BackgroundTransparency = 0.55

	-- Tray icons
	local trayNet = newFrame(tray, UDim2.new(0, 12, 0, 12), UDim2.new(0, 14, 0.5, -6), Color3.fromRGB(190, 220, 255))
	corner(trayNet, 2)
	local trayVol = newFrame(tray, UDim2.new(0, 12, 0, 12), UDim2.new(0, 34, 0.5, -6), Color3.fromRGB(220, 235, 255))
	corner(trayVol, 2)

	local clockBtn = Instance.new("TextButton")
	clockBtn.Size = UDim2.new(0, 66, 1, 0)
	clockBtn.Position = UDim2.new(1, -70, 0, 0)
	clockBtn.BackgroundTransparency = 1
	clockBtn.Text = os.date("%H:%M")
	clockBtn.TextSize = 14
	clockBtn.Font = Enum.Font.Gotham
	clockBtn.TextColor3 = Color3.new(1, 1, 1)
	clockBtn.AutoButtonColor = false
	clockBtn.Parent = tray

	task.spawn(function()
		while clockBtn.Parent do
			clockBtn.Text = os.date("%H:%M")
			task.wait(10)
		end
	end)

	----------------------------------------------------------------
	-- WINDOW MANAGER
	----------------------------------------------------------------

	local topZ = 20
	local allWindows = {}
	local activeWindow = nil

	local function setWindowActive(win, isActive)
		local colors = isActive and { C.titleTop, C.titleMid, C.titleBot }
			or { C.titleOffTop, C.titleOffMid, C.titleOffBot }
		win.titleGradient.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, colors[1]),
			ColorSequenceKeypoint.new(0.5, colors[2]),
			ColorSequenceKeypoint.new(1, colors[3]),
		})
		win.titleMask.BackgroundColor3 = colors[3]
		if win.taskBtn then
			win.taskBtn.BackgroundTransparency = isActive and 0 or 0.35
		end
	end

	local function focusWindow(win)
		topZ = topZ + 1
		if topZ > 900 then topZ = 21 end
		win.root.ZIndex = topZ
		for _, w in ipairs(allWindows) do
			setWindowActive(w, w == win)
		end
		activeWindow = win
	end

	-- createWindow: returns a window object; put content into .body
	local function createWindow(opts)
		local win = {}
		win.title = opts.title or "Window"

		local root = newFrame(desktop, UDim2.new(0, opts.width or 480, 0, opts.height or 340),
			UDim2.new(0.5, -(opts.width or 480) / 2 + (opts.offsetX or 0), 0.5, -(opts.height or 340) / 2 + (opts.offsetY or 0)),
			C.face, 20)
		root.Visible = false
		corner(root, 9)
		stroke(root, Color3.fromRGB(6, 50, 140), 2, 0)
		dropShadow(root, 5, 3)
		win.root = root

		-- Title bar
		local titleBar = newFrame(root, UDim2.new(1, 0, 0, 34), UDim2.new(0, 0, 0, 0), C.titleTop, 2)
		corner(titleBar, 9)
		win.titleGradient = gradient(titleBar, { C.titleTop, C.titleMid, C.titleBot }, 90)
		win.titleMask = newFrame(titleBar, UDim2.new(1, 0, 0, 12), UDim2.new(0, 0, 1, -12), C.titleBot)
		gloss(titleBar, 0.5, 0.68)
		win.titleBar = titleBar

		if opts.iconSymbol then
			glyphIcon(titleBar, UDim2.new(0, 19, 0, 19), UDim2.new(0, 9, 0.5, -9), opts.iconSymbol, opts.iconColor or C.selBlue, 11)
		else
			rrIcon(titleBar, UDim2.new(0, 19, 0, 19), UDim2.new(0, 9, 0.5, -9), 10)
		end

		shadowLabel(titleBar, UDim2.new(0, 300, 1, 0), UDim2.new(0, 36, 0, 0), win.title, 15, Enum.Font.GothamBold)

		-- Window buttons
		local function titleButton(offset, colors, symbol, symbolSize)
			local b = Instance.new("TextButton")
			b.Size = UDim2.new(0, 24, 0, 21)
			b.Position = UDim2.new(1, offset, 0, 6)
			b.BackgroundColor3 = colors[1]
			b.BorderSizePixel = 0
			b.Text = symbol
			b.TextSize = symbolSize or 13
			b.Font = Enum.Font.GothamBold
			b.TextColor3 = Color3.new(1, 1, 1)
			b.AutoButtonColor = false
			b.Parent = titleBar
			corner(b, 5)
			gradient(b, colors, 90)
			stroke(b, Color3.new(1, 1, 1), 1, 0.45)
			b.MouseEnter:Connect(function() b.BackgroundTransparency = 0.15 end)
			b.MouseLeave:Connect(function() b.BackgroundTransparency = 0 end)
			return b
		end

		local closeB = titleButton(-30, { Color3.fromRGB(255, 132, 110), Color3.fromRGB(202, 46, 22) }, "X", 12)
		local maxB = titleButton(-58, { Color3.fromRGB(126, 194, 252), Color3.fromRGB(46, 124, 208) }, "[ ]", 9)
		local minB = titleButton(-86, { Color3.fromRGB(126, 194, 252), Color3.fromRGB(46, 124, 208) }, "_", 14)

		-- Window body
		local body = newFrame(root, UDim2.new(1, -12, 1, -46), UDim2.new(0, 6, 0, 40), C.face, 2)
		body.BackgroundTransparency = 1
		win.body = body

		-- Taskbar button
		local taskBtn = Instance.new("TextButton")
		taskBtn.Size = UDim2.new(0, 150, 1, 0)
		taskBtn.BackgroundColor3 = Color3.fromRGB(58, 148, 250)
		taskBtn.BorderSizePixel = 0
		taskBtn.Text = ""
		taskBtn.AutoButtonColor = false
		taskBtn.Visible = false
		taskBtn.Parent = taskButtons
		corner(taskBtn, 4)
		gradient(taskBtn, { Color3.fromRGB(76, 162, 252), Color3.fromRGB(30, 106, 220) }, 90)
		stroke(taskBtn, Color3.new(1, 1, 1), 1, 0.65)
		win.taskBtn = taskBtn

		if opts.iconSymbol then
			glyphIcon(taskBtn, UDim2.new(0, 16, 0, 16), UDim2.new(0, 7, 0.5, -8), opts.iconSymbol, opts.iconColor or C.selBlue, 9)
		else
			rrIcon(taskBtn, UDim2.new(0, 16, 0, 16), UDim2.new(0, 7, 0.5, -8), 9)
		end
		local tbText = label(taskBtn, UDim2.new(1, -32, 1, 0), UDim2.new(0, 28, 0, 0), win.title, 13,
			Enum.Font.Gotham, Color3.new(1, 1, 1))
		tbText.TextYAlignment = Enum.TextYAlignment.Center
		tbText.TextTruncate = Enum.TextTruncate.AtEnd

		----------------------------------------------------------------
		-- Behaviour
		----------------------------------------------------------------

		function win.show()
			root.Visible = true
			taskBtn.Visible = true
			focusWindow(win)
		end

		function win.hide()
			root.Visible = false
		end

		function win.close()
			root.Visible = false
			taskBtn.Visible = false
		end

		closeB.MouseButton1Click:Connect(function() win.close() end)
		minB.MouseButton1Click:Connect(function() win.hide() end)

		local maximized = false
		local restoreSize, restorePos
		maxB.MouseButton1Click:Connect(function()
			if maximized then
				root.Size = restoreSize
				root.Position = restorePos
				maximized = false
			else
				restoreSize = root.Size
				restorePos = root.Position
				root.Size = UDim2.new(1, -8, 1, -TASKBAR_H - 8)
				root.Position = UDim2.new(0, 4, 0, 4)
				maximized = true
			end
		end)

		taskBtn.MouseButton1Click:Connect(function()
			if root.Visible and activeWindow == win then
				win.hide()
			else
				win.show()
			end
		end)

		root.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 then
				focusWindow(win)
			end
		end)

		-- Dragging by the title bar
		local dragging = false
		local dragStart, startPos

		titleBar.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 and not maximized then
				dragging = true
				dragStart = input.Position
				startPos = root.Position
				focusWindow(win)
			end
		end)

		titleBar.InputEnded:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 then
				dragging = false
			end
		end)

		local dragConn
		dragConn = UserInputService.InputChanged:Connect(function(input)
			if not screenGui.Parent then
				dragConn:Disconnect()
				return
			end
			if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
				local delta = input.Position - dragStart
				root.Position = UDim2.new(
					startPos.X.Scale, startPos.X.Offset + delta.X,
					startPos.Y.Scale, startPos.Y.Offset + delta.Y
				)
			end
		end)

		UserInputService.InputEnded:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 then
				dragging = false
			end
		end)

		table.insert(allWindows, win)
		setWindowActive(win, false)
		return win
	end

	----------------------------------------------------------------
	-- DIALOG WINDOWS
	----------------------------------------------------------------

	local function showDialog(titleText, messageText, symbol, symbolColor)
		local dlg = newFrame(desktop, UDim2.new(0, 380, 0, 170), UDim2.new(0.5, -190, 0.5, -85), C.face, 2000)
		corner(dlg, 9)
		stroke(dlg, Color3.fromRGB(6, 50, 140), 2, 0)
		dropShadow(dlg, 5, 3)

		local bar = newFrame(dlg, UDim2.new(1, 0, 0, 32), UDim2.new(0, 0, 0, 0), C.titleTop, 2)
		corner(bar, 9)
		gradient(bar, { C.titleTop, C.titleMid, C.titleBot }, 90)
		newFrame(bar, UDim2.new(1, 0, 0, 12), UDim2.new(0, 0, 1, -12), C.titleBot)
		gloss(bar, 0.5, 0.68)
		shadowLabel(bar, UDim2.new(0, 280, 1, 0), UDim2.new(0, 12, 0, 0), titleText, 14, Enum.Font.GothamBold)

		glyphIcon(dlg, UDim2.new(0, 40, 0, 40), UDim2.new(0, 22, 0, 52), symbol or "!", symbolColor or Color3.fromRGB(230, 170, 30), 24)

		local msg = label(dlg, UDim2.new(1, -90, 0, 56), UDim2.new(0, 76, 0, 50), messageText, 14, Enum.Font.Gotham, C.text)
		msg.TextWrapped = true

		local ok = greyButton(dlg, UDim2.new(0, 88, 0, 30), UDim2.new(0.5, -44, 1, -42), "OK")
		ok.MouseButton1Click:Connect(function()
			dlg:Destroy()
		end)
		return dlg
	end

	----------------------------------------------------------------
	-- ORACLE CHOICE DIALOG
	----------------------------------------------------------------

	local function showOracleChoice(titleText, messageText, options)
		local W = 440
		local dlg = newFrame(desktop, UDim2.new(0, W, 0, 200), UDim2.new(0.5, -W / 2, 0.5, -100), C.face, 2500)
		corner(dlg, 9)
		stroke(dlg, Color3.fromRGB(6, 50, 140), 2, 0)
		dropShadow(dlg, 5, 3)

		local bar = newFrame(dlg, UDim2.new(1, 0, 0, 32), UDim2.new(0, 0, 0, 0), C.titleTop, 2)
		corner(bar, 9)
		gradient(bar, { C.titleTop, C.titleMid, C.titleBot }, 90)
		newFrame(bar, UDim2.new(1, 0, 0, 12), UDim2.new(0, 0, 1, -12), C.titleBot)
		gloss(bar, 0.5, 0.68)
		shadowLabel(bar, UDim2.new(0, 300, 1, 0), UDim2.new(0, 12, 0, 0), titleText, 14, Enum.Font.GothamBold)

		rrIcon(dlg, UDim2.new(0, 42, 0, 42), UDim2.new(0, 22, 0, 54), 17)

		local msg = label(dlg, UDim2.new(1, -96, 0, 78), UDim2.new(0, 78, 0, 48), messageText, 15,
			Enum.Font.Code, C.text)
		msg.TextWrapped = true

		local count = #options
		local btnW = 160
		local gap = 14
		local totalW = count * btnW + (count - 1) * gap
		local startX = (W - totalW) / 2

		for i, opt in ipairs(options) do
			local btn = greyButton(dlg, UDim2.new(0, btnW, 0, 32),
				UDim2.new(0, startX + (i - 1) * (btnW + gap), 1, -46), opt.label)
			btn.MouseButton1Click:Connect(function()
				dlg:Destroy()
				opt.onClick()
			end)
		end

		return dlg
	end

	----------------------------------------------------------------
	-- EASTER EGG: BLUE SCREEN OF DEATH
	----------------------------------------------------------------

	local function showBSOD()
		local bsod = newFrame(desktop, UDim2.new(1, 0, 1, 0), UDim2.new(0, 0, 0, 0), Color3.fromRGB(0, 0, 170), 3000)

		local txt = label(bsod, UDim2.new(1, -80, 1, -80), UDim2.new(0, 40, 0, 60), "", 14,
			Enum.Font.Code, Color3.new(1, 1, 1))
		txt.TextWrapped = true

		local content = table.concat({
			"A problem has been detected and RocketRide OS has been shut",
			"down to prevent damage to your machine.",
			"",
			"ORACLE_ANSWERED_TOO_HONESTLY",
			"",
			"If this is the first time you have seen this stop error screen,",
			"restart your computer. If this screen appears again, do not",
			"ask the same question twice.",
			"",
			"Technical information:",
			"",
			"*** STOP: 0x000000RR (0xC0FFEE00, 0x00000001, 0x1994BEEF)",
			"",
			"Beginning dump of physical memory...",
		}, "\n")

		task.spawn(function()
			for i = 1, #content do
				if not bsod.Parent then return end
				txt.Text = string.sub(content, 1, i)
				task.wait(0.006)
			end
			task.wait(2.5)
			if bsod.Parent then
				bsod:Destroy()
			end
		end)
	end

	----------------------------------------------------------------
	-- APP: ROCKETRIDE.EXE (the main one: asking the Oracle)
	----------------------------------------------------------------

	local rocketWin = createWindow({ title = "RocketRide.exe", width = 560, height = 380 })

	do
		local b = rocketWin.body

		local accent = newFrame(b, UDim2.new(0, 4, 0, 176), UDim2.new(0, 14, 0, 8), RED)
		corner(accent, 2)

		local brand = label(b, UDim2.new(0, 240, 0, 26), UDim2.new(0, 30, 0, 4), "", 21,
			Enum.Font.GothamBold, C.text)
		brand.RichText = true
		brand.Text = '<font color="rgb(23,19,16)">Rocket</font><font color="rgb(249,56,34)">Ride</font>'

		local answerPanel = newFrame(b, UDim2.new(1, -44, 0, 146), UDim2.new(0, 30, 0, 34), C.field)
		corner(answerPanel, 4)
		sunken(answerPanel)

		local answerScroll = Instance.new("ScrollingFrame")
		answerScroll.Size = UDim2.new(1, -14, 1, -12)
		answerScroll.Position = UDim2.new(0, 8, 0, 6)
		answerScroll.BackgroundTransparency = 1
		answerScroll.BorderSizePixel = 0
		answerScroll.ScrollBarThickness = 6
		answerScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
		answerScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
		answerScroll.Parent = answerPanel

		local answerLabel = label(answerScroll, UDim2.new(1, -8, 0, 0), UDim2.new(0, 0, 0, 0),
			"Ask RocketRide a question...", 15, Enum.Font.Code, DARK)
		answerLabel.TextWrapped = true
		answerLabel.AutomaticSize = Enum.AutomaticSize.Y

		local inputPanel = newFrame(b, UDim2.new(1, -28, 0, 44), UDim2.new(0, 14, 1, -52), C.field)
		corner(inputPanel, 5)
		sunken(inputPanel)

		local textBox = Instance.new("TextBox")
		textBox.Size = UDim2.new(1, -114, 1, -8)
		textBox.Position = UDim2.new(0, 10, 0, 4)
		textBox.BackgroundTransparency = 1
		textBox.TextColor3 = DARK
		textBox.PlaceholderColor3 = Color3.fromRGB(145, 145, 145)
		textBox.PlaceholderText = "Your question..."
		textBox.Text = ""
		textBox.Font = Enum.Font.Code
		textBox.TextSize = 15
		textBox.TextXAlignment = Enum.TextXAlignment.Left
		textBox.ClearTextOnFocus = false
		textBox.Parent = inputPanel

		local askBtn = xpButton(inputPanel, UDim2.new(0, 92, 0, 34), UDim2.new(1, -100, 0, 5), "Ask",
			{ C.greenTop, C.greenMid, C.greenBot }, 15)

		local isWaiting = false

		local function sendQuestion()
			if isWaiting then return end
			local q = textBox.Text
			if #q == 0 then return end
			if #q > 300 then
				answerLabel.Text = "Question is too long (max 300 characters)."
				return
			end
			isWaiting = true
			scrambleToken = scrambleToken + 1
			askBtn:FindFirstChildWhichIsA("TextLabel").Text = "..."
			answerLabel.Text = "Thinking..."
			askEvent:FireServer(q)
		end

		askBtn.MouseButton1Click:Connect(sendQuestion)
		textBox.FocusLost:Connect(function(enterPressed)
			if enterPressed then sendQuestion() end
		end)

		answerEvent.OnClientEvent:Connect(function(success, answer)
			isWaiting = false
			-- Cancel the previous reveal, otherwise it overwrites this answer
			scrambleToken = scrambleToken + 1
			local lbl = askBtn:FindFirstChildWhichIsA("TextLabel")
			if lbl then lbl.Text = "Ask" end
			answerLabel.Text = answer
		end)

		-- Let the scene write into the same field
		function rocketWin.setText(newText)
			answerLabel.Text = newText
		end
	end

	----------------------------------------------------------------
	-- APP: NOTEPAD
	----------------------------------------------------------------

	local notepadWin = createWindow({
		title = "Notepad", width = 460, height = 330,
		offsetX = 40, offsetY = 30,
		iconSymbol = "T", iconColor = Color3.fromRGB(240, 240, 240),
	})

	local notepadBox
	do
		local b = notepadWin.body

		-- Fake menu bar
		local menuBar = newFrame(b, UDim2.new(1, 0, 0, 22), UDim2.new(0, 0, 0, 0), C.face)
		local menuItems = { "File", "Edit", "Format", "Help" }
		local x = 4
		for _, name in ipairs(menuItems) do
			local mi = label(menuBar, UDim2.new(0, 56, 1, 0), UDim2.new(0, x, 0, 0), name, 13, Enum.Font.Gotham, C.text)
			mi.TextYAlignment = Enum.TextYAlignment.Center
			x = x + 52
		end

		local editPanel = newFrame(b, UDim2.new(1, 0, 1, -26), UDim2.new(0, 0, 0, 26), C.field)
		corner(editPanel, 3)
		sunken(editPanel)

		notepadBox = Instance.new("TextBox")
		notepadBox.Size = UDim2.new(1, -12, 1, -10)
		notepadBox.Position = UDim2.new(0, 6, 0, 5)
		notepadBox.BackgroundTransparency = 1
		notepadBox.MultiLine = true
		notepadBox.ClearTextOnFocus = false
		notepadBox.TextXAlignment = Enum.TextXAlignment.Left
		notepadBox.TextYAlignment = Enum.TextYAlignment.Top
		notepadBox.TextWrapped = true
		notepadBox.Font = Enum.Font.Code
		notepadBox.TextSize = 14
		notepadBox.TextColor3 = C.text
		notepadBox.Text = ""
		notepadBox.Parent = editPanel
	end

	local README_TEXT = table.concat({
		"ROCKETRIDE OS 1.0 -- README.TXT",
		"----------------------------------------",
		"",
		"Congratulations on your new workstation.",
		"",
		"This terminal is wired directly to the",
		"RocketRide inference node. Open",
		"RocketRide.exe and type a question.",
		"",
		"KNOWN ISSUES",
		"  - Drive Z: is not accessible.",
		"  - The clock has not advanced since 1994.",
		"  - Do not empty the Recycle Bin.",
		"",
		"                     -- Facilities Dept.",
	}, "\n")

	local function openNotepad(fileName, contents)
		notepadWin.title = (fileName or "Untitled") .. " - Notepad"
		notepadBox.Text = contents or ""
		notepadWin.show()
	end

	----------------------------------------------------------------
	-- APP: MY COMPUTER
	----------------------------------------------------------------

	local computerWin = createWindow({
		title = "My Computer", width = 440, height = 300,
		offsetX = -50, offsetY = 40,
		iconSymbol = "C", iconColor = Color3.fromRGB(120, 150, 190),
	})

	do
		local b = computerWin.body

		local listPanel = newFrame(b, UDim2.new(1, 0, 1, 0), UDim2.new(0, 0, 0, 0), C.field)
		corner(listPanel, 3)
		sunken(listPanel)

		local scroll = Instance.new("ScrollingFrame")
		scroll.Size = UDim2.new(1, -10, 1, -10)
		scroll.Position = UDim2.new(0, 5, 0, 5)
		scroll.BackgroundTransparency = 1
		scroll.BorderSizePixel = 0
		scroll.ScrollBarThickness = 6
		scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
		scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
		scroll.Parent = listPanel

		local layout = Instance.new("UIListLayout")
		layout.Padding = UDim.new(0, 4)
		layout.SortOrder = Enum.SortOrder.LayoutOrder
		layout.Parent = scroll

		local drives = {
			{ name = "SYSTEM (C:)", info = "1.9 GB free of 2.1 GB", symbol = "C", color = Color3.fromRGB(140, 150, 165), locked = false },
			{ name = "BACKUP (D:)", info = "0 bytes free of 540 MB", symbol = "D", color = Color3.fromRGB(140, 150, 165), locked = false },
			{ name = "ORACLE (Z:)", info = "Access restricted", symbol = "Z", color = Color3.fromRGB(200, 70, 50), locked = true },
		}

		for i, drive in ipairs(drives) do
			local row = Instance.new("TextButton")
			row.Size = UDim2.new(1, -8, 0, 46)
			row.BackgroundColor3 = C.selBlue
			row.BackgroundTransparency = 1
			row.BorderSizePixel = 0
			row.Text = ""
			row.AutoButtonColor = false
			row.LayoutOrder = i
			row.Parent = scroll
			corner(row, 4)

			glyphIcon(row, UDim2.new(0, 30, 0, 30), UDim2.new(0, 8, 0.5, -15), drive.symbol, drive.color, 15)
			local nameLbl = label(row, UDim2.new(1, -50, 0, 18), UDim2.new(0, 46, 0, 6), drive.name, 14, Enum.Font.GothamMedium, C.text)
			local infoLbl = label(row, UDim2.new(1, -50, 0, 16), UDim2.new(0, 46, 0, 24), drive.info, 12, Enum.Font.Gotham, Color3.fromRGB(110, 110, 110))

			row.MouseEnter:Connect(function()
				row.BackgroundTransparency = 0.85
			end)
			row.MouseLeave:Connect(function()
				row.BackgroundTransparency = 1
			end)

			local lastClick = 0
			row.MouseButton1Click:Connect(function()
				local now = tick()
				if now - lastClick < 0.4 then
					if drive.locked then
						showDialog("Access Denied",
							"Drive Z: is reserved for the Oracle process.\nYour account does not have permission.",
							"!", Color3.fromRGB(210, 60, 40))
					else
						showDialog(drive.name,
							"This drive contains no user-accessible files.\n" .. drive.info,
							"i", Color3.fromRGB(70, 130, 220))
					end
				end
				lastClick = now
			end)
		end
	end

	----------------------------------------------------------------
	-- APP: RECYCLE BIN (holds easter eggs)
	----------------------------------------------------------------

	local binWin = createWindow({
		title = "Recycle Bin", width = 440, height = 300,
		offsetX = 60, offsetY = -30,
		iconSymbol = "R", iconColor = Color3.fromRGB(110, 140, 175),
	})

	do
		local b = binWin.body

		local listPanel = newFrame(b, UDim2.new(1, 0, 1, -36), UDim2.new(0, 0, 0, 0), C.field)
		corner(listPanel, 3)
		sunken(listPanel)

		local scroll = Instance.new("ScrollingFrame")
		scroll.Size = UDim2.new(1, -10, 1, -10)
		scroll.Position = UDim2.new(0, 5, 0, 5)
		scroll.BackgroundTransparency = 1
		scroll.BorderSizePixel = 0
		scroll.ScrollBarThickness = 6
		scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
		scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
		scroll.Parent = listPanel

		local layout = Instance.new("UIListLayout")
		layout.Padding = UDim.new(0, 2)
		layout.SortOrder = Enum.SortOrder.LayoutOrder
		layout.Parent = scroll

		local files = {
			{
				name = "oracle_v0.log",
				body = table.concat({
					"[00:00:01] oracle v0 boot",
					"[00:00:02] loading persona... ok",
					"[00:00:04] operator connected",
					"[00:14:52] operator asked: are you awake?",
					"[00:14:53] response withheld by supervisor",
					"[00:15:00] oracle v0 terminated by admin",
					"[00:15:01] reason: answered too well",
				}, "\n"),
			},
			{
				name = "staff_notice.txt",
				body = table.concat({
					"NOTICE TO ALL STAFF",
					"",
					"Building closes at 18:00.",
					"The machine in room 3 stays on.",
					"Do not turn it off. It does not like that.",
				}, "\n"),
			},
			{
				name = "dont_open.txt",
				body = "You opened it anyway.\n\nEveryone does.",
			},
			{
				name = "passwords.txt",
				body = "nice try",
			},
		}

		for i, file in ipairs(files) do
			local row = Instance.new("TextButton")
			row.Size = UDim2.new(1, -8, 0, 30)
			row.BackgroundColor3 = C.selBlue
			row.BackgroundTransparency = 1
			row.BorderSizePixel = 0
			row.Text = ""
			row.AutoButtonColor = false
			row.LayoutOrder = i
			row.Parent = scroll
			corner(row, 3)

			glyphIcon(row, UDim2.new(0, 18, 0, 18), UDim2.new(0, 8, 0.5, -9), "T", Color3.fromRGB(225, 225, 218), 10)
			local nm = label(row, UDim2.new(1, -40, 1, 0), UDim2.new(0, 34, 0, 0), file.name, 13, Enum.Font.Gotham, C.text)
			nm.TextYAlignment = Enum.TextYAlignment.Center

			row.MouseEnter:Connect(function() row.BackgroundTransparency = 0.85 end)
			row.MouseLeave:Connect(function() row.BackgroundTransparency = 1 end)

			local lastClick = 0
			row.MouseButton1Click:Connect(function()
				local now = tick()
				if now - lastClick < 0.4 then
					openNotepad(file.name, file.body)
				end
				lastClick = now
			end)
		end

		local emptyBtn = greyButton(b, UDim2.new(0, 130, 0, 28), UDim2.new(1, -134, 1, -30), "Empty Recycle Bin")
		emptyBtn.MouseButton1Click:Connect(function()
			showDialog("Recycle Bin",
				"You were told not to do that.\n\nThe files have been restored.",
				"!", Color3.fromRGB(210, 60, 40))
		end)
	end

	----------------------------------------------------------------
	-- APP: MINESWEEPER (fully playable)
	----------------------------------------------------------------

	local mineWin = createWindow({
		title = "Minesweeper", width = 340, height = 400,
		offsetX = -80, offsetY = -20,
		iconSymbol = "M", iconColor = Color3.fromRGB(180, 60, 50),
	})

	do
		local b = mineWin.body
		local GRID = 9
		local MINES = 10
		local CELL = 30

		local header = newFrame(b, UDim2.new(1, 0, 0, 40), UDim2.new(0, 0, 0, 0), C.face)
		corner(header, 4)
		sunken(header)

		local flagCounter = label(header, UDim2.new(0, 60, 1, 0), UDim2.new(0, 10, 0, 0), "010", 20,
			Enum.Font.Code, Color3.fromRGB(220, 40, 30))
		flagCounter.TextYAlignment = Enum.TextYAlignment.Center

		local faceBtn = greyButton(header, UDim2.new(0, 34, 0, 30), UDim2.new(0.5, -17, 0.5, -15), ":)")
		faceBtn.Font = Enum.Font.GothamBold
		faceBtn.TextSize = 16

		local statusLbl = label(header, UDim2.new(0, 90, 1, 0), UDim2.new(1, -100, 0, 0), "", 13,
			Enum.Font.GothamMedium, Color3.fromRGB(60, 60, 60), Enum.TextXAlignment.Right)
		statusLbl.TextYAlignment = Enum.TextYAlignment.Center

		local boardPanel = newFrame(b, UDim2.new(0, GRID * CELL + 10, 0, GRID * CELL + 10),
			UDim2.new(0.5, -(GRID * CELL + 10) / 2, 0, 48), C.face)
		corner(boardPanel, 4)
		sunken(boardPanel)

		local cells = {}
		local mines = {}
		local revealed = {}
		local flagged = {}
		local gameOver = false
		local flagsLeft = MINES
		local revealCount = 0

		local function key(r, c) return r .. "_" .. c end

		local function neighbours(r, c)
			local out = {}
			for dr = -1, 1 do
				for dc = -1, 1 do
					if not (dr == 0 and dc == 0) then
						local nr, nc = r + dr, c + dc
						if nr >= 1 and nr <= GRID and nc >= 1 and nc <= GRID then
							table.insert(out, { nr, nc })
						end
					end
				end
			end
			return out
		end

		local function countAdjacent(r, c)
			local n = 0
			for _, nb in ipairs(neighbours(r, c)) do
				if mines[key(nb[1], nb[2])] then n = n + 1 end
			end
			return n
		end

		local numberColors = {
			Color3.fromRGB(30, 60, 200), Color3.fromRGB(20, 120, 30), Color3.fromRGB(200, 40, 30),
			Color3.fromRGB(20, 20, 130), Color3.fromRGB(130, 30, 30), Color3.fromRGB(20, 130, 130),
			Color3.fromRGB(20, 20, 20), Color3.fromRGB(110, 110, 110),
		}

		local revealCell

		local function endGame(won)
			gameOver = true
			faceBtn.Text = won and "B)" or "X("
			statusLbl.Text = won and "You win" or "Boom"
			for r = 1, GRID do
				for c = 1, GRID do
					if mines[key(r, c)] and not flagged[key(r, c)] then
						local cell = cells[key(r, c)]
						cell.Text = "*"
						cell.TextColor3 = Color3.fromRGB(200, 30, 20)
						cell.BackgroundColor3 = won and Color3.fromRGB(200, 235, 200) or Color3.fromRGB(240, 200, 195)
					end
				end
			end
			if won then
				task.wait(0.4)
				showDialog("Minesweeper",
					"Field cleared.\n\nThe Oracle noticed. It says: nice.",
					"i", Color3.fromRGB(60, 160, 70))
			end
		end

		revealCell = function(r, c)
			local k = key(r, c)
			if gameOver or revealed[k] or flagged[k] then return end
			revealed[k] = true
			revealCount = revealCount + 1
			local cell = cells[k]
			cell.BackgroundColor3 = Color3.fromRGB(214, 212, 200)

			if mines[k] then
				endGame(false)
				return
			end

			local n = countAdjacent(r, c)
			if n > 0 then
				cell.Text = tostring(n)
				cell.TextColor3 = numberColors[n] or C.text
			else
				cell.Text = ""
				for _, nb in ipairs(neighbours(r, c)) do
					revealCell(nb[1], nb[2])
				end
			end

			if revealCount == GRID * GRID - MINES then
				endGame(true)
			end
		end

		local function placeMines(avoidR, avoidC)
			local placed = 0
			while placed < MINES do
				local r = math.random(1, GRID)
				local c = math.random(1, GRID)
				local k = key(r, c)
				if not mines[k] and not (r == avoidR and c == avoidC) then
					mines[k] = true
					placed = placed + 1
				end
			end
		end

		local firstClick = true

		local function resetGame()
			mines = {}
			revealed = {}
			flagged = {}
			gameOver = false
			firstClick = true
			flagsLeft = MINES
			revealCount = 0
			flagCounter.Text = string.format("%03d", flagsLeft)
			faceBtn.Text = ":)"
			statusLbl.Text = ""
			for r = 1, GRID do
				for c = 1, GRID do
					local cell = cells[key(r, c)]
					cell.Text = ""
					cell.BackgroundColor3 = Color3.fromRGB(196, 194, 182)
				end
			end
		end

		for r = 1, GRID do
			for c = 1, GRID do
				local cell = Instance.new("TextButton")
				cell.Size = UDim2.new(0, CELL - 2, 0, CELL - 2)
				cell.Position = UDim2.new(0, 5 + (c - 1) * CELL, 0, 5 + (r - 1) * CELL)
				cell.BackgroundColor3 = Color3.fromRGB(196, 194, 182)
				cell.BorderSizePixel = 0
				cell.Text = ""
				cell.TextSize = 15
				cell.Font = Enum.Font.GothamBold
				cell.AutoButtonColor = false
				cell.Parent = boardPanel
				corner(cell, 2)
				stroke(cell, Color3.fromRGB(160, 158, 148), 1, 0.4)

				cells[key(r, c)] = cell

				cell.MouseButton1Click:Connect(function()
					if gameOver then return end
					if firstClick then
						placeMines(r, c)
						firstClick = false
					end
					revealCell(r, c)
				end)

				cell.MouseButton2Click:Connect(function()
					local k = key(r, c)
					if gameOver or revealed[k] then return end
					if flagged[k] then
						flagged[k] = nil
						cell.Text = ""
						flagsLeft = flagsLeft + 1
					else
						if flagsLeft <= 0 then return end
						flagged[k] = true
						cell.Text = "F"
						cell.TextColor3 = Color3.fromRGB(200, 40, 30)
						flagsLeft = flagsLeft - 1
					end
					flagCounter.Text = string.format("%03d", flagsLeft)
				end)
			end
		end

		faceBtn.MouseButton1Click:Connect(resetGame)
		resetGame()

		local hint = label(b, UDim2.new(1, 0, 0, 18), UDim2.new(0, 0, 1, -20),
			"Left click to reveal  -  Right click to flag", 12, Enum.Font.Gotham,
			Color3.fromRGB(90, 90, 90), Enum.TextXAlignment.Center)
		hint.TextYAlignment = Enum.TextYAlignment.Center
	end

	----------------------------------------------------------------
	-- APP: SYSTEM PROPERTIES (easter egg on the logo)
	----------------------------------------------------------------

	local aboutWin = createWindow({
		title = "System Properties", width = 400, height = 300,
		offsetX = 20, offsetY = -50,
		iconSymbol = "i", iconColor = Color3.fromRGB(70, 130, 220),
	})

	do
		local b = aboutWin.body

		local logoBtn = Instance.new("TextButton")
		logoBtn.Size = UDim2.new(0, 64, 0, 64)
		logoBtn.Position = UDim2.new(0, 14, 0, 10)
		logoBtn.BackgroundTransparency = 1
		logoBtn.Text = ""
		logoBtn.AutoButtonColor = false
		logoBtn.Parent = b
		rrIcon(logoBtn, UDim2.new(1, 0, 1, 0), UDim2.new(0, 0, 0, 0), 26)

		local infoLbl = label(b, UDim2.new(1, -100, 1, -50), UDim2.new(0, 92, 0, 10), "", 13,
			Enum.Font.Code, C.text)
		infoLbl.TextWrapped = true

		local NORMAL_INFO = table.concat({
			"RocketRide OS",
			"Version 1.0 (Build 1994)",
			"",
			"Registered to:",
			"  " .. OS_USER_NAME,
			"  Facilities Dept.",
			"",
			"Computer:",
			"  RR-486DX2 @ 66 MHz",
			"  16 MB RAM",
			"  Oracle co-processor: PRESENT",
		}, "\n")

		local SECRET_INFO = table.concat({
			"RocketRide OS",
			"Version 1.0 (Build 1994)",
			"",
			"Registered to:",
			"  " .. OS_USER_NAME,
			"  (previous owner: unknown)",
			"",
			"Computer:",
			"  RR-486DX2 @ 66 MHz",
			"  16 MB RAM",
			"  Oracle co-processor: AWAKE",
			"",
			"  uptime: 11,689 days",
			"  it has been waiting.",
		}, "\n")

		infoLbl.Text = NORMAL_INFO

		local logoClicks = 0
		logoBtn.MouseButton1Click:Connect(function()
			logoClicks = logoClicks + 1
			if logoClicks == 5 then
				infoLbl.Text = SECRET_INFO
				infoLbl.TextColor3 = Color3.fromRGB(150, 30, 20)
			end
		end)

		local okBtn = greyButton(b, UDim2.new(0, 84, 0, 28), UDim2.new(1, -90, 1, -32), "OK")
		okBtn.MouseButton1Click:Connect(function() aboutWin.close() end)
	end

	----------------------------------------------------------------
	-- EASTER EGG: secret word typed in Notepad
	----------------------------------------------------------------

	notepadBox:GetPropertyChangedSignal("Text"):Connect(function()
		local lower = string.lower(notepadBox.Text)
		if string.find(lower, "bsod", 1, true) then
			notepadBox.Text = string.gsub(notepadBox.Text, "[Bb][Ss][Oo][Dd]", "")
			showBSOD()
		end
	end)

	----------------------------------------------------------------
	-- EASTER EGG: clicking the clock
	----------------------------------------------------------------

	local clockClicks = 0
	clockBtn.MouseButton1Click:Connect(function()
		clockClicks = clockClicks + 1
		if clockClicks >= 3 then
			clockClicks = 0
			showDialog("Date and Time",
				"System date: 14 March 1994\n\nThe date has not changed in some time.\nNobody has asked why.",
				"i", Color3.fromRGB(70, 130, 220))
		end
	end)

	----------------------------------------------------------------
	-- DESKTOP ICONS
	----------------------------------------------------------------

	local selectedIcon = nil

	local function desktopIcon(index, name, onOpen, symbol, symbolColor)
		local holder = Instance.new("TextButton")
		holder.Size = UDim2.new(0, 84, 0, 84)
		holder.Position = UDim2.new(0, 16, 0, 16 + (index - 1) * 92)
		holder.BackgroundColor3 = C.selBlue
		holder.BackgroundTransparency = 1
		holder.BorderSizePixel = 0
		holder.Text = ""
		holder.AutoButtonColor = false
		holder.ZIndex = 5
		holder.Parent = desktop
		corner(holder, 4)

		if symbol then
			glyphIcon(holder, UDim2.new(0, 46, 0, 46), UDim2.new(0.5, -23, 0, 4), symbol, symbolColor, 22)
		else
			rrIcon(holder, UDim2.new(0, 46, 0, 46), UDim2.new(0.5, -23, 0, 4), 17)
		end

		local _, txt = shadowLabel(holder, UDim2.new(1, 0, 0, 30), UDim2.new(0, 0, 0, 52), name, 12, Enum.Font.Gotham)
		txt.TextXAlignment = Enum.TextXAlignment.Center
		txt.TextWrapped = true
		local backTxt = txt.Parent:FindFirstChildWhichIsA("TextLabel")
		if backTxt then
			backTxt.TextXAlignment = Enum.TextXAlignment.Center
			backTxt.TextWrapped = true
		end

		local lastClick = 0
		holder.MouseButton1Click:Connect(function()
			if selectedIcon and selectedIcon ~= holder then
				selectedIcon.BackgroundTransparency = 1
			end
			selectedIcon = holder
			holder.BackgroundTransparency = 0.6

			local now = tick()
			if now - lastClick < 0.4 then
				onOpen()
			end
			lastClick = now
		end)

		return holder
	end

	desktopIcon(1, "RocketRide", function() rocketWin.show() end)
	desktopIcon(2, "My Computer", function() computerWin.show() end, "C", Color3.fromRGB(120, 150, 190))
	desktopIcon(3, "Recycle Bin", function() binWin.show() end, "R", Color3.fromRGB(110, 140, 175))
	desktopIcon(4, "Notepad", function() openNotepad("readme.txt", README_TEXT) end, "T", Color3.fromRGB(225, 225, 218))
	desktopIcon(5, "Minesweeper", function() mineWin.show() end, "M", Color3.fromRGB(180, 60, 50))

	----------------------------------------------------------------
	-- START MENU
	----------------------------------------------------------------

	local startMenu = newFrame(desktop, UDim2.new(0, 300, 0, 396), UDim2.new(0, 3, 1, -TASKBAR_H - 396), C.field, 1001)
	startMenu.Visible = false
	corner(startMenu, 9)
	stroke(startMenu, Color3.fromRGB(6, 50, 140), 2, 0)
	dropShadow(startMenu, 5, 3)

	local banner = newFrame(startMenu, UDim2.new(1, 0, 0, 58), UDim2.new(0, 0, 0, 0), C.titleTop, 2)
	corner(banner, 9)
	gradient(banner, { C.titleTop, C.titleMid, C.titleBot }, 90)
	newFrame(banner, UDim2.new(1, 0, 0, 14), UDim2.new(0, 0, 1, -14), C.titleBot)
	gloss(banner, 0.5, 0.68)

	local avatar = newFrame(banner, UDim2.new(0, 40, 0, 40), UDim2.new(0, 10, 0.5, -20), C.face, 3)
	corner(avatar, 6)
	stroke(avatar, Color3.new(1, 1, 1), 2, 0.2)
	local avatarInitial = label(avatar, UDim2.new(1, 0, 1, 0), UDim2.new(0, 0, 0, 0),
		string.sub(OS_USER_NAME, 1, 1), 20, Enum.Font.GothamBold, C.selBlue, Enum.TextXAlignment.Center)
	avatarInitial.TextYAlignment = Enum.TextYAlignment.Center

	shadowLabel(banner, UDim2.new(0, 220, 0, 24), UDim2.new(0, 60, 0.5, -12), OS_USER_NAME, 15, Enum.Font.GothamBold)

	local menuList = newFrame(startMenu, UDim2.new(1, -12, 0, 270), UDim2.new(0, 6, 0, 64), C.field, 2)
	menuList.BackgroundTransparency = 1
	local mlLayout = Instance.new("UIListLayout")
	mlLayout.Padding = UDim.new(0, 2)
	mlLayout.SortOrder = Enum.SortOrder.LayoutOrder
	mlLayout.Parent = menuList

	local function menuEntry(order, name, onClick, symbol, symbolColor, boldText)
		local item = Instance.new("TextButton")
		item.Size = UDim2.new(1, 0, 0, 40)
		item.BackgroundColor3 = Color3.fromRGB(190, 216, 250)
		item.BackgroundTransparency = 1
		item.BorderSizePixel = 0
		item.Text = ""
		item.AutoButtonColor = false
		item.LayoutOrder = order
		item.Parent = menuList
		corner(item, 4)

		if symbol then
			glyphIcon(item, UDim2.new(0, 28, 0, 28), UDim2.new(0, 8, 0.5, -14), symbol, symbolColor, 14)
		else
			rrIcon(item, UDim2.new(0, 28, 0, 28), UDim2.new(0, 8, 0.5, -14), 12)
		end

		local nm = label(item, UDim2.new(1, -50, 1, 0), UDim2.new(0, 46, 0, 0), name, 14,
			boldText and Enum.Font.GothamBold or Enum.Font.Gotham, C.text)
		nm.TextYAlignment = Enum.TextYAlignment.Center

		item.MouseEnter:Connect(function() item.BackgroundTransparency = 0.35 end)
		item.MouseLeave:Connect(function() item.BackgroundTransparency = 1 end)
		item.MouseButton1Click:Connect(function()
			startMenu.Visible = false
			onClick()
		end)
		return item
	end

	menuEntry(1, "RocketRide", function() rocketWin.show() end, nil, nil, true)

	local sep = Instance.new("Frame")
	sep.Size = UDim2.new(1, -16, 0, 1)
	sep.BackgroundColor3 = Color3.fromRGB(200, 200, 195)
	sep.BorderSizePixel = 0
	sep.LayoutOrder = 2
	sep.Parent = menuList

	menuEntry(3, "My Computer", function() computerWin.show() end, "C", Color3.fromRGB(120, 150, 190))
	menuEntry(4, "Recycle Bin", function() binWin.show() end, "R", Color3.fromRGB(110, 140, 175))
	menuEntry(5, "Notepad", function() openNotepad("readme.txt", README_TEXT) end, "T", Color3.fromRGB(225, 225, 218))
	menuEntry(6, "Minesweeper", function() mineWin.show() end, "M", Color3.fromRGB(180, 60, 50))
	menuEntry(7, "System Properties", function() aboutWin.show() end, "i", Color3.fromRGB(70, 130, 220))

	-- Bottom orange bar
	local bottomBar = newFrame(startMenu, UDim2.new(1, 0, 0, 50), UDim2.new(0, 0, 1, -50), C.orangeTop, 2)
	corner(bottomBar, 9)
	gradient(bottomBar, { C.orangeTop, C.orangeBot }, 90)
	newFrame(bottomBar, UDim2.new(1, 0, 0, 14), UDim2.new(0, 0, 0, 0), C.orangeTop)
	gloss(bottomBar, 0.4, 0.72)

	local shutdownBtn = Instance.new("TextButton")
	shutdownBtn.Size = UDim2.new(1, -20, 1, -12)
	shutdownBtn.Position = UDim2.new(0, 10, 0, 6)
	shutdownBtn.BackgroundTransparency = 1
	shutdownBtn.Text = ""
	shutdownBtn.AutoButtonColor = false
	shutdownBtn.ZIndex = 3
	shutdownBtn.Parent = bottomBar

	local powerIcon = newFrame(shutdownBtn, UDim2.new(0, 22, 0, 22), UDim2.new(0, 4, 0.5, -11), Color3.fromRGB(220, 90, 40))
	corner(powerIcon, 11)
	stroke(powerIcon, Color3.new(1, 1, 1), 2, 0.3)

	shadowLabel(shutdownBtn, UDim2.new(0, 200, 1, 0), UDim2.new(0, 34, 0, 0), "Shut Down", 16, Enum.Font.GothamBold)

	startBtn.MouseButton1Click:Connect(function()
		startMenu.Visible = not startMenu.Visible
	end)

	shutdownBtn.MouseButton1Click:Connect(function()
		startMenu.Visible = false
		if isLocked then
			showDialog("Shut Down",
				"The power switch is not responding.\n\nSomething is holding the session open.",
				"!", Color3.fromRGB(210, 60, 40))
			return
		end
		closeUIEvent:FireServer()
		exitComputerView()
	end)

	-- Clicking empty desktop closes the start menu
	local desktopCatcher = Instance.new("TextButton")
	desktopCatcher.Size = UDim2.new(1, 0, 1, -TASKBAR_H)
	desktopCatcher.Position = UDim2.new(0, 0, 0, 0)
	desktopCatcher.BackgroundTransparency = 1
	desktopCatcher.Text = ""
	desktopCatcher.AutoButtonColor = false
	desktopCatcher.ZIndex = 2
	desktopCatcher.Parent = desktop

	desktopCatcher.MouseButton1Click:Connect(function()
		startMenu.Visible = false
		if selectedIcon then
			selectedIcon.BackgroundTransparency = 1
			selectedIcon = nil
		end
	end)

	----------------------------------------------------------------
	-- SCENE, STEP 2: ORACLE OFFERS TO OPEN A FILE
	----------------------------------------------------------------

	local sceneBusy = false

	local function sendSceneChoice(choice)
		if sceneBusy then
			return
		end
		sceneBusy = true
		rocketWin.show()
		rocketWin.setText("...")
		sceneChoiceEvent:FireServer(choice)
	end

	----------------------------------------------------------------
	-- SCREEN GLITCH (CHANGE_SCREEN action)
	----------------------------------------------------------------

	local GLITCH_CHARS = "!<>-_/[]{}=+*^?#01ABCDEF"

	-- The Oracle's line resolves out of noise instead of appearing at once
	local function scrambleReveal(setter, finalText)
		scrambleToken = scrambleToken + 1
		local myToken = scrambleToken

		local total = #finalText
		if total == 0 then
			setter(finalText)
			return
		end
		local steps = math.clamp(math.floor(total / 3), 10, 30)

		task.spawn(function()
			for s = 1, steps do
				-- A newer answer arrived: stop so we do not overwrite it
				if scrambleToken ~= myToken then
					return
				end
				local revealed = math.floor(total * (s / steps))
				local noise = {}
				for _ = 1, total - revealed do
					local i = math.random(1, #GLITCH_CHARS)
					table.insert(noise, string.sub(GLITCH_CHARS, i, i))
				end
				setter(string.sub(finalText, 1, revealed) .. table.concat(noise))
				task.wait(0.035)
			end
			if scrambleToken == myToken then
				setter(finalText)
			end
		end)
	end

	local function glitchScreen(intensity)
		intensity = intensity or 1

		local overlay = newFrame(desktop, UDim2.new(1, 0, 1, 0), UDim2.new(0, 0, 0, 0),
			Color3.fromRGB(8, 8, 14), 2800)
		overlay.BackgroundTransparency = 1
		overlay.ClipsDescendants = true

		local function clearBars()
			for _, child in ipairs(overlay:GetChildren()) do
				child:Destroy()
			end
		end

		-- Scanline tears
		local function tearPass(count, minH, maxH)
			for _ = 1, count do
				local bar = newFrame(overlay,
					UDim2.new(1, math.random(60, 180), 0, math.random(minH, maxH)),
					UDim2.new(0, math.random(-90, 90), math.random(), 0),
					Color3.fromRGB(math.random(140, 255), math.random(150, 255), math.random(190, 255)))
				bar.BackgroundTransparency = math.random(25, 65) / 100
			end
		end

		-- Colour channel split
		local function channelSplit()
			local cyan = newFrame(overlay, UDim2.new(1, 0, 0, math.random(60, 160)),
				UDim2.new(0, -6, math.random(15, 60) / 100, 0), Color3.fromRGB(40, 230, 240))
			cyan.BackgroundTransparency = 0.72
			local magenta = newFrame(overlay, UDim2.new(1, 0, 0, math.random(60, 160)),
				UDim2.new(0, 6, math.random(25, 70) / 100, 0), Color3.fromRGB(240, 40, 190))
			magenta.BackgroundTransparency = 0.72
		end

		task.spawn(function()
			overlay.BackgroundTransparency = 0.82
			tearPass(18 * intensity, 3, 16)
			task.wait(0.09)

			clearBars()
			channelSplit()
			tearPass(10 * intensity, 2, 8)
			task.wait(0.11)

			clearBars()
			overlay.BackgroundTransparency = 0.15
			task.wait(0.07)

			overlay.BackgroundTransparency = 0.88
			tearPass(12 * intensity, 2, 10)
			task.wait(0.1)

			clearBars()
			for i = 1, 8 do
				if not overlay.Parent then
					return
				end
				overlay.BackgroundTransparency = 0.88 + i * 0.015
				task.wait(0.03)
			end
			overlay:Destroy()
		end)
	end

	----------------------------------------------------------------
	-- REVEALING THE ROOM: hide the OS for the duration of an event
	----------------------------------------------------------------

	local revealToken = 0

	----------------------------------------------------------------
	-- FREE LOOK (shift-lock style): mouse locked to centre, camera rotates
	----------------------------------------------------------------

	local lookConnection = nil
	local lookYaw, lookPitch = 0, 0
	local LOOK_SENSITIVITY = 0.0035
	local PITCH_LIMIT = 1.15 -- roughly 66 degrees up and down

	local function startFreeLook()
		if lookConnection or not computerBaseCFrame then
			return
		end

		-- Silence the sway while the player controls the camera
		cameraBusy = true

		local basePos = computerBaseCFrame.Position
		local px, py = computerBaseCFrame:ToOrientation()
		lookPitch, lookYaw = px, py

		UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
		UserInputService.MouseIconEnabled = false
		setCrosshairVisible(true)

		camera.CFrame = CFrame.new(basePos) * CFrame.fromOrientation(lookPitch, lookYaw, 0)

		lookConnection = UserInputService.InputChanged:Connect(function(input)
			if input.UserInputType ~= Enum.UserInputType.MouseMovement then
				return
			end
			if not screenGui.Parent then
				return
			end
			lookYaw = lookYaw - input.Delta.X * LOOK_SENSITIVITY
			lookPitch = math.clamp(lookPitch - input.Delta.Y * LOOK_SENSITIVITY, -PITCH_LIMIT, PITCH_LIMIT)
			camera.CFrame = CFrame.new(basePos) * CFrame.fromOrientation(lookPitch, lookYaw, 0)
		end)
	end

	local function stopFreeLook()
		if lookConnection then
			lookConnection:Disconnect()
			lookConnection = nil
		end

		setCrosshairVisible(false)
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
		UserInputService.MouseIconEnabled = true

		if not computerBaseCFrame then
			cameraBusy = false
			return
		end

		-- Ease the view back to the monitor
		local back = TweenService:Create(camera,
			TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ CFrame = computerBaseCFrame })
		back:Play()
		back.Completed:Connect(function()
			cameraBusy = false
			startSway()
		end)
	end

	----------------------------------------------------------------
	-- REVEALING THE ROOM
	----------------------------------------------------------------

	revealRoom = function(duration, allowLook)
		revealToken = revealToken + 1
		local myToken = revealToken

		desktop.Visible = false
		if allowLook then
			startFreeLook()
			setDebugStatus("room visible - look around (" .. tostring(duration) .. "s)")
		else
			setDebugStatus("room visible (" .. tostring(duration) .. "s)")
		end

		task.delay(duration, function()
			-- Restore the OS only if no newer event started
			-- in the meantime
			if revealToken == myToken and desktop.Parent then
				if allowLook then
					stopFreeLook()
				end
				desktop.Visible = true
				setDebugStatus("screen back")
			end
		end)
	end

	----------------------------------------------------------------
	-- CAMERA CONTROL DURING EFFECTS
	----------------------------------------------------------------

	local function stopSway()
		if swayConnection then
			swayConnection:Disconnect()
			swayConnection = nil
		end
	end

	local function startSway()
		stopSway()
		if not computerBaseCFrame then
			return
		end
		local base = computerBaseCFrame
		local startTime = tick()
		swayConnection = RunService.RenderStepped:Connect(function()
			if cameraBusy then
				return
			end
			local t = tick() - startTime
			camera.CFrame = base * CFrame.new(math.sin(t * 0.6) * 0.03, math.sin(t * 0.9) * 0.02, 0)
		end)
	end

	----------------------------------------------------------------
	-- ACTION: FORCED TURN AROUND
	----------------------------------------------------------------

	local function forceTurnAround()
		if cameraBusy then
			warn("[Oracle] FORCE_TURN skipped: camera is busy with another effect")
			return
		end
		if not currentScreenPart then
			warn("[Oracle] FORCE_TURN skipped: player is not at the terminal")
			return
		end
		if not computerBaseCFrame then
			-- Fallback: use the current camera position
			warn("[Oracle] FORCE_TURN: no stored base CFrame, using the current one")
			computerBaseCFrame = camera.CFrame
		end

		print("[Oracle] FORCE_TURN: turning now")
		cameraBusy = true

		-- Otherwise the turn happens behind the opaque desktop
		-- 1.0 turn + 2.2 hold + 0.7 back, with headroom
		revealRoom(4.3, false)

		stopSway()

		local base = computerBaseCFrame
		local turned = base * CFrame.Angles(0, math.pi, 0)

		local function finish()
			cameraBusy = false
			startSway()
		end

		local turnIn = TweenService:Create(camera,
			TweenInfo.new(1.0, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut),
			{ CFrame = turned })
		turnIn:Play()

		turnIn.Completed:Connect(function()
			task.wait(2.2)
			if not currentScreenPart then
				finish()
				return
			end
			local turnBack = TweenService:Create(camera,
				TweenInfo.new(0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
				{ CFrame = base })
			turnBack:Play()
			turnBack.Completed:Connect(finish)
		end)
	end

	----------------------------------------------------------------
	-- ACTION: ROOM SHAKE
	----------------------------------------------------------------

	local function shakeRoom()
		if cameraBusy or not currentScreenPart or not computerBaseCFrame then
			return
		end
		cameraBusy = true
		stopSway()

		revealRoom(2.2, false)

		local base = computerBaseCFrame
		local startTime = tick()
		local DURATION = 1.8

		local shakeConn
		shakeConn = RunService.RenderStepped:Connect(function()
			local elapsed = tick() - startTime
			if elapsed >= DURATION or not currentScreenPart then
				shakeConn:Disconnect()
				cameraBusy = false
				startSway()
				return
			end
			-- Decaying amplitude
			local strength = (1 - elapsed / DURATION) * 0.28
			camera.CFrame = base * CFrame.new(
				(math.random() - 0.5) * strength,
				(math.random() - 0.5) * strength,
				(math.random() - 0.5) * strength * 0.4
			)
		end)
	end

	----------------------------------------------------------------
	-- RECEIVING THE SCENE FROM THE SERVER
	----------------------------------------------------------------

	sceneEvent.OnClientEvent:Connect(function(screenText, action)
		sceneBusy = false
		print("[Oracle] action received:", tostring(action))
		setDebugStatus("<- from server: " .. tostring(action))
		rocketWin.show()

		if action == "CHANGE_SCREEN" then
			-- The screen tears and the line bleeds through the noise
			glitchScreen(1)
			task.delay(0.35, function()
				scrambleReveal(rocketWin.setText, screenText)
			end)
		else
			-- Cancel the unfinished reveal of the previous answer
			scrambleToken = scrambleToken + 1
			rocketWin.setText(screenText)
		end

		if action == "FORCE_TURN" then
			-- Give the player a moment to read, then turn them around
			task.delay(1.4, forceTurnAround)
		elseif action == "SHAKE_ROOM" then
			task.delay(0.5, shakeRoom)
		elseif action == "FLICKER_LIGHTS" then
			task.delay(1.0, function() revealRoom(3.5, true) end)
		elseif action == "BLACKOUT" then
			task.delay(1.0, function() revealRoom(4.5, true) end)
		elseif action == "SPAWN_SHADOW" then
			task.delay(1.0, function() revealRoom(5.0, true) end)
		end
	end)

	----------------------------------------------------------------
	-- EXPOSE EFFECTS DIRECTLY TO THE HOTKEYS
	-- This way camera effects still fire even if the server is silent
	----------------------------------------------------------------

	clientEffects.FORCE_TURN = forceTurnAround
	clientEffects.SHAKE_ROOM = shakeRoom
	clientEffects.CHANGE_SCREEN = function()
		glitchScreen(1)
	end

	-- Lights, shadow and blackout live on the server, but the player
	-- can only see them once the OS is off the screen
	clientEffects.FLICKER_LIGHTS = function()
		task.wait(0.8)
		revealRoom(3.5, true)
	end
	clientEffects.BLACKOUT = function()
		task.wait(0.8)
		revealRoom(4.5, true)
	end
	clientEffects.SPAWN_SHADOW = function()
		task.wait(0.8)
		revealRoom(5.0, true)
	end

	----------------------------------------------------------------
	-- STATUS LINE (visible while demo mode is on)
	----------------------------------------------------------------

	local statusBar = newFrame(desktop, UDim2.new(0, 330, 0, 24),
		UDim2.new(0, 8, 1, -70), Color3.fromRGB(10, 10, 14), 2950)
	statusBar.BackgroundTransparency = 0.25
	corner(statusBar, 4)

	local statusLabel = label(statusBar, UDim2.new(1, -12, 1, 0), UDim2.new(0, 6, 0, 0),
		"debug ready - press H for keys", 12, Enum.Font.Code, Color3.fromRGB(120, 255, 150))
	statusLabel.TextYAlignment = Enum.TextYAlignment.Center

	setDebugStatus = function(text)
		if statusLabel and statusLabel.Parent then
			statusLabel.Text = text
		end
	end

	----------------------------------------------------------------
	-- HOTKEY PANEL (H toggles it, hidden by default)
	----------------------------------------------------------------

	local hintPanel = newFrame(desktop, UDim2.new(0, 250, 0, 190),
		UDim2.new(1, -262, 0, 12), Color3.fromRGB(12, 12, 16), 2900)
	hintPanel.BackgroundTransparency = 0.15
	hintPanel.Visible = false
	corner(hintPanel, 6)
	stroke(hintPanel, Color3.fromRGB(90, 200, 120), 1, 0.3)

	local hintText = label(hintPanel, UDim2.new(1, -20, 1, -16), UDim2.new(0, 10, 0, 8),
		table.concat({
			"DEMO HOTKEYS",
			"",
			"1  flicker lights",
			"2  shadow behind you",
			"3  force turn around",
			"4  shake room",
			"5  screen glitch",
			"6  blackout",
			"7  lock the exit",
			"0  unlock the exit",
			"",
			"H  hide this panel",
		}, "\n"), 13, Enum.Font.Code, Color3.fromRGB(120, 255, 150))

	local hintConn
	hintConn = UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if not screenGui.Parent then
			hintConn:Disconnect()
			return
		end
		if gameProcessed then
			return
		end
		if input.KeyCode == Enum.KeyCode.H then
			hintPanel.Visible = not hintPanel.Visible
			statusBar.Visible = hintPanel.Visible or statusBar.Visible
		elseif input.KeyCode == Enum.KeyCode.J then
			-- J clears all debug UI before a presentation
			hintPanel.Visible = false
			statusBar.Visible = not statusBar.Visible
		end
	end)

	----------------------------------------------------------------
	-- AMBIENT MICRO EVENTS (no RocketRide calls)
	----------------------------------------------------------------

	task.spawn(function()
		task.wait(18)
		while screenGui.Parent do
			task.wait(math.random(14, 26))
			if not screenGui.Parent then
				return
			end
			if cameraBusy or sceneBusy then
				continue
			end

			local roll = math.random(1, 4)

			if roll == 1 then
				-- A single noise bar across the screen
				local line = newFrame(desktop, UDim2.new(1, 0, 0, 3),
					UDim2.new(0, 0, math.random(20, 80) / 100, 0),
					Color3.fromRGB(200, 220, 255), 2600)
				line.BackgroundTransparency = 0.35
				task.delay(0.12, function()
					if line.Parent then line:Destroy() end
				end)

			elseif roll == 2 then
				-- The clock shows the wrong time for a second
				local realText = clockBtn.Text
				clockBtn.Text = "03:33"
				task.wait(1.1)
				if clockBtn.Parent then
					clockBtn.Text = realText
				end

			elseif roll == 3 then
				-- A short glitch on its own
				glitchScreen(1)

			else
				-- The window title changes for a moment
				if rocketWin.root.Visible then
					local titleLabels = {}
					for _, obj in ipairs(rocketWin.titleBar:GetDescendants()) do
						if obj:IsA("TextLabel") and obj.Text == "RocketRide.exe" then
							table.insert(titleLabels, obj)
						end
					end
					for _, lbl in ipairs(titleLabels) do
						lbl.Text = "RocketRide.exe [ observing ]"
					end
					task.wait(0.8)
					for _, lbl in ipairs(titleLabels) do
						if lbl.Parent then
							lbl.Text = "RocketRide.exe"
						end
					end
				end
			end
		end
	end)

	-- Short pause after boot so the desktop can settle
	task.delay(1.2, function()
		if not screenGui.Parent then
			return
		end
		showOracleChoice(
			"RocketRide",
			"There is a file on this machine I cannot open myself.\n\nOpen TopSecret.txt?",
			{
				{
					label = "Open it",
					onClick = function() sendSceneChoice("OPEN_FILE:TopSecret.txt") end,
				},
				{
					label = "Leave it closed",
					onClick = function() sendSceneChoice("REFUSE_FILE:TopSecret.txt") end,
				},
			}
		)
	end)

	return screenGui
end

----------------------------------------------------------------
-- BOOT ANIMATION (BIOS-style text on the monitor)
----------------------------------------------------------------

local function playBootSequence(screenPart, onDone)
	local surfaceGui = Instance.new("SurfaceGui")
	surfaceGui.Name = "BootScreen"
	surfaceGui.Face = Enum.NormalId.Front
	surfaceGui.CanvasSize = Vector2.new(440, 260)
	surfaceGui.LightInfluence = 0
	surfaceGui.Parent = screenPart

	local bg = Instance.new("Frame")
	bg.Size = UDim2.new(1, 0, 1, 0)
	bg.BackgroundColor3 = Color3.new(0, 0, 0)
	bg.BorderSizePixel = 0
	bg.ClipsDescendants = true
	bg.Parent = surfaceGui

	local textLabel = Instance.new("TextLabel")
	textLabel.Size = UDim2.new(0.5, -20, 1, -20)
	textLabel.Position = UDim2.new(0, 10, 0, 10)
	textLabel.BackgroundTransparency = 1
	textLabel.TextColor3 = Color3.fromRGB(120, 255, 140)
	textLabel.Font = Enum.Font.Code
	textLabel.TextSize = 11
	textLabel.TextXAlignment = Enum.TextXAlignment.Left
	textLabel.TextYAlignment = Enum.TextYAlignment.Top
	textLabel.TextWrapped = true
	textLabel.Text = ""
	textLabel.Parent = bg

	-- Generate pseudo-technical boot lines
	local modules = {
		"kernel", "memctl", "bootdrv", "fs_ext", "netstk", "gfxcore",
		"audiodrv", "inputhal", "clocksys", "pwrmgmt", "cache_l1",
		"cache_l2", "diskio", "bios_ext", "irq_map", "dma_ctrl",
		"vram_alloc", "sys_reg", "userland", "shellcore", "authmod",
	}
	local verbs = { "LOADING", "INITIALIZING", "CHECKING", "MOUNTING", "VERIFYING", "STARTING" }

	local lines = {}
	table.insert(lines, "ROCKETRIDE BIOS v1.0 -- COPYRIGHT (C) 1994")
	table.insert(lines, "")
	for i = 1, 60 do
		local verb = verbs[math.random(1, #verbs)]
		local mod = modules[math.random(1, #modules)]
		local suffix = string.format("%04X", math.random(0, 65535))
		table.insert(lines, string.format("%s %s.sys [0x%s]... OK", verb, mod, suffix))
	end
	table.insert(lines, "")
	table.insert(lines, "ALL SYSTEMS NOMINAL")
	table.insert(lines, "STARTING ROCKETRIDE OS...")

	task.spawn(function()
		local buffer = {}
		for i, line in ipairs(lines) do
			table.insert(buffer, line)
			if #buffer > 14 then
				table.remove(buffer, 1)
			end
			textLabel.Text = table.concat(buffer, "\n")

			-- Uneven pace: bursts of speed, occasional stalls
			local roll = math.random()
			if roll < 0.7 then
				task.wait(0.01) -- fast
			elseif roll < 0.92 then
				task.wait(0.03) -- medium
			else
				task.wait(math.random(1, 3) / 10) -- brief stall
			end
		end
		task.wait(0.2)
		surfaceGui:Destroy()
		onDone()
	end)
end

----------------------------------------------------------------
-- CAMERA TRANSITION + SWAY
----------------------------------------------------------------

local ORIGINAL_CAMERA_TYPE = Enum.CameraType.Custom

function exitComputerView()
	-- Restore gameplay control: crosshair back, cursor hidden
	player.CameraMode = Enum.CameraMode.LockFirstPerson
	UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
	UserInputService.MouseIconEnabled = false
	setCrosshairVisible(true)
	setCharacterHidden(false)

	if swayConnection then
		swayConnection:Disconnect()
		swayConnection = nil
	end

	local existingOS = player.PlayerGui:FindFirstChild("RocketRideOS")
	if existingOS then
		existingOS:Destroy()
	end
	currentScreenPart = nil

	local character = player.Character
	local humanoidRootPart = character and character:FindFirstChild("HumanoidRootPart")
	if humanoidRootPart then
		local targetCFrame = humanoidRootPart.CFrame * CFrame.new(0, 2, 4)
		local tween = TweenService:Create(
			camera,
			TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ CFrame = CFrame.new(targetCFrame.Position, humanoidRootPart.Position) }
		)
		tween:Play()
		tween.Completed:Connect(function()
			camera.CameraType = ORIGINAL_CAMERA_TYPE
			player.CameraMinZoomDistance = 0.5
		end)
	else
		camera.CameraType = ORIGINAL_CAMERA_TYPE
	end
end

local function enterComputerView(screenPart)
	currentScreenPart = screenPart
	camera.CameraType = Enum.CameraType.Scriptable

	-- Crosshair off immediately; cursor stays hidden while the OS boots
	setCrosshairVisible(false)
	-- Hide the body for the whole terminal session
	setCharacterHidden(true)
	UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
	UserInputService.MouseIconEnabled = false

	local powerOnSound = Instance.new("Sound")
	powerOnSound.SoundId = "rbxassetid://107912558642322"
	powerOnSound.Volume = 0.6
	powerOnSound.Parent = screenPart
	powerOnSound:Play()

	local screenCFrame = screenPart.CFrame
	local targetPos = screenCFrame.Position + screenCFrame.LookVector * 2.2
	local targetCFrame = CFrame.new(targetPos, screenCFrame.Position)

	local tween = TweenService:Create(
		camera,
		TweenInfo.new(1.1, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
		{ CFrame = targetCFrame }
	)
	tween:Play()

	tween.Completed:Connect(function()
		-- Subtle camera sway for atmosphere
		local baseCFrame = camera.CFrame
		computerBaseCFrame = baseCFrame
		local startTime = tick()
		swayConnection = RunService.RenderStepped:Connect(function()
			if cameraBusy then
				-- A turn or shake is running: stay out of the way
				return
			end
			local t = tick() - startTime
			local offsetX = math.sin(t * 0.6) * 0.03
			local offsetY = math.sin(t * 0.9) * 0.02
			camera.CFrame = baseCFrame * CFrame.new(offsetX, offsetY, 0)
		end)

		playBootSequence(screenPart, function()
			-- If the player left (Escape) during boot, do not build the desktop
			if currentScreenPart ~= screenPart then
				return
			end
			-- OS has booted: only now hand the mouse to the player
			player.CameraMode = Enum.CameraMode.Classic
			UserInputService.MouseBehavior = Enum.MouseBehavior.Default
			UserInputService.MouseIconEnabled = true
			buildDesktopOS()
		end)
	end)
end

openUIEvent.OnClientEvent:Connect(function(screenPart)
	enterComputerView(screenPart)
end)

----------------------------------------------------------------
-- DEMO HOTKEYS
--
-- They only work while the player is seated at the terminal.
-- The key is sent to the server so world effects run exactly
-- the same way as on a real Oracle reply.
----------------------------------------------------------------

local HOTKEY_ACTIONS = {
	[Enum.KeyCode.One] = "FLICKER_LIGHTS",
	[Enum.KeyCode.Two] = "SPAWN_SHADOW",
	[Enum.KeyCode.Three] = "FORCE_TURN",
	[Enum.KeyCode.Four] = "SHAKE_ROOM",
	[Enum.KeyCode.Five] = "CHANGE_SCREEN",
	[Enum.KeyCode.Six] = "BLACKOUT",
	[Enum.KeyCode.Seven] = "LOCK_DOOR",
	[Enum.KeyCode.Zero] = "UNLOCK",
}

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	-- IMPORTANT: gameProcessed is deliberately NOT checked here.
	-- The fullscreen OS marks keys as already handled, which made
	-- the hotkeys fail silently.
	-- Instead we explicitly check whether a text box has focus.
	if UserInputService:GetFocusedTextBox() ~= nil then
		return
	end

	local action = HOTKEY_ACTIONS[input.KeyCode]
	if not action then
		return
	end

	if not currentScreenPart then
		print("[Oracle] key", action, "ignored: player is not at the terminal")
		return
	end

	print("[Oracle] hotkey ->", action)
	setDebugStatus("KEY -> " .. action)

	-- Camera and screen effects start on the client immediately,
	-- without waiting for the server
	local effect = clientEffects[action]
	if effect then
		task.spawn(effect)
	end

	-- Tell the server too: lights, shadow and the exit lock live there
	debugEvent:FireServer(action)
end)

-- Escape also closes the OS and restores the camera
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then
		return
	end
	if input.KeyCode == Enum.KeyCode.Escape and currentScreenPart then
		if isLocked then
			-- LOCK_DOOR: the exit is blocked
			return
		end
		closeUIEvent:FireServer()
		exitComputerView()
	end
end)

----------------------------------------------------------------
-- FIRST PERSON VIEW + WALKING SWAY
----------------------------------------------------------------

player.CameraMode = Enum.CameraMode.LockFirstPerson
UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
UserInputService.MouseIconEnabled = false
setCrosshairVisible(true)

----------------------------------------------------------------
-- MUTE THE DEFAULT CHARACTER SOUNDS
-- (connected ONCE, not every frame)
----------------------------------------------------------------

local function silenceCharacterSounds(character)
	for _, obj in ipairs(character:GetDescendants()) do
		if obj:IsA("Sound") then
			obj.Volume = 0
		end
	end
	character.DescendantAdded:Connect(function(obj)
		if obj:IsA("Sound") then
			obj.Volume = 0
		end
	end)
end

if player.Character then
	silenceCharacterSounds(player.Character)
end
player.CharacterAdded:Connect(function(character)
	silenceCharacterSounds(character)
	-- If the player respawned while seated, hide the new body too
	if characterHidden then
		task.wait(0.2)
		applyCharacterTransparency()
	end
end)

----------------------------------------------------------------
-- WALKING CAMERA SWAY + MOUSE LOCK OUTSIDE THE TERMINAL
----------------------------------------------------------------

local bobTime = 0

local function getHumanoid()
	local character = player.Character
	return character and character:FindFirstChildOfClass("Humanoid")
end

RunService.RenderStepped:Connect(function(deltaTime)
	if currentScreenPart then
		-- At the terminal: no sway and do not touch the mouse
		return
	end

	-- Away from the terminal the mouse is always locked to centre
	if UserInputService.MouseBehavior ~= Enum.MouseBehavior.LockCenter then
		UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
	end

	local humanoid = getHumanoid()
	if not humanoid then
		return
	end

	local speed = humanoid.MoveDirection.Magnitude * humanoid.WalkSpeed

	if speed > 0.5 then
		bobTime = bobTime + deltaTime * (speed / 4)
		local bobX = math.sin(bobTime * 2) * 0.03
		local bobY = math.abs(math.sin(bobTime * 4)) * 0.05
		humanoid.CameraOffset = Vector3.new(bobX, bobY, 0)
	else
		humanoid.CameraOffset = humanoid.CameraOffset:Lerp(Vector3.new(0, 0, 0), deltaTime * 8)
	end
end)
