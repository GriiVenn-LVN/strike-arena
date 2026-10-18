--!strict
-- StarterPlayerScripts/EmoteController (LocalScript)
-- Touche T : joue la danse équipée (animation R15 que tu crées dans l'Animation Editor).
-- Les touches sont personnalisables : lis-les depuis le profil (profile.binds) ou ContextActionService.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local Config = require(ReplicatedStorage.Shared.Config)

local player = Players.LocalPlayer
local getProfile = ReplicatedStorage:WaitForChild("GetProfile") :: RemoteFunction

local current: AnimationTrack? = nil

local function stop()
	if current then current:Stop(0.2); current = nil end
end

local function emote(_, state: Enum.UserInputState)
	if state ~= Enum.UserInputState.Begin then return Enum.ContextActionResult.Pass end
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not hum or hum.Health <= 0 then return Enum.ContextActionResult.Pass end
	local data = getProfile:InvokeServer()
	if not data then return Enum.ContextActionResult.Pass end
	local def = Config.DANCES[data.profile.equippedDance]
	if not def then return Enum.ContextActionResult.Sink end
	if def.animationId == "rbxassetid://0" then
		-- pas d'animation importée : danse procédurale du jeu web, jouée par SoldierController chez tout le monde
		local dr = ReplicatedStorage:FindFirstChild("SoldierDance") :: RemoteEvent?
		if dr then dr:FireServer(true) end
		return Enum.ContextActionResult.Sink
	end
	stop()
	local anim = Instance.new("Animation"); anim.AnimationId = def.animationId
	local animator = hum:FindFirstChildOfClass("Animator") or Instance.new("Animator", hum)
	local track = animator:LoadAnimation(anim)
	current = track
	track.Priority = Enum.AnimationPriority.Action
	track:Play(0.2)
	task.delay(def.length, function() if current then stop() end end)
	-- annule si le joueur bouge
	local conn; conn = hum.Running:Connect(function(speed) if speed > 1 then stop(); conn:Disconnect() end end)
	return Enum.ContextActionResult.Sink
end

-- Touche configurable : remplace Enum.KeyCode.T par la valeur du profil du joueur
ContextActionService:BindAction("Emote", emote, false, Enum.KeyCode.T)
