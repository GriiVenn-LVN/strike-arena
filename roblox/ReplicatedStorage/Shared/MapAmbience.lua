--!strict
-- ReplicatedStorage/Shared/MapAmbience (ModuleScript, client)
-- Ambiance de la carte où se trouve le joueur, comme sur le web (applyTheme / buildSky de src/40_gfx.js, thèmes de
-- src/41_gfx_themes.js, 42_haunt.js, 8W_halloween.js, poussière de src/50_fx.js), avec ce que Roblox fait nativement :
--   • lumière : style réaliste (ombres nettes et douces), soleil placé dans la direction du thème (sunPos), lumière
--     du ciel et du sol (hémisphère du web), reflets du ciel (env du thème), exposition, brouillard du thème ;
--   • ciel : dégradé du web (MapDress.skyImages), soleil, lune des cartes hantées, halo de la lune, étoiles, nuages ;
--   • post-traitement du web : bloom (plus fort de nuit), saturation ×1,1, contraste ×1,06, rayons du soleil le jour,
--     flou très léger au loin (hors de la zone de jeu) ;
--   • particules autour de la caméra : poussière qui flotte (toutes les cartes), neige (Station), feuilles (Temple).
-- Rien de neuf à envoyer sur Roblox : les images viennent de MapDress (déjà dans MeshAssets).
-- Qualité basse (ombres coupées dans les réglages) : ni particules, ni flou, ni étoiles. Bloom et rayons restent
-- allumés en permanence (Intensity à 0 au lobby) pour que les réglages du menu (MainMenu) puissent les couper.
local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local MapData = require(ReplicatedStorage.Shared.MapData)
local MapScene = require(ReplicatedStorage.Shared.MapScene)
local MapDress = require(ReplicatedStorage.Shared.MapDress)

local MapAmbience = {}
local U = Config.STUDS_PER_METER

-- valeurs des thèmes du web absentes de l'export : env (intensité des reflets du ciel), lune peinte dans le ciel
-- (taille en degrés) et couleur de son halo
type Extra = { env: number, moon: number?, halo: Color3? }
local EXTRA: { [string]: Extra } = {
	sand = { env = 0.5 }, snow = { env = 0.8 }, industrial = { env = 0.6 }, night = { env = 0.35 }, metro = { env = 0.5 },
	jungle = { env = 0.6 }, range = { env = 0.7 },
	haunt = { env = 0.12, moon = 8.5 },                                          -- lune de 26 m à 175 m (42_haunt.js)
	halloween = { env = 0.14, moon = 11, halo = Color3.fromRGB(255, 150, 70) },   -- lune orange de 34 m + halo (8W_halloween.js)
}

-- ---------- éclairage du lobby (remis en sortant de la carte) ----------
local PROPS = { "Ambient", "OutdoorAmbient", "Brightness", "ClockTime", "GeographicLatitude", "FogColor", "FogStart", "FogEnd",
	"ColorShift_Top", "ColorShift_Bottom", "ExposureCompensation", "EnvironmentDiffuseScale", "EnvironmentSpecularScale",
	"ShadowSoftness", "LightingStyle" }
local lobby: { [string]: any } = {}
for _, k in ipairs(PROPS) do pcall(function() lobby[k] = (Lighting :: any)[k] end) end
local lobbyKids: { Instance } = {}       -- ciel et atmosphère d'origine, retirés le temps d'un match
local lobbyClouds: { [string]: any }? = nil

-- ---------- post-traitement (créé une fois) ----------
local bloom = Instance.new("BloomEffect"); bloom.Name = "MapBloom"; bloom.Intensity = 0; bloom.Parent = Lighting
local rays = Instance.new("SunRaysEffect"); rays.Name = "MapSunRays"; rays.Intensity = 0; rays.Parent = Lighting
local grade = Instance.new("ColorCorrectionEffect"); grade.Name = "MapGrade"; grade.Enabled = false; grade.Parent = Lighting
local depth = Instance.new("DepthOfFieldEffect"); depth.Name = "MapDepth"; depth.Enabled = false; depth.NearIntensity = 0; depth.Parent = Lighting

local function c3(t: { number }?): Color3 return if t then Color3.new(t[1], t[2], t[3]) else Color3.new(1, 1, 1) end
local function scale(c: Color3, k: number): Color3 return Color3.new(math.min(1, c.R * k), math.min(1, c.G * k), math.min(1, c.B * k)) end
local function rgbText(s: string?): Color3      -- couleur « r,g,b » des nuages du web
	local r, g, b = string.match(s or "", "(%d+)%s*,%s*(%d+)%s*,%s*(%d+)")
	return Color3.fromRGB(tonumber(r) or 255, tonumber(g) or 255, tonumber(b) or 255)
