--!strict
-- ReplicatedStorage/Shared/Grenades (ModuleScript, client + serveur)
-- Grenades et mines du jeu web (src/60_game.js throwNade/updateNades/explodeNade, src/63_agents.js placeMine),
-- mêmes valeurs : lancer à 15 m/s (+2,5 vers le haut, +40 % de la vitesse du lanceur), gravité 18 m/s²,
-- rebonds (murs −45 %, sol 35 % + frottement 0,72), mèches frag 1,9 s / flash 1,5 s / fumigène 1,3 s.
-- Le serveur simule la grenade qui compte ; chaque client rejoue la même trajectoire pour l'afficher sans saccade.
local Config = require(script.Parent.Config)

local G = {}
local M = Config.STUDS_PER_METER
G.M = M

G.KINDS = {
	frag = { n = "Grenade frag", key = "G", fuse = 1.9, color = Color3.fromRGB(63, 90, 46), short = "G" },
	flash = { n = "Flashbang", key = "F", fuse = 1.5, color = Color3.fromRGB(221, 221, 221), short = "F" },
	smoke = { n = "Fumigène", key = "H", fuse = 1.3, color = Color3.fromRGB(154, 160, 168), short = "H" },
}
G.ORDER = { "frag", "flash", "smoke" }
G.GRAVITY = 18 * M
G.RADIUS = .07 * M
G.FRAG_R = 9                    -- m : 140 × (1 − d/9), 60 % sur soi
G.FLASH_R = 34
G.SMOKE_R = 3.6                 -- m, nuage de 18 s
G.SMOKE_T = 18
G.MINE = { max = 2, arm = 1, trigger = 1.5, dy = 1.6, r = 5, see = 8 }
G.WARN_R = 9.5                  -- alerte grenade : frag à moins de 9,5 m (src/8Zf_confort.js)

-- sons (planche du web, sinon sons fournis avec Roblox)
G.SFX = {
	boom = { sheet = "boom", id = "rbxasset://sounds/Rocket shot.wav", volume = 0.9, pitch = 0.6 },
	bang = { sheet = "bang", id = "rbxasset://sounds/Rocket shot.wav", volume = 0.8, pitch = 1.5 },
	pop = { sheet = "pop", id = "rbxasset://sounds/clickfast.wav", volume = 0.5, pitch = 0.6 },
	smoke = { sheet = "pop", id = "rbxasset://sounds/swoosh.wav", volume = 0.5, pitch = 0.5 },
	click = { sheet = "click", id = "rbxasset://sounds/clickfast.wav", volume = 0.4, pitch = 1.2 },
	throw = { sheet = "draw", id = "rbxasset://sounds/swoosh.wav", volume = 0.4, pitch = 1.1 },
}

-- vitesse de départ (studs/s) ; look = regard (unitaire), carVel = vitesse du lanceur
function G.launch(look: Vector3, carVel: Vector3): Vector3
	local pitch = math.asin(math.clamp(look.Y, -1, 1)) + .16
	local h = Vector3.new(look.X, 0, look.Z)
	h = if h.Magnitude > 1e-4 then h.Unit else Vector3.new(0, 0, -1)
	local d = h * math.cos(pitch) + Vector3.new(0, math.sin(pitch), 0)
	return d * 15 * M + Vector3.new(0, 2.5 * M, 0) + Vector3.new(carVel.X, 0, carVel.Z) * .4
end
-- lancer vers un point (bots) : vitesse horizontale clamp(L × 0,85, 6, 17) m/s, 5 m/s vers le haut
function G.launchAt(from: Vector3, target: Vector3): Vector3
	local d = Vector3.new(target.X - from.X, 0, target.Z - from.Z)
	local L = d.Magnitude / M
	local s = math.clamp(L * .85, 6, 17) * M
	return (if d.Magnitude > 1e-3 then d.Unit else Vector3.new(0, 0, -1)) * s + Vector3.new(0, 5 * M, 0)
end

export type Nade = { id: number, kind: string, p: Vector3, v: Vector3, t: number, owner: Instance?, team: string?, bounced: boolean? }

-- rayon qui ignore les personnages (une grenade traverse les joueurs, comme sur le web)
local function cast(from: Vector3, d: Vector3, params: RaycastParams): RaycastResult?
	for _ = 1, 4 do
		local r = workspace:Raycast(from, d, params)
		if not r then return nil end
		local m = r.Instance:FindFirstAncestorOfClass("Model")
		if (m and m:FindFirstChildOfClass("Humanoid")) or r.Instance:GetAttribute("MineId") ~= nil then params:AddToFilter(r.Instance)
		else return r end
	end
	return nil
