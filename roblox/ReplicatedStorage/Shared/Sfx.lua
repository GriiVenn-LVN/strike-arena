--!strict
-- ReplicatedStorage/Shared/Sfx (ModuleScript, côté client)
-- Joue un son. Les vrais sons du jeu web sont rangés dans UN seul fichier audio (« planche », SoundSheet.lua) :
-- dès que ModeConfig.SOUND_SHEET contient son numéro, chaque son en est un extrait (Sound.PlaybackRegion).
-- Tant qu'il vaut 0, on garde les sons fournis avec Roblox (champ id de ModeConfig.SOUNDS).
--
-- Mixage (comme le jeu web : égaliseur, compresseur, réverbération) : chaque son passe par un groupe (SoundGroup)
-- de SoundService, avec ses effets :
--   "weapons" tirs, explosions, manipulations d'arme (égaliseur + compresseur + réverbération du lieu)
--   "steps"   pas, sauts, glissades (égaliseur + réverbération plus légère)
--   "ui"      touches, achats, annonces de manche (égaliseur + compresseur léger, pas de réverbération)
--   "ambient" fonds sonores des cartes (baisse tout seul pendant les tirs proches)
--   "music"   musique (rien ne la joue encore)
-- "master" est le groupe SoundService.Master (le même que celui du menu) : il règle aussi les sons sans groupe.
--
-- API des volumes (pour le menu d'options) :
--   Sfx.setVolume(groupName: string, v: number)   -- groupName : "master", "weapons", "steps", "ui", "ambient", "music"
--                                                 -- v : multiplicateur, 1 = niveau d'origine, borné entre 0 et 2
--   Sfx.getVolume(groupName: string): number      -- valeur réglée (1 par défaut, 0 pour un nom inconnu)
--   Sfx.GROUPS                                    -- la liste des six noms, dans l'ordre ci-dessus
-- Les valeurs ne sont pas sauvegardées ici : le menu les garde et les remet au démarrage.
--
-- Autres fonctions :
--   Sfx.play(def, at?, vol?)        -- def = entrée de ModeConfig.SOUNDS ({ id, volume, pitch, sheet, group?, rate? })
--                                   -- ou nom d'un son de la planche ("magout"…) ; at = position du son dans le monde
--   Sfx.step(surface, at?, vol?)    -- un pas sur "sand", "grass", "snow", "stone", "wood" ou "metal" (ModeConfig.SOUNDS.STEPS)
--   Sfx.setAcoustics(name)          -- réverbération du lieu (ModeConfig.SOUNDS.ACOUSTICS), appelé par AmbienceController
--   Sfx.muffle(sec, k?)             -- oreilles bouchées (aigus coupés) pendant sec secondes, k = force 0..1
--   Sfx.group(groupName)            -- le SoundGroup d'un groupe (nil côté serveur)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local ModeConfig = require(ReplicatedStorage.Shared.ModeConfig)
local Sheet = require(ReplicatedStorage.Shared.SoundSheet)

local Sfx = {}
local BASE = 0.7          -- volume du fusil d'assaut ; les autres sons gardent leur écart de volume du web
local M = 3.571           -- studs par mètre (Config.STUDS_PER_METER)
local SOUNDS: any = ModeConfig.SOUNDS

Sfx.GROUPS = { "master", "weapons", "steps", "ui", "ambient", "music" }

-- ---------- classement des sons ----------
local FIRE = { pistol = true, smg = true, rifle = true, lmg = true, sniper = true, shotgun = true }
local GROUP_OF: { [string]: string } = {
	pistol = "weapons", smg = "weapons", rifle = "weapons", lmg = "weapons", sniper = "weapons", shotgun = "weapons",
	knife = "weapons", knifehit = "weapons", reload = "weapons", magout = "weapons", magin = "weapons", rack = "weapons",
	shellin = "weapons", bolt = "weapons", pump = "weapons", draw = "weapons", click = "weapons", shell = "weapons",
	boom = "weapons", bang = "weapons", pop = "weapons", beep = "weapons",
	jump = "steps", slide = "steps", land = "steps",
	hit = "ui", hs = "ui", kill = "ui", dmg = "ui", shield = "ui", shieldbreak = "ui", pickup = "ui", buy = "ui",
	deny = "ui", win = "ui", lose = "ui", round = "ui", tick = "ui", heal = "ui", ui = "ui",
}
-- portée des sons placés dans le monde (mètres) : plein volume jusqu'à min, silence à max
local RANGE: { [string]: { number } } = {
	fire = { 6, 120 }, boom = { 12, 180 }, bang = { 8, 120 }, pop = { 4, 70 }, beep = { 3, 45 },
	steps = { 1.5, 28 }, handling = { 1.5, 25 }, knife = { 2, 30 }, default = { 3, 80 },
}
local HANDLING = { reload = true, magout = true, magin = true, rack = true, shellin = true, bolt = true, pump = true, draw = true, click = true, shell = true }
-- queue de tir (grondement qui suit le coup, comme gunShot() du web) : durée relative, volume
local TAIL: { [string]: { number } } = {
	pistol = { 0.45, 0.3 }, smg = { 0.35, 0.24 }, rifle = { 0.75, 0.34 }, lmg = { 0.8, 0.36 }, sniper = { 1.4, 0.45 }, shotgun = { 1.1, 0.42 },
}

-- ---------- groupes et effets ----------
type Fx = { group: SoundGroup, eq: EqualizerSoundEffect?, reverb: ReverbSoundEffect?, mix: any }
local fx: { [string]: Fx } = {}
local master: SoundGroup? = nil
local VOL: { [string]: number } = { master = 1, weapons = 1, steps = 1, ui = 1, ambient = 1, music = 1 }
local acoustic: any = SOUNDS.ACOUSTICS and SOUNDS.ACOUSTICS.lobby or {}
local ready = false

local function applyVolumes()
	if master then master.Volume = VOL.master end
	for name, f in pairs(fx) do
		f.group.Volume = (f.mix.vol or 1) * VOL[name] * VOL.master
	end
end

local function makeGroup(name: string): Fx
	local mix = (SOUNDS.MIX and SOUNDS.MIX[name]) or { vol = 1, low = 0, mid = 0, high = 0 }
	local gname = "Sfx_" .. name
	local old = SoundService:FindFirstChild(gname)
	if old then old:Destroy() end
	local g = Instance.new("SoundGroup"); g.Name = gname
	local f: Fx = { group = g, mix = mix }
	local eq = Instance.new("EqualizerSoundEffect")
	eq.LowGain = mix.low or 0; eq.MidGain = mix.mid or 0; eq.HighGain = mix.high or 0; eq.Priority = 3; eq.Parent = g
	f.eq = eq
	if name == "weapons" or name == "ui" then
		local c = Instance.new("CompressorSoundEffect")
		if name == "weapons" then c.Threshold = -14; c.Ratio = 6; c.Attack = 0.003; c.Release = 0.2
		else c.Threshold = -18; c.Ratio = 3; c.Attack = 0.005; c.Release = 0.15 end
		c.Priority = 2; c.Parent = g
	end
	if name == "weapons" or name == "steps" then
		local r = Instance.new("ReverbSoundEffect"); r.Priority = 1; r.Parent = g
		f.reverb = r
	end
	g.Parent = SoundService
	return f
end

local function setReverb(r: ReverbSoundEffect, p: any, wetOffset: number, t: number)
	local goal = {
		DecayTime = math.clamp(p.decay or 1, 0.1, 20), Density = math.clamp(p.density or 0.7, 0, 1),
		Diffusion = math.clamp(p.diffusion or 0.6, 0, 1), DryLevel = p.dry or 0, WetLevel = (p.wet or -14) + wetOffset,
	}
	if t <= 0 then
		r.DecayTime = goal.DecayTime; r.Density = goal.Density; r.Diffusion = goal.Diffusion; r.DryLevel = goal.DryLevel; r.WetLevel = goal.WetLevel
	else
		TweenService:Create(r, TweenInfo.new(t, Enum.EasingStyle.Sine), goal):Play()
	end
end

-- crée les groupes au premier son (côté client seulement)
local function ensure(): boolean
	if ready then return true end
	if not RunService:IsClient() then return false end
	ready = true
	local m = SoundService:FindFirstChild("Master")
	if m and m:IsA("SoundGroup") then master = m
	else
		local g = Instance.new("SoundGroup"); g.Name = "Master"; g.Parent = SoundService; master = g
	end
	for _, name in ipairs({ "weapons", "steps", "ui", "ambient", "music" }) do fx[name] = makeGroup(name) end
	-- l'ambiance et la musique baissent d'elles-mêmes quand les armes sont fortes (compresseur déclenché par les armes)
	for _, name in ipairs({ "ambient", "music" }) do
		local c = Instance.new("CompressorSoundEffect")
		c.SideChain = fx.weapons.group; c.Threshold = -32; c.Ratio = 4; c.Attack = 0.01; c.Release = 0.6; c.Priority = 2
		c.Parent = fx[name].group
	end
	for name, f in pairs(fx) do
		if f.reverb then setReverb(f.reverb, acoustic, if name == "steps" then -4 else 0, 0) end
	end
	applyVolumes()
	return true
end

function Sfx.group(name: string): SoundGroup?
	if name == "master" then ensure(); return master end
	if not ensure() then return nil end
	local f = fx[name]
	return f and f.group
end

function Sfx.setVolume(name: string, v: number)
	if VOL[name] == nil or typeof(v) ~= "number" or v ~= v then return end
	VOL[name] = math.clamp(v, 0, 2)
	if ensure() then applyVolumes() end
end

function Sfx.getVolume(name: string): number
	return VOL[name] or 0
end

-- réverbération du lieu (nom d'une entrée de ModeConfig.SOUNDS.ACOUSTICS)
function Sfx.setAcoustics(name: string)
	local p = SOUNDS.ACOUSTICS and SOUNDS.ACOUSTICS[name]
	if not p or p == acoustic then return end
	acoustic = p
	if not ensure() then return end
	for gname, f in pairs(fx) do
		if f.reverb then setReverb(f.reverb, p, if gname == "steps" then -4 else 0, 0.8) end
	end
end

function Sfx.isIndoor(): boolean return acoustic.indoor == true end

-- oreilles bouchées après une explosion ou un flash : les aigus reviennent peu à peu (tinnitus() du web)
local muffleTweens: { Tween } = {}
function Sfx.muffle(sec: number, k: number?)
	if not ensure() then return end
	local s = math.clamp(k or 1, 0, 1)
	for _, tw in ipairs(muffleTweens) do tw:Cancel() end
	table.clear(muffleTweens)
	for _, f in pairs(fx) do
		local eq = f.eq
		if eq then
			eq.HighGain = (f.mix.high or 0) - 34 * s; eq.MidGain = (f.mix.mid or 0) - 12 * s
			local tw = TweenService:Create(eq, TweenInfo.new(math.max(0.1, sec), Enum.EasingStyle.Quad, Enum.EasingDirection.In),
				{ HighGain = f.mix.high or 0, MidGain = f.mix.mid or 0 })
			tw:Play(); table.insert(muffleTweens, tw)
		end
	end
end

-- ---------- lecture ----------
local function listener(): Vector3?
	local cam = workspace.CurrentCamera
	return cam and cam.CFrame.Position
end

local lastRate: { [string]: number } = {}
-- hauteur au hasard autour de 1 (± var), jamais deux fois presque la même d'affilée pour un même son
local function vary(key: string, var: number): number
	local r = 1 + (math.random() * 2 - 1) * var
	local prev = lastRate[key]
	if prev and math.abs(r - prev) < var * 0.3 then r = 1 + (if r > prev then 1 else -1) * var * (0.4 + math.random() * 0.6) end
	lastRate[key] = r
	return r
end

type Opts = { id: string, region: { number }?, volume: number, speed: number, group: string?, at: Vector3?,
	range: { number }?, high: number?, mid: number?, low: number?, delay: number?, echo: any?, len: number }

local function emit(o: Opts): Sound
	local s = Instance.new("Sound")
	s.SoundId = o.id
	local region = o.region
	if region then
		s.PlaybackRegionsEnabled = true
		s.PlaybackRegion = NumberRange.new(region[1], region[1] + region[2])
	end
	s.Volume = o.volume; s.PlaybackSpeed = o.speed
	local f = o.group and fx[o.group]
	if f then s.SoundGroup = f.group elseif master then s.SoundGroup = master end
	if o.high or o.mid or o.low then
		local eq = Instance.new("EqualizerSoundEffect")
		eq.HighGain = o.high or 0; eq.MidGain = o.mid or 0; eq.LowGain = o.low or 0; eq.Parent = s
	end
	if o.echo then
		local e = Instance.new("EchoSoundEffect")
		e.Delay = math.clamp(o.echo.delay or 0.25, 0.01, 1); e.Feedback = math.clamp(o.echo.feedback or 0.3, 0, 0.9)
		e.DryLevel = 0; e.WetLevel = o.echo.wet or -10; e.Parent = s
	end
	local life = o.len / math.max(0.05, o.speed) + (o.delay or 0) + (if o.echo then 2 else 1) + (acoustic.decay or 1) * 0.5
	local holder: Instance = s
	if o.at then
		local rg = o.range or RANGE.default
		s.RollOffMode = Enum.RollOffMode.InverseTapered
		s.RollOffMinDistance = rg[1] * M; s.RollOffMaxDistance = rg[2] * M
		local a = Instance.new("Attachment"); a.WorldPosition = o.at; a.Parent = workspace.Terrain
		s.Parent = a; holder = a
	else
		s.Parent = SoundService
	end
	if o.delay and o.delay > 0.005 then
		task.delay(o.delay, function() if s.Parent then s:Play() end end)
	else
		s:Play()
	end
	Debris:AddItem(holder, math.max(4, life))
	return s
end

-- def = entrée de ModeConfig.SOUNDS ({ id, volume, pitch, sheet }) ou nom d'un son de la planche ("magout"…)
function Sfx.play(def: any, at: Vector3?, vol: number?): Sound?
	if typeof(def) == "string" then def = SOUNDS[def] or { sheet = def } end
	if type(def) ~= "table" then return nil end
	ensure()
	local name: string? = if typeof(def.sheet) == "string" then def.sheet else nil
	local region = name and Sheet[name]
	local useSheet = ModeConfig.SOUND_SHEET ~= 0 and region ~= nil
	local o: Opts
	if useSheet and region and name then
		o = { id = "rbxassetid://" .. ModeConfig.SOUND_SHEET, region = region, len = region[2],
			volume = BASE * region[3] * (vol or 1) * (def.gain or 1) * (0.94 + math.random() * 0.12),
			speed = (def.rate or 1) * vary(name, def.var or 0.04) }
	elseif typeof(def.id) == "string" and def.id ~= "" then
		o = { id = def.id, len = 3, volume = (def.volume or 0.6) * (vol or 1) * (0.94 + math.random() * 0.12),
			speed = (def.pitch or 1) * vary(def.id, 0.05) }
	else
		return nil
	end
	local fire = name ~= nil and FIRE[name] == true
	o.group = def.group or (name and GROUP_OF[name]) or (if at then "weapons" else "ui")
	o.at = at
	local d = 0
	if at then
		local L = listener()
		d = if L then (at - L).Magnitude / M else 0
		o.range = if fire then RANGE.fire elseif name and RANGE[name] then RANGE[name]
			elseif o.group == "steps" then RANGE.steps elseif name and HANDLING[name] then RANGE.handling
			elseif name == "knife" or name == "knifehit" then RANGE.knife else RANGE.default
		-- sons lointains plus sourds (l'air garde les graves)
		if d > 30 then local k = math.clamp((d - 30) / 70, 0, 1); o.high = -20 * k; o.mid = -6 * k end
	end
	local s = emit(o)
	if fire and useSheet and region and name then
		-- queue du tir : le même coup, plus grave et plus long, filtré ; plus présente de loin ;
		-- dehors elle revient en écho, dedans elle est plus courte, plus claire et plus forte
		local T = TAIL[name] or TAIL.rifle
		local indoor = acoustic.indoor == true
		local far = 1 + math.clamp(d / 60, 0, 1.2)
		local rate = (if indoor then 0.72 else 0.5 + 0.1 / T[1]) * vary(name .. "_tail", 0.05)
		emit({
			id = o.id, region = region, len = region[2], group = "weapons", at = at,
			volume = BASE * region[3] * (vol or 1) * T[2] * far * (if indoor then 1.3 else 1),
			speed = math.clamp(rate, 0.35, 0.85),
			high = if indoor then -14 else -24 - 6 * math.clamp(d / 100, 0, 1), mid = if indoor then -4 else -8, low = 2,
			range = if at then { 15, 260 } else nil,
			delay = 0.03 + (if at then d / 343 * 0.5 else 0),
			echo = if indoor then nil else acoustic.echo,
		})
	end
	-- explosion ou flash tout près : oreilles bouchées
	if at and (name == "bang" or name == "boom") then
		local near = if name == "bang" then 18 else 9
		if d < near then Sfx.muffle(if name == "bang" then 2.6 else 1.4, 1 - d / near * 0.6) end
	end
	return s
end

-- un pas (couches de ModeConfig.SOUNDS.STEPS) ; vol comme sfx('step') du web
function Sfx.step(surface: string, at: Vector3?, vol: number?)
	local steps = SOUNDS.STEPS
	local layers = steps and (steps[surface] or steps.sand)
	if not layers then return end
	local v = (vol or 0.3) * (0.88 + math.random() * 0.24)
	for _, L in ipairs(layers) do
		local region = Sheet[L.sheet]
		if region and ModeConfig.SOUND_SHEET ~= 0 then
			if not ensure() then return end
			local o: Opts = { id = "rbxassetid://" .. ModeConfig.SOUND_SHEET, region = region, len = region[2],
				volume = BASE * region[3] * (L.vol or 1) * v, speed = (L.rate or 1) * vary("step_" .. surface, 0.07),
				group = "steps", at = at, range = RANGE.steps, delay = L.delay }
			emit(o)
		end
	end
end

return Sfx
