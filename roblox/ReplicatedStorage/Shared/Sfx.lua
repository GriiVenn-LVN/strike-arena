--!strict
-- ReplicatedStorage/Shared/Sfx (ModuleScript, côté client)
-- Joue un son. Les vrais sons du jeu web sont rangés dans UN seul fichier audio (« planche », SoundSheet.lua) :
-- dès que ModeConfig.SOUND_SHEET contient son numéro, chaque son en est un extrait (Sound.PlaybackRegion).
-- Tant qu'il vaut 0, on garde les sons fournis avec Roblox (champ id de ModeConfig.SOUNDS).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local Debris = game:GetService("Debris")

local ModeConfig = require(ReplicatedStorage.Shared.ModeConfig)
local Sheet = require(ReplicatedStorage.Shared.SoundSheet)

local Sfx = {}
local BASE = 0.7          -- volume du fusil d'assaut ; les autres sons gardent leur écart de volume du web

-- def = entrée de ModeConfig.SOUNDS ({ id, volume, pitch, sheet }) ou nom d'un son de la planche ("magout"…)
function Sfx.play(def: any, at: Vector3?, vol: number?)
	if typeof(def) == "string" then def = ModeConfig.SOUNDS[def] or { sheet = def } end
	if not def then return end
	local s = Instance.new("Sound")
	local region = def.sheet and Sheet[def.sheet]
	if ModeConfig.SOUND_SHEET ~= 0 and region then
		s.SoundId = "rbxassetid://" .. ModeConfig.SOUND_SHEET
		s.PlaybackRegionsEnabled = true
		s.PlaybackRegion = NumberRange.new(region[1], region[1] + region[2])
		s.Volume = BASE * region[3] * (vol or 1)
		s.PlaybackSpeed = 0.96 + math.random() * 0.08
	elseif def.id and def.id ~= "" then
		s.SoundId = def.id; s.Volume = (def.volume or 0.6) * (vol or 1)
		s.PlaybackSpeed = (def.pitch or 1) * (0.95 + math.random() * 0.1)
	else
		s:Destroy(); return
	end
	if at then
		local a = Instance.new("Attachment"); a.WorldPosition = at; a.Parent = workspace.Terrain
		s.RollOffMaxDistance = 300; s.Parent = a; s:Play()
		Debris:AddItem(a, 4)
	else
		s.Parent = SoundService; s:Play()
		Debris:AddItem(s, 4)
	end
end

return Sfx
