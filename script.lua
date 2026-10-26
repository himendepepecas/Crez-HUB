--// CREZ hub | Roblox | executor
-- SAFE MODE: launcher pergunta antes de carregar. ON = zero hookmetamethod/hookfunction e features server-visible travadas.
-- pular o launcher: getgenv().CrezSafe = true / false antes do loadstring (autoexec)
local env = (getgenv and getgenv()) or _G
if env.CrezHub and env.CrezHub.Unload then pcall(env.CrezHub.Unload) end
if not game:IsLoaded() then game.Loaded:Wait() end

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")
local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")
local VirtualUser = game:GetService("VirtualUser")
local StarterGui = game:GetService("StarterGui")
local GuiService = game:GetService("GuiService")
local Stats = game:GetService("Stats")
local TweenService = game:GetService("TweenService")
local VIM
pcall(function() VIM = game:GetService("VirtualInputManager") end)

local LP = Players.LocalPlayer
while not LP do task.wait() LP = Players.LocalPlayer end
local Mouse = LP:GetMouse()
local function cam() return Workspace.CurrentCamera end

----------------------------------------------------------------------
-- base
----------------------------------------------------------------------
local T = {
	bg = Color3.fromRGB(13, 13, 16),
	side = Color3.fromRGB(17, 17, 20),
	sec = Color3.fromRGB(22, 22, 26),
	elem = Color3.fromRGB(32, 32, 37),
	stroke = Color3.fromRGB(44, 44, 50),
	text = Color3.fromRGB(228, 228, 232),
	dim = Color3.fromRGB(128, 128, 138),
	accent = Color3.fromRGB(230, 30, 30),
	defaults = {},
	version = "BETA 1.0",
	scale = 1,
}
local FONT, FONTB = Enum.Font.GothamMedium, Enum.Font.GothamBold

local F, Elements, Refreshers, Conns = {}, {}, {}, {}
local Cleanups = {}
local Unloaded = false
local Unload
local ActiveDrag, Binding, drag
local Pop, PopScale -- color picker popup (created below)

local function on(sig, fn) local c = sig:Connect(fn) Conns[#Conns + 1] = c return c end
local function reg(fn) Refreshers[#Refreshers + 1] = fn fn() end
local function refreshAll() for _, r in ipairs(Refreshers) do r() end end
local notify
do
	local lastMsg, lastT = nil, 0
	notify = function(msg)
		if F.ui_notify == false then return end
		msg = tostring(msg)
		if msg == lastMsg and tick() - lastT < 1.5 then return end
		lastMsg, lastT = msg, tick()
		pcall(function() StarterGui:SetCore("SendNotification", {Title = "CREZ", Text = msg, Duration = 4}) end)
	end
end

local function mk(class, props)
	local i = Instance.new(class)
	local parent = props.Parent
	props.Parent = nil
	for k, v in pairs(props) do i[k] = v end
	i.Parent = parent
	return i
end
local function corner(p, r) return mk("UICorner", {CornerRadius = UDim.new(0, r or 3), Parent = p}) end
local function stroke(p, c, t) return mk("UIStroke", {Color = c, Thickness = t or 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = p}) end
local function pad(p, l, t, r, b)
	return mk("UIPadding", {PaddingLeft = UDim.new(0, l), PaddingTop = UDim.new(0, t), PaddingRight = UDim.new(0, r), PaddingBottom = UDim.new(0, b), Parent = p})
end
local function vlist(p, gap) return mk("UIListLayout", {Padding = UDim.new(0, gap or 0), SortOrder = Enum.SortOrder.LayoutOrder, Parent = p}) end
local function label(parent, text, size, color, font, xa)
	return mk("TextLabel", {BackgroundTransparency = 1, Text = text, TextSize = size or 12, TextColor3 = color or T.text,
		Font = font or FONT, TextXAlignment = xa or Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Parent = parent})
end
local function guiParent()
	if gethui then local ok, h = pcall(gethui) if ok and h then return h end end
	local ok, cg = pcall(function() return game:GetService("CoreGui") end)
	if ok and cg then return cg end
	return LP:WaitForChild("PlayerGui")
end
local function rname() return HttpService:GenerateGUID(false) end
local function fmt(v)
	if v % 1 == 0 then return tostring(v) end
	local s = string.format("%.2f", v):gsub("0+$", ""):gsub("%.$", "")
	return s
end

local Null = setmetatable({Remove = function() end}, {__newindex = function() end})
local function D(class, props)
	if not Drawing then return Null end
	local ok, d = pcall(Drawing.new, class)
	if not ok then return Null end
	for k, v in pairs(props or {}) do d[k] = v end
	return d
end

local ErrSeen = {}
local function guard(name, fn)
	return function(...)
		local ok, err = pcall(fn, ...)
		if not ok and not ErrSeen[name] then
			ErrSeen[name] = tostring(err)
			warn("[CREZ] " .. name .. ": " .. tostring(err))
			notify(name .. " error: " .. tostring(err))
		end
	end
end

----------------------------------------------------------------------
-- safe mode: launcher + lock list
----------------------------------------------------------------------
-- flags travadas no safe mode: hooks, ou coisa que o server ve / anticheat checa (WalkSpeed, CFrame, velocity, sizes, Gravity, parts no character)
local RISKY = {}
for _, f in ipairs({
	-- hooks
	"silent_enabled", "silent_ray", "silent_mouse", "silent_cam", "silent_uis", "silent_magic", "ic_on",
	-- server-visible / detectable
	"hb_on",
	"char_speed_on", "char_jump_on", "char_inf", "char_bhop", "char_fly", "char_noclip", "char_spin",
	"tr_walkfling", "tr_invisfling", "tr_invis", "tr_dead", "tr_freeze", "tr_loopjump", "tr_follow", "tr_anti",
	"world_grav", "misc_clicktp",
	"fx_rep", "fx_scale", "fx_aura", "fx_trail", "fx_light", "fx_body",
}) do RISKY[f] = true end
local RISKY_BTN = {
	["Execute Infinite Yield"] = true, ["Fling selected player"] = true, ["Fling all players"] = true,
	["Teleport to player"] = true, ["Respawn in place"] = true, ["Sit"] = true,
}

local SAFE
if env.CrezSafe ~= nil then
	SAFE = (env.CrezSafe == true)
else
	SAFE = true
	local LG = mk("ScreenGui", {Name = rname(), ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 1000, ZIndexBehavior = Enum.ZIndexBehavior.Sibling})
	if syn and syn.protect_gui then pcall(syn.protect_gui, LG) end
	LG.Parent = guiParent()
	local box = mk("Frame", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(320, 196),
		BackgroundColor3 = T.bg, BorderSizePixel = 0, Parent = LG})
	corner(box, 4) stroke(box, T.stroke)
	local ttl = label(box, "CREZ", 22, T.accent, Enum.Font.GothamBlack)
	ttl.Position = UDim2.fromOffset(16, 10) ttl.Size = UDim2.new(1, -32, 0, 28)
	local sub = label(box, T.version .. "  /  launcher", 10, T.dim)
	sub.Position = UDim2.fromOffset(17, 38) sub.Size = UDim2.new(1, -32, 0, 12)

	local row = mk("TextButton", {Position = UDim2.fromOffset(16, 60), Size = UDim2.new(1, -32, 0, 24), BackgroundColor3 = T.sec, BorderSizePixel = 0,
		Text = "", AutoButtonColor = false, Parent = box})
	corner(row, 3) stroke(row, T.stroke)
	local rl = label(row, "Safe mode", 13, T.text, FONTB)
	rl.Position = UDim2.fromOffset(10, 0) rl.Size = UDim2.new(1, -60, 1, 0)
	local cb = mk("Frame", {Size = UDim2.fromOffset(14, 14), Position = UDim2.new(1, -24, 0.5, -7), BackgroundColor3 = T.accent, BorderSizePixel = 0, Parent = row})
	corner(cb, 2)
	local desc = label(box, "", 11, T.dim)
	desc.Position = UDim2.fromOffset(16, 90) desc.Size = UDim2.new(1, -32, 0, 56)
	desc.TextWrapped = true desc.TextYAlignment = Enum.TextYAlignment.Top desc.TextTruncate = Enum.TextTruncate.None
	local function paint()
		cb.BackgroundColor3 = SAFE and T.accent or T.elem
		desc.Text = SAFE
			and "ON: sem hookmetamethod / hookfunction / namecall. Silent Aim, Interceptor e tudo que o server ve ou o anticheat checa (speed, fly, noclip, hitbox, fling, gravity...) ficam travados. ESP, aimbot de camera, visuais e misc funcionam."
			or "OFF: tudo liberado, hooks incluidos. Risco de kick em jogo com anticheat."
	end
	paint()
	local go = mk("TextButton", {Position = UDim2.fromOffset(16, 154), Size = UDim2.new(1, -32, 0, 28), BackgroundColor3 = T.accent, BorderSizePixel = 0,
		Text = "Execute", Font = FONTB, TextSize = 13, TextColor3 = Color3.new(1, 1, 1), AutoButtonColor = false, Parent = box})
	corner(go, 3)
	local done = Instance.new("BindableEvent")
	row.MouseButton1Click:Connect(function() SAFE = not SAFE paint() end)
	go.MouseButton1Click:Connect(function() done:Fire() end)
	done.Event:Wait()
	LG:Destroy()
	done:Destroy()
end

----------------------------------------------------------------------
-- gui
----------------------------------------------------------------------
local Gui = mk("ScreenGui", {Name = rname(), ResetOnSpawn = false, IgnoreGuiInset = true, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, DisplayOrder = 999})
if syn and syn.protect_gui then pcall(syn.protect_gui, Gui) end
Gui.Parent = guiParent()
local Holder = mk("Folder", {Name = rname(), Parent = Gui})

local BASE_W, BASE_H = 660, 430
local Main = mk("Frame", {Name = rname(), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(BASE_W, BASE_H), BackgroundColor3 = T.bg, BorderSizePixel = 0, Parent = Gui})
local MainScale = mk("UIScale", {Parent = Main})
corner(Main, 4) stroke(Main, T.stroke)

local Side = mk("Frame", {Size = UDim2.new(0, 150, 1, 0), BackgroundColor3 = T.side, BorderSizePixel = 0, Parent = Main})
corner(Side, 4)
mk("Frame", {Size = UDim2.new(0, 6, 1, 0), Position = UDim2.new(1, -6, 0, 0), BackgroundColor3 = T.side, BorderSizePixel = 0, Parent = Side})
mk("Frame", {Size = UDim2.new(0, 1, 1, 0), Position = UDim2.new(1, -1, 0, 0), BackgroundColor3 = T.stroke, BorderSizePixel = 0, Parent = Side})

local LogoArea = mk("Frame", {Size = UDim2.new(1, 0, 0, 66), BackgroundTransparency = 1, Parent = Side})
local Logo = label(LogoArea, "CREZ", 26, T.accent, Enum.Font.GothamBlack)
Logo.Position = UDim2.new(0, 16, 0, 10) Logo.Size = UDim2.new(1, -16, 0, 30)
local Sub = label(LogoArea, T.version .. "  /  roblox" .. (SAFE and "  /  safe" or ""), 10, T.dim)
Sub.Position = UDim2.new(0, 17, 0, 40) Sub.Size = UDim2.new(1, -16, 0, 12)
reg(function() Logo.TextColor3 = T.accent end)

local TabList = mk("ScrollingFrame", {Position = UDim2.new(0, 0, 0, 70), Size = UDim2.new(1, 0, 1, -76), BackgroundTransparency = 1,
	BorderSizePixel = 0, ScrollBarThickness = 0, AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(),
	ScrollingDirection = Enum.ScrollingDirection.Y, Parent = Side})
vlist(TabList, 2)

local Content = mk("Frame", {Position = UDim2.new(0, 151, 0, 0), Size = UDim2.new(1, -151, 1, 0), BackgroundTransparency = 1, ClipsDescendants = true, Parent = Main})
local Top = mk("Frame", {Size = UDim2.new(1, 0, 0, 36), BackgroundTransparency = 1, Parent = Content})
local Title = label(Top, "", 14, T.text, FONTB)
Title.Position = UDim2.new(0, 14, 0, 0) Title.Size = UDim2.new(1, -56, 1, 0)
mk("Frame", {Size = UDim2.new(1, -20, 0, 1), Position = UDim2.new(0, 10, 0, 35), BackgroundColor3 = T.stroke, BorderSizePixel = 0, Parent = Top})
local CloseBtn = mk("TextButton", {Size = UDim2.fromOffset(22, 22), Position = UDim2.new(1, -32, 0, 7), BackgroundColor3 = T.elem, BorderSizePixel = 0,
	Text = "x", Font = FONTB, TextSize = 12, TextColor3 = T.text, AutoButtonColor = false, Parent = Top})
corner(CloseBtn, 3)
local Pages = mk("Frame", {Position = UDim2.new(0, 0, 0, 38), Size = UDim2.new(1, 0, 1, -62), BackgroundTransparency = 1, Parent = Content})
local Foot = label(Content, "", 11, T.dim, FONT, Enum.TextXAlignment.Center)
Foot.Position = UDim2.new(0, 0, 1, -20) Foot.Size = UDim2.new(1, 0, 0, 18)

local function setMenu(v)
	Main.Visible = v
	if v then
		MainScale.Scale = T.scale * 0.94
		TweenService:Create(MainScale, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Scale = T.scale}):Play()
	end
	if not v and Pop then Pop.Visible = false end
end
on(CloseBtn.MouseButton1Click, function() setMenu(false) end)

if UIS.TouchEnabled and not UIS.KeyboardEnabled then
	local tb = mk("TextButton", {Size = UDim2.fromOffset(42, 42), Position = UDim2.new(0, 12, 0.5, -21), BackgroundColor3 = T.bg, Text = "C",
		Font = Enum.Font.GothamBlack, TextSize = 20, TextColor3 = T.accent, AutoButtonColor = false, Parent = Gui})
	corner(tb, 21) stroke(tb, T.stroke)
	on(tb.MouseButton1Click, function() setMenu(not Main.Visible) end)
end

----------------------------------------------------------------------
-- input helpers (drag / keybinds)
----------------------------------------------------------------------
local function ptr(i)
	if i.UserInputType == Enum.UserInputType.Touch then
		local inset = GuiService:GetGuiInset()
		return Vector2.new(i.Position.X + inset.X, i.Position.Y + inset.Y)
	end
	return UIS:GetMouseLocation()
end
local function isPress(i) return i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch end

local function makeDrag(fr)
	on(fr.InputBegan, function(i)
		if isPress(i) then drag = {ptr(i), Main.Position} end
	end)
end
makeDrag(Top) makeDrag(LogoArea)
on(UIS.InputChanged, function(i)
	if i.UserInputType ~= Enum.UserInputType.MouseMovement and i.UserInputType ~= Enum.UserInputType.Touch then return end
	if drag then
		local d = ptr(i) - drag[1]
		Main.Position = UDim2.new(drag[2].X.Scale, drag[2].X.Offset + d.X, drag[2].Y.Scale, drag[2].Y.Offset + d.Y)
	elseif ActiveDrag then
		ActiveDrag(ptr(i))
	end
end)
on(UIS.InputEnded, function(i)
	if isPress(i) then drag = nil ActiveDrag = nil end
end)

local BindEnum = {}
local function bindEnum(name)
	local e = BindEnum[name]
	if e == nil then
		local ok, v = pcall(function()
			if name:sub(1, 5) == "Mouse" then return Enum.UserInputType[name] end
			return Enum.KeyCode[name]
		end)
		e = (ok and v) or false
		BindEnum[name] = e
	end
	return e
end
local function bindDown(name)
	if not name or name == "None" then return true end
	local e = bindEnum(name)
	if not e then return false end
	if e.EnumType == Enum.UserInputType then return UIS:IsMouseButtonPressed(e) end
	return UIS:IsKeyDown(e)
end

----------------------------------------------------------------------
-- color picker (hue ring + saturation/value square)
----------------------------------------------------------------------
local openPicker
do
local PW, PH = 220, 280
local WHEEL, CX, CY = 200, 100, 100
local ROUT, RIN = 96, 78
local RMID = (ROUT + RIN) / 2
local SQ = math.floor(2 * (RIN - 6) / math.sqrt(2))

Pop = mk("Frame", {Name = rname(), Size = UDim2.fromOffset(PW, PH), BackgroundColor3 = T.bg, BorderSizePixel = 0, Visible = false, Active = true, Parent = Gui})
corner(Pop, 4) stroke(Pop, T.stroke)
PopScale = mk("UIScale", {Parent = Pop})
local PTitle = label(Pop, "Color", 12, T.text, FONTB)
PTitle.Position = UDim2.fromOffset(12, 6) PTitle.Size = UDim2.new(1, -44, 0, 20)
local PClose = mk("TextButton", {Size = UDim2.fromOffset(20, 20), Position = UDim2.new(1, -28, 0, 6), BackgroundColor3 = T.elem, BorderSizePixel = 0,
	Text = "x", Font = FONTB, TextSize = 12, TextColor3 = T.text, AutoButtonColor = false, Parent = Pop})
corner(PClose, 3)
on(PClose.MouseButton1Click, function() Pop.Visible = false end)

local Wheel = mk("Frame", {Size = UDim2.fromOffset(WHEEL, WHEEL), Position = UDim2.new(0.5, -WHEEL / 2, 0, 32), BackgroundTransparency = 1, Parent = Pop})
local NSEG = 96
for k = 0, NSEG - 1 do
	local a = (k + 0.5) / NSEG * math.pi * 2
	mk("Frame", {AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(ROUT - RIN + 2, math.ceil(2 * math.pi * RMID / NSEG) + 2),
		Position = UDim2.fromOffset(CX + math.cos(a) * RMID, CY + math.sin(a) * RMID), Rotation = math.deg(a),
		BackgroundColor3 = Color3.fromHSV((k + 0.5) / NSEG, 1, 1), BorderSizePixel = 0, Parent = Wheel})
end
local SV = mk("Frame", {Size = UDim2.fromOffset(SQ, SQ), Position = UDim2.fromOffset(CX - SQ / 2, CY - SQ / 2), BackgroundColor3 = Color3.new(1, 0, 0), BorderSizePixel = 0, Parent = Wheel})
corner(SV, 3)
local satL = mk("Frame", {Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, Parent = SV})
corner(satL, 3)
mk("UIGradient", {Transparency = NumberSequence.new(0, 1), Parent = satL})
local valL = mk("Frame", {Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0, Parent = SV})
corner(valL, 3)
mk("UIGradient", {Rotation = 90, Transparency = NumberSequence.new(1, 0), Parent = valL})
local RM = mk("Frame", {AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(12, 12), BackgroundTransparency = 1, Parent = Wheel})
corner(RM, 6) stroke(RM, Color3.new(1, 1, 1), 2)
local SM = mk("Frame", {AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(10, 10), BackgroundTransparency = 1, Parent = SV})
corner(SM, 5) stroke(SM, Color3.new(1, 1, 1), 2)
local WHit = mk("TextButton", {Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "", AutoButtonColor = false, Parent = Wheel})

local Prev = mk("Frame", {Size = UDim2.fromOffset(34, 24), Position = UDim2.fromOffset(12, 242), BackgroundColor3 = Color3.new(1, 0, 0), BorderSizePixel = 0, Parent = Pop})
corner(Prev, 3) stroke(Prev, T.stroke)
local Hex = mk("TextBox", {Size = UDim2.fromOffset(84, 24), Position = UDim2.fromOffset(52, 242), BackgroundColor3 = T.elem, BorderSizePixel = 0,
	Text = "", ClearTextOnFocus = false, Font = FONT, TextSize = 12, TextColor3 = T.text, PlaceholderText = "#RRGGBB", Parent = Pop})
corner(Hex, 3) stroke(Hex, T.stroke)
local Rgb = label(Pop, "", 11, T.dim, FONT, Enum.TextXAlignment.Left)
Rgb.Position = UDim2.fromOffset(144, 242) Rgb.Size = UDim2.fromOffset(70, 24)

local PK = {h = 0, s = 1, v = 1, set = nil, mode = nil}
local function pkRender(fire)
	local col = Color3.fromHSV(PK.h, PK.s, PK.v)
	SV.BackgroundColor3 = Color3.fromHSV(PK.h, 1, 1)
	local a = PK.h * math.pi * 2
	RM.Position = UDim2.fromOffset(CX + math.cos(a) * RMID, CY + math.sin(a) * RMID)
	SM.Position = UDim2.fromScale(PK.s, 1 - PK.v)
	Prev.BackgroundColor3 = col
	local r, g, b = math.floor(col.R * 255 + 0.5), math.floor(col.G * 255 + 0.5), math.floor(col.B * 255 + 0.5)
	Hex.Text = string.format("#%02X%02X%02X", r, g, b)
	Rgb.Text = r .. ", " .. g .. ", " .. b
	if fire and PK.set then PK.set(col) end
end
local function wheelInput(p)
	if PK.mode == "ring" then
		local ac = Wheel.AbsolutePosition + Wheel.AbsoluteSize / 2
		local d = p - ac
		PK.h = (math.atan2(d.Y, d.X) / (math.pi * 2)) % 1
	elseif PK.mode == "sv" then
		PK.s = math.clamp((p.X - SV.AbsolutePosition.X) / SV.AbsoluteSize.X, 0, 1)
		PK.v = 1 - math.clamp((p.Y - SV.AbsolutePosition.Y) / SV.AbsoluteSize.Y, 0, 1)
	end
	pkRender(true)
