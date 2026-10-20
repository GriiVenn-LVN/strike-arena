--!strict
-- StarterPlayerScripts/Menu/Fx (ModuleScript, client) — effets du menu, branchés par des appels courts :
--   Fx.ambient(bgGui)              poussières lumineuses qui montent doucement et petits éclats au fond du menu
--   Fx.confetti(obj)               pluie de confettis qui part du centre d'un objet (récompense récupérée)
--   Fx.coins(n, obj?)              pièces qui volent vers le compteur, avec un « +n 💰 » qui défile
--   Fx.reward(obj, coins, xp)      confettis + pièces + petit message (défi récupéré)
--   Fx.pop(texte, couleur?)        petite notification qui tombe en haut de l'écran puis s'efface
--   Fx.flipOut(obj) / Fx.flipIn(obj)  carte qui s'efface / nouvelle carte qui arrive (défi changé)
--   Fx.countTo(label, a, b, fmt)   nombre qui défile dans un texte
-- Tout est dessiné dans une ScreenGui à part (« MenuFx », au-dessus du menu, jamais cliquable) : rien ne bouge la mise en page.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Fx = {}

local GOLD = Color3.fromRGB(255, 210, 58)
local COLORS = { Color3.fromRGB(255, 70, 85), GOLD, Color3.fromRGB(74, 163, 255), Color3.fromRGB(125, 255, 159), Color3.fromRGB(199, 125, 255), Color3.new(1, 1, 1) }

local function make(class: string, props: { [string]: any }, parent: Instance?): any
	local o: any = Instance.new(class)
	if o:IsA("GuiObject") then o.BorderSizePixel = 0; o.Active = false; pcall(function() o.Interactable = false end) end
	if class == "TextLabel" then o.BackgroundTransparency = 1; o.Font = Enum.Font.GothamBlack; o.TextColor3 = Color3.new(1, 1, 1); o.RichText = true end
	for k, v in pairs(props) do o[k] = v end
	if parent then o.Parent = parent end
	return o
end
local function tween(o: Instance, t: number, props: { [string]: any }, style: Enum.EasingStyle?, dir: Enum.EasingDirection?): Tween
	local tw = TweenService:Create(o, TweenInfo.new(t, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), props)
	tw:Play()
	return tw
end

-- couche des effets (créée au premier besoin)
local fxGui: ScreenGui? = nil
local function layer(): ScreenGui
	if fxGui and fxGui.Parent then return fxGui end
	local pg = Players.LocalPlayer:WaitForChild("PlayerGui")
	local g = make("ScreenGui", { Name = "MenuFx", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 30, ZIndexBehavior = Enum.ZIndexBehavior.Sibling }, pg)
	fxGui = g
	return g
end
-- position d'un objet du menu dans la couche des effets (qui ignore la barre du haut de Roblox, pas le menu)
local function absPos(o: GuiObject): Vector2
	local sg = o:FindFirstAncestorWhichIsA("ScreenGui")
	local inset = if sg and not sg.IgnoreGuiInset then game:GetService("GuiService"):GetGuiInset() else Vector2.zero
	return o.AbsolutePosition + inset
end
local function center(o: GuiObject?): Vector2
	local g = layer()
	if o and o.Parent then return absPos(o) + o.AbsoluteSize / 2 end
	return g.AbsoluteSize / 2
