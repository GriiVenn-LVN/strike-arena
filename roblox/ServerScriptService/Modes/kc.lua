--!strict
-- Modes/kc : Élimination confirmée (web : src/8W_confirm.js). Par équipe : chaque soldat éliminé lâche une plaque à la
-- couleur de son équipe, qui reste 30 s. La plaque d'un ADVERSAIRE ramassée = +1 point (élimination confirmée) ;
-- celle d'un ALLIÉ = l'adversaire ne marque pas (élimination refusée). Les éliminations seules ne rapportent rien.
-- Les bots vont chercher les plaques proches.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local WeaponService = require(script.Parent.Parent.WeaponService)

local LIFE, R = 30, 1.35 * Config.STUDS_PER_METER
local COL = { Attaquants = Color3.fromRGB(255, 122, 74), ["Défenseurs"] = Color3.fromRGB(74, 163, 255) }
local U = Config.STUDS_PER_METER
local M = {}
local function MS(): any return require(script.Parent.Parent.MatchService) :: any end
local popEvent = ReplicatedStorage:FindFirstChild("ModePop") :: RemoteEvent?
if not popEvent then
	local e = Instance.new("RemoteEvent"); e.Name = "ModePop"; e.Parent = ReplicatedStorage; popEvent = e
end

type Tag = { model: Model, team: string, pos: Vector3, life: number }

local function drop(m: any, victim: any, team: string)
	local ch = WeaponService.charOf(victim)
	local root = ch and ch:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then return end
	local rp = RaycastParams.new(); rp.FilterType = Enum.RaycastFilterType.Exclude; rp.FilterDescendantsInstances = { (ch :: any) :: Instance }
	local hit = workspace:Raycast(root.Position, Vector3.new(0, -25, 0), rp)
	local pos = if hit then hit.Position else root.Position - Vector3.new(0, 3, 0)
	local col = COL[team] or Color3.new(1, 1, 1)
	local model = Instance.new("Model"); model.Name = "Pickup_tag"
	model:SetAttribute("Pickup", "tag"); model:SetAttribute("TagTeam", team)
	local core = Instance.new("Part"); core.Name = "Core"; core.Size = Vector3.new(0.34, 0.5, 0.06) * U; core.Color = col
	core.Material = Enum.Material.Neon; core.Anchored = true; core.CanCollide = false; core.CanQuery = false; core.CanTouch = false
	core.CFrame = CFrame.new(pos + Vector3.new(0, 0.85 * U, 0)); core.Parent = model
	local chain = Instance.new("Part"); chain.Name = "Chain"; chain.Size = Vector3.new(0.02, 0.36, 0.02) * U; chain.Color = Color3.fromRGB(200, 205, 215)
	chain.Material = Enum.Material.Metal; chain.Anchored = true; chain.CanCollide = false; chain.CanQuery = false; chain.CFrame = core.CFrame * CFrame.new(0, 0.42 * U, 0); chain.Parent = model
	local ring = Instance.new("Part"); ring.Name = "Ring"; ring.Shape = Enum.PartType.Cylinder; ring.Size = Vector3.new(0.04 * U, 1.4 * U, 1.4 * U)
	ring.Color = col; ring.Material = Enum.Material.Neon; ring.Transparency = 0.5; ring.Anchored = true; ring.CanCollide = false; ring.CanQuery = false
	ring.CFrame = CFrame.new(pos + Vector3.new(0, 0.05, 0)) * CFrame.Angles(0, 0, math.rad(90)); ring.Parent = model
	local light = Instance.new("PointLight"); light.Color = col; light.Range = 2 * U; light.Brightness = 1.5; light.Parent = core
	model.PrimaryPart = core
	model.Parent = m.map.folder
	table.insert(m.data.tags, { model = model, team = team, pos = pos, life = LIFE } :: Tag)
end

function M.setup(m: any) m.data.tags = {} end
function M.onKill(m: any, _killer: any, victim: any, _key: string, _hs: boolean, _ks: any, vs: any): boolean
	drop(m, victim, vs.team)
	return true      -- l'élimination seule ne marque pas
end
function M.tick(m: any, dt: number)
	local tags: { Tag } = m.data.tags
	for i = #tags, 1, -1 do
		local t = tags[i]
		t.life -= dt
		if t.life < 5 then   -- clignote avant de disparaître, comme le web
			local on = math.sin(os.clock() * 14) > 0
			for _, d in ipairs(t.model:GetChildren()) do if d:IsA("BasePart") and d.Name ~= "Ring" then d.Transparency = if on then 0 else 0.75 end end
		end
		if t.life <= 0 then t.model:Destroy(); table.remove(tags, i); continue end
		for _, c in ipairs(MS().combatants(m)) do
			local ch = MS().aliveChar(c)
			local root = ch and ch:FindFirstChild("HumanoidRootPart") :: BasePart?
			if root and (Vector3.new(root.Position.X, 0, root.Position.Z) - Vector3.new(t.pos.X, 0, t.pos.Z)).Magnitude <= R
				and math.abs(root.Position.Y - 3 - t.pos.Y) < 1.6 * U + 3 then
				local team = WeaponService.teamOf(c) :: string
				local s = m.stats[MS().keyOf(c)]
				local conf = team ~= t.team
				if conf then
					m.score[team] = (m.score[team] or 0) + 1
					if s then s.pts += 1; s.score += 50 end
				elseif s then s.score += 25 end
				local p = if typeof(c) == "Instance" and c:IsA("Player") then c else nil
				if p and popEvent then
					popEvent:FireClient(p, if conf then "ÉLIMINATION CONFIRMÉE  +1" else "ÉLIMINATION REFUSÉE", if conf then Color3.fromRGB(255, 210, 58) else Color3.fromRGB(125, 216, 255), if conf then "powerup" else "pickup")
				end
				t.model:Destroy(); table.remove(tags, i)
				break
			end
		end
	end
	-- pour le HUD : nombre de plaques à confirmer / à refuser vues par chaque équipe
	local counts = { Attaquants = 0, ["Défenseurs"] = 0 }
	for _, t in ipairs(tags) do counts[t.team] = (counts[t.team] or 0) + 1 end
	m.data.public = { tags = counts }
end
function M.botGoal(m: any, bot: Model): Vector3?
	local root = bot:FindFirstChild("HumanoidRootPart") :: BasePart?
	local hum = bot:FindFirstChildOfClass("Humanoid")
	if not root or not hum then return nil end
	local team = bot:GetAttribute("Team")
	local best, bd = nil, (if hum.Health < 45 then 12 else 26) * U
	for _, t in ipairs(m.data.tags :: { Tag }) do
		local d = (t.pos - root.Position).Magnitude * (if t.team == team then 1.25 else 1)
		if d < bd then best, bd = t.pos, d end
	end
	return best
end
function M.info(m: any): any
	return { line = "Ramasse les plaques — premier à " .. tostring(m.limit), color = Color3.fromRGB(255, 207, 74), kind = "kc" }
end
function M.cleanup(m: any)
	for _, t in ipairs(m.data.tags or {}) do if t.model.Parent then t.model:Destroy() end end
	m.data.tags = {}
end
local _ = Players
return M