end
local function low(): boolean return not Lighting.GlobalShadows end

-- ---------- état de la carte habillée ----------
type State = { key: string, origin: Vector3, center: Vector3, night: boolean, holder: Folder, sky: Sky?, clouds: Clouds?,
	emit: Part?, emitters: { ParticleEmitter }, stars: Part?, conn: RBXScriptConnection? }
local cur: State? = nil

-- ---------- soleil : ClockTime + latitude pour que le soleil de Roblox soit dans la direction sunPos du web ----------
local sunCache: { [string]: { number } } = {}
local function placeSun(id: string, want: Vector3)
	local c = sunCache[id]
	if c then Lighting.ClockTime = c[1]; Lighting.GeographicLatitude = c[2]; return end
	local best, bc, bl = -2, 12, 41.73
	local ok = true
	local function try(t: number, lat: number)
		Lighting.ClockTime = t; Lighting.GeographicLatitude = lat
		local d: any = Lighting:GetSunDirection()
		if typeof(d) ~= "Vector3" then ok = false; return end
		local s = (d :: Vector3):Dot(want)
		if s > best then best, bc, bl = s, t, lat end
	end
	-- recherche grossière puis fine (une fois par carte)
	for lat = -80, 80, 10 do
		for t = 6, 18, 0.5 do try(t, lat); if not ok then break end end
		if not ok then break end
	end
	if ok then
		local l0, t0 = bl, bc
		for lat = l0 - 9, l0 + 9, 1.5 do
			for t = t0 - 0.45, t0 + 0.45, 0.075 do try(t, math.clamp(lat, -90, 90)) end
		end
	else                                   -- direction du soleil indisponible : seulement sa hauteur
		local el = math.deg(math.asin(math.clamp(want.Y, -1, 1)))
		bc, bl = 6 + el / 15, 41.73
	end
	sunCache[id] = { bc, bl }
	Lighting.ClockTime = bc; Lighting.GeographicLatitude = bl
end

-- ---------- ciel lointain : étoiles et halo de la lune (BillboardGui loin de la carte : ni brouillard ni parallaxe) ----------
local FAR = 1500
local function farAnchor(st: State): Part
	if st.stars then return st.stars end
	local p = Instance.new("Part")
	p.Name = "CielLointain"; p.Anchored = true; p.CanCollide = false; p.CanQuery = false; p.CanTouch = false
	p.Transparency = 1; p.Size = Vector3.new(0.2, 0.2, 0.2); p.CastShadow = false; p.CFrame = CFrame.new(st.center)
	p.Parent = st.holder
	st.stars = p
	return p
end

local function farBillboard(st: State, dir: Vector3, size: UDim2): BillboardGui
	local at = Instance.new("Attachment"); at.Position = dir * FAR; at.Parent = farAnchor(st)
	local bg = Instance.new("BillboardGui")
	bg.Size = size; bg.LightInfluence = 0; bg.Adornee = at; bg.Parent = at
	return bg
end

-- étoiles du web : n points de 1,6 px au-dessus de l'horizon (stars() de 41_gfx_themes.js)
local function buildStars(st: State, n: number)
	local rng = Random.new(n * 7919)
	for _ = 1, n do
		local a, e = rng:NextNumber(0, math.pi * 2), rng:NextNumber(0.08, 1.2)
		local bg = farBillboard(st, Vector3.new(math.cos(a) * math.cos(e), math.sin(e), math.sin(a) * math.cos(e)), UDim2.fromOffset(2, 2))
		local f = Instance.new("Frame")
		f.Size = UDim2.fromScale(1, 1); f.BorderSizePixel = 0; f.BackgroundColor3 = Color3.new(1, 1, 1)
		f.BackgroundTransparency = rng:NextNumber(0.05, 0.45)
		f.Parent = bg
	end
end

-- halo de la lune (sprite additif du web, 95 m à 180 m, teinté de la couleur du soleil du thème)
local function buildHalo(st: State, dir: Vector3, col: Color3, deg: number, transp: number)
	local img = MapDress.glow()
	if not img then return end
	local s = 2 * FAR * math.tan(math.rad(deg / 2))
	local bg = farBillboard(st, dir, UDim2.fromScale(s, s))
	bg.Brightness = 1.2
	local il = Instance.new("ImageLabel")
	il.Size = UDim2.fromScale(1, 1); il.BackgroundTransparency = 1; il.ImageContent = img
	il.ImageColor3 = col; il.ImageTransparency = transp
	il.Parent = bg
