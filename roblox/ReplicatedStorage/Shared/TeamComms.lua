--!strict
-- Shared/TeamComms : réglages partagés du ping et des messages rapides (TeamCommsService / CommsController)
local TeamComms = {}

TeamComms.PING_COOLDOWN = 0.8   -- secondes entre deux pings d'un même joueur
TeamComms.PING_LIFE = 6         -- durée d'affichage d'un ping (un ennemi marqué : PING_LIFE / 2)
TeamComms.CHAT_COOLDOWN = 1.5

-- messages rapides (touche N puis 1 à 6), comme la radio de CS
TeamComms.LINES = {
	"Besoin d'aide !",
	"Ennemi repéré !",
	"Je couvre.",
	"On fonce !",
	"Recule !",
	"Bien joué !",
}

return TeamComms