end
on(WHit.InputBegan, function(i)
	if not isPress(i) then return end
	local p = ptr(i)
	local sp, sz = SV.AbsolutePosition, SV.AbsoluteSize
	local ac = Wheel.AbsolutePosition + Wheel.AbsoluteSize / 2
	local sc = Wheel.AbsoluteSize.X / WHEEL
	local rad = (p - ac).Magnitude / sc
	if p.X >= sp.X and p.X <= sp.X + sz.X and p.Y >= sp.Y and p.Y <= sp.Y + sz.Y then
		PK.mode = "sv"
	elseif rad >= RIN - 8 and rad <= ROUT + 8 then
		PK.mode = "ring"
	else
		return
	end
	wheelInput(p)
	ActiveDrag = wheelInput
end)
on(Hex.FocusLost, function()
	local r, g, b = Hex.Text:match("^#?(%x%x)(%x%x)(%x%x)$")
	if r then
		local c = Color3.fromRGB(tonumber(r, 16), tonumber(g, 16), tonumber(b, 16))
		PK.h, PK.s, PK.v = c:ToHSV()
	end
	pkRender(r ~= nil)
end)

function openPicker(col, setter, title)
	PK.set = nil
	PK.h, PK.s, PK.v = col:ToHSV()
	pkRender(false)
	PK.set = setter
	PTitle.Text = title or "Color"
	local sc = MainScale.Scale
	local c = cam()
	local vp = c and c.ViewportSize or Vector2.new(1280, 720)
	local w, hgt = PW * sc, PH * sc
	local mx, my, mw = Main.AbsolutePosition.X, Main.AbsolutePosition.Y, Main.AbsoluteSize.X
	local x = mx + mw + 8
	if x + w > vp.X then x = mx - w - 8 end
	if x < 4 then x = math.clamp(vp.X - w - 8, 4, math.max(4, vp.X)) end
	local y = math.clamp(my, 4, math.max(4, vp.Y - hgt - 4))
	Pop.Position = UDim2.fromOffset(x, y)
	Pop.Visible = true
end
end

local lastVP, lastUS
local function fit(force)
	local c = cam()
	local vp = c and c.ViewportSize or Vector2.new(1280, 720)
	local us = F.ui_scale or 1
	if not force and vp == lastVP and us == lastUS then return end
	lastVP, lastUS = vp, us
	local maxFit = math.min((vp.X - 20) / BASE_W, (vp.Y - 20) / BASE_H)
	local s = math.max(0.4, math.min(math.clamp(us, 0.5, 1.4), maxFit))
	MainScale.Scale = s
	PopScale.Scale = s
	T.scale = s
end

----------------------------------------------------------------------
-- ui lib: tabs / sections / elements
----------------------------------------------------------------------
local Tab, Section = {}, {}
Tab.__index = Tab
Section.__index = Section
local Tabs, lastGroup, sideOrd, Active = {}, nil, 0, nil
local KBList = {}
local function sideNext() sideOrd += 1 return sideOrd end

local function selectTab(tab)
	Active = tab
	for _, t in ipairs(Tabs) do t.page.Visible = (t == tab) end
	Title.Text = tab.name
	Pop.Visible = false
	refreshAll()
end

