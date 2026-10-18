--!strict
-- ServerScriptService/AdminConfig (ModuleScript, serveur seulement : jamais envoyé aux joueurs)
-- Qui peut ouvrir le panneau admin (AdminService) :
--   1) le propriétaire du jeu (créateur de l'expérience, ou propriétaire du groupe qui la publie : rang 255),
--      ou un identifiant listé dans USER_IDS ;
--   2) ET il doit taper le code ci-dessous (16 caractères, tirets facultatifs), comme le code admin du web.
-- Un joueur normal ne voit jamais le panneau : la touche Inser / F2 ne fait rien pour lui et le serveur refuse tout.
-- ⚠ Change CODE avant de publier (le dépôt est public). Ce fichier reste sur le serveur.
local AdminConfig = {}

AdminConfig.CODE = "CHANGE-MOI-AVANT-PUBLI"   -- remplace par ton propre code (lettres et chiffres, 16 caractères conseillés)
AdminConfig.USER_IDS = {} :: { number }       -- autres comptes autorisés (en plus du propriétaire), ex. { 12345678 }
AdminConfig.STUDIO = true                     -- en test dans Studio, la personne qui teste compte comme propriétaire
AdminConfig.MAX_TRIES = 5                     -- essais de code par minute

return AdminConfig