end

-- ---------- nuages (Clouds du terrain), comme la couche de nuages du ciel du web ----------
local function setClouds(st: State, th: any)
	local terrain = workspace:FindFirstChildOfClass("Terrain")
	if not terrain then return end
	local cov = if typeof(th.cov) == "number" then th.cov else 0.42
	local cl = terrain:FindFirstChildOfClass("Clouds")
	if cl and cl.Name ~= "MapClouds" and not lobbyClouds then
		lobbyClouds = { Cover = cl.Cover, Density = cl.Density, Color = cl.Color, Enabled = cl.Enabled }
	end
	if not cl then
		cl = Instance.new("Clouds"); (cl :: Clouds).Name = "MapClouds"; (cl :: Clouds).Parent = terrain
	end
	local c = cl :: Clouds
	c.Enabled = cov > 0.01
	c.Cover = math.clamp(cov * 0.9, 0, 1)
	c.Density = math.clamp(0.35 + cov * 0.45, 0, 1)
	c.Color = rgbText(th.cloud)
	st.clouds = c
end

local function restoreClouds()
	local terrain = workspace:FindFirstChildOfClass("Terrain")
	local cl = terrain and terrain:FindFirstChildOfClass("Clouds")
	if not cl then return end
	if cl.Name == "MapClouds" then cl:Destroy(); return end
	local o = lobbyClouds
	if o then
		pcall(function() cl.Cover = o.Cover; cl.Density = o.Density; cl.Color = o.Color; cl.Enabled = o.Enabled end)
	end
end

-- ---------- particules d'ambiance autour de la caméra ----------
local function seq(pts: { { number } }): NumberSequence
	local k = {}
	for _, p in ipairs(pts) do table.insert(k, NumberSequenceKeypoint.new(p[1], p[2], p[3] or 0)) end
	return NumberSequence.new(k)
end

local function emitter(st: State, name: string): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	e.Name = name
	e.Shape = Enum.ParticleEmitterShape.Box; e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	e.Enabled = not low()
	e.Parent = st.emit
	table.insert(st.emitters, e)
	return e
end

local function buildParticles(st: State, id: string, themeName: string, base: string)
	local snow = base == "snow"
	-- volume du web : 50 m × 50 m autour de la caméra, de 0,3 à 12 m (14 m pour la neige)
	local hgt = (if snow then 14 else 12) * U
	local p = Instance.new("Part")
	p.Name = "Ambiance"; p.Anchored = true; p.CanCollide = false; p.CanQuery = false; p.CanTouch = false
	p.Transparency = 1; p.CastShadow = false; p.Size = Vector3.new(50 * U, hgt, 50 * U)
	p.CFrame = CFrame.new(st.center + Vector3.new(0, hgt / 2, 0))
	p.Parent = st.holder
	st.emit = p
	local soft = MapDress.glow()
	local e = emitter(st, if snow then "Neige" else "Poussiere")
	if soft then e.TextureContent = soft end
	e.LightInfluence = 0
	if snow then
		-- flocons qui tombent (0,9 à 1,5 m/s) en dérivant
		e.Rate = 34; e.Lifetime = NumberRange.new(6, 10)
		e.EmissionDirection = Enum.NormalId.Bottom; e.Speed = NumberRange.new(0.9 * U, 1.5 * U); e.SpreadAngle = Vector2.new(14, 14)
		e.Acceleration = Vector3.new(0.3 * U, 0, 0)
		e.Size = seq({ { 0, 0.26, 0.1 }, { 1, 0.26, 0.1 } })
		e.Transparency = seq({ { 0, 1 }, { 0.1, 0.25 }, { 0.85, 0.25 }, { 1, 1 } })
		e.Color = ColorSequence.new(Color3.new(1, 1, 1)); e.LightEmission = 0.6
	else
		-- poussière qui flotte dans la lumière (motes du web : 260 grains, alpha 0,1 à 0,35)
		e.Rate = 26; e.Lifetime = NumberRange.new(7, 12)
		e.Speed = NumberRange.new(0.04 * U, 0.14 * U); e.SpreadAngle = Vector2.new(180, 180)
		e.Size = seq({ { 0, 0.17, 0.08 }, { 1, 0.17, 0.08 } })
		e.Transparency = seq({ { 0, 1 }, { 0.2, 0.72, 0.1 }, { 0.8, 0.72, 0.1 }, { 1, 1 } })
		e.Color = ColorSequence.new(Color3.new(1, 0.95, 0.85)); e.LightEmission = 1
	end
	-- Temple perdu : quelques feuilles qui tombent en tournoyant (texture de feuille du web)
	if themeName == "jungle" then
		local info = MapScene.info(id)
		local leaf: Content? = nil
		for _, m in ipairs(info and info.mats or {}) do
			if m.tex and MapScene.texKind(m.tex) == "leafbroad" then leaf = MapDress.texture(m.tex); break end
		end
		if leaf then
			local f = emitter(st, "Feuilles")
			f.TextureContent = leaf
			f.Rate = 2.5; f.Lifetime = NumberRange.new(8, 11)
			f.EmissionDirection = Enum.NormalId.Bottom; f.Speed = NumberRange.new(0.5 * U, 0.9 * U); f.SpreadAngle = Vector2.new(35, 35)
			f.Acceleration = Vector3.new(0.25 * U, 0, 0.12 * U); f.Drag = 0.4
			f.Rotation = NumberRange.new(0, 360); f.RotSpeed = NumberRange.new(-120, 120)
			f.Size = seq({ { 0, 0.32 * U, 0.08 * U }, { 1, 0.32 * U, 0.08 * U } })
			f.Transparency = seq({ { 0, 1 }, { 0.08, 0 }, { 0.9, 0 }, { 1, 1 } })
			f.Color = ColorSequence.new(Color3.fromRGB(176, 140, 80), Color3.fromRGB(122, 140, 66))
			f.LightInfluence = 1; f.LightEmission = 0
		end
	end
	-- le volume suit la caméra (les particules déjà émises restent sur place)
	local groundY = st.origin.Y
	st.conn = RunService.RenderStepped:Connect(function()
		local cam = workspace.CurrentCamera
		if not cam or not p.Parent then return end
		local pos = cam.CFrame.Position
		p.CFrame = CFrame.new(pos.X, groundY + 0.3 * U + hgt / 2, pos.Z)
	end)
