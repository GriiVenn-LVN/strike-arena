--!strict
-- Modes/objutil : outils partagés des modes à objectifs (bombe, zone, drapeaux). Ce n'est pas un mode (absent de Modes.LIST).
-- Couleurs d'équipe du web, combattants en vie, hauteur du sol, cases libres de la grille, anneaux et drapeaux posés
-- dans le dossier de la carte de la partie (le client ModeHud les anime).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local MapData = require(ReplicatedStorage.Shared.MapData)
local WeaponService = require(script.Parent.Parent.WeaponService)

local O = {}
local U = Config.STUDS_PER_METER
O.U = U
O.T, O.CT = "Attaquants", "Défenseurs"
O.COL = { Attaquants = Color3.fromRGB(255, 122, 74), ["Défenseurs"] = Color3.fromRGB(74, 163, 255) } :: { [string]: Color3 }
O.WHITE = Color3.new(1, 1, 1)
O.CONTEST = Color3.fromRGB(255, 210, 58)
O.GOOD = Color3.fromRGB(125, 255, 159)
O.BAD = Color3.fromRGB(255, 107, 107)

function O.MS(): any return require(script.Parent.Parent.MatchService) :: any end
function O.other(team: string): string return if team == O.T then O.CT else O.T end
function O.isPlayer(c: any): boolean return typeof(c) == "Instance" and c:IsA("Player") end

-- racine d'un combattant en vie (nil s'il est mort ou sans personnage)
function O.root(c: any): BasePart?
	local ch = O.MS().aliveChar(c)
	return ch and ch:FindFirstChild("HumanoidRootPart") :: BasePart?
