--!strict
-- StarterPlayerScripts/MapDetailController
-- Habille côté client la carte où se trouve le joueur (dossier de Workspace avec l'attribut MapId), comme sur le web,
-- avec ReplicatedStorage/Shared/MapDress (textures, maillages, halos) ; les autres cartes en cours ne sont pas habillées
-- (mémoire et fluidité). Ambiance de la carte où se trouve le joueur : ciel dégradé, brouillard, lumière
-- (thèmes de src/41_gfx_themes.js) ; au lobby, l'éclairage d'origine est remis.
local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local MapScene = require(ReplicatedStorage.Shared.MapScene)
local MapDress = require(ReplicatedStorage.Shared.MapDress)

local player = Players.LocalPlayer
local U = Config.STUDS_PER_METER

type Build = MapDress.Build
local builds: { [Instance]: Build } = {}

-- ---------- une carte ----------
local function cleanup(f: Instance)
	local b = builds[f]
	if not b then return end
	b.alive = false
	builds[f] = nil
	if b.details then b.details:Destroy() end
	for _, em in ipairs(b.meshes) do pcall(function() em:Destroy() end) end
	for _, im in ipairs(b.images) do pcall(function() im:Destroy() end) end
end

local queue: { Build } = {}
local busy = false

local function process(b: Build)
	local info = MapScene.info(b.id)
	if not info then return end
	-- attend d'avoir reçu tout le décor du serveur
	local want = b.folder:GetAttribute("NVis")
	local t0 = os.clock()
	while b.alive and typeof(want) == "number" and os.clock() - t0 < 15 do
		local vis = b.folder:FindFirstChild("Visuals")
		if vis and #vis:GetChildren() >= want then break end
		task.wait(0.25)
	end
	if not b.alive then return end
	local details = Instance.new("Folder"); details.Name = "Details"; details.Parent = b.folder
	b.details = details
	local steps: { { any } } = { { "textures", MapDress.dressPrims }, { "halos", MapDress.buildGlows }, { "maillages", MapDress.buildMeshes } }
	for _, step in ipairs(steps) do
		local ok, err = pcall(step[2] :: any, b, info)
		if not ok then warn("[MapDetail] " .. step[1] .. " : " .. tostring(err)) end
	end
end

local function pump()
	if busy then return end
	busy = true
	task.spawn(function()
		while #queue > 0 do
			local b = table.remove(queue, 1) :: Build
			if b.alive then process(b) end
		end
		busy = false
	end)
end

local function watch(f: Instance)
	if builds[f] or not f:IsA("Folder") then return end
	local id = f:GetAttribute("MapId")
	if typeof(id) ~= "string" or not MapScene.has(id) then return end
	local origin = f:GetAttribute("Origin")
	local b: Build = { folder = f, id = id, origin = if typeof(origin) == "Vector3" then origin else Vector3.zero, alive = true, meshes = {}, images = {} }
	builds[f] = b
	f.AncestryChanged:Connect(function() if not f:IsDescendantOf(workspace) then cleanup(f) end end)
	table.insert(queue, b)
	pump()
end

workspace.ChildRemoved:Connect(function(c: Instance) cleanup(c) end)


-- ---------- ambiance : ciel, brouillard, lumière de la carte où l'on est ----------
local PROPS = { "Ambient", "OutdoorAmbient", "Brightness", "ClockTime", "FogColor", "FogStart", "FogEnd", "ColorShift_Top", "ColorShift_Bottom",
	"ExposureCompensation", "EnvironmentDiffuseScale", "EnvironmentSpecularScale" }
local lobby: { [string]: any } = {}
for _, k in ipairs(PROPS) do pcall(function() lobby[k] = (Lighting :: any)[k] end) end
local lobbyKids: { Instance } = {}       -- ciel et atmosphère d'origine, retirés le temps d'un match

local function c3(t: { number }?): Color3 return if t then Color3.new(t[1], t[2], t[3]) else Color3.new(1, 1, 1) end
local function scale(c: Color3, k: number): Color3 return Color3.new(math.min(1, c.R * k), math.min(1, c.G * k), math.min(1, c.B * k)) end

local current: string? = nil
local mapSky: Sky? = nil

local function restoreLobby()
	for k, v in pairs(lobby) do pcall(function() (Lighting :: any)[k] = v end) end
	if mapSky then mapSky:Destroy(); mapSky = nil end
	for _, k in ipairs(lobbyKids) do pcall(function() k.Parent = Lighting end) end
	lobbyKids = {}
end

local function applyTheme(id: string)
	local info = MapScene.info(id)
	local th = info and info.theme
	if not th then restoreLobby(); return end
	local L = Lighting :: any
	pcall(function()
		local hemiS, hemiG, sunC = c3(th.hemiS), c3(th.hemiG), c3(th.sunC)
		L.OutdoorAmbient = scale(hemiS:Lerp(hemiG, 0.4), math.clamp(th.hemiI * 1.3, 0.2, 1.2))
		L.Ambient = scale(hemiG, math.clamp(th.hemiI * 0.8, 0.1, 0.8))
		L.Brightness = math.clamp(th.sunI, 0.15, 3)
		L.ColorShift_Top = sunC
		L.ColorShift_Bottom = hemiG
		L.ExposureCompensation = math.clamp(math.log(th.exp or 1, 2), -1, 1)
		L.EnvironmentSpecularScale = math.clamp(th.env or 0.5, 0, 1)
		L.EnvironmentDiffuseScale = math.clamp(th.env or 0.5, 0.2, 1)
		local sp = th.sunPos or { 55, 80, 34 }
		local el = math.deg(math.atan2(sp[2], math.sqrt(sp[1] * sp[1] + sp[3] * sp[3])))
		L.ClockTime = 6 + el / 15                    -- hauteur du soleil (ou de la lune) du thème
		L.FogColor = c3(th.fog); L.FogStart = (th.fogN or 50) * U; L.FogEnd = (th.fogF or 200) * U
	end)
	-- l'atmosphère et le ciel du lobby remplacent le brouillard : on les retire le temps du match
	for _, k in ipairs(Lighting:GetChildren()) do
		if (k:IsA("Atmosphere") or k:IsA("Sky")) and k ~= mapSky then table.insert(lobbyKids, k); k.Parent = nil end
	end
	if mapSky then mapSky:Destroy(); mapSky = nil end
	local imgs = th.sky and MapDress.skyImages(id, th.sky)
	local sky = Instance.new("Sky"); sky.Name = "MapSky"
	sky.CelestialBodiesShown = (th.sunI or 0) >= 1.5     -- soleil visible de jour, rien de nuit (le ciel du web n'a pas de lune)
	sky.StarCount = if (th.stars or 0) > 0 then 3000 else 0
	if imgs then
		pcall(function()
			local side = imgs.side
			sky.SkyboxBackContent = side; sky.SkyboxFrontContent = side; sky.SkyboxLeftContent = side; sky.SkyboxRightContent = side
			sky.SkyboxUpContent = imgs.up; sky.SkyboxDownContent = imgs.dn
		end)
	end
	sky.Parent = Lighting
	mapSky = sky
end

-- carte du joueur : attribut MatchMap du personnage (nom du dossier), sinon la carte sous la caméra, sinon le lobby
local function myMap(): Instance?
	local char = player.Character
	local name = player:GetAttribute("MatchMap") or (char and char:GetAttribute("MatchMap"))
	if typeof(name) == "string" and name ~= "" then
		local f = workspace:FindFirstChild(name)
		if f and f:GetAttribute("MapId") then return f end
	end
	local cam = workspace.CurrentCamera
	if not cam then return nil end
	local pos = cam.CFrame.Position
	local best: Instance?, bd = nil, math.huge
	for _, f in ipairs(workspace:GetChildren()) do
		local id = f:GetAttribute("MapId")
		if f:IsA("Folder") and typeof(id) == "string" then
			local o = f:GetAttribute("Origin")
			local size = f:GetAttribute("MapSize")
			local org = if typeof(o) == "Vector3" then o else Vector3.zero
			local sz = if typeof(size) == "number" then size else 40 * 2 * U
			local c = org + Vector3.new(sz / 2, 0, sz / 2)
			local d = Vector2.new(pos.X - c.X, pos.Z - c.Z).Magnitude
			if d < sz * 0.75 and d < bd then best, bd = f, d end
		end
	end
	return best
end

task.spawn(function()
	local away = 0
	while true do
		local f = myMap()
		-- seule la carte du joueur est habillée ; les autres sont libérées (après 20 s au lobby pour la dernière)
		if f then
			away = 0
			local cur = builds[f]
			if cur and cur.id ~= f:GetAttribute("MapId") then cleanup(f) end
			watch(f)
			for g in pairs(builds) do if g ~= f then cleanup(g) end end
		else
			away += 0.5
			if away >= 20 then for g in pairs(builds) do cleanup(g) end end
		end
		local key = if f then (f.Name .. "@" .. tostring(f:GetAttribute("MapId"))) else nil
		if key ~= current then
			current = key
			if f then applyTheme(f:GetAttribute("MapId") :: string) else restoreLobby() end
		end
		task.wait(0.5)
	end
end)