end

-- ---------- qualité : suit le réglage des ombres du menu ----------
local function applyQuality()
	local st = cur
	local lo = low()
	depth.Enabled = st ~= nil and not lo
	if not st then return end
	for _, e in ipairs(st.emitters) do e.Enabled = not lo end
	if st.stars then             -- étoiles (taille en pixels) coupées en qualité basse, halo de la lune gardé
		for _, d in ipairs(st.stars:GetDescendants()) do if d:IsA("BillboardGui") then d.Enabled = not lo or d.Size.X.Scale > 0 end end
	end
end
Lighting:GetPropertyChangedSignal("GlobalShadows"):Connect(applyQuality)

-- ---------- API ----------
local function clearMap()
	local st = cur
	cur = nil
	if not st then return end
	if st.conn then st.conn:Disconnect() end
	if st.sky then st.sky:Destroy() end
	st.holder:Destroy()
end

function MapAmbience.restore()
	clearMap()
	for k, v in pairs(lobby) do pcall(function() (Lighting :: any)[k] = v end) end
	for _, k in ipairs(lobbyKids) do pcall(function() k.Parent = Lighting end) end
	lobbyKids = {}
	restoreClouds()
	bloom.Intensity = 0; rays.Intensity = 0; grade.Enabled = false; depth.Enabled = false
end