local function newTab(name, group)
	if group ~= lastGroup then
		lastGroup = group
		local g = label(TabList, group, 11, T.dim)
		g.Size = UDim2.new(1, 0, 0, 22) g.LayoutOrder = sideNext() g.TextYAlignment = Enum.TextYAlignment.Bottom
		pad(g, 14, 0, 0, 3)
	end
	local btn = mk("TextButton", {Size = UDim2.new(1, 0, 0, 28), BackgroundColor3 = T.sec, BackgroundTransparency = 1, BorderSizePixel = 0,
		Text = "", AutoButtonColor = false, LayoutOrder = sideNext(), Parent = TabList})
	local marker = mk("Frame", {Size = UDim2.new(0, 3, 1, 0), BackgroundColor3 = T.accent, BorderSizePixel = 0, Parent = btn})
	local icon = mk("Frame", {Size = UDim2.fromOffset(8, 8), Position = UDim2.new(0, 16, 0.5, -4), BackgroundColor3 = T.dim, BorderSizePixel = 0, Parent = btn})
	corner(icon, 2)
	local lbl = label(btn, name, 12, T.dim)
	lbl.Position = UDim2.new(0, 34, 0, 0) lbl.Size = UDim2.new(1, -34, 1, 0)

	local page = mk("ScrollingFrame", {Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 3,
		ScrollBarImageColor3 = T.stroke, AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(),
		ScrollingDirection = Enum.ScrollingDirection.Y, Visible = false, Parent = Pages})
	local cols = {}
	for c = 1, 2 do
		cols[c] = mk("Frame", {Size = UDim2.new(0.5, -16, 0, 0), Position = UDim2.new(c == 1 and 0 or 0.5, c == 1 and 10 or 2, 0, 6),
			AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, Parent = page})
		vlist(cols[c], 8)
		mk("Frame", {Size = UDim2.new(1, 0, 0, 8), BackgroundTransparency = 1, LayoutOrder = 9999, Parent = cols[c]})
	end

	local tab = setmetatable({name = name, page = page, cols = cols, cn = {0, 0}}, Tab)
	Tabs[#Tabs + 1] = tab
	on(btn.MouseButton1Click, function() selectTab(tab) end)
	reg(function()
		local a = (Active == tab)
		marker.Visible = a
		marker.BackgroundColor3 = T.accent
		icon.BackgroundColor3 = a and T.accent or T.dim
		lbl.TextColor3 = a and T.text or T.dim
		btn.BackgroundTransparency = a and 0 or 1
	end)
	return tab
end

function Tab:Section(title, col)
	self.cn[col] += 1
	local f = mk("Frame", {Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundColor3 = T.sec, BorderSizePixel = 0,
		LayoutOrder = self.cn[col], Parent = self.cols[col]})
	corner(f, 3) stroke(f, T.stroke) pad(f, 8, 8, 8, 8) vlist(f, 5)
	local head = mk("Frame", {Size = UDim2.new(1, 0, 0, 18), BackgroundTransparency = 1, LayoutOrder = 0, Parent = f})
	local ic = mk("Frame", {Size = UDim2.fromOffset(8, 8), Position = UDim2.new(0, 0, 0.5, -4), BackgroundColor3 = T.accent, BorderSizePixel = 0, Parent = head})
	corner(ic, 2)
	reg(function() ic.BackgroundColor3 = T.accent end)
	local l = label(head, title, 12, T.text, FONTB)
	l.Position = UDim2.new(0, 16, 0, 0) l.Size = UDim2.new(1, -34, 1, 0)
	local arrow = label(head, "v", 11, T.dim, FONT, Enum.TextXAlignment.Right)
	arrow.Size = UDim2.new(1, 0, 1, 0)
	local hbtn = mk("TextButton", {Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "", AutoButtonColor = false, Parent = head})
	local collapsed = false
	on(hbtn.MouseButton1Click, function()
		collapsed = not collapsed
		arrow.Text = collapsed and ">" or "v"
		for _, ch in ipairs(f:GetChildren()) do
			if ch ~= head and ch:IsA("GuiObject") then ch.Visible = not collapsed end
		end
	end)
	return setmetatable({frame = f, n = 0}, Section)
end
function Section:ord() self.n += 1 return self.n end

function Section:Label(text)
	local l = label(self.frame, text, 11, T.dim)
	l.Size = UDim2.new(1, 0, 0, 0) l.AutomaticSize = Enum.AutomaticSize.Y l.TextWrapped = true
	l.TextTruncate = Enum.TextTruncate.None l.LayoutOrder = self:ord()
	return l
end

function Section:Toggle(o)
	local locked = SAFE and RISKY[o.flag] or false
	F[o.flag] = (o.default == true) and not locked
	local kbf = o.flag .. "__kb"
	F[kbf] = "None"
	T.defaults[o.flag] = F[o.flag]
	T.defaults[kbf] = "None"
	local row = mk("TextButton", {Size = UDim2.new(1, 0, 0, 20), BackgroundTransparency = 1, Text = "", AutoButtonColor = false, LayoutOrder = self:ord(), Parent = self.frame})
	local lbl = label(row, o.text .. (locked and " (safe)" or ""), 12, T.dim)
	lbl.Size = UDim2.new(1, -76, 1, 0)
	local box = mk("Frame", {Size = UDim2.fromOffset(12, 12), Position = UDim2.new(1, -12, 0.5, -6), BackgroundColor3 = T.elem, BorderSizePixel = 0, Parent = row})
	corner(box, 2)
	local st = stroke(box, T.stroke)
	local kb = mk("TextButton", {Size = UDim2.fromOffset(46, 14), Position = UDim2.new(1, -66, 0.5, -7), BackgroundColor3 = T.elem, BorderSizePixel = 0,
		Font = FONT, TextSize = 10, TextColor3 = T.dim, AutoButtonColor = false, Text = "-", Parent = row})
	corner(kb, 3)
	local kst = stroke(kb, T.stroke)
	local function kshow()
		local k = F[kbf]
		kb.Text = (k == "None") and "-" or k:gsub("MouseButton", "M"):sub(1, 7)
		kb.TextColor3 = (k == "None") and T.dim or T.text
		kst.Color = T.stroke
	end
	kshow()
	local function refresh()
		local v = F[o.flag]
		box.BackgroundColor3 = v and T.accent or T.elem
		st.Color = v and T.accent or T.stroke
		lbl.TextColor3 = v and T.text or T.dim
	end
	reg(refresh)
	local function set(v)
		if locked and v then
			notify(o.text .. ": blocked by Safe mode")
			v = false
		end
		F[o.flag] = v and true or false
		refresh()
		if o.cb then pcall(o.cb, F[o.flag]) end
	end
	on(row.MouseButton1Click, function() set(not F[o.flag]) end)
	on(kb.MouseButton1Click, function()
		if Binding then Binding.cancel() end
		kb.Text = "..."
		kst.Color = T.accent
		Binding = {
			cancel = function() Binding = nil kshow() end,
			fn = function(name)
				if name == "Escape" or name == "Backspace" then name = "None" end
				F[kbf] = name
				kshow()
			end,
		}
	end)
	Elements[o.flag] = {Set = set}
	Elements[kbf] = {Set = function(v) F[kbf] = tostring(v) kshow() end}
	KBList[#KBList + 1] = {o.flag, kbf}
end

function Section:Slider(o)
	local min, max, step = o.min, o.max, o.step or 1
	F[o.flag] = o.default or min
	T.defaults[o.flag] = F[o.flag]
	local row = mk("Frame", {Size = UDim2.new(1, 0, 0, 30), BackgroundTransparency = 1, LayoutOrder = self:ord(), Parent = self.frame})
	local lbl = label(row, o.text, 12, T.dim)
	lbl.Size = UDim2.new(1, -56, 0, 14)
	local val = label(row, "", 12, T.text, FONT, Enum.TextXAlignment.Right)
	val.Size = UDim2.new(0, 56, 0, 14) val.Position = UDim2.new(1, -56, 0, 0)
	local bar = mk("Frame", {Size = UDim2.new(1, 0, 0, 4), Position = UDim2.new(0, 0, 0, 21), BackgroundColor3 = T.elem, BorderSizePixel = 0, Parent = row})
	corner(bar, 2)
	local fill = mk("Frame", {Size = UDim2.new(0, 0, 1, 0), BackgroundColor3 = T.accent, BorderSizePixel = 0, Parent = bar})
	corner(fill, 2)
	local hit = mk("TextButton", {Size = UDim2.new(1, 0, 0, 14), Position = UDim2.new(0, 0, 0, 16), BackgroundTransparency = 1, Text = "", Parent = row})
	local function render()
		local v = F[o.flag]
		fill.Size = UDim2.new((v - min) / (max - min), 0, 1, 0)
		val.Text = fmt(v) .. (o.suffix or "")
	end
	reg(function() fill.BackgroundColor3 = T.accent end)
	local function set(v)
		v = math.clamp(tonumber(v) or min, min, max)
		v = min + math.floor((v - min) / step + 0.5) * step
		v = tonumber(string.format("%.4f", math.clamp(v, min, max)))
		F[o.flag] = v
		render()
		if o.cb then pcall(o.cb, v) end
	end
	render()
	on(hit.InputBegan, function(i)
		if isPress(i) then
			local function fromX(p) set(min + (max - min) * math.clamp((p.X - bar.AbsolutePosition.X) / bar.AbsoluteSize.X, 0, 1)) end
			fromX(ptr(i))
			ActiveDrag = fromX
		end
	end)
	Elements[o.flag] = {Set = set}
end

function Section:Button(o)
	local locked = SAFE and RISKY_BTN[o.text] or false
	local b = mk("TextButton", {Size = UDim2.new(1, 0, 0, 24), BackgroundColor3 = T.elem, BorderSizePixel = 0, Text = o.text .. (locked and " (safe)" or ""), Font = FONT, TextSize = 12,
		TextColor3 = locked and T.dim or T.text, AutoButtonColor = false, LayoutOrder = self:ord(), Parent = self.frame})
	corner(b, 3)
	local st = stroke(b, T.stroke)
	on(b.MouseEnter, function() st.Color = T.accent end)
	on(b.MouseLeave, function() st.Color = T.stroke end)
	on(b.MouseButton1Click, function()
		if locked then return notify(o.text .. ": blocked by Safe mode") end
		pcall(o.cb)
	end)
end

function Section:Cycle(o)
	local locked = SAFE and RISKY[o.flag] or false
	F[o.flag] = o.default or o.options[1]
	if locked then F[o.flag] = o.options[1] end
	T.defaults[o.flag] = F[o.flag]
	local row = mk("Frame", {Size = UDim2.new(1, 0, 0, 22), BackgroundTransparency = 1, LayoutOrder = self:ord(), Parent = self.frame})
	local lbl = label(row, o.text .. (locked and " (safe)" or ""), 12, T.dim)
	lbl.Size = UDim2.new(1, -116, 1, 0)
	local btn = mk("TextButton", {Size = UDim2.new(0, 112, 0, 20), Position = UDim2.new(1, -112, 0.5, -10), BackgroundColor3 = T.elem, BorderSizePixel = 0,
		Font = FONT, TextSize = 11, TextColor3 = T.text, AutoButtonColor = false, Text = "", TextTruncate = Enum.TextTruncate.AtEnd, Parent = row})
	corner(btn, 3) stroke(btn, T.stroke)
	local function set(v)
		if not table.find(o.options, v) then return end
		if locked and v ~= o.options[1] then
			notify(o.text .. ": blocked by Safe mode")
			v = o.options[1]
		end
		F[o.flag] = v
		btn.Text = v .. "  >"
		if o.cb then pcall(o.cb, v) end
	end
	btn.Text = tostring(F[o.flag]) .. "  >"
	on(btn.MouseButton1Click, function()
		if #o.options == 0 then return end
		local idx = table.find(o.options, F[o.flag]) or 0
		set(o.options[idx % #o.options + 1])
	end)
	Elements[o.flag] = {Set = set}
end

function Section:Keybind(o)
	F[o.flag] = o.default or "None"
	T.defaults[o.flag] = F[o.flag]
	local row = mk("Frame", {Size = UDim2.new(1, 0, 0, 22), BackgroundTransparency = 1, LayoutOrder = self:ord(), Parent = self.frame})
	local lbl = label(row, o.text, 12, T.dim)
	lbl.Size = UDim2.new(1, -96, 1, 0)
	local btn = mk("TextButton", {Size = UDim2.new(0, 92, 0, 20), Position = UDim2.new(1, -92, 0.5, -10), BackgroundColor3 = T.elem, BorderSizePixel = 0,
		Font = FONT, TextSize = 11, TextColor3 = T.text, AutoButtonColor = false, Text = "", Parent = row})
	corner(btn, 3)
	local st = stroke(btn, T.stroke)
	local function show() btn.Text = "[" .. tostring(F[o.flag]) .. "]" st.Color = T.stroke end
	local function set(v)
		F[o.flag] = tostring(v)
		show()
		if o.cb then pcall(o.cb, F[o.flag]) end
	end
	show()
	on(btn.MouseButton1Click, function()
		if Binding then Binding.cancel() end
		btn.Text = "[ ... ]"
		st.Color = T.accent
		Binding = {
			cancel = function() Binding = nil show() end,
			fn = function(name)
				if name == "Escape" or name == "Backspace" then name = o.required and F[o.flag] or "None" end
				set(name)
			end,
		}
	end)
	Elements[o.flag] = {Set = set}
end

function Section:Color(o)
	F[o.flag] = o.default or Color3.fromRGB(230, 30, 30)
	T.defaults[o.flag] = F[o.flag]
	local row = mk("Frame", {Size = UDim2.new(1, 0, 0, 22), BackgroundTransparency = 1, LayoutOrder = self:ord(), Parent = self.frame})
	local lbl = label(row, o.text, 12, T.dim)
	lbl.Size = UDim2.new(1, -46, 1, 0)
	local sw = mk("TextButton", {Size = UDim2.new(0, 38, 0, 16), Position = UDim2.new(1, -38, 0.5, -8), BackgroundColor3 = F[o.flag], BorderSizePixel = 0,
		Text = "", AutoButtonColor = false, Parent = row})
	corner(sw, 3)
	local st = stroke(sw, T.stroke)
	on(sw.MouseEnter, function() st.Color = T.accent end)
	on(sw.MouseLeave, function() st.Color = T.stroke end)
	local function set(c)
		F[o.flag] = c
		sw.BackgroundColor3 = c
		if o.cb then pcall(o.cb, c) end
	end
	on(sw.MouseButton1Click, function() openPicker(F[o.flag], set, o.text) end)
	Elements[o.flag] = {Set = set}
end

function Section:TextInput(o)
	F[o.flag] = ""
	local tb = mk("TextBox", {Size = UDim2.new(1, 0, 0, 24), BackgroundColor3 = T.elem, BorderSizePixel = 0, Text = "", PlaceholderText = o.placeholder or "",
		PlaceholderColor3 = T.dim, ClearTextOnFocus = false, Font = FONT, TextSize = 12, TextColor3 = T.text, TextXAlignment = Enum.TextXAlignment.Left,
		LayoutOrder = self:ord(), Parent = self.frame})
	corner(tb, 3) stroke(tb, T.stroke) pad(tb, 6, 0, 6, 0)
	on(tb:GetPropertyChangedSignal("Text"), function() F[o.flag] = tb.Text end)
	Elements[o.flag] = {Set = function(v) tb.Text = tostring(v) end, nosave = true}
end

function Section:List(o)
	F[o.flag] = o.default or ""
	local box = mk("ScrollingFrame", {Size = UDim2.new(1, 0, 0, o.height or 120), BackgroundColor3 = T.elem, BorderSizePixel = 0, ScrollBarThickness = 3,
		ScrollBarImageColor3 = T.dim, AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(), ScrollingDirection = Enum.ScrollingDirection.Y,
		LayoutOrder = self:ord(), Parent = self.frame})
	corner(box, 3) stroke(box, T.stroke) pad(box, 3, 3, 6, 3) vlist(box, 2)
	local rows, api = {}, {items = {}}
	local function paint()
		for id, r in pairs(rows) do
			local sel = F[o.flag] == id
			r.btn.BackgroundColor3 = sel and T.accent or T.sec
			r.name.TextColor3 = sel and Color3.new(1, 1, 1) or T.text
			r.info.TextColor3 = sel and Color3.new(1, 1, 1) or T.dim
		end
	end
	reg(paint)
	local function pick(id)
		F[o.flag] = id
		paint()
		if o.cb then pcall(o.cb, id) end
	end
	function api.Refresh()
		local items = o.getItems()
		local seen = {}
		api.items = {}
		for i, it in ipairs(items) do
			seen[it.id] = true
			api.items[i] = it.id
			local r = rows[it.id]
			if not r then
				local btn = mk("TextButton", {Size = UDim2.new(1, 0, 0, 22), BackgroundColor3 = T.sec, BorderSizePixel = 0, Text = "", AutoButtonColor = false, Parent = box})
				corner(btn, 3)
				local nm = label(btn, "", 12, T.text)
				nm.Position = UDim2.new(0, 6, 0, 0) nm.Size = UDim2.new(1, -94, 1, 0)
				local inf = label(btn, "", 11, T.dim, FONT, Enum.TextXAlignment.Right)
				inf.Position = UDim2.new(1, -88, 0, 0) inf.Size = UDim2.new(0, 84, 1, 0)
				local id = it.id
				on(btn.MouseButton1Click, function() pick(id) end)
				r = {btn = btn, name = nm, info = inf}
				rows[it.id] = r
			end
			r.btn.LayoutOrder = i
			r.name.Text = it.text
			r.info.Text = it.info or ""
		end
		for id, r in pairs(rows) do
			if not seen[id] then r.btn:Destroy() rows[id] = nil end
		end
		paint()
	end
	Elements[o.flag] = {Set = function(v) F[o.flag] = v paint() end, Refresh = api.Refresh, nosave = true, api = api}
	api.Refresh()
end

----------------------------------------------------------------------
-- shared helpers
----------------------------------------------------------------------
local function hum() local c = LP.Character return c and c:FindFirstChildOfClass("Humanoid") end
local function hrp() local c = LP.Character return c and c:FindFirstChild("HumanoidRootPart") end
local function isTeam(plr) return plr.Team ~= nil and plr.Team == LP.Team end
local WL = {}
local function setProp(i, k, v) i[k] = v end

local lmbDown, lmbUntil = false, 0
local function shooting() return lmbDown or tick() < lmbUntil end

local AimCircle = D("Circle", {NumSides = 64, Thickness = 1, Filled = false, Transparency = 1, Visible = false})
local SilCircle = D("Circle", {NumSides = 64, Thickness = 1, Filled = false, Transparency = 1, Visible = false})
local SilLine = D("Line", {Thickness = 1, Transparency = 1, Visible = false})

----------------------------------------------------------------------
-- targeting
----------------------------------------------------------------------
local RP = RaycastParams.new()
RP.FilterType = Enum.RaycastFilterType.Exclude
RP.IgnoreWater = true

local function visible(c, part, char)
	local ign = {c}
	if LP.Character then ign[2] = LP.Character end
	local origin = c.CFrame.Position
	local dir = part.Position - origin
	for _ = 1, 4 do
		RP.FilterDescendantsInstances = ign
		local r = Workspace:Raycast(origin, dir, RP)
		if not r then return true end
		local hit = r.Instance
		if hit:IsDescendantOf(char) then return true end
		if hit.Transparency >= 0.9 or not hit.CanCollide then
			ign[#ign + 1] = hit
			origin = r.Position
			dir = part.Position - origin
		else
			return false
		end
	end
	return false
end

local NAMES = {
	Head = {"Head"},
	Torso = {"UpperTorso", "Torso"},
	Root = {"HumanoidRootPart"},
	Closest = {"Head", "UpperTorso", "Torso", "LowerTorso", "HumanoidRootPart"},
}

-- pre = "aim_" or "silent_"; lock = optional player to stay on (ignores FOV)
local function pickTarget(pre, lock)
	local c = cam()
	if not c then return end
	local mp = UIS:GetMouseLocation()
	local fov, prio, maxd = F[pre .. "fov"], F[pre .. "prio"], F[pre .. "dist"]
	local names = NAMES[F[pre .. "part"]] or NAMES.Head
	local cpos = c.CFrame.Position
	local bp, bplr, bch, bscore
	local wall = F[pre .. "wall"] and not (pre == "silent_" and F.silent_magic)
	local list
	if lock then list = {lock}
	elseif F[pre .. "onlysel"] then
		local sp = Players:FindFirstChild(F.tp_target or "")
		list = sp and {sp} or {}
	else list = Players:GetPlayers() end
	for _, plr in ipairs(list) do
		if plr ~= LP then
			local ch = plr.Character
			local h = ch and ch:FindFirstChildOfClass("Humanoid")
			local root = ch and ch:FindFirstChild("HumanoidRootPart")
			if h and root and h.Health > 0
				and not WL[plr.UserId]
				and not (F[pre .. "team"] and isTeam(plr))
				and not (F[pre .. "ff"] and ch:FindFirstChildOfClass("ForceField"))
				and (root.Position - cpos).Magnitude <= maxd then
				for _, n in ipairs(names) do
					local part = ch:FindFirstChild(n)
					if part and part:IsA("BasePart") then
						local sp, on_ = c:WorldToViewportPoint(part.Position)
						if on_ then
							local d = (Vector2.new(sp.X, sp.Y) - mp).Magnitude
							if d <= fov or lock then
								local score = d
								if prio == "Distance" then score = (part.Position - cpos).Magnitude
								elseif prio == "Health" then score = h.Health end
								if (bscore == nil or score < bscore) and (not wall or visible(c, part, ch)) then
									bp, bplr, bch, bscore = part, plr, ch, score
								end
							end
						end
					end
				end
			end
		end
	end
	if not bp then return end
	local vel = bch.HumanoidRootPart.AssemblyLinearVelocity
	return bp, bp.Position + vel * F[pre .. "pred"], bplr, bch
end

----------------------------------------------------------------------
-- silent aim hooks (installed lazily, once per executor session) - nunca instalados no safe mode
----------------------------------------------------------------------
local HK = env.CrezHooks
if not HK then HK = {} env.CrezHooks = HK end
if HK.ver ~= 2 then HK.nc, HK.idx, HK.ver = nil, nil, 2 end
HK.cur, HK.F, HK.mouse, HK.ws, HK.uis, HK.cam, HK.inset = nil, F, Mouse, Workspace, UIS, nil, 0
HK.cnt = {ray = 0, fpr = 0, cam = 0, mouse = 0, uis = 0}
HK.mbp = RaycastParams.new()
HK.mbp.FilterType = Enum.RaycastFilterType.Include
HK.mbp.IgnoreWater = true

local ensureHooks
do
local wrapC = newcclosure or function(f) return f end
local hookWarned = false

local function installNC()
	if HK.nc then return end
	local old
	old = hookmetamethod(game, "__namecall", wrapC(function(self, ...)
		local cur = HK.cur
		if cur == nil then return old(self, ...) end
		local method = getnamecallmethod()
		if checkcaller() then return old(self, ...) end
		local fl = HK.F
		if not fl then return old(self, ...) end
		if self == HK.ws then
			if fl.silent_ray then
				if method == "Raycast" then
					local a = table.pack(...)
					local o, d = a[1], a[2]
					if typeof(o) == "Vector3" and typeof(d) == "Vector3" then
						local v = cur.pos - o
						if v.Magnitude > 0.001 then
							HK.cnt.ray += 1
							if fl.silent_magic and cur.char then
								local ok, r = pcall(HK.ws.Raycast, HK.ws, o, v.Unit * math.max(d.Magnitude, v.Magnitude + 5), HK.mbp)
								if ok and r then return r end
							end
							a[2] = v.Unit * d.Magnitude
							return old(self, table.unpack(a, 1, a.n))
						end
					end
				elseif method == "FindPartOnRay" or method == "FindPartOnRayWithIgnoreList" or method == "FindPartOnRayWithWhitelist" then
					local a = table.pack(...)
					local r = a[1]
					if typeof(r) == "Ray" then
						local v = cur.pos - r.Origin
						if v.Magnitude > 0.001 then
							HK.cnt.fpr += 1
							if fl.silent_magic and cur.char then
								local nr = Ray.new(r.Origin, v.Unit * math.max(r.Direction.Magnitude, v.Magnitude + 5))
								local ok, p, ps, nm, mt = pcall(HK.ws.FindPartOnRayWithWhitelist, HK.ws, nr, {cur.char}, true)
								if ok and p then return p, ps, nm, mt end
							end
							a[1] = Ray.new(r.Origin, v.Unit * r.Direction.Magnitude)
							return old(self, table.unpack(a, 1, a.n))
						end
					end
				end
			end
		elseif self == HK.cam then
			if fl.silent_cam and (method == "ScreenPointToRay" or method == "ViewportPointToRay") then
				HK.cnt.cam += 1
				local r = old(self, ...)
				local v = cur.pos - r.Origin
				if v.Magnitude > 0.001 then return Ray.new(r.Origin, v.Unit * r.Direction.Magnitude) end
				return r
			end
		elseif self == HK.uis then
			if fl.silent_uis and method == "GetMouseLocation" then HK.cnt.uis += 1 return cur.sp end
		end
		return old(self, ...)
	end))
	HK.nc = true
end

local function installIdx()
	if HK.idx then return end
	local old
	old = hookmetamethod(game, "__index", wrapC(function(self, key)
		local cur = HK.cur
		if cur ~= nil and self == HK.mouse and not checkcaller() then
			local fl = HK.F
			if fl then
				if fl.silent_mouse then
					if key == "Hit" or key == "hit" then HK.cnt.mouse += 1 return CFrame.new(cur.pos)
					elseif key == "Target" or key == "target" then return cur.part
					elseif key == "UnitRay" and HK.cam then
						local o = HK.cam.CFrame.Position
						local v = cur.pos - o
						if v.Magnitude > 0.001 then return Ray.new(o, v.Unit) end
					end
				end
				if fl.silent_uis then
					if key == "X" then HK.cnt.uis += 1 return math.floor(cur.sp.X)
					elseif key == "Y" then return math.floor(cur.sp.Y - HK.inset) end
				end
			end
		end
		return old(self, key)
	end))
	HK.idx = true
end

function ensureHooks()
	if SAFE then
		if not hookWarned then hookWarned = true notify("Safe mode: hooks disabled") end
		return
	end
	if not (hookmetamethod and getnamecallmethod and checkcaller) then
		if not hookWarned then hookWarned = true notify("Executor lacks hookmetamethod/getnamecallmethod: Silent Aim unavailable") end
		return
	end
	local ok = true
	if (F.silent_ray or F.silent_cam or F.silent_uis) and not HK.nc then ok = pcall(installNC) and ok end
	if (F.silent_mouse or F.silent_uis) and not HK.idx then ok = pcall(installIdx) and ok end
	if not ok and not hookWarned then hookWarned = true notify("Silent Aim hook failed to install") end
end
end

----------------------------------------------------------------------
-- aimbot / silent / trigger / hitbox
----------------------------------------------------------------------
local AimLock
local function aimStep(dt)
	AimCircle.Visible = false
	if not F.aim_enabled then AimLock = nil return end
	local mp = UIS:GetMouseLocation()
	if F.aim_showfov then
		AimCircle.Position = mp AimCircle.Radius = F.aim_fov AimCircle.Color = F.aim_fovcolor AimCircle.Visible = true
	end
	if not bindDown(F.aim_key) then AimLock = nil return end
	local part, pos, plr
	if F.aim_sticky and AimLock then part, pos, plr = pickTarget("aim_", AimLock) end
	if not part then part, pos, plr = pickTarget("aim_") end
	AimLock = F.aim_sticky and plr or nil
	if not part then return end
	local c = cam()
	local alpha = math.clamp((1 - F.aim_smooth / 100) * dt * 60, 0.005, 1)
	if F.aim_method == "Camera" then
		local sm = HK.sm
		local cf = c.CFrame
		if sm then cf = cf * CFrame.new(0, 0, 0, 1 / sm[1], 0, 0, 0, 1 / sm[2], 0, 0, 0, 1) end
		local nf = cf:Lerp(CFrame.lookAt(cf.Position, pos), alpha)
		if sm then nf = nf * CFrame.new(0, 0, 0, sm[1], 0, 0, 0, sm[2], 0, 0, 0, 1) end
		c.CFrame = nf
		if sm then HK.sLast = c.CFrame end
	elseif mousemoverel then
		local sp = c:WorldToViewportPoint(pos)
		local d = (Vector2.new(sp.X, sp.Y) - mp) * alpha
		mousemoverel(d.X, d.Y)
	end
end

local CUR = {pos = Vector3.zero, part = nil, sp = Vector2.zero}
local rollT, roll = 0, true
local function silentStep()
	HK.cur = nil
	HK.tgt = nil
	SilCircle.Visible = false
	SilLine.Visible = false
	if Unloaded or SAFE or not F.silent_enabled then return end
	local c = cam()
	if not c then return end
	HK.cam = c
	HK.inset = GuiService:GetGuiInset().Y
	local mp = UIS:GetMouseLocation()
	if F.silent_showfov then
		SilCircle.Position = mp SilCircle.Radius = F.silent_fov SilCircle.Color = F.silent_fovcolor SilCircle.Visible = true
	end
	if not bindDown(F.silent_key) then return end
	local part, pos, tplr, tch = pickTarget("silent_")
	if not part then return end
	HK.tgt, HK.tpos = tch, pos
	local s = c:WorldToViewportPoint(pos)
	local sp = Vector2.new(s.X, s.Y)
	if F.silent_line then
		SilLine.From = mp SilLine.To = sp SilLine.Color = F.silent_fovcolor SilLine.Visible = true
	end
	if tick() - rollT > 0.1 then rollT = tick() roll = math.random(1, 100) <= F.silent_chance end
	if roll and (not F.silent_onlyshoot or shooting()) then
		CUR.pos, CUR.part, CUR.sp, CUR.char = pos, part, sp, tch
		CUR.plr = tplr
		CUR.hum = tch and tch:FindFirstChildOfClass("Humanoid")
		if F.silent_magic then HK.mbp.FilterDescendantsInstances = {tch} end
		HK.cur = CUR
	end
end

-- magic bullet: while a target is locked, parts between you and it stop answering raycasts (CanQuery = false),
-- so any client-side hit test (Raycast, FindPartOnRay, Mouse.Target...) reaches the player through walls.
do
	local function build()
		local MB, mbp, acc = {}, RaycastParams.new(), 0
		mbp.FilterType = Enum.RaycastFilterType.Exclude
		mbp.IgnoreWater = true
		local function restore()
			for part in pairs(MB) do
				if part.Parent then pcall(setProp, part, "CanQuery", true) end
				MB[part] = nil
			end
		end
		Cleanups[#Cleanups + 1] = restore
		function HK.mb(dt)
			local tch, tpos = HK.tgt, HK.tpos
			if Unloaded or SAFE or not (F.silent_enabled and F.silent_magic) or not tch or not tch.Parent then
				if next(MB) then restore() end
				acc = 1
				return
			end
			acc += dt
			if acc < 0.06 then return end
			acc = 0
			local c = cam()
			if not c then return end
			for part in pairs(MB) do
				if part.Parent then pcall(setProp, part, "CanQuery", true) end
			end
			local need = {}
			local origins = {c.CFrame.Position}
			local r = hrp()
			if r then origins[2] = r.Position + Vector3.new(0, 1.5, 0) end
			for _, o in ipairs(origins) do
				local ig = {tch, c}
				if LP.Character then ig[3] = LP.Character end
				for _ = 1, 12 do
					mbp.FilterDescendantsInstances = ig
					local res = Workspace:Raycast(o, tpos - o, mbp)
					if not res then break end
					local hit = res.Instance
					if hit:IsA("Terrain") then break end
					need[hit] = true
					ig[#ig + 1] = hit
				end
			end
			table.clear(MB)
			for part in pairs(need) do
				pcall(setProp, part, "CanQuery", false)
				MB[part] = true
			end
		end
	end
	build()
end

local nextShot = 0
local function click()
	if mouse1click then mouse1click() return end
	if VIM then
		local p = UIS:GetMouseLocation()
		VIM:SendMouseButtonEvent(p.X, p.Y, 0, true, game, 0)
		task.delay(0.02, function() VIM:SendMouseButtonEvent(p.X, p.Y, 0, false, game, 0) end)
	end
end
local function trigStep()
	if not F.trig_on or tick() < nextShot or not bindDown(F.trig_key) then return end
	local t = Mouse.Target
	if not t then return end
	local m = t:FindFirstAncestorOfClass("Model")
	local plr = m and Players:GetPlayerFromCharacter(m)
	if not plr or plr == LP or WL[plr.UserId] then return end
	local h = m:FindFirstChildOfClass("Humanoid")
	if not h or h.Health <= 0 or (F.trig_team and isTeam(plr)) then return end
	nextShot = tick() + F.trig_delay / 1000
	click()
end
local nextClick = 0
local function autoStep()
	if not F.ac_on or Unloaded or tick() < nextClick or not bindDown(F.ac_key) or UIS:GetFocusedTextBox() then return end
	nextClick = tick() + 1 / F.ac_cps
	click()
end

local HB, HBPART = {}, {Root = "HumanoidRootPart", Head = "Head", Torso = "Torso"}
local function hbBase(ch)
	local n = HBPART[F.hb_part] or "HumanoidRootPart"
	if n == "Torso" then return ch:FindFirstChild("UpperTorso") or ch:FindFirstChild("Torso") end
	return ch:FindFirstChild(n)
end
local function hbDrop(ch, e)
	pcall(function()
		if e.extra then
			e.extra:Destroy()
		elseif e.part and e.part.Parent and e.o then
			e.part.Size, e.part.Transparency, e.part.CanCollide, e.part.Massless = e.o[1], e.o[2], e.o[3], e.o[4]
		end
	end)
	HB[ch] = nil
end
local function hbRestore() for ch, e in pairs(HB) do hbDrop(ch, e) end end
local hbT = 0
local function hbStep(dt)
	if not F.hb_on or Unloaded then
		if next(HB) then hbRestore() end
		return
	end
	hbT += dt
	if hbT > 0.5 then
		hbT = 0
		for ch in pairs(HB) do if not ch.Parent then HB[ch] = nil end end
	end
	local c = cam()
	local cpos = c and c.CFrame.Position or Vector3.zero
	local size, mode = F.hb_size, F.hb_mode
	local sz = Vector3.new(size, size, size)
	for _, plr in ipairs(Players:GetPlayers()) do
		local ch = plr ~= LP and plr.Character
		local h = ch and ch:FindFirstChildOfClass("Humanoid")
		local base = ch and hbBase(ch)
		local e = ch and HB[ch]
		local ok = h and base and base:IsA("BasePart") and h.Health > 0 and not WL[plr.UserId]
			and not (F.hb_team and isTeam(plr)) and (base.Position - cpos).Magnitude <= F.hb_dist
		if ok then
			if e and (e.mode ~= mode or e.part ~= base or (e.extra and not e.extra.Parent)) then hbDrop(ch, e) e = nil end
			if not e then
				e = {mode = mode, part = base}
				if mode == "Extra part" then
					local x = Instance.new("Part")
					x.Name = base.Name
					x.Size = sz
					x.Transparency = F.hb_trans
					x.Color = T.accent
					x.Material = Enum.Material.SmoothPlastic
					x.CanCollide = false
					x.Massless = true
					x.CFrame = base.CFrame
					x.Parent = ch
					local w = Instance.new("WeldConstraint")
					w.Part0 = base
					w.Part1 = x
					w.Parent = x
					e.extra = x
				else
					e.o = {base.Size, base.Transparency, base.CanCollide, base.Massless}
				end
				HB[ch] = e
			end
			local tgt = e.extra or base
			if tgt.Size ~= sz then tgt.Size = sz end
			if tgt.Transparency ~= F.hb_trans then tgt.Transparency = F.hb_trans end
			if not e.extra then
				if base.CanCollide then base.CanCollide = false end
				if not base.Massless then base.Massless = true end
			end
		elseif e then
			hbDrop(ch, e)
		end
	end
end

----------------------------------------------------------------------
-- esp
----------------------------------------------------------------------
local ESP, HL = {}, {}
local R15J = {
	{"Head", "UpperTorso"}, {"UpperTorso", "LowerTorso"},
	{"UpperTorso", "LeftUpperArm"}, {"LeftUpperArm", "LeftLowerArm"}, {"LeftLowerArm", "LeftHand"},
	{"UpperTorso", "RightUpperArm"}, {"RightUpperArm", "RightLowerArm"}, {"RightLowerArm", "RightHand"},
	{"LowerTorso", "LeftUpperLeg"}, {"LeftUpperLeg", "LeftLowerLeg"}, {"LeftLowerLeg", "LeftFoot"},
	{"LowerTorso", "RightUpperLeg"}, {"RightUpperLeg", "RightLowerLeg"}, {"RightLowerLeg", "RightFoot"},
}
local R6J = {{"Head", "Torso"}, {"Torso", "Left Arm"}, {"Torso", "Right Arm"}, {"Torso", "Left Leg"}, {"Torso", "Right Leg"}}

local function addESP(plr)
	if plr == LP or ESP[plr] then return end
	local o = {
		boxOut = D("Square", {Thickness = 3, Filled = false, Color = Color3.new(0, 0, 0), Transparency = 1}),
		box = D("Square", {Thickness = 1, Filled = false, Transparency = 1}),
		name = D("Text", {Size = 13, Center = true, Outline = true, Font = 2, Color = Color3.new(1, 1, 1), Transparency = 1}),
		info = D("Text", {Size = 12, Center = true, Outline = true, Font = 2, Color = Color3.fromRGB(200, 200, 200), Transparency = 1}),
		tracer = D("Line", {Thickness = 1, Transparency = 1}),
		hpBg = D("Line", {Thickness = 4, Color = Color3.new(0, 0, 0), Transparency = 1}),
		hp = D("Line", {Thickness = 2, Transparency = 1}),
		dot = D("Circle", {NumSides = 16, Radius = 3, Filled = true, Transparency = 1}),
		skel = {},
	}
	for i = 1, 14 do o.skel[i] = D("Line", {Thickness = 1, Transparency = 1}) end
	ESP[plr] = o
end
local function removeESP(plr)
	local o = ESP[plr]
	if o then
		for k, v in pairs(o) do
			if k == "skel" then
				for _, l in ipairs(v) do pcall(function() l:Remove() end) end
			else
				pcall(function() v:Remove() end)
			end
		end
		ESP[plr] = nil
	end
	if HL[plr] then pcall(function() HL[plr]:Destroy() end) HL[plr] = nil end
end
local function hideDraw(o)
	for k, v in pairs(o) do
		if k == "skel" then for _, l in ipairs(v) do l.Visible = false end else v.Visible = false end
	end
end

local function espStep()
	local c = cam()
	if not c then return end
	local vp = c.ViewportSize
	local mp = UIS:GetMouseLocation()
	local cpos = c.CFrame.Position
	for plr, o in pairs(ESP) do
		hideDraw(o)
		local ch = plr.Character
		local h = ch and ch:FindFirstChildOfClass("Humanoid")
		local root = ch and ch:FindFirstChild("HumanoidRootPart")
		local ok = not Unloaded and F.esp_enabled and h and root and h.Health > 0 and not (F.esp_team and isTeam(plr))
		local dist = ok and (root.Position - cpos).Magnitude or 0
		local hl = HL[plr]
		if ok and dist <= F.esp_dist then
			local col = WL[plr.UserId] and Color3.fromRGB(80, 255, 120) or ((F.esp_tcolor and plr.Team and plr.TeamColor.Color) or F.esp_color)
			if F.esp_chams then
				if not hl or not hl.Parent then
					hl = mk("Highlight", {DepthMode = Enum.HighlightDepthMode.AlwaysOnTop, OutlineTransparency = 0, Parent = Holder})
					HL[plr] = hl
				end
				if hl.Adornee ~= ch then hl.Adornee = ch end
				hl.FillColor = col hl.OutlineColor = col hl.FillTransparency = F.esp_chamtr hl.Enabled = true
			elseif hl then
				hl.Enabled = false
			end
			local pos, vis = c:WorldToViewportPoint(root.Position)
			if vis then
				local head = ch:FindFirstChild("Head")
				local topY = head and (head.Position.Y + head.Size.Y / 2 + 0.15) or (root.Position.Y + 2.7)
				local feet = (h.RigType == Enum.HumanoidRigType.R15) and (h.HipHeight + root.Size.Y / 2) or 3
				local top = c:WorldToViewportPoint(Vector3.new(root.Position.X, topY, root.Position.Z))
				local bot = c:WorldToViewportPoint(Vector3.new(root.Position.X, root.Position.Y - feet - 0.1, root.Position.Z))
				local hgt = math.abs(bot.Y - top.Y)
				local w = hgt * 0.55
				local x, y = pos.X - w / 2, math.min(top.Y, bot.Y)
				if F.esp_box then
					o.boxOut.Position = Vector2.new(x, y) o.boxOut.Size = Vector2.new(w, hgt) o.boxOut.Visible = true
					o.box.Position = Vector2.new(x, y) o.box.Size = Vector2.new(w, hgt) o.box.Color = col o.box.Visible = true
				end
				if F.esp_name then
					o.name.Text = plr.DisplayName o.name.Position = Vector2.new(pos.X, y - 16) o.name.Visible = true
				end
				local txt = ""
				if F.esp_dist_on then txt = "[" .. math.floor(dist) .. "m]" end
				if F.esp_tool then
					local tool = ch:FindFirstChildOfClass("Tool")
					if tool then txt = txt .. (txt ~= "" and " " or "") .. tool.Name end
				end
				if txt ~= "" then o.info.Text = txt o.info.Position = Vector2.new(pos.X, y + hgt + 2) o.info.Visible = true end
				if F.esp_hp then
					local frac = math.clamp(h.Health / math.max(h.MaxHealth, 1), 0, 1)
					local bx = x - 5
					o.hpBg.From = Vector2.new(bx, y + hgt + 1) o.hpBg.To = Vector2.new(bx, y - 1) o.hpBg.Visible = true
					o.hp.From = Vector2.new(bx, y + hgt) o.hp.To = Vector2.new(bx, y + hgt - hgt * frac)
					o.hp.Color = Color3.fromRGB(255, 0, 0):Lerp(Color3.fromRGB(0, 255, 0), frac) o.hp.Visible = true
				end
				if F.esp_tracer then
					local from = vp / 2
					if F.esp_tracer_o == "Bottom" then from = Vector2.new(vp.X / 2, vp.Y) elseif F.esp_tracer_o == "Mouse" then from = mp end
					o.tracer.From = from o.tracer.To = Vector2.new(pos.X, y + hgt) o.tracer.Color = col o.tracer.Visible = true
				end
				if F.esp_headdot and head then
					local hp_ = c:WorldToViewportPoint(head.Position)
					o.dot.Position = Vector2.new(hp_.X, hp_.Y) o.dot.Radius = math.max(2, hgt * 0.07) o.dot.Color = col o.dot.Visible = true
				end
			end
			if F.esp_skel then
				local J = (h.RigType == Enum.HumanoidRigType.R15) and R15J or R6J
				for idx, jn in ipairs(J) do
					local a, b, ln = ch:FindFirstChild(jn[1]), ch:FindFirstChild(jn[2]), o.skel[idx]
					if a and b and ln then
						local pa, va = c:WorldToViewportPoint(a.Position)
						local pb, vb = c:WorldToViewportPoint(b.Position)
						if va and vb then
							ln.From = Vector2.new(pa.X, pa.Y) ln.To = Vector2.new(pb.X, pb.Y) ln.Color = col ln.Visible = true
						end
					end
				end
			end
		elseif hl then
			hl.Enabled = false
		end
	end
end
for _, p in ipairs(Players:GetPlayers()) do addESP(p) end

----------------------------------------------------------------------
-- overlay: crosshair / watermark
----------------------------------------------------------------------
local CrossL = {}
for i = 1, 4 do CrossL[i] = D("Line", {Thickness = 1, Transparency = 1, Visible = false}) end
local CrossDot = D("Circle", {NumSides = 16, Radius = 1.5, Filled = true, Transparency = 1, Visible = false})
local function crossStep()
	if not F.cross_on or Unloaded then
		for i = 1, 4 do CrossL[i].Visible = false end
		CrossDot.Visible = false
		return
	end
	local c = cam()
	if not c then return end
	local ctr = F.cross_mouse and UIS:GetMouseLocation() or (c.ViewportSize / 2)
	local s, g, th, col = F.cross_size, F.cross_gap, F.cross_thick, F.cross_color
	local segs = {
		{Vector2.new(-g - s, 0), Vector2.new(-g, 0)}, {Vector2.new(g, 0), Vector2.new(g + s, 0)},
		{Vector2.new(0, -g - s), Vector2.new(0, -g)}, {Vector2.new(0, g), Vector2.new(0, g + s)},
	}
	for i = 1, 4 do
		local l = CrossL[i]
		l.From = ctr + segs[i][1] l.To = ctr + segs[i][2] l.Color = col l.Thickness = th l.Visible = true
	end
	CrossDot.Position = ctr CrossDot.Color = col CrossDot.Visible = F.cross_dot
end

local WM = D("Text", {Size = 14, Outline = true, Font = 2, Transparency = 1, Visible = false})
local fpsAvg, pingV, pingT = 60, 0, 0
local function wmStep(dt)
	fpsAvg = fpsAvg * 0.9 + (1 / math.max(dt, 1e-4)) * 0.1
	if not F.wm_on or Unloaded then WM.Visible = false return end
	pingT -= dt
	if pingT <= 0 then
		pingT = 1
		pcall(function() pingV = math.floor(Stats.Network.ServerStatsItem["Data Ping"]:GetValue()) end)
	end
	WM.Text = string.format("CREZ hub%s  |  %d fps  |  %d ms  |  %d players", SAFE and " [safe]" or "", math.floor(fpsAvg + 0.5), pingV, #Players:GetPlayers())
	WM.Position = Vector2.new(12, 8) WM.Color = T.accent WM.Visible = true
end

----------------------------------------------------------------------
-- world
----------------------------------------------------------------------
local WO = {}
local PostOff = {}
local function wset(inst, prop, v)
	local o = WO[inst]
	if not o then o = {} WO[inst] = o end
	if o[prop] == nil then o[prop] = inst[prop] end
	if inst[prop] ~= v then inst[prop] = v end
end
local function wrestore(inst, props)
	local o = inst and WO[inst]
	if not o then return end
	for _, p in ipairs(props) do
		if o[p] ~= nil then pcall(setProp, inst, p, o[p]) o[p] = nil end
	end
end
local function worldStep()
	if Unloaded then return end
	local atm = Lighting:FindFirstChildOfClass("Atmosphere")
	if F.world_fb then
		wset(Lighting, "Brightness", F.world_bright)
		wset(Lighting, "GlobalShadows", false)
		wset(Lighting, "Ambient", Color3.fromRGB(190, 190, 190))
		wset(Lighting, "OutdoorAmbient", Color3.fromRGB(190, 190, 190))
	end
	if F.world_amb then
		wset(Lighting, "Ambient", F.world_ambcolor)
		wset(Lighting, "OutdoorAmbient", F.world_ambcolor)
	end
	if F.world_fog then
		wset(Lighting, "FogEnd", 1e9)
		if atm then wset(atm, "Density", 0) end
	end
	if F.world_time then wset(Lighting, "ClockTime", F.world_timeval) end
	local c = cam()
	if F.world_fov and c then wset(c, "FieldOfView", F.world_fovval) end
	if F.world_grav then wset(Workspace, "Gravity", F.world_gravval) end
	if F.world_zoom then wset(LP, "CameraMaxZoomDistance", 1e4) end
	if F.world_camocc then wset(LP, "DevCameraOcclusionMode", Enum.DevCameraOcclusionMode.Invisicam) end
	if F.world_nopost then
		for _, e in ipairs(Lighting:GetChildren()) do
			if e:IsA("PostEffect") and e.Enabled and not e:GetAttribute("crez") then PostOff[e] = true e.Enabled = false end
		end
	end
end
local function restoreFB()
	wrestore(Lighting, {"Brightness", "GlobalShadows", "Ambient", "OutdoorAmbient"})
end
local function restoreFog()
	wrestore(Lighting, {"FogEnd"})
	local a = Lighting:FindFirstChildOfClass("Atmosphere")
	if a then wrestore(a, {"Density"}) end
end

----------------------------------------------------------------------
-- painter: recolors the whole model (parts, accessories, textures, clothes)
----------------------------------------------------------------------
local MAT_NAMES = {"Original", "Neon", "ForceField", "Glass", "Metal", "SmoothPlastic", "Plastic", "Marble", "Ice", "Foil", "DiamondPlate", "Granite", "Wood"}
local function matOf(n) if n == "Original" then return nil end return Enum.Material[n] end

local function newPainter(roots)
	return {roots = roots, orig = {}, sa = {}, parts = {}, acc = 0, dirty = true, active = false}
end
local function cap(p, inst, prop)
	local o = p.orig[inst]
	if not o then o = {} p.orig[inst] = o end
	if o[prop] == nil then o[prop] = inst[prop] end
end
local function blank(p, d, prop)
	if d[prop] ~= "" then
		cap(p, d, prop)
		pcall(setProp, d, prop, "")
	end
end
local function scan(p, deco)
	local parts = {}
	local function handle(d)
		if d:IsA("BasePart") then
			parts[#parts + 1] = d
			cap(p, d, "Color") cap(p, d, "Material")
			if d:IsA("MeshPart") then blank(p, d, "TextureID") end
		elseif d:IsA("SpecialMesh") then blank(p, d, "TextureId")
		elseif d:IsA("Shirt") then blank(p, d, "ShirtTemplate")
		elseif d:IsA("Pants") then blank(p, d, "PantsTemplate")
		elseif d:IsA("ShirtGraphic") then blank(p, d, "Graphic")
		elseif d:IsA("SurfaceAppearance") then
			p.sa[#p.sa + 1] = {d, d.Parent}
			d.Parent = nil
		elseif deco and d:IsA("Decal") and d.Transparency < 1 then
			cap(p, d, "Transparency")
			d.Transparency = 1
		end
	end
	for _, root in ipairs(p.roots()) do
		handle(root)
		for _, d in ipairs(root:GetDescendants()) do handle(d) end
	end
	p.parts = parts
end
local function applyPaint(p, color, mat)
	local orig, parts = p.orig, p.parts
	for i = 1, #parts do
		local d = parts[i]
		if d.Parent then
			if d.Color ~= color then d.Color = color end
			local m = mat or (orig[d] and orig[d].Material)
			if m and d.Material ~= m then d.Material = m end
		end
	end
end
local function restorePaint(p)
	for inst, o in pairs(p.orig) do
		if inst.Parent then
			for prop, v in pairs(o) do pcall(setProp, inst, prop, v) end
		end
	end
	for _, e in ipairs(p.sa) do
		pcall(function() if e[2] and e[2].Parent then e[1].Parent = e[2] end end)
	end
	p.orig, p.sa, p.parts, p.active = {}, {}, {}, false
end
local function painterStep(p, dt, enabled, color, mat, deco, interval)
	if not enabled or Unloaded then
		if p.active then restorePaint(p) end
		return
	end
	p.active = true
	p.acc += dt
	if p.dirty or p.acc >= interval then
		p.acc = 0 p.dirty = false
		scan(p, deco)
	end
	applyPaint(p, color, mat)
end

local BodyP = newPainter(function()
	local t, ch = {}, LP.Character
	if ch then for _, c in ipairs(ch:GetChildren()) do if not c:IsA("Tool") then t[#t + 1] = c end end end
	return t
end)
local ToolP = newPainter(function()
	local t, ch = {}, LP.Character
	if ch then for _, c in ipairs(ch:GetChildren()) do if c:IsA("Tool") then t[#t + 1] = c end end end
	return t
end)
local ViewP = newPainter(function() local c = cam() return c and c:GetChildren() or {} end)
local function dirtyAll() BodyP.dirty = true ToolP.dirty = true ViewP.dirty = true end

local function hookChar(ch)
	on(ch.DescendantAdded, function() BodyP.dirty = true ToolP.dirty = true end)
end
local function hookCam()
	local c = cam()
	if c then on(c.DescendantAdded, function() ViewP.dirty = true end) end
end

local function paintStep(dt)
	local rc = Color3.fromHSV((tick() * F.rainbow_speed * 0.1) % 1, 1, 1)
	local rb = F.rainbow
	painterStep(BodyP, dt, F.body_on, rb and rc or F.body_color, matOf(F.body_mat), F.body_nodecal, 0.25)
	painterStep(ToolP, dt, F.tool_on, rb and rc or F.tool_color, matOf(F.tool_mat), true, 0.1)
	painterStep(ViewP, dt, F.view_on, rb and rc or F.view_color, matOf(F.view_mat), true, 0.1)
end

----------------------------------------------------------------------
-- movement
----------------------------------------------------------------------
local Base = {ws = 16, jp = 50, jh = 7.2, usejp = true}
local NoclipOrig = setmetatable({}, {__mode = "k"})
local ncParts, ncChar, ncT = {}, nil, 0
local flyPos, flyOn = nil, false

local function restoreSpeed()
	local h = hum()
	if h and F.char_speed_on then h.WalkSpeed = Base.ws end
end
local function restoreJump()
	local h = hum()
	if h and F.char_jump_on then
		if Base.usejp then h.JumpPower = Base.jp else h.JumpHeight = Base.jh end
	end
end
local function humStep()
	local h = hum()
	if not h or Unloaded then return end
	if F.char_speed_on and F.char_speed_m == "WalkSpeed" and h.WalkSpeed ~= F.char_speed then h.WalkSpeed = F.char_speed end
	if F.char_jump_on and F.char_jump_m == "Property" then
		if h.UseJumpPower then
			if h.JumpPower ~= F.char_jump then h.JumpPower = F.char_jump end
		else
			local jh = F.char_jump ^ 2 / (2 * Workspace.Gravity)
			if math.abs(h.JumpHeight - jh) > 0.01 then h.JumpHeight = jh end
		end
	end
end

local function moveStep(dt)
	if Unloaded then return end
	local h, r = hum(), hrp()
	if not (h and r) then return end
	if F.char_fly then
		local c = cam()
		if not flyOn then flyOn = true flyPos = r.Position end
		if not flyPos or (r.Position - flyPos).Magnitude > 30 then flyPos = r.Position end
		if not h.PlatformStand then h.PlatformStand = true end
		local look, right = c.CFrame.LookVector, c.CFrame.RightVector
		local flat = Vector3.new(look.X, 0, look.Z)
		local dir = Vector3.zero
		local md = h.MoveDirection
		if md.Magnitude > 0.01 and flat.Magnitude > 0.001 then
			local f = flat.Unit
			local rt = f:Cross(Vector3.yAxis)
			dir = look * md:Dot(f) + right * md:Dot(rt)
		end
		if not UIS:GetFocusedTextBox() then
			if UIS:IsKeyDown(Enum.KeyCode.Space) then dir += Vector3.yAxis end
			if UIS:IsKeyDown(Enum.KeyCode.LeftShift) or UIS:IsKeyDown(Enum.KeyCode.LeftControl) then dir -= Vector3.yAxis end
		end
		if dir.Magnitude > 1 then dir = dir.Unit end
		flyPos += dir * F.char_flyspeed * dt
		local face = flat.Magnitude > 0.001 and flat or r.CFrame.LookVector
		r.CFrame = CFrame.lookAt(flyPos, flyPos + face)
		r.AssemblyLinearVelocity = Vector3.zero
		r.AssemblyAngularVelocity = Vector3.zero
		return
	elseif flyOn then
		flyOn = false flyPos = nil
		h.PlatformStand = false
	end
	local bhopping = false
	if F.char_bhop and not UIS:GetFocusedTextBox() then
		local md = h.MoveDirection
		if md.Magnitude > 0.01 then
			bhopping = true
			if not Base.bv then Base.bv, Base.bt = math.max(h.WalkSpeed, 16), 0 end
			if h.FloorMaterial ~= Enum.Material.Air and tick() - Base.bt > 0.2 then
				Base.bt = tick()
				Base.bv = math.min(F.bhop_max, Base.bv + F.bhop_gain)
				h:ChangeState(Enum.HumanoidStateType.Jumping)
			end
			local v = r.AssemblyLinearVelocity
			r.AssemblyLinearVelocity = Vector3.new(md.X * Base.bv, v.Y, md.Z * Base.bv)
		else
			Base.bv = nil
		end
	else
		Base.bv = nil
	end
	if F.char_spin then
		if h.AutoRotate then h.AutoRotate = false end
		r.CFrame = r.CFrame * CFrame.Angles(0, math.rad(F.char_spinspeed) * dt, 0)
	end
	if F.char_speed_on and F.char_speed_m ~= "WalkSpeed" and not bhopping then
		local md = h.MoveDirection
		if md.Magnitude > 0 then
			if F.char_speed_m == "CFrame" then
				local extra = math.max(F.char_speed - h.WalkSpeed, 0)
				r.CFrame = r.CFrame + md * extra * dt
			else
				local v = r.AssemblyLinearVelocity
				r.AssemblyLinearVelocity = Vector3.new(md.X * F.char_speed, v.Y, md.Z * F.char_speed)
			end
		end
	end
end

local function noclipStep()
	if Unloaded then return end
	local active = F.char_noclip or (F.char_fly and F.char_flync)
	if not active then
		if next(NoclipOrig) then
			for p in pairs(NoclipOrig) do if p.Parent then p.CanCollide = true end end
			table.clear(NoclipOrig)
		end
		return
	end
	local ch = LP.Character
	if not ch then return end
	if ch ~= ncChar or tick() - ncT > 0.5 then
		ncChar, ncT = ch, tick()
		ncParts = {}
		for _, p in ipairs(ch:GetDescendants()) do if p:IsA("BasePart") then ncParts[#ncParts + 1] = p end end
	end
	for i = 1, #ncParts do
		local p = ncParts[i]
		if p.CanCollide then NoclipOrig[p] = true p.CanCollide = false end
	end
end

local function specStep()
	if not F.spec_on or Unloaded then return end
	local plr = Players:FindFirstChild(F.tp_target)
	local h = plr and plr.Character and plr.Character:FindFirstChildOfClass("Humanoid")
	local c = cam()
	if h and c and c.CameraSubject ~= h then c.CameraSubject = h end
end

----------------------------------------------------------------------
-- misc / config
----------------------------------------------------------------------
local function refreshPlayers()
	local e = Elements.tp_target
	if e and e.Refresh then e.Refresh() end
end

local function serverHop()
	notify("Searching for a server...")
	task.spawn(function()
		local ok, res = pcall(function()
			local url = ("https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=Asc&limit=100"):format(game.PlaceId)
			return HttpService:JSONDecode(game:HttpGet(url))
		end)
		if not ok or type(res) ~= "table" or not res.data then return notify("Server list request failed") end
		local list = {}
		for _, s in ipairs(res.data) do
			if s.id ~= game.JobId and s.playing and s.maxPlayers and s.playing < s.maxPlayers then list[#list + 1] = s.id end
		end
		if #list == 0 then return notify("No other servers found") end
		TeleportService:TeleportToPlaceInstance(game.PlaceId, list[math.random(#list)], LP)
	end)
end

----------------------------------------------------------------------
-- tabs
----------------------------------------------------------------------
-- COMBAT
do
	local tAim = newTab("Aimbot", "Combat")
	local s = tAim:Section("Aimbot", 1)
	s:Toggle{text = "Enabled", flag = "aim_enabled"}
	s:Keybind{text = "Aim key", flag = "aim_key", default = "MouseButton2"}
	s:Cycle{text = "Method", flag = "aim_method", options = {"Camera", "Mouse"}}
	s:Cycle{text = "Target part", flag = "aim_part", options = {"Head", "Torso", "Root", "Closest"}}
	s:Cycle{text = "Priority", flag = "aim_prio", options = {"Cursor", "Distance", "Health"}}
	s:Slider{text = "Smoothness", flag = "aim_smooth", min = 0, max = 95, default = 30, suffix = "%"}
	s:Slider{text = "Prediction", flag = "aim_pred", min = 0, max = 0.3, step = 0.01, default = 0}
	s:Toggle{text = "Sticky target", flag = "aim_sticky"}
	s:Label("Method 'Mouse' needs mousemoverel; use it in games with a custom camera.")
	local t = tAim:Section("Targeting", 2)
	t:Toggle{text = "Team check", flag = "aim_team", default = true}
	t:Toggle{text = "Wall check", flag = "aim_wall", default = true}
	t:Toggle{text = "Ignore ForceField", flag = "aim_ff"}
	t:Slider{text = "Max distance", flag = "aim_dist", min = 100, max = 5000, step = 50, default = 2000}
	local f = tAim:Section("FOV", 2)
	f:Toggle{text = "Show circle", flag = "aim_showfov", default = true}
	f:Slider{text = "Radius", flag = "aim_fov", min = 20, max = 800, default = 120, suffix = "px"}
	f:Color{text = "Color", flag = "aim_fovcolor"}
end

do
	local tSil = newTab("Silent Aim", "Combat")
	local s = tSil:Section("Silent Aim", 1)
	s:Toggle{text = "Enabled", flag = "silent_enabled", cb = function(v) if v then ensureHooks() end end}
	s:Keybind{text = "Active key", flag = "silent_key", default = "None"}
	s:Toggle{text = "Only while shooting", flag = "silent_onlyshoot", default = true}
	s:Cycle{text = "Target part", flag = "silent_part", options = {"Head", "Torso", "Root", "Closest"}}
	s:Cycle{text = "Priority", flag = "silent_prio", options = {"Cursor", "Distance", "Health"}}
	s:Slider{text = "Hit chance", flag = "silent_chance", min = 1, max = 100, default = 100, suffix = "%"}
	s:Slider{text = "Prediction", flag = "silent_pred", min = 0, max = 0.3, step = 0.01, default = 0}
	if SAFE then s:Label("Safe mode: Silent Aim usa hookmetamethod, entao fica travado. Reexecute com Safe mode OFF pra usar.") end
	local t = tSil:Section("Targeting", 1)
	t:Toggle{text = "Team check", flag = "silent_team", default = true}
	t:Toggle{text = "Wall check", flag = "silent_wall", default = true}
	t:Toggle{text = "Ignore ForceField", flag = "silent_ff"}
	t:Slider{text = "Max distance", flag = "silent_dist", min = 100, max = 5000, step = 50, default = 2000}
	local f = tSil:Section("FOV", 2)
	f:Toggle{text = "Show circle", flag = "silent_showfov", default = true}
	f:Slider{text = "Radius", flag = "silent_fov", min = 20, max = 800, default = 150, suffix = "px"}
	f:Color{text = "Color", flag = "silent_fovcolor"}
	f:Toggle{text = "Line to target", flag = "silent_line"}
	local m = tSil:Section("Methods", 2)
	local function mcb() if F.silent_enabled then ensureHooks() end end
	local PRESETS = {
		Custom = false,
		["Raycast only"] = {ray = true, mouse = false, cam = false, uis = false},
		["Raycast + Mouse"] = {ray = true, mouse = true, cam = false, uis = false},
		["Mouse only"] = {ray = false, mouse = true, cam = false, uis = false},
		["Camera rays"] = {ray = false, mouse = false, cam = true, uis = false},
		["Cursor spoof"] = {ray = false, mouse = false, cam = true, uis = true},
		["All methods"] = {ray = true, mouse = true, cam = true, uis = true},
	}
	m:Cycle{text = "Preset", flag = "silent_preset", default = "Raycast only",
		options = {"Custom", "Raycast only", "Raycast + Mouse", "Mouse only", "Camera rays", "Cursor spoof", "All methods"}, cb = function(v)
			local pr = PRESETS[v]
			if not pr then return end
			for k, val in pairs(pr) do Elements["silent_" .. k].Set(val) end
		end}
	m:Toggle{text = "Raycast / FindPartOnRay", flag = "silent_ray", default = true, cb = mcb}
	m:Toggle{text = "Mouse.Hit / Target", flag = "silent_mouse", cb = mcb}
	m:Toggle{text = "Camera ScreenPointToRay", flag = "silent_cam", cb = mcb}
	m:Toggle{text = "Mouse position spoof", flag = "silent_uis", cb = mcb}
	m:Toggle{text = "Magic bullet (walls)", flag = "silent_magic", cb = mcb}
	local cl = m:Label("Intercepted: -")
	m:Button{text = "Reset counters", cb = function() for k in pairs(HK.cnt) do HK.cnt[k] = 0 end end}
	m:Button{text = "Apply detected (smart)", cb = function()
		local c = HK.cnt
		local ray, camm, mouse, uis = (c.ray + c.fpr) > 0, c.cam > 0, c.mouse > 0, c.uis > 0
		if not (ray or camm or mouse or uis) then
			return notify("Nothing intercepted yet: turn silent aim on, shoot at a player, then try again")
		end
		Elements.silent_ray.Set(ray)
		Elements.silent_cam.Set(camm)
		Elements.silent_mouse.Set(mouse and not ray and not camm)
		Elements.silent_uis.Set(uis and not ray and not camm)
		Elements.silent_preset.Set("Custom")
		notify("Applied the methods this game actually uses")
	end}
	m:Label("Do not enable every method at once: guns like ACS can break. Pick a preset, shoot at a player a few times, then press Apply detected.")
	m:Label("Magic bullet: while a target is locked, the walls between you and it stop answering raycasts, and Raycast/FindPartOnRay return the hit on the player. It only works in games that decide hits on the client and whose server does not check line of sight. Turn Silent Aim on, keep Raycast on, and aim near the player (inside the FOV).")
	local macc = 0
	local mupd = guard("Silent counters", function(dt)
		macc += dt
		if macc < 0.5 then return end
		macc = 0
		local c = HK.cnt
		cl.Text = string.format("Intercepted: Raycast %d | FindPart %d | CamRay %d | Mouse %d | Cursor %d", c.ray, c.fpr, c.cam, c.mouse, c.uis)
	end)
	on(RunService.Heartbeat, function(dt) if not Unloaded and Active == tSil then mupd(dt) end end)
end

do
	local tExtra = newTab("Extras", "Combat")
	local s = tExtra:Section("Triggerbot", 1)
	s:Toggle{text = "Enabled", flag = "trig_on"}
	s:Keybind{text = "Active key", flag = "trig_key", default = "None"}
	s:Slider{text = "Delay", flag = "trig_delay", min = 0, max = 500, step = 5, default = 80, suffix = "ms"}
	s:Toggle{text = "Team check", flag = "trig_team", default = true}
	local ac = tExtra:Section("Autoclicker", 1)
	ac:Toggle{text = "Enabled", flag = "ac_on"}
	ac:Keybind{text = "Hold key", flag = "ac_key", default = "None"}
	ac:Slider{text = "Clicks per second", flag = "ac_cps", min = 1, max = 30, default = 10}
	local h = tExtra:Section("Hitbox Expander", 2)
	h:Toggle{text = "Enabled", flag = "hb_on", cb = function(v) if not v then hbRestore() end end}
	h:Cycle{text = "Mode", flag = "hb_mode", options = {"Extra part", "Resize part"}, cb = function() hbRestore() end}
	h:Cycle{text = "Part", flag = "hb_part", options = {"Root", "Head", "Torso"}, cb = function() hbRestore() end}
	h:Slider{text = "Size", flag = "hb_size", min = 2, max = 40, default = 8}
	h:Slider{text = "Max distance", flag = "hb_dist", min = 50, max = 2000, step = 50, default = 400}
	h:Slider{text = "Transparency", flag = "hb_trans", min = 0, max = 1, step = 0.05, default = 0.7}
	h:Toggle{text = "Team check", flag = "hb_team", default = true}
	h:Label("Extra part adds an invisible welded box and never touches the rig, so nobody freezes. Resize part edits the real part and can freeze players in some games.")
end

-- INTERCEPTOR
do
	local function build()
		local tIc = newTab("Interceptor", "Combat")
		local IC = {log = {}, byName = {}, spoofed = 0, learned = 0, last = "-", inHookT = 0, hooked = false, on = false}
		local A = {ok = false, origin = Vector3.zero, look = Vector3.zero, hit = Vector3.zero, root = nil, tgt = nil, tmodel = nil}
		HK.aim = A
		local DENY = {"chat", "message", "analytics", "report", "emote"}
		-- method-style calls inside a namecall hook would overwrite the namecall state, so use function-style ones
		local IsA, IsDesc, GPC = game.IsA, game.IsDescendantOf, Players.GetPlayerFromCharacter

		-- real aim data, read from the hub's own context (never spoofed)
		local function updAim()
			if not IC.on or Unloaded then A.ok = false return end
			local c = cam()
			if not c then A.ok = false return end
			local r = hrp()
			A.origin, A.look = c.CFrame.Position, c.CFrame.LookVector
			local okh, hit = pcall(function() return Mouse.Hit.Position end)
			A.hit = okh and hit or (A.origin + A.look * 500)
			A.tgt = Mouse.Target
			A.tmodel = A.tgt and A.tgt:FindFirstAncestorOfClass("Model") or nil
			A.root = r and r.Position or nil
			A.ok = true
		end

		-- what does this value look like relative to where you are really aiming?
		local function vecRole(v)
			local d = A.hit - A.origin
			local dm = d.Magnitude
			local mag = v.Magnitude
			if mag > 0.9 and mag < 1.1 then
				if dm > 1 and v:Dot(d.Unit) > 0.97 then return "dir" end
				return nil
			end
			if (v - A.hit).Magnitude < math.max(4, dm * 0.03) then return "hitpos" end
			if (v - A.origin).Magnitude < 12 or (A.root and (v - A.root).Magnitude < 12) then return "origin" end
			if mag > 5 and dm > 1 and v.Unit:Dot(d.Unit) > 0.985 then return "dirRange" end
			return nil
		end
		local function roleOf(v, t)
			if t == "Instance" then
				local ok, res = pcall(function()
					local ch = LP.Character
					if IsA(v, "BasePart") then
						if ch and IsDesc(v, ch) then return nil end
						return "part"
					elseif IsA(v, "Humanoid") then
						return (v.Parent ~= ch) and "humanoid" or nil
					elseif IsA(v, "Model") then
						return (v ~= ch and GPC(Players, v)) and "char" or nil
					elseif IsA(v, "Player") then
						return (v ~= LP) and "player" or nil
					end
					return nil
				end)
				return ok and res or nil
			elseif t == "Vector3" then
				return vecRole(v)
			elseif t == "CFrame" then
				local pr = vecRole(v.Position)
				if pr == "hitpos" then return "cfHit" end
				if pr == "origin" then
					local d = A.hit - A.origin
					if d.Magnitude > 1 and v.LookVector:Dot(d.Unit) > 0.97 then return "cfLook" end
				end
				return nil
			elseif t == "Ray" then
				if (v.Origin - A.origin).Magnitude < 15 or (A.root and (v.Origin - A.root).Magnitude < 15) then return "ray" end
			end
			return nil
		end
		local function points(role, v)
			if role == "part" then return (v == A.tgt) and 2 or 1 end
			if role == "humanoid" or role == "char" or role == "player" then
				local m = A.tmodel
				if not m then return 1 end
				local ok, same = pcall(function()
					if role == "humanoid" then return v.Parent == m end
					if role == "char" then return v == m end
					return v.Character == m
				end)
				return (ok and same) and 2 or 1
			end
			return 2
		end
		local function score(v, depth)
			local t = typeof(v)
			if t == "table" then
				if depth >= 2 then return 0 end
				local sc, n = 0, 0
				for _, x in pairs(v) do
					n += 1
					if n > 40 then break end
					sc += score(x, depth + 1)
				end
				return sc
			end
			local role = roleOf(v, t)
			if not role or role == "origin" then return 0 end
			return points(role, v)
		end
		local function spoof(role, v, cur)
			if role == "part" then return cur.part
			elseif role == "humanoid" then return cur.hum
			elseif role == "char" then return cur.char
			elseif role == "player" then return cur.plr end
			local to = cur.pos - A.origin
			local dist = to.Magnitude
			if dist < 0.001 then return nil end
			if role == "hitpos" then return cur.pos
			elseif role == "dir" then return to.Unit
			elseif role == "dirRange" then return to.Unit * math.max(v.Magnitude, dist + 5)
			elseif role == "cfHit" then return CFrame.new(cur.pos)
			elseif role == "cfLook" then return CFrame.lookAt(v.Position, cur.pos)
			elseif role == "ray" then
				local d2 = cur.pos - v.Origin
				return Ray.new(v.Origin, d2.Unit * math.max(v.Direction.Magnitude, d2.Magnitude + 5))
			end
			return nil
		end
		local function rebuild(v, depth, cur)
			local t = typeof(v)
			if t == "table" then
				if depth >= 2 then return v, false end
				local nt, changed, n = {}, false, 0
				for k, x in pairs(v) do
					n += 1
					if n > 40 then return v, false end
					local nv, ch = rebuild(x, depth + 1, cur)
					nt[k] = nv
					if ch then changed = true end
				end
				if changed then return nt, true end
				return v, false
			end
			local role = roleOf(v, t)
			if not role or role == "origin" then return v, false end
			local nv = spoof(role, v, cur)
			if nv == nil then return v, false end
			return nv, true
		end
		local function denied(remote)
			local n = remote.Name:lower()
			for _, pat in ipairs(DENY) do if n:find(pat, 1, true) then return true end end
			return false
		end
		local function newInfo(remote)
			local okn, full = pcall(remote.GetFullName, remote)
			local info = {name = okn and full or remote.Name, short = remote.Name, n = 0, hits = 0, spoofs = 0, armed = false}
			IC.log[remote] = info
			IC.byName[info.name] = info
			IC.learned += 1
			return info
		end

		-- runs inside the remote hooks: learn which remotes carry aim data, rewrite them while Silent Aim has a target
		local function process(remote, ...)
			if not (A.ok and IC.on) then return nil end
			local cur = HK.cur
			local learn = F.ic_learn and (F.ic_trigger == "Always" or shooting())
			if not (learn or cur) then return nil end
			local args = table.pack(...)
			local pts = 0
			for i = 1, args.n do pts += score(args[i], 0) end
			if pts == 0 then return nil end
			local info = IC.log[remote]
			if learn then
				info = info or newInfo(remote)
				info.n += 1
				if pts >= 2 then info.hits += 1 end
				if F.ic_mode == "Auto-armed" and not info.armed and info.hits >= F.ic_need then
					info.armed = true
					task.defer(notify, "Armed remote: " .. info.short)
				end
			end
			if not cur then return nil end
			if not ((info and info.armed) or (F.ic_mode == "Aggressive (all remotes)" and not denied(remote))) then return nil end
			local out, changed = {n = args.n}, false
			for i = 1, args.n do
				local nv, ch = rebuild(args[i], 0, cur)
				out[i] = nv
				if ch then changed = true end
			end
			if not changed then return nil end
			IC.spoofed += 1
			IC.last = remote.Name
			if info then info.spoofs += 1 end
			return out
		end

		local function install()
			if SAFE then return false end
			if IC.hooked then return true end
			if not (hookmetamethod and getnamecallmethod and setnamecallmethod and checkcaller) then return false end
			local wrap = newcclosure or function(f) return f end
			local ok = pcall(function()
				local old
				old = hookmetamethod(game, "__namecall", wrap(function(self, ...)
					local m = getnamecallmethod()
					if IC.on and (m == "FireServer" or m == "InvokeServer" or m == "fireServer" or m == "invokeServer") and not checkcaller() then
						local okp, new = pcall(process, self, ...)
						if not okp then new = nil end
						setnamecallmethod(m)
						IC.inHookT = os.clock()
						local ret
						if new then ret = table.pack(old(self, table.unpack(new, 1, new.n)))
						else ret = table.pack(old(self, ...)) end
						IC.inHookT = 0
						return table.unpack(ret, 1, ret.n)
					end
					return old(self, ...)
				end))
			end)
			if ok and hookfunction then
				local seen = {}
				local function hookFn(f)
					if type(f) ~= "function" or seen[f] then return end
					seen[f] = true
					pcall(function()
						local old2
						old2 = hookfunction(f, wrap(function(self, ...)
							if IC.on and os.clock() - IC.inHookT > 0.05 and not checkcaller() then
								local okp, new = pcall(process, self, ...)
								if okp and new then return old2(self, table.unpack(new, 1, new.n)) end
							end
							return old2(self, ...)
						end))
					end)
				end
				pcall(function() hookFn(Instance.new("RemoteEvent").FireServer) end)
				pcall(function() hookFn(Instance.new("RemoteFunction").InvokeServer) end)
				pcall(function() hookFn(Instance.new("UnreliableRemoteEvent").FireServer) end)
			end
			IC.hooked = ok
			return ok
		end

		local function armByName(q)
			q = tostring(q or ""):lower()
			if q == "" then return notify("Type part of the remote name first") end
			local n = 0
			for _, root in ipairs({game:GetService("ReplicatedStorage"), game:GetService("ReplicatedFirst")}) do
				for _, d in ipairs(root:GetDescendants()) do
					if (d:IsA("RemoteEvent") or d:IsA("RemoteFunction") or d:IsA("UnreliableRemoteEvent")) and d.Name:lower():find(q, 1, true) then
						local info = IC.log[d] or newInfo(d)
						info.armed = true
						n += 1
					end
				end
			end
			Elements.ic_sel.Refresh()
			notify("Armed " .. n .. " remotes")
		end

		-- UI --------------------------------------------------------------
		local s = tIc:Section("Interceptor", 1)
		s:Toggle{text = "Enabled", flag = "ic_on", cb = function(v)
			IC.on = v
			if v then
				if not install() then
					IC.on = false
					notify("Interceptor needs hookmetamethod, getnamecallmethod and setnamecallmethod")
				elseif not F.silent_enabled then
					notify("Turn Silent Aim on too: it provides the target")
				end
			end
		end}
		s:Cycle{text = "Mode", flag = "ic_mode", options = {"Auto-armed", "Armed list only", "Aggressive (all remotes)"}}
		s:Toggle{text = "Learn remotes", flag = "ic_learn", default = true}
		s:Cycle{text = "Learn when", flag = "ic_trigger", options = {"While shooting", "Always"}}
		s:Slider{text = "Arm after hits", flag = "ic_need", min = 1, max = 10, default = 2}
		if SAFE then s:Label("Safe mode: Interceptor usa hookmetamethod/hookfunction, travado.") end
		s:Label("1) Turn Silent Aim on. 2) Enable the Interceptor. 3) Shoot at players a few times: every remote that carries hit data (hit part, humanoid, position, direction, ray) is learned and armed. 4) From then on, whenever Silent Aim has a target, those remotes are rewritten with the target's part, humanoid, position or direction.")
		s:Label("Auto-armed arms remotes by itself. Armed list only uses what you arm by hand. Aggressive rewrites every remote that carries aim data while you shoot, which catches games that learning misses but can break unrelated remotes. It only helps in games where the server trusts the hit data the client sends.")

		local r = tIc:Section("Learned remotes", 2)
		r:List{flag = "ic_sel", height = 170, getItems = function()
			local t = {}
			for _, info in pairs(IC.log) do
				t[#t + 1] = {id = info.name, text = info.short, info = info.hits .. "/" .. info.n .. (info.armed and " ARMED" or "")}
			end
			table.sort(t, function(a, b) return a.id < b.id end)
			return t
		end}
		r:Button{text = "Arm selected", cb = function()
			local i = IC.byName[F.ic_sel]
			if i then i.armed = true Elements.ic_sel.Refresh() else notify("Select a remote first") end
		end}
		r:Button{text = "Disarm selected", cb = function()
			local i = IC.byName[F.ic_sel]
			if i then i.armed = false Elements.ic_sel.Refresh() else notify("Select a remote first") end
		end}
		r:Button{text = "Arm all learned", cb = function()
			for _, info in pairs(IC.log) do info.armed = true end
			Elements.ic_sel.Refresh()
		end}
		r:Button{text = "Clear list", cb = function()
			IC.log, IC.byName, IC.learned = {}, {}, 0
			Elements.ic_sel.Set("")
			Elements.ic_sel.Refresh()
		end}
		r:Button{text = "Copy remote path", cb = function()
			if F.ic_sel ~= "" and setclipboard then setclipboard(F.ic_sel) notify("Path copied") end
		end}
		r:TextInput{flag = "ic_manual", placeholder = "remote name contains..."}
		r:Button{text = "Arm remotes by name", cb = function() armByName(F.ic_manual) end}
		local st = r:Label("-")

		local updG = guard("Interceptor aim", updAim)
		on(RunService.RenderStepped, function() if not Unloaded then updG() end end)
		local acc = 0
		local tickf = guard("Interceptor UI", function(dt)
			acc += dt
			if acc < 0.7 then return end
			acc = 0
			Elements.ic_sel.Refresh()
			local armed = 0
			for _, info in pairs(IC.log) do if info.armed then armed += 1 end end
			st.Text = string.format("Learned: %d | Armed: %d | Rewritten calls: %d | Last: %s", IC.learned, armed, IC.spoofed, IC.last)
		end)
		on(RunService.Heartbeat, function(dt) if not Unloaded and Active == tIc then tickf(dt) end end)
		Cleanups[#Cleanups + 1] = function() IC.on = false end
	end
	build()
end

-- VISUALS
do
	local tEsp = newTab("ESP", "Visuals")
	local s = tEsp:Section("ESP", 1)
	s:Toggle{text = "Enabled", flag = "esp_enabled"}
	s:Toggle{text = "Box", flag = "esp_box", default = true}
	s:Toggle{text = "Name", flag = "esp_name", default = true}
	s:Toggle{text = "Distance", flag = "esp_dist_on", default = true}
	s:Toggle{text = "Health bar", flag = "esp_hp", default = true}
	s:Toggle{text = "Held tool", flag = "esp_tool"}
	s:Toggle{text = "Skeleton", flag = "esp_skel"}
	s:Toggle{text = "Head dot", flag = "esp_headdot"}
	s:Toggle{text = "Tracers", flag = "esp_tracer"}
	s:Toggle{text = "Chams", flag = "esp_chams"}
	local c = tEsp:Section("Settings", 2)
	c:Toggle{text = "Team check", flag = "esp_team", default = true}
	c:Toggle{text = "Use team color", flag = "esp_tcolor"}
	c:Slider{text = "Max distance", flag = "esp_dist", min = 100, max = 5000, step = 50, default = 1500}
	c:Cycle{text = "Tracer origin", flag = "esp_tracer_o", options = {"Bottom", "Center", "Mouse"}}
	c:Slider{text = "Chams fill", flag = "esp_chamtr", min = 0, max = 1, step = 0.05, default = 0.5}
	c:Color{text = "Color", flag = "esp_color"}
end

do
	local tWorld = newTab("World", "Visuals")
	local s = tWorld:Section("Lighting", 1)
	s:Toggle{text = "Fullbright", flag = "world_fb", cb = function(v) if not v then restoreFB() end end}
	s:Slider{text = "Brightness", flag = "world_bright", min = 1, max = 5, step = 0.5, default = 2}
	s:Toggle{text = "Remove fog", flag = "world_fog", cb = function(v) if not v then restoreFog() end end}
	s:Toggle{text = "Custom ambient", flag = "world_amb", cb = function(v) if not v then restoreFB() end end}
	s:Color{text = "Ambient color", flag = "world_ambcolor", default = Color3.fromRGB(120, 60, 255)}
	s:Toggle{text = "Force time", flag = "world_time", cb = function(v) if not v then wrestore(Lighting, {"ClockTime"}) end end}
	s:Slider{text = "Time of day", flag = "world_timeval", min = 0, max = 24, step = 0.5, default = 14}
	local w = tWorld:Section("Camera & Physics", 2)
	w:Toggle{text = "Custom FOV", flag = "world_fov", cb = function(v) if not v then wrestore(cam(), {"FieldOfView"}) end end}
	w:Slider{text = "FOV", flag = "world_fovval", min = 40, max = 120, default = 70}
	w:Toggle{text = "Unlock zoom", flag = "world_zoom", cb = function(v) if not v then wrestore(LP, {"CameraMaxZoomDistance"}) end end}
	w:Toggle{text = "Custom gravity", flag = "world_grav", cb = function(v) if not v then wrestore(Workspace, {"Gravity"}) end end}
	w:Slider{text = "Gravity", flag = "world_gravval", min = 0, max = 400, default = 196}
	w:Toggle{text = "Camera through walls", flag = "world_camocc", cb = function(v) if not v then wrestore(LP, {"DevCameraOcclusionMode"}) end end}
	s:Toggle{text = "Disable post effects", flag = "world_nopost", cb = function(v)
		if not v then for e in pairs(PostOff) do if e.Parent then e.Enabled = true end end table.clear(PostOff) end
	end}
end

do
	local tOver = newTab("Overlay", "Visuals")
	local c = tOver:Section("Crosshair", 1)
	c:Toggle{text = "Enabled", flag = "cross_on"}
	c:Toggle{text = "Follow mouse", flag = "cross_mouse"}
	c:Toggle{text = "Center dot", flag = "cross_dot", default = true}
	c:Slider{text = "Size", flag = "cross_size", min = 2, max = 30, default = 8}
	c:Slider{text = "Gap", flag = "cross_gap", min = 0, max = 20, default = 4}
	c:Slider{text = "Thickness", flag = "cross_thick", min = 1, max = 4, default = 1}
	c:Color{text = "Color", flag = "cross_color", default = Color3.fromRGB(0, 255, 120)}
	local w = tOver:Section("Info", 2)
	w:Toggle{text = "Watermark (FPS / ping)", flag = "wm_on", default = true}
end

-- PLAYER
do
	local tMove = newTab("Movement", "Player")
	local m = tMove:Section("Speed & Jump", 1)
	m:Toggle{text = "Speed", flag = "char_speed_on", cb = function(v)
		local h = hum()
		if h then if v then Base.ws = h.WalkSpeed else h.WalkSpeed = Base.ws end end
	end}
	m:Cycle{text = "Speed method", flag = "char_speed_m", options = {"WalkSpeed", "CFrame", "Velocity"}, cb = function() restoreSpeed() end}
	m:Slider{text = "Speed", flag = "char_speed", min = 16, max = 300, default = 60}
	m:Toggle{text = "Jump boost", flag = "char_jump_on", cb = function(v)
		local h = hum()
		if h then
			if v then Base.jp, Base.jh, Base.usejp = h.JumpPower, h.JumpHeight, h.UseJumpPower
			elseif Base.usejp then h.JumpPower = Base.jp else h.JumpHeight = Base.jh end
		end
	end}
	m:Cycle{text = "Jump method", flag = "char_jump_m", options = {"Property", "Velocity"}, cb = function() restoreJump() end}
	m:Slider{text = "Jump power", flag = "char_jump", min = 50, max = 500, default = 120}
	m:Toggle{text = "Infinite jump", flag = "char_inf"}
	m:Toggle{text = "Bunny hop (auto)", flag = "char_bhop"}
	m:Slider{text = "Bhop max speed", flag = "bhop_max", min = 20, max = 300, default = 90}
	m:Slider{text = "Bhop gain / jump", flag = "bhop_gain", min = 0, max = 20, step = 0.5, default = 4}
	local f = tMove:Section("Fly & Noclip", 2)
	f:Toggle{text = "Fly (WASD / Space / Shift)", flag = "char_fly", cb = function(v)
		if not v then local h = hum() if h then h.PlatformStand = false end flyOn = false flyPos = nil end
	end}
	f:Slider{text = "Fly speed", flag = "char_flyspeed", min = 10, max = 300, default = 60}
	f:Toggle{text = "Noclip while flying", flag = "char_flync", default = true}
	f:Toggle{text = "Noclip", flag = "char_noclip"}
	f:Toggle{text = "Spin", flag = "char_spin", cb = function(v)
		local h = hum()
		if h then if v then Base.ar = h.AutoRotate else h.AutoRotate = Base.ar ~= false end end
	end}
	f:Slider{text = "Spin speed", flag = "char_spinspeed", min = 30, max = 1440, step = 10, default = 360, suffix = "/s"}
	f:Label("CFrame / Velocity speed methods bypass games that reset WalkSpeed.")
	if SAFE then f:Label("Safe mode: speed, jump, fly, noclip, spin e bhop travados (o server ve e anticheat checa).") end
end

do
	local tChar = newTab("Character", "Player")
	local b = tChar:Section("Body", 1)
	b:Toggle{text = "Recolor character", flag = "body_on"}
	b:Color{text = "Color", flag = "body_color"}
	b:Cycle{text = "Material", flag = "body_mat", options = MAT_NAMES, default = "Neon"}
	b:Toggle{text = "Hide face / decals", flag = "body_nodecal", default = true, cb = function()
		if BodyP.active then restorePaint(BodyP) BodyP.dirty = true end
	end}
	local t = tChar:Section("Weapon (held tool)", 2)
	t:Toggle{text = "Recolor weapon", flag = "tool_on"}
	t:Color{text = "Color", flag = "tool_color", default = Color3.fromRGB(0, 200, 255)}
	t:Cycle{text = "Material", flag = "tool_mat", options = MAT_NAMES, default = "Neon"}
	local v = tChar:Section("Viewmodel (first person)", 2)
	v:Toggle{text = "Recolor viewmodel", flag = "view_on"}
	v:Color{text = "Color", flag = "view_color", default = Color3.fromRGB(0, 200, 255)}
	v:Cycle{text = "Material", flag = "view_mat", options = MAT_NAMES, default = "Neon"}
	local r = tChar:Section("Rainbow", 1)
	r:Toggle{text = "Rainbow (all of the above)", flag = "rainbow"}
	r:Slider{text = "Speed", flag = "rainbow_speed", min = 1, max = 10, default = 3}
end

do
	local tPlr = newTab("Players", "Player")
	local function selPlayer() return Players:FindFirstChild(F.tp_target or "") end
	local function items()
		local t = {}
		local c = cam()
		local cp = c and c.CFrame.Position
		for _, p in ipairs(Players:GetPlayers()) do
			if p ~= LP then
				local ch = p.Character
				local h = ch and ch:FindFirstChildOfClass("Humanoid")
				local r = ch and ch:FindFirstChild("HumanoidRootPart")
				local info = h and (math.floor(h.Health) .. "hp") or ""
				if r and cp then info = info .. " " .. math.floor((r.Position - cp).Magnitude) .. "m" end
				if WL[p.UserId] then info = "[W] " .. info end
				t[#t + 1] = {id = p.Name, info = info,
					text = (p.DisplayName ~= p.Name) and (p.DisplayName .. " (@" .. p.Name .. ")") or p.Name}
			end
		end
		table.sort(t, function(a, b) return a.id:lower() < b.id:lower() end)
		return t
	end
	local l = tPlr:Section("Player list", 1)
	local infoL
	local function upd()
		local p = selPlayer()
		if not infoL then return end
		if not p then infoL.Text = "No player selected" return end
		local ch = p.Character
		local h = ch and ch:FindFirstChildOfClass("Humanoid")
		local tool = ch and ch:FindFirstChildOfClass("Tool")
		infoL.Text = string.format("%s | HP %d/%d | Team: %s | Tool: %s | ID %d", p.Name, math.floor(h and h.Health or 0),
			math.floor(h and h.MaxHealth or 0), p.Team and p.Team.Name or "none", tool and tool.Name or "-", p.UserId)
	end
	l:List{flag = "tp_target", height = 230, getItems = items, cb = upd}
	infoL = l:Label("No player selected")

	local function step(d)
		local ids = Elements.tp_target.api.items
		if #ids == 0 then return notify("No players") end
		local i = (table.find(ids, F.tp_target) or (d > 0 and 0 or 1)) + d
		if i < 1 then i = #ids elseif i > #ids then i = 1 end
		Elements.tp_target.Set(ids[i])
		if not F.spec_on then Elements.spec_on.Set(true) end
		upd()
	end
	local a = tPlr:Section("View & teleport", 2)
	a:Toggle{text = "View (spectate)", flag = "spec_on", cb = function(v)
		if not v then local c, h = cam(), hum() if c and h then c.CameraSubject = h end end
	end}
	a:Button{text = "View previous player", cb = function() step(-1) end}
	a:Button{text = "View next player", cb = function() step(1) end}
	a:Button{text = "Teleport to player", cb = function()
		local plr = selPlayer()
		local ch = plr and plr.Character
		local tr, mr = ch and ch:FindFirstChild("HumanoidRootPart"), hrp()
		if tr and mr then mr.CFrame = tr.CFrame * CFrame.new(0, 0, 3) else notify("Select a player first") end
	end}
	a:Button{text = "Copy username", cb = function()
		local p = selPlayer()
		if p and setclipboard then setclipboard(p.Name) notify("Copied " .. p.Name) end
	end}
	a:Button{text = "Copy UserId", cb = function()
		local p = selPlayer()
		if p and setclipboard then setclipboard(tostring(p.UserId)) notify("Copied " .. p.UserId) end
	end}
	local w = tPlr:Section("Targeting & whitelist", 2)
	w:Toggle{text = "Aimbot: only selected", flag = "aim_onlysel"}
	w:Toggle{text = "Silent: only selected", flag = "silent_onlysel"}
	w:Button{text = "Whitelist: toggle selected", cb = function()
		local p = selPlayer()
		if not p then return notify("Select a player first") end
		WL[p.UserId] = (not WL[p.UserId]) or nil
		notify(p.Name .. (WL[p.UserId] and " whitelisted" or " removed from whitelist"))
		refreshPlayers()
	end}
	w:Button{text = "Whitelist: clear all", cb = function() table.clear(WL) refreshPlayers() end}
	w:Label("Whitelisted players are ignored by aimbot, silent aim, triggerbot and hitbox, and shown green in ESP.")

	local acc = 0
	local tick_ = guard("Player list", function(dt)
		acc += dt
		if acc >= 1 then acc = 0 Elements.tp_target.Refresh() upd() end
	end)
	on(RunService.Heartbeat, function(dt)
		if Unloaded or Active ~= tPlr then return end
		tick_(dt)
	end)
end

-- TROLL
do
	local function build()
		local tTr = newTab("Troll", "Player")
		local TR = {vel = Vector3.zero, movel = 0.1, hit = false, busy = false, stop = false, anti = {}, seat = nil}
		local fAng = 0

		local function selTarget()
			local plr = Players:FindFirstChild(F.tp_target or "")
			local ch = plr and plr.Character
			return plr, ch and ch:FindFirstChild("HumanoidRootPart"), ch and ch:FindFirstChildOfClass("Humanoid")
		end

		-- walkfling: velocity spike after physics, restored before render so only others feel it
		on(RunService.Heartbeat, function()
			if Unloaded or not F.tr_walkfling then return end
			local r = hrp()
			if not r then return end
			TR.vel = r.AssemblyLinearVelocity
			TR.hit = true
			r.AssemblyLinearVelocity = TR.vel * 1e4 + Vector3.new(0, 1e4, 0)
		end)
		on(RunService.RenderStepped, function()
			if not TR.hit then return end
			local r = hrp()
			if r then r.AssemblyLinearVelocity = TR.vel end
		end)
		on(RunService.Stepped, function()
			if Unloaded then return end
			if TR.hit then
				TR.hit = false
				local r = hrp()
				if r then
					r.AssemblyLinearVelocity = TR.vel + Vector3.new(0, TR.movel, 0)
					TR.movel = -TR.movel
				end
			end
			if F.tr_anti then
				for _, plr in ipairs(Players:GetPlayers()) do
					local ch = plr ~= LP and plr.Character
					if ch then
						for _, d in ipairs(ch:GetChildren()) do
							if d:IsA("BasePart") and d.CanCollide then TR.anti[d] = true d.CanCollide = false end
						end
					end
				end
			end
		end)

		-- per-frame states: anti-fling velocity clamp, loop jump, play dead, follow
		on(RunService.Heartbeat, function(dt)
			if Unloaded then return end
			local r, h = hrp(), hum()
			if not (r and h) then return end
			if F.tr_anti and not F.tr_walkfling and not TR.busy then
				if r.AssemblyAngularVelocity.Magnitude > 120 or r.AssemblyLinearVelocity.Magnitude > 450 then
					r.AssemblyLinearVelocity = Vector3.zero
					r.AssemblyAngularVelocity = Vector3.zero
				end
			end
			if F.tr_loopjump then h.Jump = true end
			if F.tr_dead then
				if not h.PlatformStand then h.PlatformStand = true end
				r.CFrame = CFrame.new(r.Position) * CFrame.Angles(-math.pi / 2, 0, 0)
			end
			if F.tr_follow and not TR.busy then
				local _, tr = selTarget()
				if tr then
					local m, d = F.tr_follow_m, F.tr_dist
					local cf
					if m == "Behind" then cf = tr.CFrame * CFrame.new(0, 0, d)
					elseif m == "Above head" then cf = tr.CFrame * CFrame.new(0, d + 2, 0)
					elseif m == "Underneath" then cf = tr.CFrame * CFrame.new(0, -d - 2, 0)
					else
						fAng += dt * F.tr_speed
						cf = CFrame.lookAt(tr.Position + Vector3.new(math.cos(fAng) * d, 1, math.sin(fAng) * d), tr.Position)
					end
					r.CFrame = cf
					r.AssemblyLinearVelocity = Vector3.zero
				end
			end
		end)

		local function respawnInPlace()
			local r, h = hrp(), hum()
			if not (r and h) then return end
			local cf = r.CFrame
			local conn
			conn = LP.CharacterAdded:Connect(function(ch)
				conn:Disconnect()
				local nr = ch:WaitForChild("HumanoidRootPart", 10)
				if nr then task.wait(0.1) nr.CFrame = cf end
			end)
			h.Health = 0
		end

		-- seat-weld invisibility (known trick, game dependent)
		local function invisOn()
			if TR.seat then return end
			local ch, r = LP.Character, hrp()
			local torso = ch and (ch:FindFirstChild("Torso") or ch:FindFirstChild("UpperTorso"))
			if not (r and torso) then return notify("Character not ready") end
			task.spawn(function()
				local old = r.CFrame
				local far = Vector3.new(-25.95, 84, 3537.55)
				r.CFrame = CFrame.new(far)
				task.wait(0.15)
				if not (r.Parent and torso.Parent) then return end
				local seat = Instance.new("Seat")
				seat.Name = "invischair"
				seat.Anchored = false
				seat.CanCollide = false
				seat.Transparency = 1
				seat.Position = far
				seat.Parent = Workspace
				local weld = Instance.new("Weld")
				weld.Part0 = seat
				weld.Part1 = torso
				weld.Parent = seat
				task.wait()
				seat.CFrame = old
				TR.seat = seat
				notify("Invisible (experimental). Turn it off to respawn in place")
			end)
		end
		local function invisOff()
			local seat = TR.seat
			if not seat then return end
			TR.seat = nil
			pcall(function() seat:Destroy() end)
			respawnInPlace()
		end

		-- target fling: sit on the target at huge velocity, then return
		local function flingOne(plr)
			local r, h = hrp(), hum()
			local tch = plr.Character
			local tr = tch and tch:FindFirstChild("HumanoidRootPart")
			local th = tch and tch:FindFirstChildOfClass("Humanoid")
			if not (r and h and tr and th) then return false end
			local old = r.CFrame
			local oldH = Workspace.FallenPartsDestroyHeight
			Workspace.FallenPartsDestroyHeight = -1e9
			local t0, ang, flip = tick(), 0, 1
			while not TR.stop and not Unloaded and r.Parent and tr.Parent and th.Health > 0 and h.Health > 0
				and tick() - t0 < 2.2 and tr.AssemblyLinearVelocity.Magnitude < 500 do
				ang += 100
				flip = -flip
				local lead = Vector3.zero
				local sp = tr.AssemblyLinearVelocity.Magnitude
				if sp < 50 then lead = th.MoveDirection * sp / 1.25 end
				r.CFrame = CFrame.new(tr.Position + lead) * CFrame.new(0, 1.5 * flip, 0) * CFrame.Angles(math.rad(ang), 0, 0)
				r.AssemblyLinearVelocity = Vector3.new(9e7, 9e8, 9e7)
				r.AssemblyAngularVelocity = Vector3.new(9e8, 9e8, 9e8)
				task.wait()
			end
			for _ = 1, 15 do
				if not r.Parent then break end
				r.AssemblyLinearVelocity = Vector3.zero
				r.AssemblyAngularVelocity = Vector3.zero
				r.CFrame = old
				task.wait()
			end
			Workspace.FallenPartsDestroyHeight = oldH
			return true
		end
		local function runFling(list)
			if TR.busy then return notify("A fling is already running") end
			if #list == 0 then return notify("No targets") end
			TR.busy, TR.stop = true, false
			task.spawn(function()
				local n = 0
				for _, plr in ipairs(list) do
					if TR.stop or Unloaded then break end
					if flingOne(plr) then n += 1 end
				end
				TR.busy = false
				notify("Fling finished (" .. n .. " targets)")
			end)
		end

		local s1 = tTr:Section("Fling", 1)
		s1:Toggle{text = "Walkfling", flag = "tr_walkfling"}
		s1:Toggle{text = "Invis fling (experimental)", flag = "tr_invisfling", cb = function(v)
			if v then
				invisOn()
				Elements.tr_walkfling.Set(true)
			else
				Elements.tr_walkfling.Set(false)
				invisOff()
			end
		end}
		s1:Button{text = "Fling selected player", cb = function()
			local plr = Players:FindFirstChild(F.tp_target or "")
			if not plr then return notify("Select a player in the Players tab first") end
			runFling({plr})
		end}
		s1:Button{text = "Fling all players", cb = function()
			local list = {}
			for _, plr in ipairs(Players:GetPlayers()) do
				if plr ~= LP and not WL[plr.UserId] and not (F.tr_fling_team and isTeam(plr)) then list[#list + 1] = plr end
			end
			runFling(list)
		end}
		s1:Button{text = "Stop fling", cb = function() TR.stop = true end}
		s1:Toggle{text = "Skip teammates (fling all)", flag = "tr_fling_team", default = true}
		s1:Label("Walkfling: touch players while you move. Fling selected / all: you jump onto them for a moment and come back. The selected player comes from the Players tab. Results depend on the game's physics and anticheat.")

		local s2 = tTr:Section("Invisible & fake states", 1)
		s2:Toggle{text = "Invisible (experimental)", flag = "tr_invis", cb = function(v) if v then invisOn() else invisOff() end end}
		s2:Toggle{text = "Play dead", flag = "tr_dead", cb = function(v)
			if not v then
				local h, r = hum(), hrp()
				if h then h.PlatformStand = false end
				if r then r.CFrame = CFrame.new(r.Position) end
			end
		end}
		s2:Toggle{text = "Freeze position (lag switch)", flag = "tr_freeze", cb = function(v)
			local r = hrp()
			if r then r.Anchored = v end
		end}
		s2:Toggle{text = "Loop jump", flag = "tr_loopjump"}
		s2:Button{text = "Sit", cb = function() local h = hum() if h then h.Sit = true end end}
		s2:Button{text = "Respawn in place", cb = respawnInPlace}

		local s3 = tTr:Section("Follow selected player", 2)
		s3:Toggle{text = "Follow", flag = "tr_follow"}
		s3:Cycle{text = "Mode", flag = "tr_follow_m", options = {"Behind", "Above head", "Underneath", "Orbit"}}
		s3:Slider{text = "Distance", flag = "tr_dist", min = 1, max = 30, default = 5}
		s3:Slider{text = "Orbit speed", flag = "tr_speed", min = 1, max = 20, default = 4}
		s3:Label("Underneath puts you inside the ground, so turn Noclip on first.")

		local s4 = tTr:Section("Defense", 2)
		s4:Toggle{text = "Anti-fling", flag = "tr_anti", cb = function(v)
			if not v then
				for part in pairs(TR.anti) do if part.Parent then part.CanCollide = true end end
				table.clear(TR.anti)
			end
		end}
		s4:Label("Other players' bodies stop colliding with you and sudden velocity spikes on your character are cancelled.")
		if SAFE then s4:Label("Safe mode: toda esta aba esta travada (mexe em CFrame/velocity/physics que o server replica).") end

		Cleanups[#Cleanups + 1] = function()
			TR.stop = true
			local r, h = hrp(), hum()
			if r and F.tr_freeze then r.Anchored = false end
			if h and F.tr_dead then h.PlatformStand = false end
			for part in pairs(TR.anti) do if part.Parent then part.CanCollide = true end end
			if TR.seat then pcall(function() TR.seat:Destroy() end) end
		end
	end
	build()
end

-- MISC
do
	local tMisc = newTab("Utilities", "Miscellaneous")
	local u = tMisc:Section("Tools", 1)
	u:Button{text = "Execute Infinite Yield", cb = function()
		task.spawn(function()
			local ok, err = pcall(function()
				loadstring(game:HttpGet("https://raw.githubusercontent.com/EdgeIY/infiniteyield/master/source"))()
			end)
			if not ok then notify("Infinite Yield failed: " .. tostring(err)) end
		end)
	end}
	u:Toggle{text = "Anti-AFK", flag = "misc_afk", default = true}
	u:Toggle{text = "Auto rejoin on kick", flag = "misc_rejoin"}
	u:Toggle{text = "Ctrl + Click teleport", flag = "misc_clicktp"}
	u:Slider{text = "FPS cap", flag = "misc_fps", min = 30, max = 360, step = 10, default = 60, cb = function(v)
		if setfpscap then setfpscap(v) end
	end}
	u:Button{text = "Reset character", cb = function() local h = hum() if h then h.Health = 0 end end}
	local s = tMisc:Section("Server", 2)
	s:Button{text = "Rejoin", cb = function() TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LP) end}
	s:Button{text = "Server hop", cb = serverHop}
	s:Button{text = "Copy PlaceId", cb = function()
		if setclipboard then setclipboard(tostring(game.PlaceId)) notify("PlaceId copied") end
	end}
	s:Button{text = "Copy JobId", cb = function()
		if setclipboard then setclipboard(tostring(game.JobId)) notify("JobId copied") end
	end}
end

do
	local function build()
		local tFx = newTab("???", "Miscellaneous")
		local FX = {o = {}, pe = {}, t = 0, hue = 0, wk = "Off", bk = "None", sc = setmetatable({}, {__mode = "k"}), acc = 0}
		local RAINBOW = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 0, 0)), ColorSequenceKeypoint.new(0.17, Color3.fromRGB(255, 200, 0)),
			ColorSequenceKeypoint.new(0.34, Color3.fromRGB(80, 255, 80)), ColorSequenceKeypoint.new(0.5, Color3.fromRGB(0, 220, 255)),
			ColorSequenceKeypoint.new(0.67, Color3.fromRGB(60, 80, 255)), ColorSequenceKeypoint.new(0.84, Color3.fromRGB(200, 60, 255)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 0, 0)),
		})

		-- weather ---------------------------------------------------
		local WK = {
			Snow = {off = 35, rate = 2.2, build = function(e)
				e.Lifetime = NumberRange.new(7, 10) e.Speed = NumberRange.new(9, 14) e.Size = NumberSequence.new(0.3)
				e.Color = ColorSequence.new(Color3.new(1, 1, 1)) e.LightEmission = 0.4 e.SpreadAngle = Vector2.new(12, 12)
				e.EmissionDirection = Enum.NormalId.Bottom e.Rotation = NumberRange.new(0, 360) e.RotSpeed = NumberRange.new(-40, 40)
			end},
			Rain = {off = 35, rate = 7, build = function(e)
				e.Lifetime = NumberRange.new(0.8, 1) e.Speed = NumberRange.new(95, 110) e.Size = NumberSequence.new(0.5)
				e.Color = ColorSequence.new(Color3.fromRGB(170, 200, 255)) e.LightEmission = 0.2 e.SpreadAngle = Vector2.new(2, 2)
				e.EmissionDirection = Enum.NormalId.Bottom e.Orientation = Enum.ParticleOrientation.VelocityParallel
				e.Transparency = NumberSequence.new(0.35)
			end},
			Embers = {off = -3, rate = 1.2, build = function(e)
				e.Lifetime = NumberRange.new(4, 7) e.Speed = NumberRange.new(3, 7) e.Size = NumberSequence.new(0.25)
				e.Color = ColorSequence.new(Color3.fromRGB(255, 170, 40), Color3.fromRGB(255, 60, 10)) e.LightEmission = 1
				e.SpreadAngle = Vector2.new(25, 25) e.EmissionDirection = Enum.NormalId.Top
			end},
			Sparkles = {off = 4, rate = 0.8, build = function(e)
				e.Lifetime = NumberRange.new(3, 5) e.Speed = NumberRange.new(0.5, 2) e.Size = NumberSequence.new(0.35)
				e.Color = RAINBOW e.LightEmission = 1 e.SpreadAngle = Vector2.new(180, 180) e.EmissionDirection = Enum.NormalId.Top
			end},
		}
		local function weatherSet(kind)
			if FX.em then pcall(function() FX.em:Destroy() end) FX.em = nil end
			local w = WK[kind]
			if not w then
				if FX.part then pcall(function() FX.part:Destroy() end) FX.part = nil end
				FX.wk = "Off"
				return
			end
			local c = cam()
			if not c then return end
			if not FX.part or not FX.part.Parent then
				local part = Instance.new("Part")
				part.Name = rname()
				part.Anchored, part.CanCollide, part.CanQuery, part.CanTouch = true, false, false, false
				part.Transparency = 1
				part.Size = Vector3.new(90, 1, 90)
				part.Parent = c
				FX.part = part
			end
			FX.wk = kind
			local e = Instance.new("ParticleEmitter")
			e.Name = rname()
			w.build(e)
			e.Rate = w.rate * F.fx_intensity
			e.Parent = FX.part
			FX.em = e
		end

		-- character effects ----------------------------------------
		local function put(key, cond, make)
			local list = FX.o[key]
			if cond then
				local r = hrp()
				if r and (not list or not list[1].Parent) then
					if list then for _, i in ipairs(list) do pcall(i.Destroy, i) end end
					list = make(r)
					FX.o[key] = list
				end
				return list
			elseif list then
				for _, i in ipairs(list) do pcall(i.Destroy, i) end
				FX.o[key] = nil
			end
		end
		local function charTick()
			local ch = LP.Character
			local a = put("aura", F.fx_aura, function(r)
				local e = Instance.new("ParticleEmitter")
				e.Rate = 30 e.Lifetime = NumberRange.new(1, 1.6) e.Speed = NumberRange.new(0.5, 2) e.SpreadAngle = Vector2.new(180, 180)
				e.LightEmission = 1 e.EmissionDirection = Enum.NormalId.Top
				e.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 1.2), NumberSequenceKeypoint.new(1, 0)})
				e.Parent = r
				return {e}
			end)
			if a then a[1].Color = ColorSequence.new(F.fx_auracol) end
			local t = put("trail", F.fx_trail, function(r)
				local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
				a0.Position, a1.Position = Vector3.new(0, 1, 0), Vector3.new(0, -1, 0)
				a0.Parent, a1.Parent = r, r
				local tr = Instance.new("Trail")
				tr.Attachment0, tr.Attachment1 = a0, a1
				tr.Color = RAINBOW
				tr.LightEmission = 0.8
				tr.Transparency = NumberSequence.new(0, 1)
				tr.Parent = r
				return {tr, a0, a1}
			end)
			if t then t[1].Lifetime = F.fx_traillife end
			local g = put("glow", F.fx_glow, function()
				local h = Instance.new("Highlight")
				h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
				h.FillTransparency = 0.75
				h.Parent = Holder
				return {h}
			end)
			if g then g[1].Adornee = ch g[1].FillColor = F.fx_glowcol g[1].OutlineColor = F.fx_glowcol end
			local l = put("light", F.fx_light, function(r)
				local pl = Instance.new("PointLight")
				pl.Shadows = false
				pl.Parent = r
				return {pl}
			end)
			if l then l[1].Brightness = F.fx_lightb l[1].Range = F.fx_lightr l[1].Color = F.fx_lightcol end
			local kind = F.fx_body
			if FX.bk ~= kind then
				local old = FX.o.bfx
				if old then for _, i in ipairs(old) do pcall(i.Destroy, i) end FX.o.bfx = nil end
				FX.bk = kind
			end
			put("bfx", kind ~= "None", function(r)
				local i = Instance.new(kind)
				i.Parent = r
				return {i}
			end)
			local h = hum()
			if h then
				local want = F.fx_scale and F.fx_scaleval or nil
				for _, n in ipairs({"BodyHeightScale", "BodyWidthScale", "BodyDepthScale", "HeadScale"}) do
					local v = h:FindFirstChild(n)
					if v and v:IsA("NumberValue") then
						if FX.sc[v] == nil then FX.sc[v] = v.Value end
						if want then
							if v.Value ~= want then v.Value = want end
						elseif v.Value ~= FX.sc[v] then
							v.Value = FX.sc[v]
						end
					end
				end
			end
		end

		-- post processing -------------------------------------------
		local function pe(class, key, enabled, props)
			local o = FX.pe[key]
			if enabled then
				if not o or not o.Parent then
					o = Instance.new(class)
					o.Name = rname()
					o:SetAttribute("crez", true)
					o.Parent = Lighting
					FX.pe[key] = o
				end
				for k, v in pairs(props) do if o[k] ~= v then o[k] = v end end
			elseif o then
				pcall(function() o:Destroy() end)
				FX.pe[key] = nil
			end
		end
		local function peTick()
			pe("ColorCorrectionEffect", "cc", F.fx_cc, {Saturation = F.fx_ccsat, Contrast = F.fx_cccon, Brightness = F.fx_ccbri, TintColor = F.fx_cctint})
			pe("BlurEffect", "blur", F.fx_blur, {Size = F.fx_blursize})
			pe("BloomEffect", "bloom", F.fx_bloom, {Intensity = F.fx_bloomi, Size = 24, Threshold = 0.8})
			pe("SunRaysEffect", "rays", F.fx_rays, {Intensity = 0.25, Spread = 1})
		end

		-- cinematic bars --------------------------------------------
		local barT = mk("Frame", {Size = UDim2.new(1, 0, 0, 0), BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0, ZIndex = 0, Visible = false, Parent = Gui})
		local barB = mk("Frame", {AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.new(1, 0, 0, 0),
			BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0, ZIndex = 0, Visible = false, Parent = Gui})

		-- freecam -----------------------------------------------------
		local fc = {on = false, cf = CFrame.new(), yaw = 0, pitch = 0}
		local function controls(enable)
			pcall(function()
				local pm = require(LP:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule", 2))
				local ctl = pm:GetControls()
				if enable then ctl:Enable() else ctl:Disable() end
			end)
		end
		local function freecamStart()
			local c = cam()
			if not c or fc.on then return end
			fc.on = true
			fc.cf = c.CFrame
			fc.pitch, fc.yaw = c.CFrame:ToOrientation()
			fc.ctype = c.CameraType
			c.CameraType = Enum.CameraType.Scriptable
			controls(false)
		end
		local function freecamStop()
			if not fc.on then return end
			fc.on = false
			local c = cam()
			if c then c.CameraType = fc.ctype or Enum.CameraType.Custom end
			UIS.MouseBehavior = Enum.MouseBehavior.Default
			controls(true)
		end

		-- replicated accessory effects: accessory handles are physics-owned by you, so everyone sees them move ----
		local RA = {list = {}, ch = nil, t = 0, acc = 0, hist = {}}
		local function raCollect(n)
			local out, ch = {}, LP.Character
			if not ch then return out end
			for _, acc in ipairs(ch:GetChildren()) do
				if #out >= n then break end
				if acc:IsA("Accessory") then
					local hd = acc:FindFirstChild("Handle")
					if hd and hd:IsA("BasePart") then
						local w = hd:FindFirstChildWhichIsA("JointInstance") or hd:FindFirstChildWhichIsA("WeldConstraint")
						if w then out[#out + 1] = {h = hd, w = w} end
					end
				end
			end
			return out
		end
		local function raRelease()
			for _, e in ipairs(RA.list) do pcall(function() e.w.Enabled = true end) end
			RA.list = {}
			RA.ch = nil
		end
		local raStep = guard("Shared accessories", function(dt)
			if not F.fx_rep then
				if #RA.list > 0 then raRelease() end
				return
			end
			local r, ch = hrp(), LP.Character
			if not (r and ch) then return end
			RA.t += dt
			RA.acc += dt
			RA.hist[#RA.hist + 1] = r.Position
			if #RA.hist > 240 then table.remove(RA.hist, 1) end
			if ch ~= RA.ch or RA.acc > 1 then
				RA.acc = 0
				if ch ~= RA.ch then RA.list = {} RA.ch = ch end
				local fresh = raCollect(F.fx_repn)
				for _, old in ipairs(RA.list) do
					local keep = false
					for _, e in ipairs(fresh) do if e.h == old.h then keep = true break end end
					if not keep then pcall(function() old.w.Enabled = true end) end
				end
				RA.list = fresh
			end
			local n = #RA.list
			if n == 0 then return end
			local mode, rad, hgt, spd = F.fx_repmode, F.fx_reprad, F.fx_rephgt, F.fx_repspd
			for i, e in ipairs(RA.list) do
				local hd = e.h
				if hd.Parent then
					if e.w.Enabled then e.w.Enabled = false end
					if hd.CanCollide then hd.CanCollide = false end
					if not hd.Massless then hd.Massless = true end
					local ph = (i - 1) / n * math.pi * 2
					local cf
					if mode == "Orbit" then
						local a = RA.t * spd + ph
						cf = CFrame.new(r.Position + Vector3.new(math.cos(a) * rad, hgt, math.sin(a) * rad)) * CFrame.Angles(RA.t * 2, a, 0)
					elseif mode == "Halo" then
						local head = ch:FindFirstChild("Head")
						local base = head and head.Position or (r.Position + Vector3.new(0, 2, 0))
						local a = RA.t * spd + ph
						cf = CFrame.new(base + Vector3.new(math.cos(a) * rad * 0.5, 1.6, math.sin(a) * rad * 0.5)) * CFrame.Angles(0, a, 0)
					elseif mode == "Snake" then
						local pp = RA.hist[#RA.hist - i * 10] or r.Position
						cf = CFrame.new(pp + Vector3.new(0, hgt, 0))
					else
						local side = (i % 2 == 0) and 1 or -1
						local lvl = math.ceil(i / 2)
						local flap = math.sin(RA.t * spd * 2 + lvl * 0.5) * 0.35
						cf = r.CFrame * CFrame.new(side * (1 + lvl * 0.9), 0.8 + lvl * 0.25 + flap, 1.1) * CFrame.Angles(0, 0, side * (0.4 + flap))
					end
					hd.CFrame = cf
					hd.AssemblyLinearVelocity = Vector3.zero
					hd.AssemblyAngularVelocity = Vector3.zero
				end
			end
		end)

		-- stretched screen (camera matrix squeeze) -------------------------------------------------------------
		HK.stretch = guard("Stretch", function()
			if not F.fx_stretch then HK.sm = nil return end
			local c = cam()
			if not c then HK.sm = nil return end
			HK.sm = {F.fx_sx, F.fx_sy}
			if c.CFrame ~= HK.sLast then
				c.CFrame = c.CFrame * CFrame.new(0, 0, 0, F.fx_sx, 0, 0, 0, F.fx_sy, 0, 0, 0, 1)
				HK.sLast = c.CFrame
			end
		end)

		-- sections ----------------------------------------------------
		local a = tFx:Section("Lights & sky", 1)
		local lightProps = {"Ambient", "OutdoorAmbient", "ColorShift_Top", "ColorShift_Bottom"}
		a:Toggle{text = "Disco lights", flag = "fx_disco", cb = function(v) if not v then wrestore(Lighting, lightProps) end end}
		a:Slider{text = "Disco tempo", flag = "fx_tempo", min = 1, max = 20, default = 6, suffix = "/s"}
		a:Toggle{text = "Rainbow sky", flag = "fx_rainbow", cb = function(v)
			if not v then
				wrestore(Lighting, {"ColorShift_Top", "ColorShift_Bottom"})
				local at = Lighting:FindFirstChildOfClass("Atmosphere")
				if at then wrestore(at, {"Color"}) end
			end
		end}
		a:Toggle{text = "Day / night cycle", flag = "fx_cycle"}
		a:Slider{text = "Cycle speed", flag = "fx_cyclespd", min = 1, max = 100, default = 20}
		a:Button{text = "Noon", cb = function() Lighting.ClockTime = 12 end}
		a:Button{text = "Sunset", cb = function() Lighting.ClockTime = 18 end}
		a:Button{text = "Midnight", cb = function() Lighting.ClockTime = 0 end}

		local cm = tFx:Section("Camera", 1)
		cm:Toggle{text = "Freecam (hold RMB, WASD, Q/E)", flag = "fx_free", cb = function(v) if v then freecamStart() else freecamStop() end end}
		cm:Slider{text = "Freecam speed", flag = "fx_fcspeed", min = 5, max = 200, default = 40}
		cm:Slider{text = "Freecam sensitivity", flag = "fx_fcsens", min = 0.2, max = 3, step = 0.1, default = 1}
		cm:Toggle{text = "Cinematic bars", flag = "fx_bars"}
		cm:Slider{text = "Bars size", flag = "fx_barsize", min = 0, max = 30, default = 12, suffix = "%"}

		local pf = tFx:Section("Performance", 1)
		pf:Toggle{text = "Potato mode", flag = "fx_potato", cb = function(v)
			pcall(function()
				local r = settings().Rendering
				if v then FX.ql = FX.ql or r.QualityLevel r.QualityLevel = Enum.QualityLevel.Level01
				elseif FX.ql then r.QualityLevel = FX.ql FX.ql = nil end
			end)
			if v then wset(Lighting, "GlobalShadows", false) else wrestore(Lighting, {"GlobalShadows"}) end
		end}

		local sc = tFx:Section("Screen", 1)
		sc:Toggle{text = "Stretched screen", flag = "fx_stretch", cb = function(v)
			if not v then
				local c = cam()
				if c and HK.sm and c.CFrame == HK.sLast then
					c.CFrame = c.CFrame * CFrame.new(0, 0, 0, 1 / HK.sm[1], 0, 0, 0, 1 / HK.sm[2], 0, 0, 0, 1)
				end
				HK.sm = nil
			end
		end}
		sc:Cycle{text = "Preset", flag = "fx_stretchp", options = {"Custom", "Slight", "4:3 stretched", "Extreme"}, cb = function(v)
			local map = {Slight = 0.85, ["4:3 stretched"] = 0.75, Extreme = 0.5}
			if map[v] then Elements.fx_sx.Set(1) Elements.fx_sy.Set(map[v]) end
		end}
		sc:Slider{text = "Horizontal", flag = "fx_sx", min = 0.6, max = 1.6, step = 0.01, default = 1}
		sc:Slider{text = "Vertical", flag = "fx_sy", min = 0.3, max = 1.2, step = 0.01, default = 0.65}
		sc:Label("Squeezes the camera so everything looks wider. ESP, aimbot and silent aim follow the stretched view.")

		local sh = tFx:Section("Shared with other players", 1)
		sh:Toggle{text = "Floating accessories", flag = "fx_rep", cb = function(v) if not v then raRelease() end end}
		sh:Cycle{text = "Pattern", flag = "fx_repmode", options = {"Orbit", "Halo", "Snake", "Wings"}}
		sh:Slider{text = "Accessories used", flag = "fx_repn", min = 1, max = 8, default = 4}
		sh:Slider{text = "Radius", flag = "fx_reprad", min = 2, max = 12, step = 0.5, default = 5}
		sh:Slider{text = "Height", flag = "fx_rephgt", min = -2, max = 6, step = 0.5, default = 1.5}
		sh:Slider{text = "Speed", flag = "fx_repspd", min = 0.5, max = 10, step = 0.5, default = 2.5}
		sh:Button{text = "Release accessories", cb = function() raRelease() end}
		sh:Label("Roblox only shows other players what your client controls by physics, and that is your own accessories. They are detached and moved every frame, so everyone sees them at once. Particles, fire, sparkles, trails, colors, lights and the orb are made by your client and stay visible only to you.")

		local w = tFx:Section("Weather", 2)
		w:Cycle{text = "Weather", flag = "fx_weather", options = {"Off", "Snow", "Rain", "Embers", "Sparkles"}, cb = weatherSet}
		w:Slider{text = "Intensity", flag = "fx_intensity", min = 1, max = 100, default = 40, cb = function(v)
			if FX.em and WK[FX.wk] then FX.em.Rate = WK[FX.wk].rate * v end
		end}

		local ch = tFx:Section("Character effects", 2)
		ch:Toggle{text = "Aura", flag = "fx_aura"}
		ch:Color{text = "Aura color", flag = "fx_auracol", default = Color3.fromRGB(120, 80, 255)}
		ch:Toggle{text = "Rainbow trail", flag = "fx_trail"}
		ch:Slider{text = "Trail length", flag = "fx_traillife", min = 0.2, max = 3, step = 0.1, default = 1}
		ch:Toggle{text = "Outline glow", flag = "fx_glow"}
		ch:Color{text = "Glow color", flag = "fx_glowcol", default = Color3.fromRGB(0, 200, 255)}
		ch:Toggle{text = "Point light", flag = "fx_light"}
		ch:Slider{text = "Light brightness", flag = "fx_lightb", min = 1, max = 10, default = 3}
		ch:Slider{text = "Light range", flag = "fx_lightr", min = 8, max = 60, default = 20}
		ch:Color{text = "Light color", flag = "fx_lightcol", default = Color3.new(1, 1, 1)}
		ch:Cycle{text = "Body effect", flag = "fx_body", options = {"None", "Fire", "Smoke", "Sparkles"}}
		ch:Toggle{text = "Resize character (R15)", flag = "fx_scale"}
		ch:Slider{text = "Body scale", flag = "fx_scaleval", min = 0.3, max = 4, step = 0.1, default = 1.5}
		ch:Toggle{text = "Companion orb", flag = "fx_orb"}
		ch:Color{text = "Orb color", flag = "fx_orbcol", default = Color3.fromRGB(0, 255, 200)}

		local pp = tFx:Section("Post-processing", 2)
		pp:Toggle{text = "Color grading", flag = "fx_cc"}
		pp:Slider{text = "Saturation", flag = "fx_ccsat", min = -1, max = 3, step = 0.05, default = 1}
		pp:Slider{text = "Contrast", flag = "fx_cccon", min = -1, max = 1, step = 0.05, default = 0}
		pp:Slider{text = "Brightness", flag = "fx_ccbri", min = -0.5, max = 0.5, step = 0.05, default = 0}
		pp:Color{text = "Tint", flag = "fx_cctint", default = Color3.new(1, 1, 1)}
		pp:Toggle{text = "Blur", flag = "fx_blur"}
		pp:Slider{text = "Blur size", flag = "fx_blursize", min = 0, max = 56, default = 12}
		pp:Toggle{text = "Bloom", flag = "fx_bloom"}
		pp:Slider{text = "Bloom intensity", flag = "fx_bloomi", min = 0, max = 3, step = 0.1, default = 1}
		pp:Toggle{text = "Sun rays", flag = "fx_rays"}

		-- main loop -----------------------------------------------------
		local step = guard("Effects tab", function(dt)
			local c = cam()
			if F.fx_disco then
				FX.t += dt * F.fx_tempo
				if FX.t >= 1 then
					FX.t = 0
					local col = Color3.fromHSV(math.random(), 0.9, 1)
					wset(Lighting, "Ambient", col) wset(Lighting, "OutdoorAmbient", col)
					wset(Lighting, "ColorShift_Top", Color3.fromHSV(math.random(), 1, 1))
					wset(Lighting, "ColorShift_Bottom", Color3.fromHSV(math.random(), 1, 1))
				end
			end
			if F.fx_rainbow then
				FX.hue = (FX.hue + dt * 0.08) % 1
				wset(Lighting, "ColorShift_Top", Color3.fromHSV(FX.hue, 0.8, 1))
				wset(Lighting, "ColorShift_Bottom", Color3.fromHSV((FX.hue + 0.5) % 1, 0.8, 1))
				local at = Lighting:FindFirstChildOfClass("Atmosphere")
				if at then wset(at, "Color", Color3.fromHSV(FX.hue, 0.5, 1)) end
			end
			if F.fx_cycle then wset(Lighting, "ClockTime", (Lighting.ClockTime + dt * F.fx_cyclespd * 0.05) % 24) end
			if FX.part and c then
				if FX.part.Parent ~= c then FX.part.Parent = c end
				FX.part.CFrame = CFrame.new(c.CFrame.Position + Vector3.new(0, WK[FX.wk] and WK[FX.wk].off or 0, 0))
			end
			-- companion orb
			if F.fx_orb and c then
				local r = hrp()
				if r then
					if not FX.orb or not FX.orb.Parent then
						local o = Instance.new("Part")
						o.Name = rname()
						o.Shape = Enum.PartType.Ball
						o.Size = Vector3.new(1.3, 1.3, 1.3)
						o.Material = Enum.Material.Neon
						o.Anchored, o.CanCollide, o.CanQuery, o.CanTouch = true, false, false, false
						local pl = Instance.new("PointLight")
						pl.Range, pl.Brightness = 14, 2
						pl.Parent = o
						o.Parent = c
						FX.orb = o
						FX.orbp = r.Position + Vector3.new(2, 3, 0)
					end
					FX.orb.Color = F.fx_orbcol
					local pl = FX.orb:FindFirstChildOfClass("PointLight")
					if pl then pl.Color = F.fx_orbcol end
					local goal = r.Position + r.CFrame.RightVector * 3 + Vector3.new(0, 3 + math.sin(os.clock() * 2) * 0.5, 0)
					FX.orbp = FX.orbp:Lerp(goal, math.clamp(dt * 6, 0, 1))
					FX.orb.CFrame = CFrame.new(FX.orbp)
				end
			elseif FX.orb then
				pcall(function() FX.orb:Destroy() end)
				FX.orb = nil
			end
			-- bars
			local show = F.fx_bars and c ~= nil
			barT.Visible, barB.Visible = show, show
			if show then
				local hgt = math.floor(c.ViewportSize.Y * F.fx_barsize / 100)
				barT.Size = UDim2.new(1, 0, 0, hgt)
				barB.Size = UDim2.new(1, 0, 0, hgt)
			end
			-- freecam
			if fc.on and c then
				if UIS:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) then
					UIS.MouseBehavior = Enum.MouseBehavior.LockCurrentPosition
					local d = UIS:GetMouseDelta()
					fc.yaw -= d.X * 0.0035 * F.fx_fcsens
					fc.pitch = math.clamp(fc.pitch - d.Y * 0.0035 * F.fx_fcsens, -1.55, 1.55)
				else
					UIS.MouseBehavior = Enum.MouseBehavior.Default
				end
				local rot = CFrame.fromOrientation(fc.pitch, fc.yaw, 0)
				local mv = Vector3.zero
				if not UIS:GetFocusedTextBox() then
					if UIS:IsKeyDown(Enum.KeyCode.W) then mv += Vector3.new(0, 0, -1) end
					if UIS:IsKeyDown(Enum.KeyCode.S) then mv += Vector3.new(0, 0, 1) end
					if UIS:IsKeyDown(Enum.KeyCode.A) then mv += Vector3.new(-1, 0, 0) end
					if UIS:IsKeyDown(Enum.KeyCode.D) then mv += Vector3.new(1, 0, 0) end
					if UIS:IsKeyDown(Enum.KeyCode.E) or UIS:IsKeyDown(Enum.KeyCode.Space) then mv += Vector3.new(0, 1, 0) end
					if UIS:IsKeyDown(Enum.KeyCode.Q) or UIS:IsKeyDown(Enum.KeyCode.LeftControl) then mv += Vector3.new(0, -1, 0) end
				end
				local spd = F.fx_fcspeed * (UIS:IsKeyDown(Enum.KeyCode.LeftShift) and 3 or 1)
				local move = rot * Vector3.new(mv.X, 0, mv.Z) + Vector3.new(0, mv.Y, 0)
				fc.cf = CFrame.new(fc.cf.Position + move * spd * dt) * rot
				c.CameraType = Enum.CameraType.Scriptable
				c.CFrame = fc.cf
			end
			-- slower work: character effects and post effects
			FX.acc += dt
			if FX.acc >= 0.2 then
				FX.acc = 0
				charTick()
				peTick()
			end
		end)
		on(RunService.RenderStepped, function(dt) if not Unloaded then step(dt) end end)
		on(RunService.Heartbeat, function(dt) if not Unloaded then raStep(dt) end end)

		Cleanups[#Cleanups + 1] = function()
			freecamStop()
			raRelease()
			HK.stretch, HK.sm = nil, nil
			for _, list in pairs(FX.o) do for _, i in ipairs(list) do pcall(i.Destroy, i) end end
			for _, o in pairs(FX.pe) do pcall(function() o:Destroy() end) end
			if FX.part then pcall(function() FX.part:Destroy() end) end
			if FX.orb then pcall(function() FX.orb:Destroy() end) end
			for v, orig in pairs(FX.sc) do if v.Parent then pcall(setProp, v, "Value", orig) end end
			if FX.ql then pcall(function() settings().Rendering.QualityLevel = FX.ql end) end
		end
	end
	build()
end

do
	local tCfg = newTab("Config", "Miscellaneous")
	local DIR = "crez_hub"
	local function clean(n)
		n = tostring(n or ""):gsub("[^%w _%-]", ""):gsub("^%s+", ""):gsub("%s+$", "")
		return n
	end
	local function items()
		local out = {}
		if listfiles and isfolder and isfolder(DIR) then
			local ok, files = pcall(listfiles, DIR)
			if ok and type(files) == "table" then
				for _, f in ipairs(files) do
					local n = f:match("([^/\\]+)%.json$")
					if n and n:sub(1, 1) ~= "_" then out[#out + 1] = {id = n, text = n} end
				end
			end
		end
		table.sort(out, function(a, b) return a.id:lower() < b.id:lower() end)
		return out
	end
	local function refresh() local e = Elements.cfg_sel if e then e.Refresh() end end
	local function save(name)
		name = clean(name)
		if name == "" then return notify("Type a config name first") end
		if not writefile then return notify("Executor has no writefile") end
		pcall(function() if makefolder and isfolder and not isfolder(DIR) then makefolder(DIR) end end)
		local out = {}
		for k, v in pairs(F) do
			local e = Elements[k]
			if not (e and e.nosave) then
				if typeof(v) == "Color3" then out[k] = {__c = {v.R, v.G, v.B}} else out[k] = v end
			end
		end
		local ok, err = pcall(function() writefile(DIR .. "/" .. name .. ".json", HttpService:JSONEncode(out)) end)
		notify(ok and ("Saved config: " .. name) or ("Save failed: " .. tostring(err)))
		if ok then Elements.cfg_sel.Set(name) refresh() end
	end
	local function loadc(name)
		name = clean(name)
		local path = DIR .. "/" .. name .. ".json"
		if name == "" or not (readfile and isfile) or not isfile(path) then return notify("Config not found") end
		local ok, data = pcall(function() return HttpService:JSONDecode(readfile(path)) end)
		if not ok or type(data) ~= "table" then return notify("Config file is invalid") end
		for k, v in pairs(data) do
			local e = Elements[k]
			if e and not e.nosave then
				if type(v) == "table" and v.__c then v = Color3.new(v.__c[1], v.__c[2], v.__c[3]) end
				e.Set(v)
			end
		end
		notify("Loaded config: " .. name)
	end

	local m = tCfg:Section("Menu", 1)
	m:Keybind{text = "Menu key", flag = "menu_key", default = "Insert", required = true, cb = function(k) Foot.Text = "CREZ hub " .. T.version .. "   |   menu: " .. k end}
	m:Color{text = "Accent color", flag = "ui_accent", default = T.accent, cb = function(c) T.accent = c refreshAll() end}
	m:Slider{text = "UI scale", flag = "ui_scale", min = 0.6, max = 1.3, step = 0.05, default = 1, cb = function() fit(true) end}
	m:Toggle{text = "Notifications", flag = "ui_notify", default = true}
	m:Label(SAFE and "Safe mode: ON (sem hooks, features detectaveis travadas). Pra mudar, reexecute o script."
		or "Safe mode: OFF (tudo liberado). Pra mudar, reexecute o script.")
	local u = tCfg:Section("Hub", 1)
	u:Button{text = "Unload hub", cb = function() Unload() end}
	u:Button{text = "Reset all to defaults", cb = function()
		for flag, v in pairs(T.defaults) do
			local e = Elements[flag]
			if e and not e.nosave then e.Set(v) end
		end
		notify("Settings reset to defaults")
	end}
	local ds = tCfg:Section("Diagnostics", 1)
	local dl = ds:Label("No module errors so far.")
	ds:Button{text = "Show / copy error log", cb = function()
		local parts = {}
		for name, e in pairs(ErrSeen) do parts[#parts + 1] = name .. ": " .. tostring(e) end
		table.sort(parts)
		local txt = #parts > 0 and table.concat(parts, "\n") or "No module errors so far."
		dl.Text = txt:sub(1, 600)
		if #parts > 0 and setclipboard then setclipboard(txt) notify("Error log copied (" .. #parts .. ")") end
	end}
	ds:Label("CREZ hub " .. T.version .. ". A module that errors is isolated and reported here, so one failure never stops the rest of the hub.")

	local c = tCfg:Section("Configs", 2)
	c:TextInput{flag = "cfg_name", placeholder = "config name"}
	c:List{flag = "cfg_sel", height = 120, getItems = items, cb = function(id) Elements.cfg_name.Set(id) end}
	c:Button{text = "Save (typed name / selected)", cb = function()
		save(F.cfg_name ~= "" and F.cfg_name or F.cfg_sel)
	end}
	c:Button{text = "Load selected", cb = function() loadc(F.cfg_sel) end}
	c:Button{text = "Delete selected", cb = function()
		local name = clean(F.cfg_sel)
		if name == "" or not delfile then return notify("Nothing to delete") end
		pcall(delfile, DIR .. "/" .. name .. ".json")
		Elements.cfg_sel.Set("")
		refresh()
		notify("Deleted " .. name)
	end}
	c:Button{text = "Autoload: set selected", cb = function()
		local name = clean(F.cfg_sel)
		if name == "" or not writefile then return notify("Select a config first") end
		pcall(writefile, DIR .. "/_autoload.txt", name)
		notify("Autoload: " .. name)
	end}
	c:Button{text = "Autoload: clear", cb = function()
		if delfile and isfile and isfile(DIR .. "/_autoload.txt") then pcall(delfile, DIR .. "/_autoload.txt") end
		notify("Autoload cleared")
	end}
	c:Button{text = "Refresh list", cb = refresh}

	task.defer(function()
		if Unloaded then return end
		if isfile and readfile and isfile(DIR .. "/_autoload.txt") then
			local ok, n = pcall(readfile, DIR .. "/_autoload.txt")
			if ok and clean(n) ~= "" then loadc(n) end
		end
	end)
end

Foot.Text = "CREZ hub " .. T.version .. (SAFE and " [safe]" or "") .. "   |   menu: " .. F.menu_key
selectTab(Tabs[1])
fit(true)

----------------------------------------------------------------------
-- loops and input
----------------------------------------------------------------------
local RS_NAME = rname()
if LP.Character then hookChar(LP.Character) end
hookCam()
on(LP.CharacterAdded, function(ch)
	hookChar(ch)
	dirtyAll()
	flyOn, flyPos = false, nil
	task.defer(function()
		local h = ch:FindFirstChildOfClass("Humanoid") or ch:WaitForChild("Humanoid", 5)
		if h then Base.ws, Base.jp, Base.jh, Base.usejp = h.WalkSpeed, h.JumpPower, h.JumpHeight, h.UseJumpPower end
	end)
end)
on(Workspace:GetPropertyChangedSignal("CurrentCamera"), function() hookCam() ViewP.dirty = true lastVP = nil end)
on(Players.PlayerAdded, function(p) addESP(p) refreshPlayers() end)
on(Players.PlayerRemoving, function(p) removeESP(p) task.defer(refreshPlayers) end)

do
local gAim, gSilent, gEsp = guard("Aimbot", aimStep), guard("Silent Aim", silentStep), guard("ESP", espStep)
local gCross, gWorld, gPaint = guard("Crosshair", crossStep), guard("World", worldStep), guard("Painter", paintStep)
local gWM, gFit, gHum, gSpec = guard("Watermark", wmStep), guard("UI scale", fit), guard("Humanoid", humStep), guard("Spectate", specStep)
local gMove, gHB, gTrig, gNC = guard("Movement", moveStep), guard("Hitbox", hbStep), guard("Triggerbot", trigStep), guard("Noclip", noclipStep)
local gAuto = guard("Autoclicker", autoStep)
local gMB = guard("Magic bullet", function(dt) HK.mb(dt) end)

RunService:BindToRenderStep(RS_NAME, Enum.RenderPriority.Camera.Value + 1, function(dt)
	if Unloaded then return end
	if HK.stretch then HK.stretch() end
	gAim(dt) gSilent() gMB(dt) gEsp() gCross() gWorld() gPaint(dt) gWM(dt) gFit() gHum() gSpec()
end)
on(RunService.Heartbeat, function(dt)
	if Unloaded then return end
	gMove(dt) gHB(dt) gTrig() gAuto() gHum()
end)
on(RunService.Stepped, function()
	if Unloaded then return end
	gNC()
end)
end

on(UIS.JumpRequest, function()
	if Unloaded then return end
	local h, r = hum(), hrp()
	if not (h and r) then return end
	if F.char_inf then
		local jv = (F.char_jump_on and F.char_jump) or (h.UseJumpPower and h.JumpPower or math.sqrt(2 * Workspace.Gravity * h.JumpHeight))
		h:ChangeState(Enum.HumanoidStateType.Jumping)
		local v = r.AssemblyLinearVelocity
		r.AssemblyLinearVelocity = Vector3.new(v.X, jv, v.Z)
	elseif F.char_jump_on and F.char_jump_m == "Velocity" and h.FloorMaterial ~= Enum.Material.Air then
		local v = r.AssemblyLinearVelocity
		r.AssemblyLinearVelocity = Vector3.new(v.X, F.char_jump, v.Z)
	end
end)
on(GuiService.ErrorMessageChanged, function()
	if not F.misc_rejoin or Unloaded then return end
	task.delay(2, function() pcall(function() TeleportService:Teleport(game.PlaceId, LP) end) end)
end)
on(LP.Idled, function()
	if F.misc_afk then VirtualUser:CaptureController() VirtualUser:ClickButton2(Vector2.new()) end
end)

on(UIS.InputBegan, function(i, gp)
	if isPress(i) then lmbDown = true lmbUntil = tick() + 0.15 end
	if gp then return end
	local name = (i.UserInputType == Enum.UserInputType.Keyboard) and i.KeyCode.Name or i.UserInputType.Name
	if Binding then
		if name == "Unknown" or name == "Touch" or name == "MouseMovement" then return end
		local b = Binding
		Binding = nil
		b.fn(name)
		return
	end
	if name == F.menu_key then setMenu(not Main.Visible) end
	for i = 1, #KBList do
		local k = KBList[i]
		if F[k[2]] == name then local e = Elements[k[1]] if e then e.Set(not F[k[1]]) end end
	end
	if F.misc_clicktp and i.UserInputType == Enum.UserInputType.MouseButton1 and UIS:IsKeyDown(Enum.KeyCode.LeftControl) then
		local r = hrp()
		if r then r.CFrame = CFrame.new(Mouse.Hit.Position + Vector3.new(0, 3, 0)) end
	end
end)
on(UIS.InputEnded, function(i)
	if isPress(i) then lmbDown = false end
end)

----------------------------------------------------------------------
-- unload
----------------------------------------------------------------------
Unload = function()
	Unloaded = true
	HK.cur = nil
	pcall(function() RunService:UnbindFromRenderStep(RS_NAME) end)
	for _, c in ipairs(Conns) do pcall(function() c:Disconnect() end) end
	for plr in pairs(ESP) do removeESP(plr) end
	for _, d in ipairs({AimCircle, SilCircle, SilLine, CrossDot, WM}) do pcall(function() d:Remove() end) end
	for _, l in ipairs(CrossL) do pcall(function() l:Remove() end) end
	restorePaint(BodyP) restorePaint(ToolP) restorePaint(ViewP)
	for _, fn in ipairs(Cleanups) do pcall(fn) end
	hbRestore()
	for e in pairs(PostOff) do if e.Parent then e.Enabled = true end end
	pcall(function()
		for inst, o in pairs(WO) do
			if inst.Parent then for prop, v in pairs(o) do pcall(setProp, inst, prop, v) end end
		end
		local h = hum()
		if h then
			h.PlatformStand = false
			if F.char_spin then h.AutoRotate = Base.ar ~= false end
			if F.char_speed_on then h.WalkSpeed = Base.ws end
			if F.char_jump_on then if Base.usejp then h.JumpPower = Base.jp else h.JumpHeight = Base.jh end end
		end
		for p in pairs(NoclipOrig) do if p.Parent then p.CanCollide = true end end
		if F.spec_on and h and cam() then cam().CameraSubject = h end
	end)
	Gui:Destroy()
	env.CrezHub = nil
end
env.CrezHub = {Unload = Unload}

notify("CREZ " .. T.version .. (SAFE and " [safe]" or "") .. " loaded. " .. F.menu_key .. " toggles the menu")
