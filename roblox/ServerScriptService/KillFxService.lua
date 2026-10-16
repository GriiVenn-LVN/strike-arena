--!strict
-- ServerScriptService/KillFxService (ModuleScript, requis par Main)
-- À chaque élimination faite par un joueur, envoie à tous les clients l'effet d'élimination qu'il a équipé.
-- L'effet lui-même est joué par StarterPlayerScripts/KillFxController (rien de lourd côté serveur).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local KillFxConfig = require(ReplicatedStorage.Shared.KillFxConfig)
local DataService = require(script.Parent.DataService)
local WeaponService = require(script.Parent.WeaponService)

local fxEvent = Instance.new("RemoteEvent"); fxEvent.Name = "KillFx"; fxEvent.Parent = ReplicatedStorage

local KillFxService = {}

function KillFxService.equippedOf(player: Player): string
	local profile = DataService.get(player)
	local id = profile and profile.equipped and profile.equipped.killFx or "none"
	if not KillFxConfig.get(id) then return "none" end
	if id ~= "none" and not table.find(profile.inv.killfx or {}, id) then return "none" end   -- plus possédé : rien
	return id
end

WeaponService.Killed:Connect(function(killer, victim, _key: string, _headshot: boolean)
	if typeof(killer) ~= "Instance" or not killer:IsA("Player") then return end   -- les bots n'ont pas d'effet
	local id = KillFxService.equippedOf(killer)
	if id == "none" then return end
	local char = WeaponService.charOf(victim)
	local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not char or not root then return end
	fxEvent:FireAllClients(id, char, root.Position, killer.UserId)
end)

return KillFxService