-- f : dossier de la carte dans Workspace (attributs MapId, Origin, MapSize)
function MapAmbience.apply(f: Instance)
	local id = f:GetAttribute("MapId")
	if typeof(id) ~= "string" then MapAmbience.restore(); return end
	local info = MapScene.info(id)
	local th = info and info.theme
	if not th then MapAmbience.restore(); return end
	clearMap()
	local md = MapData[id]
	local themeName: string = (md and md.theme) or "sand"
	local base: string = (md and md.base) or th.base or "sand"
	local ex = EXTRA[themeName] or EXTRA.sand
	local o = f:GetAttribute("Origin")
	local size = f:GetAttribute("MapSize")
	local origin = if typeof(o) == "Vector3" then o else Vector3.zero
	local sz = if typeof(size) == "number" then size else 40 * 2 * U
	local holder = Instance.new("Folder"); holder.Name = "MapAmbience"; holder.Parent = workspace
	local night = (th.sunI or 2) < 1.5
	local st: State = { key = f.Name .. "@" .. id, origin = origin, center = origin + Vector3.new(sz / 2, 0, sz / 2), night = night,
		holder = holder, emitters = {} }
	cur = st

	-- lumière
	local L = Lighting :: any
	local sp = th.sunPos or { 55, 80, 34 }
	local sunDir = Vector3.new(sp[1], sp[2], sp[3]).Unit
	pcall(function()
		L.LightingStyle = Enum.LightingStyle.Realistic       -- ombres nettes du soleil et des lampes (rendu « Future »)
		L.ShadowSoftness = if night then 0.35 else 0.18      -- ombres douces (PCF du web)
		local hemiS, hemiG, sunC = c3(th.hemiS), c3(th.hemiG), c3(th.sunC)
		L.OutdoorAmbient = scale(hemiS:Lerp(hemiG, 0.4), math.clamp(th.hemiI * 1.3, 0.2, 1.2))
		L.Ambient = scale(hemiG, math.clamp(th.hemiI * 0.8, 0.1, 0.8))
		L.Brightness = math.clamp(th.sunI, 0.15, 3.2)
		L.ColorShift_Top = sunC
		L.ColorShift_Bottom = hemiG
		L.ExposureCompensation = math.clamp(math.log(th.exp or 1, 2), -1, 1)
		L.EnvironmentDiffuseScale = math.clamp(ex.env * 1.1, 0.1, 1)
		L.EnvironmentSpecularScale = math.clamp(ex.env * 1.3, 0.15, 1)
		L.FogColor = c3(th.fog); L.FogStart = (th.fogN or 50) * U; L.FogEnd = (th.fogF or 200) * U
	end)
	pcall(placeSun, id, sunDir)

	-- l'atmosphère et le ciel du lobby remplacent le brouillard : on les retire le temps du match
	for _, k in ipairs(Lighting:GetChildren()) do
		if k:IsA("Atmosphere") or k:IsA("Sky") then table.insert(lobbyKids, k); k.Parent = nil end
	end

	-- ciel : dégradé du web, soleil de jour, lune peinte des cartes hantées, rien dans le métro
	local imgs = th.sky and MapDress.skyImages(id, th.sky)
	local sky = Instance.new("Sky"); sky.Name = "MapSky"
	sky.StarCount = 0                                  -- étoiles du web dessinées à part (le ciel de Roblox est en plein jour)
	if themeName == "metro" then
		sky.CelestialBodiesShown = false
	elseif ex.moon then
		sky.CelestialBodiesShown = true
		sky.SunTextureId = "rbxasset://sky/moon.jpg"; sky.SunAngularSize = ex.moon
	else
		sky.CelestialBodiesShown = not night               -- port et labo : seulement le halo bleuté du web
		sky.SunAngularSize = 21
	end
	if imgs then
		pcall(function()
			local side = imgs.side
			sky.SkyboxBackContent = side; sky.SkyboxFrontContent = side; sky.SkyboxLeftContent = side; sky.SkyboxRightContent = side
			sky.SkyboxUpContent = imgs.up; sky.SkyboxDownContent = imgs.dn
		end)
	end
	sky.Parent = Lighting
	st.sky = sky
	pcall(setClouds, st, th)                           -- métro : cov = 0, pas de nuages
	if themeName ~= "metro" then
		if night then
			pcall(buildHalo, st, sunDir, ex.halo or c3(th.sunC), if ex.halo then 33 else 29, if ex.halo then 0.45 else 0.35)
			if (th.stars or 0) > 0 then pcall(buildStars, st, math.floor(th.stars * 0.7)) end
		end
	end

	-- post-traitement du web (postEnd de 40_gfx.js) : bloom 0,32 / 0,75 sur les cartes de nuit et hantées, saturation, contraste
	local dark = themeName == "night" or base == "haunt"
	bloom.Intensity = if dark then 0.75 else 0.35
	bloom.Size = if dark then 32 else 26
	bloom.Threshold = if dark then 0.95 else 1.35
	rays.Intensity = if night or themeName == "metro" then 0 else 0.05
	rays.Spread = 0.7
	grade.Saturation = 0.1; grade.Contrast = 0.06; grade.Brightness = 0; grade.TintColor = Color3.new(1, 1, 1)
	grade.Enabled = true
	-- flou léger seulement au-delà de la zone de jeu (relief et silhouettes lointaines)
	depth.FocusDistance = sz * 0.75; depth.InFocusRadius = sz * 0.75; depth.FarIntensity = 0.12; depth.NearIntensity = 0

	pcall(buildParticles, st, id, themeName, base)
	applyQuality()
end

-- clé de la carte habillée (nom du dossier @ carte), nil au lobby
function MapAmbience.current(): string?
	return if cur then cur.key else nil
end

return MapAmbience
