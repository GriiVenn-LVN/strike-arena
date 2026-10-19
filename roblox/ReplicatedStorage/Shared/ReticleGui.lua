--!strict
-- ReplicatedStorage/Shared/ReticleGui (ModuleScript, côté client)
-- Dessin d'un réticule en cadres d'interface : copie de drawReticle() du web (src/64c_sights.js).
-- Sert pour la lunette plein écran, l'aperçu Arsenal › Viseurs et la lentille des viseurs 3D (SurfaceGui).
-- draw(parent, cx, cy, R, forme, "#couleur", big) : big = réticule de lunette plein écran (R = rayon de la lunette).
local R = {}

local function hex(c: string): Color3
	local ok, col = pcall(Color3.fromHex, c)
	return if ok then col else Color3.new(1, 0, 0)
end
R.hex = hex

function R.draw(parent: GuiObject, cx: number, cy: number, Rr: number, sh: string, colHex: string, big: boolean, z: number?)
	local col = hex(colHex)
	local lw = if big then 2 else math.max(2, Rr * .07)
	local zi = z or 5
	local function dot(r: number)
		local f = Instance.new("Frame"); f.AnchorPoint = Vector2.new(.5, .5); f.Position = UDim2.fromOffset(cx, cy)
		f.Size = UDim2.fromOffset(r * 2, r * 2); f.BackgroundColor3 = col; f.BorderSizePixel = 0; f.ZIndex = zi
		local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(1, 0); c.Parent = f
		f.Parent = parent
	end
	local function dotAt(x: number, y: number, r: number)
		local f = Instance.new("Frame"); f.AnchorPoint = Vector2.new(.5, .5); f.Position = UDim2.fromOffset(x, y)
		f.Size = UDim2.fromOffset(r * 2, r * 2); f.BackgroundColor3 = col; f.BorderSizePixel = 0; f.ZIndex = zi
		local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(1, 0); c.Parent = f
		f.Parent = parent
	end
	local function line(x1: number, y1: number, x2: number, y2: number, w: number?)
		local dx, dy = x2 - x1, y2 - y1
		local L = math.sqrt(dx * dx + dy * dy)
		local f = Instance.new("Frame"); f.AnchorPoint = Vector2.new(.5, .5); f.Position = UDim2.fromOffset((x1 + x2) / 2, (y1 + y2) / 2)
		local t = w or lw
		f.Size = UDim2.fromOffset(L + t, t); f.Rotation = math.deg(math.atan2(dy, dx)); f.BackgroundColor3 = col; f.BorderSizePixel = 0; f.ZIndex = zi
		local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(1, 0); c.Parent = f       -- bouts arrondis (lineCap = round)
		f.Parent = parent
	end
	local function ring(r: number, w: number)
		local f = Instance.new("Frame"); f.AnchorPoint = Vector2.new(.5, .5); f.Position = UDim2.fromOffset(cx, cy)
		f.Size = UDim2.fromOffset(r * 2, r * 2); f.BackgroundTransparency = 1; f.ZIndex = zi
		local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(1, 0); c.Parent = f
		local s = Instance.new("UIStroke"); s.Thickness = w; s.Color = col; s.Parent = f
		f.Parent = parent
	end
	if sh == "dot" then dot(if big then math.max(3, Rr * .012) else Rr * .14)
	elseif sh == "circle" then
		ring(Rr * (if big then .14 else .72), lw); dot(if big then math.max(2.5, Rr * .009) else Rr * .09)
	elseif sh == "cross" then
		local g, e = Rr * (if big then .025 else .16), Rr * (if big then 1 else .9)
		line(cx - e, cy, cx - g, cy); line(cx + g, cy, cx + e, cy); line(cx, cy - e, cx, cy - g); line(cx, cy + g, cx, cy + e)
		dot(if big then 2 else lw * .7 / 2 + .5)
	elseif sh == "chevron" then
		local s = Rr * (if big then .07 else .38)
		local thin = if big then lw else lw * .6
		local e = Rr * (if big then 1 else .95)
		line(cx - s, cy + s * .85, cx, cy); line(cx, cy, cx + s, cy + s * .85)
		line(cx, cy + s * 1.4, cx, cy + e, thin)
		line(cx - e, cy, cx - s * 1.5, cy, thin); line(cx + s * 1.5, cy, cx + e, cy, thin)
	elseif sh == "duplex" then
		local t, a, e = lw * (if big then 3 else 2.2), Rr * .4, Rr
		local thin = if big then 1.3 else lw * .6
		line(cx - e, cy, cx - a, cy, t); line(cx + a, cy, cx + e, cy, t); line(cx, cy + a, cx, cy + e, t); line(cx, cy - e, cx, cy - a, t)
		line(cx - a, cy, cx + a, cy, thin); line(cx, cy - a, cx, cy + a, thin)
	elseif sh == "mildot" then
		local e, th = Rr, if big then 1.3 else lw * .6
		line(cx - e, cy, cx + e, cy, th); line(cx, cy - e, cx, cy + e, th)
		local st, r = Rr * .13, if big then math.max(2.5, Rr * .01) else Rr * .04
		for i = 1, 4 do
			for _, d in ipairs({ { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }) do dotAt(cx + d[1] * st * i, cy + d[2] * st * i, r) end
		end
	end
end

-- efface ce qu'un précédent draw a posé dans parent (les cadres sans nom)
function R.clear(parent: Instance)
	for _, c in ipairs(parent:GetChildren()) do if c:IsA("Frame") and c.Name == "Frame" then c:Destroy() end end
end

return R
