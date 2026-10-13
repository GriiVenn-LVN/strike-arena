--!strict
-- ServerScriptService/WeatherService (ModuleScript)
-- Météo + heure de la journée : règle Lighting côté serveur et publie l'attribut "Weather" sur Workspace
-- (le client, WeatherController, ajoute pluie / éclairs / sons).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")

local X = require(ReplicatedStorage.Shared.ConfigExtra)

local WeatherService = {}
local base = { brightness = Lighting.Brightness, fogEnd = Lighting.FogEnd, fogStart = Lighting.FogStart, fogColor = Lighting.FogColor, ambient = Lighting.Ambient }

function WeatherService.apply(weather: string, tod: string, nightMap: boolean?)
	local w = X.WEATHER[weather] or X.WEATHER.clear
	Lighting.ClockTime = if nightMap then 23 else (X.TIME_OF_DAY[tod] or 14)
	Lighting.Brightness = base.brightness * w.sun * (if tod == "night" and not nightMap then 0.35 else 1)
	Lighting.FogStart = w.fogStart or base.fogStart
	Lighting.FogEnd = if w.fogStart then w.fogEnd else base.fogEnd * w.fogEnd
	Lighting.FogColor = if weather == "clear" then base.fogColor else base.fogColor:Lerp(Color3.fromRGB(110, 118, 132), 0.55)
	Lighting.Ambient = if tod == "night" then base.ambient:Lerp(Color3.fromRGB(20, 30, 60), 0.7) else base.ambient
	workspace:SetAttribute("Weather", weather)
	workspace:SetAttribute("TimeOfDay", tod)
end

return WeatherService
