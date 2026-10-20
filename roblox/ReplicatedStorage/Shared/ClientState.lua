--!strict
-- ReplicatedStorage/Shared/ClientState (ModuleScript, côté client)
-- État partagé entre les LocalScripts d'un même joueur (arme, déplacements, viewmodel) : chaque script qui fait
-- require reçoit la même table. Rien ici ne part au serveur.
local shot = Instance.new("BindableEvent")
local draw = Instance.new("BindableEvent")
local reload = Instance.new("BindableEvent")

return {
	-- arme (écrit par WeaponController)
	weapon = nil :: string?, firing = false, mag = 0, reserve = 0, aiming = false, reloading = false, reloadStart = 0, reloadEmpty = false,
	reloadDur = 0,                           -- durée réelle de la recharge en cours (serveur : accessoires et atouts compris)
	inspectStart = -1,                       -- os.clock() du début de l'inspection (touche V), -1 = pas d'inspection
	throwStart = -9,                         -- os.clock() du dernier lancer de grenade / pose de mine (GrenadeController)
	adsT = 0,                                -- visée lissée 0..1 (WeaponController, vitesse de visée de l'armurier)
	shot = shot, onShot = shot.Event,        -- (clé) à chaque tir local
	draw = draw, onDraw = draw.Event,        -- (clé) arme sortie
	reload = reload, onReload = reload.Event,-- (clé, à vide) début de recharge
	-- déplacements (écrit par MovementController)
	sprint = false, tactical = false, slide = false, crouch = false, mantle = false,
	mantleT = 0, mantleDur = 0, mantleHigh = false,  -- escalade : os.clock() du début, durée, rebord haut (grimper) ou bas (enjamber)
	tacE = 1,                                -- jauge du sprint tactique 0..1
	fireBlockedUntil = 0,                    -- sortie de sprint : on ne tire pas tout de suite (comme sur le web)
	drinkUntil = 0, drinkHideUntil = 0,      -- boisson d'atout (PerkDrinkController) : ni tir ni visée / arme rangée jusqu'à ces os.clock()
	speed = 0, grounded = true, vy = 0,
	stepAt = 0,                              -- os.clock() de notre dernier pas entendu (AmbienceController) : l'arme et la tête s'y calent
	muzzle = nil :: Vector3?,                -- bout du canon du viewmodel (point de départ des traceurs)
	-- kill-cam (écrit par KillcamController) : { key, skin, camo } de l'arme du tueur, nil hors kill-cam
	kc = nil :: any,
	spectate = nil :: Model?,                -- soldat suivi en spectateur (SpectateController), nil sinon
	onSkin = nil :: (() -> ())?,             -- repeint l'arme du viewmodel (ViewmodelController)
	-- menu principal (MainMenu) : réglages lus par WeaponController, fenêtres des autres interfaces
	opt = { fov = 70, sens = 1, aimSens = 1, wsens = 1,  -- champ de vision, sensibilité, multiplicateur en visée, réglage par arme
		invertY = false,                     -- axe vertical inversé (à lire par la caméra : WeaponController)
		xhColor = Color3.new(1, 1, 1),       -- couleur du viseur (à lire par HudController)
		xhStyle = "dot",                     -- forme du viseur : "dot", "cross", "circle", "none" (à lire par HudController)
		showFps = false, showPing = false,   -- compteurs en haut à droite (PauseMenu)
	},
	menuOpen = false,
	panels = {} :: { [string]: () -> () },   -- ouvre la fenêtre d'une autre interface (shop, gifts, vip, codes, group, loadout)
}
