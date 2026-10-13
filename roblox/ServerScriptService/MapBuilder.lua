--!strict
-- ServerScriptService/MapBuilder (ModuleScript)
-- Construit une carte dans Workspace à partir de la grille exportée du prototype (MapData).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local MapData = require(ReplicatedStorage.Shared.MapData)

local MapBuilder = {}

local U = Config.STUDS_PER_METER           -- studs par mètre
local CELL = Config.CELL * U               -- taille d'une case en studs

local THEMES = {
	sand = { wall = Color3.fromRGB(226, 208, 168), house = Color3.fromRGB(235, 225, 203), roof = Color3.fromRGB(176, 88, 52), crate = Color3.fromRGB(165, 118, 64),
		low = Color3.fromRGB(190, 175, 140), floor = Color3.fromRGB(201, 177, 138), plat = Color3.fromRGB(205, 180, 140), mat = Enum.Material.Sandstone },
	industrial = { wall = Color3.fromRGB(150, 156, 163), house = Color3.fromRGB(141, 151, 166), roof = Color3.fromRGB(110, 118, 128), crate = Color3.fromRGB(125, 138, 106),
		low = Color3.fromRGB(141, 148, 158), floor = Color3.fromRGB(110, 116, 123), plat = Color3.fromRGB(140, 147, 156), mat = Enum.Material.Concrete },
	snow = { wall = Color3.fromRGB(130, 140, 160), house = Color3.fromRGB(150, 100, 62), roof = Color3.fromRGB(245, 248, 252), crate = Color3.fromRGB(122, 138, 106),
		low = Color3.fromRGB(250, 252, 255), floor = Color3.fromRGB(238, 243, 250), plat = Color3.fromRGB(139, 106, 70), mat = Enum.Material.Slate },
}

local function part(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?)
	local p = Instance.new("Part")
	p.Name = name; p.Anchored = true; p.Size = size; p.CFrame = cf; p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth; p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

-- Hauteur du sol d'une case (rampes comprises) en mètres
local function cellX(cx: number) return (cx + 0.5) * CELL end

function MapBuilder.build(mapId: string)
	local g = MapData.buildGrid(mapId)
	local m = g.map
	local th = THEMES[m.theme]
	local N, TY, TYH = MapData.N, MapData.TY, MapData.TYH

	local old = workspace:FindFirstChild("Map"); if old then old:Destroy() end
	local folder = Instance.new("Folder"); folder.Name = "Map"; folder.Parent = workspace

	-- sol
	part(folder, "Floor", Vector3.new(N * CELL + 200, 2, N * CELL + 200), CFrame.new(N * CELL / 2, -1, N * CELL / 2), th.floor, th.mat)

	-- blocs
	for cz = 0, N - 1 do
		for cx = 0, N - 1 do
			local i = cz * N + cx
			local t, hM = g.type[i], g.h[i]
			if t ~= 0 and g.ramp[i] == 0 then
				local hS = hM * U
				local color = th.wall
				if t == TY.HOUSE then color = th.house elseif t == TY.CRATE or t == TY.CONT then color = th.crate
				elseif t == TY.LOW or t == TY.BARREL then color = th.low elseif t == TY.PLAT then color = th.plat end
				local p = part(folder, "Block_" .. t, Vector3.new(CELL, hS, CELL), CFrame.new(cellX(cx), hS / 2, cellX(cz)), color, th.mat)
				if t == TY.HOUSE then   -- toit coloré
					part(folder, "Roof", Vector3.new(CELL + 0.4, 0.5, CELL + 0.4), CFrame.new(cellX(cx), hS + 0.25, cellX(cz)), th.roof, th.mat)
				end
				p:SetAttribute("CellType", t)
			end
			if g.ceil[i] < 90 and g.type[i] == 0 and g.ramp[i] == 0 then      -- plafond (tunnels, souk, hangars)
				local hc = g.ceil[i] * U
				part(folder, "Ceiling", Vector3.new(CELL, 1.2, CELL), CFrame.new(cellX(cx), hc + 0.6, cellX(cz)), th.low, th.mat)
			end
		end
	end

	-- rampes sous forme d'escaliers (franchissables par le Humanoid)
	for _, r in ipairs(g.ramps) do
		local lenCells = (r.axis == "x") and (r.x2 - r.x1 + 1) or (r.z2 - r.z1 + 1)
		local widCells = (r.axis == "x") and (r.z2 - r.z1 + 1) or (r.x2 - r.x1 + 1)
		local dh = math.abs(r.hB - r.hA)
		local steps = math.max(2, math.floor(dh / 0.2 + 0.5))
		local stepLen = lenCells * CELL / steps
		for s = 0, steps - 1 do
			local t = (s + 0.5) / steps
			local h = (r.hA + (r.hB - r.hA) * t) * U
			h = math.max(h, 0.4)
			if r.axis == "x" then
				local x = r.x1 * CELL + stepLen * (s + 0.5)
				part(folder, "Step", Vector3.new(stepLen, h, widCells * CELL), CFrame.new(x, h / 2, (r.z1 + widCells / 2) * CELL), th.plat, th.mat)
			else
				local z = r.z1 * CELL + stepLen * (s + 0.5)
				part(folder, "Step", Vector3.new(widCells * CELL, h, stepLen), CFrame.new((r.x1 + widCells / 2) * CELL, h / 2, z), th.plat, th.mat)
			end
		end
	end

	-- points d'apparition
	local function toWorld(c) return Vector3.new(cellX(c[1]), 3, cellX(c[2])) end
	local spawns = { T = {}, CT = {}, DM = {} }
	for _, c in ipairs(m.spawnT) do table.insert(spawns.T, toWorld(c)) end
	for _, c in ipairs(m.spawnCT) do table.insert(spawns.CT, toWorld(c)) end
	for _, c in ipairs(m.spawnDM) do table.insert(spawns.DM, toWorld(c)) end
	local sites = {}
	for _, s in ipairs(m.sites) do table.insert(sites, { name = s.n, pos = toWorld({ s.cx, s.cz }), radius = s.r * U }) end
	return { folder = folder, spawns = spawns, sites = sites, data = m }
end

return MapBuilder
