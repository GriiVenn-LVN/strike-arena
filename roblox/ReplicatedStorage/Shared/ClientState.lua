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
	inspectStart = -1,                       -- os.clock() du début de l'inspection (touche V), -1 = pas d'inspection
	throwStart = -9,                         -- os.clock() du dernier lancer de grenade / pose de mine (GrenadeController)
	adsT = 0,                                -- visée lissée 0..1 (WeaponController, vitesse de visée de l'armurier)
	shot = shot, onShot = shot.Event,        -- (clé) à chaque tir local
	draw = draw, onDraw = draw.Event,        -- (clé) arme sortie
	reload = reload, onReload = reload.Event,-- (clé, à vide) début de recharge
	-- déplacements (écrit par MovementController)
	sprint = false, tactical = false, slide = false, crouch = false, mantle = false,
	fireBlockedUntil = 0,                    -- sortie de sprint : on ne tire pas tout de suite (comme sur le web)
	speed = 0, grounded = true, vy = 0,
	muzzle = nil :: Vector3?,                -- bout du canon du viewmodel (point de départ des traceurs)
	-- kill-cam (écrit par KillcamController) : { key, skin, camo } de l'arme du tueur, nil hors kill-cam
	kc = nil :: any,
	onSkin = nil :: (() -> ())?,             -- repeint l'arme du viewmodel (ViewmodelController)
}