end
-- combattants en vie de la partie (d'une équipe si donnée)
function O.alive(m: any, team: string?): { any }
	local l = {}
	for _, c in ipairs(O.MS().combatants(m)) do
		if O.MS().aliveChar(c) and (not team or WeaponService.teamOf(c) == team) then table.insert(l, c) end
	end
	return l
end
function O.flat(a: Vector3, b: Vector3): number
	return Vector3.new(a.X - b.X, 0, a.Z - b.Z).Magnitude
end
-- les pieds d'un personnage (la racine est ~3 studs au-dessus du sol)
function O.feet(r: BasePart): Vector3 return r.Position - Vector3.new(0, 3, 0) end

-- hauteur du sol (toits, plateformes) sous un point de la carte de la partie
function O.ground(m: any, pos: Vector3): Vector3
	if m.map.groundAt then return Vector3.new(pos.X, m.map.groundAt(pos), pos.Z) end   -- hauteur de la grille (MapBuilder)
	local rp = RaycastParams.new(); rp.FilterType = Enum.RaycastFilterType.Include
	rp.FilterDescendantsInstances = { m.map.folder }
	local hit = workspace:Raycast(Vector3.new(pos.X, m.origin.Y + 60, pos.Z), Vector3.new(0, -120, 0), rp)
	return Vector3.new(pos.X, if hit then hit.Position.Y else m.origin.Y, pos.Z)
end
-- sol sans plafond : premier sol en partant de la hauteur donnée (sous un toit, sous une passerelle)
function O.groundBelow(m: any, pos: Vector3): Vector3
	local rp = RaycastParams.new(); rp.FilterType = Enum.RaycastFilterType.Include
	rp.FilterDescendantsInstances = { m.map.folder }
	local hit = workspace:Raycast(pos + Vector3.new(0, 2, 0), Vector3.new(0, -40, 0), rp)
	return if hit then hit.Position else Vector3.new(pos.X, m.origin.Y, pos.Z)
end

-- ---------- grille de la carte (cases libres), comme walkableCell / domSpot du web ----------
local grids: { [string]: any } = {}
function O.grid(m: any): any
	if m.map and m.map.grid then return m.map.grid end
	local id = m.settings.map
	if grids[id] == nil then
		local ok, g = pcall(MapData.buildGrid, id)
		grids[id] = if ok then g else false
	end
	return if grids[id] then grids[id] else nil
end
local function openCell(g: any, cx: number, cz: number): boolean
	local N = MapData.N
	if cx < 1 or cz < 1 or cx >= N - 1 or cz >= N - 1 then return false end
	local i = cz * N + cx
	return g.type[i] == 0 or (g.ramp[i] or 0) ~= 0
end
-- case libre la plus proche d'un point de la grille, entourée de cases libres (pas coincée dans un recoin)
function O.spot(m: any, fx: number, fz: number): (number, number)
	local tx, tz = math.floor(fx + 0.5), math.floor(fz + 0.5)
	local g = O.grid(m)
	if not g then return tx, tz end
	for pass = 1, 2 do
		for r = 0, 9 do
			for dz = -r, r do
				for dx = -r, r do
					if math.max(math.abs(dx), math.abs(dz)) == r then
						local cx, cz = tx + dx, tz + dz
						if openCell(g, cx, cz) then
							local ok = true
							if pass == 1 then
								for oz = -1, 1 do for ox = -1, 1 do if not openCell(g, cx + ox, cz + oz) then ok = false end end end
							end
							if ok then return cx, cz end
						end
					end
				end
			end
		end
	end
	return tx, tz
end
function O.avg(list: { any }): (number, number)
	local x, z = 0, 0
	for _, c in ipairs(list) do x += c[1]; z += c[2] end
	local n = math.max(1, #list)
	return x / n, z / n
end

-- sites de bombe de la carte : { n, pos (au sol), r (studs) }
function O.sites(m: any): { { n: string, pos: Vector3, r: number } }
	local l = {}
	for _, s in ipairs(m.map.data.sites or {}) do
		local p = O.ground(m, O.MS().cellToWorld(m, s.cx, s.cz))
		table.insert(l, { n = s.n, pos = p, r = (s.r or 7) * U })
	end
	if #l == 0 then
		table.insert(l, { n = "A", pos = O.ground(m, O.MS().cellToWorld(m, 10, 10)), r = 7 * U })
		table.insert(l, { n = "B", pos = O.ground(m, O.MS().cellToWorld(m, 30, 10)), r = 7 * U })
	end
	return l
end

-- ---------- objets posés dans la carte ----------
local function part(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, transparency: number, shape: Enum.PartType?, material: Enum.Material?): Part
	local p = Instance.new("Part"); p.Name = name; p.Anchored = true; p.CanCollide = false; p.CanQuery = false; p.CanTouch = false
	p.CastShadow = false; p.Size = size; p.CFrame = cf; p.Color = color; p.Transparency = transparency
	p.Material = material or Enum.Material.Neon
	if shape then p.Shape = shape end
	p.Parent = parent
	return p
end
O.part = part

-- anneau au sol (ringMesh du web) : disque transparent, cercle lumineux (segments) et mur translucide
function O.ring(m: any, name: string, center: Vector3, radius: number, height: number, color: Color3, wallAlpha: number?): Model
	local model = Instance.new("Model"); model.Name = name
	model:SetAttribute("ModeRing", true); model:SetAttribute("Radius", radius)
	local up = CFrame.new(center) * CFrame.Angles(0, 0, math.rad(90))
	part(model, "Disc", Vector3.new(0.1, radius * 2, radius * 2), up + Vector3.new(0, 0.12, 0), color, 0.88, Enum.PartType.Cylinder)
	part(model, "Wall", Vector3.new(height, radius * 2, radius * 2), up + Vector3.new(0, height / 2, 0), color, wallAlpha or 0.9, Enum.PartType.Cylinder, Enum.Material.ForceField)
	local seg = 40
	local len = 2 * math.pi * radius / seg + 0.15
	for i = 1, seg do
		local a = (i / seg) * math.pi * 2
		local p = center + Vector3.new(math.cos(a) * radius, 0.2, math.sin(a) * radius)
		part(model, "Seg", Vector3.new(len, 0.25, 0.35), CFrame.new(p) * CFrame.Angles(0, -a + math.pi / 2, 0), color, 0.05)
	end
	model.Parent = m.map.folder
	return model
end
function O.ringColor(model: Model?, color: Color3)
	if not model then return end
	for _, p in ipairs(model:GetChildren()) do if p:IsA("BasePart") and p.Color ~= color then p.Color = color end end
end
function O.moveRing(model: Model?, center: Vector3)
	if not model then return end
	local disc = model:FindFirstChild("Disc") :: BasePart?
	if not disc then return end
	local old = disc.Position - Vector3.new(0, 0.12, 0)
	for _, p in ipairs(model:GetChildren()) do if p:IsA("BasePart") then p.Position += center - old end end
end

-- étiquette flottante (lettre de drapeau, site de bombe) : BillboardGui toujours visible
function O.label(adornee: BasePart, text: string, color: Color3, offset: number): BillboardGui
	local bb = Instance.new("BillboardGui"); bb.Name = "Label"; bb.AlwaysOnTop = true; bb.Size = UDim2.fromOffset(42, 42)
	bb.StudsOffsetWorldSpace = Vector3.new(0, offset, 0); bb.LightInfluence = 0; bb.MaxDistance = 600
	local t = Instance.new("TextLabel"); t.Name = "Text"; t.Size = UDim2.fromScale(1, 1); t.BackgroundColor3 = Color3.new(0, 0, 0)
	t.BackgroundTransparency = 0.35; t.Text = text; t.TextColor3 = color; t.Font = Enum.Font.GothamBlack; t.TextScaled = true
	local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(1, 0); c.Parent = t
	local s = Instance.new("UIStroke"); s.Color = color; s.Thickness = 3; s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border; s.Parent = t
	t.Parent = bb
	bb.Adornee = adornee; bb.Parent = adornee
	return bb
end

-- drapeau (ctfFlagMesh du web) : mât, boule dorée, toile à la couleur de l'équipe
function O.flag(parent: Instance, name: string, at: Vector3, color: Color3): Model
	local model = Instance.new("Model"); model.Name = name
	local pole = part(model, "Pole", Vector3.new(0.07, 2.3, 0.07) * U, CFrame.new(at + Vector3.new(0, 1.15 * U, 0)), Color3.fromRGB(216, 221, 228), 0, nil, Enum.Material.Metal)
	part(model, "Tip", Vector3.new(0.14, 0.14, 0.14) * U, CFrame.new(at + Vector3.new(0, 2.33 * U, 0)), Color3.fromRGB(255, 210, 58), 0, Enum.PartType.Ball, Enum.Material.Metal)
	part(model, "Cloth", Vector3.new(1.1, 0.7, 0.03) * U, CFrame.new(at + Vector3.new(0.58 * U, 1.92 * U, 0)), color, 0, nil, Enum.Material.Fabric)
	pole.PivotOffset = CFrame.new(0, -1.15 * U, 0)       -- le pivot est au pied du mât
	model.PrimaryPart = pole
	model.Parent = parent
	return model
end

-- objet porté par un combattant (drapeau, bombe) : soudé dans son dos
function O.carry(model: Model, c: any, offset: CFrame, scale: number?)
	local r = O.root(c)
	if not r then return end
	O.release(model)
	if scale and model:GetScale() ~= scale then model:ScaleTo(scale) end
	model:PivotTo(r.CFrame * offset)
	for _, p in ipairs(model:GetDescendants()) do
		if p:IsA("BasePart") then
			p.Massless = true; p.CanCollide = false
			local w = Instance.new("WeldConstraint"); w.Name = "CarryWeld"; w.Part0 = r; w.Part1 = p; w.Parent = p
			p.Anchored = false
		end
	end
end
-- lâché : ancré là où il est posé (ou à la position donnée)
function O.release(model: Model, at: CFrame?)
	for _, p in ipairs(model:GetDescendants()) do
		if p:IsA("WeldConstraint") and p.Name == "CarryWeld" then p:Destroy() end
	end
	for _, p in ipairs(model:GetDescendants()) do if p:IsA("BasePart") then p.Anchored = true end end
	if model:GetScale() ~= 1 then model:ScaleTo(1) end
	if at then model:PivotTo(at) end
end

-- texte bref à un joueur (petit message au centre, ModePop du HUD)
local popEvent = ReplicatedStorage:FindFirstChild("ModePop") :: RemoteEvent?
function O.pop(p: Player, text: string, color: Color3?, sound: string?)
	popEvent = popEvent or ReplicatedStorage:FindFirstChild("ModePop") :: RemoteEvent?
	if not popEvent then
		local e = Instance.new("RemoteEvent"); e.Name = "ModePop"; e.Parent = ReplicatedStorage; popEvent = e
	end
	(popEvent :: RemoteEvent):FireClient(p, text, color, sound)
end

return O