end
-- cadre posé exactement sur un objet (les cartes sont dans des listes : on ne leur ajoute pas d'enfant)
local function over(o: GuiObject): Frame
	local p = absPos(o)
	return make("Frame", { Position = UDim2.fromOffset(p.X, p.Y), Size = UDim2.fromOffset(o.AbsoluteSize.X, o.AbsoluteSize.Y), BackgroundTransparency = 1,
		ClipsDescendants = true, ZIndex = 4 }, layer())
end

-- ---------- fond : poussières et éclats ----------
type Mote = { f: Frame, x: number, y: number, vy: number, ph: number, amp: number }
function Fx.ambient(bg: ScreenGui)
	if bg:FindFirstChild("FxMotes") then return end
	local holder = make("Frame", { Name = "FxMotes", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 2 }, bg)
	local rng = Random.new()
	local motes: { Mote } = {}
	for i = 1, 28 do
		local s = rng:NextInteger(2, 5)
		local f = make("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(s, s), BackgroundColor3 = COLORS[(i % 3) + 1]:Lerp(Color3.new(1, 1, 1), 0.5),
			BackgroundTransparency = rng:NextNumber(0.55, 0.85), ZIndex = 1 }, holder)
		make("UICorner", { CornerRadius = UDim.new(0.5, 0) }, f)
		table.insert(motes, { f = f, x = rng:NextNumber(), y = rng:NextNumber(), vy = rng:NextNumber(0.012, 0.035), ph = rng:NextNumber(0, 6.28), amp = rng:NextNumber(0.004, 0.018) })
	end
	-- éclat : petite étoile à 4 branches qui s'allume puis s'éteint à un endroit au hasard
	local function sparkle()
		local x, y = rng:NextNumber(0.05, 0.95), rng:NextNumber(0.1, 0.9)
		local st = make("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(x, y), Size = UDim2.fromOffset(14, 14), BackgroundTransparency = 1, ZIndex = 1 }, holder)
		local sc = make("UIScale", { Scale = 0.2 }, st)
		for _, r in ipairs({ 0, 90 }) do
			local b = make("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(1, 0, 0, 2), Rotation = r,
				BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.35, ZIndex = 1 }, st)
			make("UIGradient", { Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0), NumberSequenceKeypoint.new(1, 1) }) }, b)
		end
		tween(sc, 0.45, { Scale = 1 }, Enum.EasingStyle.Back)
		tween(st, 1.2, { Rotation = 45 })
		task.delay(0.6, function() tween(sc, 0.5, { Scale = 0 }) end)
		task.delay(1.2, function() st:Destroy() end)
	end
	local acc = 0
	local conn = RunService.Heartbeat:Connect(function(dt: number)
		if not bg.Enabled then return end   -- menu fermé : rien ne bouge
		local t = os.clock()
		for _, m in ipairs(motes) do
			m.y -= m.vy * dt
			if m.y < -0.03 then m.y = 1.03; m.x = rng:NextNumber() end
			m.f.Position = UDim2.fromScale(m.x + math.sin(t * 0.6 + m.ph) * m.amp, m.y)
		end
		acc += dt
		if acc > 1.6 then acc = 0; if rng:NextNumber() < 0.7 then sparkle() end end
	end)
	holder.Destroying:Connect(function() conn:Disconnect() end)
end

