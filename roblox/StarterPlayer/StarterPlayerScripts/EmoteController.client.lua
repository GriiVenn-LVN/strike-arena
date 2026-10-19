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
local moveConn: RBXScriptConnection? = nil

local function stop()
	if current then current:Stop(0.2); current = nil end
	if moveConn then moveConn:Disconnect(); moveConn = nil end
end

-- la demande du profil attend le serveur : elle se fait hors de l'action (une action ne doit pas attendre)
local function play(hum: Humanoid)
	local ok, data = pcall(getProfile.InvokeServer, getProfile)
	if not ok or not data or not data.profile or hum.Health <= 0 or not hum.Parent then return end
	local def = Config.DANCES[data.profile.equippedDance]
	if not def then return end
	if def.animationId == "rbxassetid://0" then
		-- pas d'animation importée : danse procédurale du jeu web, jouée par SoldierController chez tout le monde
		local dr = ReplicatedStorage:FindFirstChild("SoldierDance") :: RemoteEvent?
		if dr then dr:FireServer(true) end
		return
	end
	stop()
	local anim = Instance.new("Animation"); anim.AnimationId = def.animationId
	local animator = hum:FindFirstChildOfClass("Animator") or Instance.new("Animator", hum)
	local track = animator:LoadAnimation(anim)
	current = track
	track.Priority = Enum.AnimationPriority.Action
	track:Play(0.2)
	task.delay(def.length, function() if current == track then stop() end end)   -- pas la danse relancée entre-temps
	-- annule si le joueur bouge
	moveConn = hum.Running:Connect(function(speed) if speed > 1 and current == track then stop() end end)
end

local function emote(_, state: Enum.UserInputState)
	if state ~= Enum.UserInputState.Begin then return Enum.ContextActionResult.Pass end
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not hum or hum.Health <= 0 or player:GetAttribute("UiOpen") == true then return Enum.ContextActionResult.Pass end
	task.spawn(play, hum)
	return Enum.ContextActionResult.Sink
end
player.CharacterAdded:Connect(stop)

-- Touche configurable : remplace Enum.KeyCode.T par la valeur du profil du joueur
ContextActionService:BindAction("Emote", emote, false, Enum.KeyCode.T)