end
G.cast = cast

function G.params(exclude: { Instance }): RaycastParams
	local p = RaycastParams.new(); p.FilterType = Enum.RaycastFilterType.Exclude; p.RespectCanCollide = true
	p.FilterDescendantsInstances = exclude
	return p
end

-- un pas de simulation ; renvoie true si la grenade a rebondi (son « clic »)
function G.step(n: Nade, dt: number, params: RaycastParams): boolean
	n.t -= dt
	n.v -= Vector3.new(0, G.GRAVITY * dt, 0)
	local d = n.v * dt
	if d.Magnitude < 1e-5 then return false end
	local r = cast(n.p, d + d.Unit * G.RADIUS, params)
	if not r then n.p += d; return false end
	local nrm = r.Normal
	local loud = false
	if nrm.Y > .6 then                                  -- sol
		loud = n.v.Y < -2 * M
		local vy = math.abs(n.v.Y) * .35
		if vy < 1 * M then vy = 0 end
		n.v = Vector3.new(n.v.X * .72, vy, n.v.Z * .72)
	else                                                -- mur, plafond : la composante vers la paroi repart à −45 %
		local vn = n.v:Dot(nrm)
		if vn < 0 then n.v -= nrm * vn * 1.45 end
		loud = math.abs(vn) > 2 * M
	end
	n.p = r.Position + nrm * G.RADIUS
	return loud
end

-- modèle de la grenade (web : sphère 7 cm pour la frag, cylindre pour flash et fumigène, cuillère métal)
function G.mesh(kind: string): Model
	local m = Instance.new("Model"); m.Name = "Grenade_" .. kind
	local k = G.KINDS[kind] or G.KINDS.frag
	local b = Instance.new("Part"); b.Name = "Body"; b.Color = k.color; b.Material = Enum.Material.Metal
	if kind == "frag" then b.Shape = Enum.PartType.Ball; b.Size = Vector3.one * .14 * M
	else b.Shape = Enum.PartType.Cylinder; b.Size = Vector3.new(.15, .09, .09) * M; b.CFrame = CFrame.Angles(0, 0, math.rad(90)) end
	b.Anchored = true; b.CanCollide = false; b.CanQuery = false; b.CanTouch = false; b.Parent = m
	local l = Instance.new("Part"); l.Name = "Lever"; l.Size = Vector3.new(.015, .05, .015) * M; l.Color = Color3.fromRGB(153, 153, 153)
	l.Material = Enum.Material.Metal; l.Anchored = true; l.CanCollide = false; l.CanQuery = false; l.CanTouch = false
	l.CFrame = CFrame.new(0, .09 * M, 0); l.Parent = m
	m.PrimaryPart = b
	return m
end

-- mine de proximité (mineMesh du web) ; la DEL change de couleur (armée : clignote en rouge)
function G.mineMesh(): Model
	local m = Instance.new("Model"); m.Name = "Mine"
	local function cyl(name: string, r: number, h: number, y: number, col: Color3): Part
		local p = Instance.new("Part"); p.Name = name; p.Shape = Enum.PartType.Cylinder; p.Size = Vector3.new(h, r * 2, r * 2) * M
		p.CFrame = CFrame.new(0, y * M, 0) * CFrame.Angles(0, 0, math.rad(90)); p.Color = col; p.Material = Enum.Material.Metal
		p.Anchored = true; p.CanCollide = false; p.CanTouch = false; p.Parent = m
		return p
	end
	local base = cyl("Base", .22, .08, .04, Color3.fromRGB(58, 64, 51))
	cyl("Top", .095, .04, .1, Color3.fromRGB(34, 38, 31))
	for i = 0, 2 do
		local p = cyl("Pin", .008, .07, .14, Color3.fromRGB(153, 153, 153))
		p.CFrame = CFrame.new(math.cos(i * 2.1) * .05 * M, .14 * M, math.sin(i * 2.1) * .05 * M) * CFrame.Angles(0, 0, math.rad(90))
	end
	local led = Instance.new("Part"); led.Name = "Led"; led.Shape = Enum.PartType.Ball; led.Size = Vector3.one * .056 * M
	led.Material = Enum.Material.Neon; led.Color = Color3.fromRGB(102, 102, 102); led.CFrame = CFrame.new(.13 * M, .09 * M, 0)
	led.Anchored = true; led.CanCollide = false; led.CanTouch = false; led.Parent = m
	m.PrimaryPart = base
	return m
end

return G
