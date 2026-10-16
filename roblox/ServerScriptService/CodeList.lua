--!strict
-- ServerScriptService/CodeList (ModuleScript, SERVEUR UNIQUEMENT)
-- Liste des codes promo. Elle reste côté serveur pour que personne ne puisse lire les codes à l'avance.
--
-- Pour sortir un nouveau code (à chaque mise à jour, ou quand le jeu atteint 1 000 / 10 000 likes) :
--   ajoute une ligne, publie le jeu, puis annonce le code sur Discord, YouTube ou dans la description du jeu.
--
-- Champs :
--   code     : en MAJUSCULES (le joueur peut le taper en minuscules, les espaces sont ignorés)
--   reward   : { coins = n, box = "std"|"prem", killfx = "id", dance = "id" } (tout est facultatif)
--   from/to  : dates UTC "AAAA-MM-JJ" (facultatif) ; en dehors, le code répond « expiré » ou « pas encore actif »
return {
	{ code = "BIENVENUE", reward = { coins = 100 } },
	{ code = "HALLOWEEN25", reward = { coins = 150, killfx = "pumpkins" }, from = "2026-10-15", to = "2026-11-08" },
	{ code = "DUEL", reward = { box = "std" } },
	-- exemples à activer plus tard :
	-- { code = "1KLIKES", reward = { coins = 300 } },
	-- { code = "SAISON2", reward = { box = "prem" }, from = "2026-12-01", to = "2026-12-31" },
}