-- ---------- confettis ----------
type Bit = { f: Frame, vx: number, vy: number, vr: number }
function Fx.confetti(at: GuiObject?, count: number?)
	local g = layer()
	local c = center(at)
	local rng = Random.new()
	local bits: { Bit } = {}
	for i = 1, count or 34 do
		local f = make("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(c.X, c.Y), Size = UDim2.fromOffset(rng:NextInteger(5, 9), rng:NextInteger(3, 5)),
			BackgroundColor3 = COLORS[(i % #COLORS) + 1], Rotation = rng:NextNumber(0, 360), ZIndex = 5 }, g)
		local a = rng:NextNumber(math.rad(200), math.rad(340))
		local sp = rng:NextNumber(220, 520)
		table.insert(bits, { f = f, vx = math.cos(a) * sp, vy = math.sin(a) * sp, vr = rng:NextNumber(-540, 540) })
	end
	local life = 0
	local conn: RBXScriptConnection
	conn = RunService.Heartbeat:Connect(function(dt: number)
		life += dt
		for _, b in ipairs(bits) do
			b.vy += 900 * dt; b.vx *= (1 - 1.6 * dt)
			local p = b.f.Position
			b.f.Position = UDim2.fromOffset(p.X.Offset + b.vx * dt, p.Y.Offset + b.vy * dt)
			b.f.Rotation += b.vr * dt
			if life > 0.8 then b.f.BackgroundTransparency = math.min(1, (life - 0.8) / 0.6) end
		end
		if life > 1.4 then
			conn:Disconnect()
			for _, b in ipairs(bits) do b.f:Destroy() end
		end
	end)
end

-- ---------- nombre qui défile ----------
function Fx.countTo(label: TextLabel, from: number, to: number, fmt: ((number) -> string)?, dur: number?)
	local d = dur or 0.8
	local t0 = os.clock()
	local f = fmt or function(n: number): string return tostring(n) end
	local conn: RBXScriptConnection
	conn = RunService.Heartbeat:Connect(function()
		if not label.Parent then conn:Disconnect(); return end
		local k = math.clamp((os.clock() - t0) / d, 0, 1)
		k = 1 - (1 - k) ^ 3
		label.Text = f(math.floor(from + (to - from) * k + 0.5))
		if k >= 1 then conn:Disconnect() end
	end)
end

-- ---------- pièces qui volent + compteur ----------
function Fx.coins(n: number, from: GuiObject?)
	if n == 0 then return end
	local g = layer()
	local size = g.AbsoluteSize
	local target = Vector2.new(size.X - 150, 36)
	local c = center(from)
	-- le compteur : « +n 💰 » qui défile en haut à droite (ou « −n » quand on dépense)
	local lab = make("TextLabel", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(target.X, target.Y + 30), Size = UDim2.fromOffset(180, 30),
		TextSize = 22, TextColor3 = if n > 0 then GOLD else Color3.fromRGB(255, 120, 120), TextStrokeTransparency = 0.5, Text = (if n > 0 then "+" else "−") .. math.abs(n) .. " 💰", ZIndex = 6 }, g)
	local sc = make("UIScale", { Scale = 0.4 }, lab)
	local sign = if n > 0 then "+" else "−"
	if n > 0 then
		for i = 1, math.clamp(math.floor(n / 15), 4, 10) do
			local coin = make("TextLabel", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(c.X + math.random(-30, 30), c.Y + math.random(-12, 12)),
				Size = UDim2.fromOffset(24, 24), Text = "💰", TextSize = 20, ZIndex = 6 }, g)
			local delay = (i - 1) * 0.05
			task.delay(delay, function()
				local tw = tween(coin, 0.55, { Position = UDim2.fromOffset(target.X, target.Y) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
				tw.Completed:Connect(function() coin:Destroy() end)
			end)
		end
	end
	task.delay(if n > 0 then 0.45 else 0, function()
		tween(sc, 0.3, { Scale = 1 }, Enum.EasingStyle.Back)
		Fx.countTo(lab, 0, math.abs(n), function(v: number): string return sign .. v .. " 💰" end, 0.7)
		task.delay(1.6, function()
			tween(lab, 0.4, { TextTransparency = 1, TextStrokeTransparency = 1, Position = UDim2.fromOffset(target.X, target.Y + 6) })
			task.delay(0.45, function() lab:Destroy() end)
		end)
	end)
end

-- ---------- notification ----------
local popY = 0
function Fx.pop(msg: string, color: Color3?)
	local g = layer()
	local slot = popY; popY = (popY + 1) % 3
	local y = 86 + slot * 44
	local f = make("TextLabel", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, y - 30), Size = UDim2.fromOffset(0, 36), AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = Color3.fromRGB(11, 17, 28), Text = msg, TextSize = 14, TextColor3 = color or Color3.new(1, 1, 1),
		TextTransparency = 1, BackgroundTransparency = 1, ZIndex = 7 }, g)
	make("UICorner", { CornerRadius = UDim.new(0, 18) }, f)
	make("UIPadding", { PaddingLeft = UDim.new(0, 18), PaddingRight = UDim.new(0, 18) }, f)
	local st = make("UIStroke", { Color = color or GOLD, Thickness = 1.5, Transparency = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, f)
	local sc = make("UIScale", { Scale = 0.8 }, f)
	tween(f, 0.35, { Position = UDim2.new(0.5, 0, 0, y), TextTransparency = 0, BackgroundTransparency = 0.08 }, Enum.EasingStyle.Back)
	tween(st, 0.35, { Transparency = 0.35 })
	tween(sc, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
	task.delay(2.4, function()
		tween(f, 0.35, { TextTransparency = 1, BackgroundTransparency = 1, Position = UDim2.new(0.5, 0, 0, y - 16) })
		tween(st, 0.35, { Transparency = 1 })
		task.delay(0.4, function() f:Destroy() end)
	end)
end

-- ---------- récompense ----------
function Fx.reward(at: GuiObject?, coins: number?, xp: number?)
	Fx.confetti(at)
	if coins and coins > 0 then Fx.coins(coins, at) end
	if xp and xp > 0 then Fx.pop("✔  Défi récupéré  ·  +" .. xp .. " XP", GOLD) end
end

-- ---------- carte remplacée ----------
local function fxScale(o: Instance): UIScale
	local s = o:FindFirstChild("FxScale")
	if s and s:IsA("UIScale") then return s end
	return make("UIScale", { Name = "FxScale" }, o)
end
-- la carte rétrécit sous un voile blanc ; le voile reste jusqu'au rendu suivant (ou 2 s au plus)
function Fx.flipOut(o: GuiObject)
	tween(fxScale(o), 0.18, { Scale = 0.86 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	local flash = over(o)
	flash.BackgroundColor3 = Color3.new(1, 1, 1)
	make("UICorner", { CornerRadius = UDim.new(0, 10) }, flash)
	tween(flash, 0.18, { BackgroundTransparency = 0.6 })
	task.delay(0.3, function() tween(flash, 0.3, { BackgroundTransparency = 1 }) end)
	task.delay(0.7, function() flash:Destroy() end)
	-- remise à l'échelle si la carte n'est pas redessinée (refus du serveur)
	task.delay(0.9, function() if o.Parent then tween(fxScale(o), 0.25, { Scale = 1 }, Enum.EasingStyle.Back) end end)
end
-- la nouvelle carte arrive en rebondissant, avec un éclair doré, un reflet et quelques confettis
function Fx.flipIn(o: GuiObject)
	local s = fxScale(o)
	s.Scale = 0.7
	tween(s, 0.45, { Scale = 1 }, Enum.EasingStyle.Back)
	task.defer(function()
		if not o.Parent then return end
		local holder = over(o)
		holder.BackgroundColor3 = GOLD; holder.BackgroundTransparency = 0.5
		make("UICorner", { CornerRadius = UDim.new(0, 10) }, holder)
		tween(holder, 0.6, { BackgroundTransparency = 1 })
		local band = make("Frame", { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.fromScale(-0.5, 0.5), Size = UDim2.fromScale(0.35, 2), Rotation = 14,
			BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 5 }, holder)
		make("UIGradient", { Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0.55), NumberSequenceKeypoint.new(1, 1) }) }, band)
		task.delay(0.12, function() tween(band, 0.6, { Position = UDim2.fromScale(1.2, 0.5) }, Enum.EasingStyle.Sine) end)
		task.delay(0.9, function() holder:Destroy() end)
		Fx.confetti(o, 14)
	end)
end
-- reflet doré qui repasse sur un objet rare tant qu'il est affiché (sans lui ajouter d'enfant : listes, grilles)
function Fx.sheen(o: GuiObject, every: number?)
	local alive = true
	o.Destroying:Connect(function() alive = false end)
	task.spawn(function()
		while alive and o.Parent do
			task.wait(every or 3)
			if not (alive and o.Parent and o.Visible and o.AbsoluteSize.X > 0) then continue end
			local sg = o:FindFirstAncestorWhichIsA("ScreenGui")
			if sg and not sg.Enabled then continue end
			-- défilée hors de sa colonne : pas de reflet (il dépasserait de la zone visible)
			local sf = o:FindFirstAncestorWhichIsA("ScrollingFrame")
			if sf then
				local top, bot = sf.AbsolutePosition.Y, sf.AbsolutePosition.Y + sf.AbsoluteSize.Y
				if o.AbsolutePosition.Y < top or o.AbsolutePosition.Y + o.AbsoluteSize.Y > bot then continue end
			end
			local holder = over(o)
			make("UICorner", { CornerRadius = UDim.new(0, 10) }, holder)
			local band = make("Frame", { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.fromScale(-0.5, 0.5), Size = UDim2.fromScale(0.3, 2.2), Rotation = 14,
				BackgroundColor3 = Color3.fromRGB(255, 240, 190), ZIndex = 5 }, holder)
			make("UIGradient", { Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0.72), NumberSequenceKeypoint.new(1, 1) }) }, band)
			tween(band, 0.9, { Position = UDim2.fromScale(1.2, 0.5) }, Enum.EasingStyle.Sine)
			task.delay(0.95, function() holder:Destroy() end)
		end
	end)
end

return Fx
