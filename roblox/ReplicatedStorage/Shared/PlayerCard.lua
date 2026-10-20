--!strict
-- ReplicatedStorage/Shared/PlayerCard (ModuleScript, client + serveur)
-- Carte de joueur façon Call of Duty : une bannière (dégradé) + un emblème, choisis dans Profil › Pseudo et titre,
-- affichés dans la kill-cam (la carte du tueur) et dans l'écran d'accueil « Quoi de neuf ».
-- Tout se débloque en jouant (niveau, succès, médailles, maîtrise d'arme) ; la bannière et l'emblème Premium demandent
-- le Premium (LoyaltyService). Le serveur (CareerService) vérifie le déblocage avant d'équiper et recopie le choix dans
-- l'attribut « Card » du joueur (« banniere|embleme »).
local PlayerCard = {}

-- vue : ce qu'il faut savoir du profil pour les déblocages (construite par CareerService.cardView, envoyée au menu)
export type View = { level: number, ach: { [string]: any }, medals: { [string]: number }, gold: number, diamonds: number, dark: number,
	vip: boolean, rankBest: number, pumpkins: number }
-- need : { lvl = niveau } | { ach = succès } | { medal = id, n = nombre } | { gold = n } | { diamonds = n } | { dark = n } | { vip = true }
--        | { rank = division } | { pumpkins = n }
export type Banner = { id: string, n: string, a: Color3, b: Color3, need: { [string]: any }, fx: string? }
export type Emblem = { id: string, n: string, ic: string, need: { [string]: any } }

local function rgb(h: number): Color3
	return Color3.fromRGB(bit32.rshift(h, 16), bit32.band(bit32.rshift(h, 8), 255), bit32.band(h, 255))
end

PlayerCard.BANNERS = {
	{ id = "recrue", n = "Recrue", a = rgb(0x1e2a42), b = rgb(0x0b111c), need = { lvl = 1 } },
	{ id = "crepuscule", n = "Crépuscule", a = rgb(0xff6b5a), b = rgb(0x3a1650), need = { lvl = 5 } },
	{ id = "neon", n = "Néon", a = rgb(0x21e6c1), b = rgb(0x3a4bff), need = { lvl = 10 } },
	{ id = "jungle", n = "Jungle", a = rgb(0x4f8a2a), b = rgb(0x0e2410), need = { lvl = 15 } },
	{ id = "braise", n = "Braise", a = rgb(0xffb938), b = rgb(0x8a1a0a), need = { lvl = 20 } },
	{ id = "abysse", n = "Abysse", a = rgb(0x0a5a8a), b = rgb(0x020a1a), need = { lvl = 30 } },
	{ id = "tetes", n = "Chasseur de têtes", a = rgb(0xff4655), b = rgb(0x1a0406), need = { ach = "hs50" } },
	{ id = "centurion", n = "Centurion", a = rgb(0xc0c8d8), b = rgb(0x2a3040), need = { ach = "k100" } },
	{ id = "colline", n = "Roi de la colline", a = rgb(0x35e0c0), b = rgb(0x0a2a26), need = { ach = "koth" } },
	{ id = "triple", n = "Triplé", a = rgb(0xffd23a), b = rgb(0x5a2bd6), need = { medal = "triple", n = 1 } },
	{ id = "furie", n = "Furie", a = rgb(0xff2bd6), b = rgb(0x1a0420), need = { medal = "fury", n = 1 } },
	{ id = "or", n = "Maître d'armes", a = rgb(0xffd23a), b = rgb(0x6a4a10), need = { gold = 1 }, fx = "shine" },
	{ id = "diamant", n = "Diamant", a = rgb(0xbfe8ff), b = rgb(0x1a3a52), need = { diamonds = 1 }, fx = "shine" },
	{ id = "noire", n = "Matière noire", a = rgb(0xc77dff), b = rgb(0x07051a), need = { dark = 1 }, fx = "shine" },
	{ id = "rang_or", n = "Rang Or", a = rgb(0xffc53a), b = rgb(0x2a1a00), need = { rank = 6 } },
	{ id = "citrouille", n = "Nuit d'Halloween", a = rgb(0xff8a2a), b = rgb(0x2a1a4a), need = { pumpkins = 25 } },
	{ id = "premium", n = "Premium", a = rgb(0xffd23a), b = rgb(0xff5f48), need = { vip = true }, fx = "shine" },
} :: { Banner }

PlayerCard.EMBLEMS = {
	{ id = "cible", n = "Cible", ic = "🎯", need = { lvl = 1 } },
	{ id = "crane", n = "Crâne", ic = "💀", need = { lvl = 3 } },
	{ id = "loup", n = "Loup", ic = "🐺", need = { lvl = 8 } },
	{ id = "aigle", n = "Aigle", ic = "🦅", need = { lvl = 12 } },
	{ id = "dragon", n = "Dragon", ic = "🐉", need = { lvl = 25 } },
	{ id = "lame", n = "Lame", ic = "🔪", need = { medal = "knife", n = 10 } },
	{ id = "sang", n = "Premier sang", ic = "🔴", need = { medal = "first", n = 10 } },
	{ id = "main", n = "Équipier", ic = "🤝", need = { medal = "assist", n = 25 } },
	{ id = "bouclier", n = "Sauveur", ic = "🛡️", need = { medal = "save", n = 10 } },
	{ id = "eclair", n = "Furie", ic = "⚡", need = { medal = "fury", n = 1 } },
	{ id = "glisse", n = "Glisseur", ic = "🏂", need = { medal = "slide", n = 10 } },
	{ id = "couronne", n = "Légende", ic = "👑", need = { medal = "s10", n = 1 } },
	{ id = "medaille", n = "Maître d'armes", ic = "🥇", need = { gold = 1 } },
	{ id = "gemme", n = "Diamant", ic = "💎", need = { diamonds = 1 } },
	{ id = "galaxie", n = "Matière noire", ic = "🌌", need = { dark = 1 } },
	{ id = "potiron", n = "Citrouille", ic = "🎃", need = { pumpkins = 50 } },
	{ id = "etoile", n = "Premium", ic = "⭐", need = { vip = true } },
} :: { Emblem }

function PlayerCard.banner(id: string?): Banner
	for _, b in ipairs(PlayerCard.BANNERS) do if b.id == id then return b end end
	return PlayerCard.BANNERS[1]
end
function PlayerCard.emblem(id: string?): Emblem
	for _, e in ipairs(PlayerCard.EMBLEMS) do if e.id == id then return e end end
	return PlayerCard.EMBLEMS[1]
end
function PlayerCard.findBanner(id: string): Banner?
	for _, b in ipairs(PlayerCard.BANNERS) do if b.id == id then return b end end
	return nil
end
function PlayerCard.findEmblem(id: string): Emblem?
	for _, e in ipairs(PlayerCard.EMBLEMS) do if e.id == id then return e end end
	return nil
end

-- condition remplie ? (même règle côté client pour l'affichage et côté serveur pour la vérification)
function PlayerCard.open(need: { [string]: any }, v: View): boolean
	if need.lvl then return v.level >= need.lvl end
	if need.ach then return v.ach[need.ach] ~= nil end
	if need.medal then return (v.medals[need.medal] or 0) >= (need.n or 1) end
	if need.gold then return v.gold >= need.gold end
	if need.diamonds then return v.diamonds >= need.diamonds end
	if need.dark then return v.dark >= need.dark end
	if need.vip then return v.vip end
	if need.rank then return v.rankBest >= need.rank end
	if need.pumpkins then return v.pumpkins >= need.pumpkins end
	return false
end

-- texte de la condition (verrou dans le menu)
local MEDAL_N: { [string]: string } = { triple = "Triplé", fury = "Furie", knife = "Humiliation", first = "Premier sang", assist = "Assistance",
	save = "Sauveur", slide = "Glissade mortelle", s10 = "Légende" }
function PlayerCard.needText(need: { [string]: any }): string
	if need.lvl then return "Niveau " .. need.lvl end
	if need.ach then return "Succès à débloquer" end
	if need.medal then return "Médaille « " .. (MEDAL_N[need.medal] or need.medal) .. " » ×" .. (need.n or 1) end
	if need.gold then return "Maîtrise Or sur une arme" end
	if need.diamonds then return "Maîtrise Diamant sur une arme" end
	if need.dark then return "Maîtrise Matière noire" end
	if need.vip then return "Premium" end
	if need.rank then return "Rang Or atteint" end
	if need.pumpkins then return need.pumpkins .. " citrouilles" end
	return "Verrouillé"
end

-- « banniere|embleme » <-> ids
function PlayerCard.decode(s: any): (string, string)
	if typeof(s) ~= "string" then return "recrue", "cible" end
	local b, e = string.match(s, "^([%w_]+)|([%w_]+)$")
	return b or "recrue", e or "cible"
end

-- dessine une carte (Frame) : bannière en dégradé, emblème dans un rond, nom, titre et niveau
-- opts = { banner, emblem, name, title?, level?, size? (largeur, 300 par défaut) }
function PlayerCard.render(parent: Instance?, opts: { [string]: any }): Frame
	local TweenService = game:GetService("TweenService")
	local W = opts.size or 300
	local H = math.floor(W * 0.24)
	local b = PlayerCard.banner(opts.banner)
	local e = PlayerCard.emblem(opts.emblem)
	local function make(class: string, props: { [string]: any }, p: Instance?): any
		local o: any = Instance.new(class)
		if o:IsA("GuiObject") then o.BorderSizePixel = 0 end
		for k, v in pairs(props) do o[k] = v end
		if p then o.Parent = p end
		return o
	end
	local f = make("Frame", { Name = "PlayerCard", Size = UDim2.fromOffset(W, H), BackgroundColor3 = Color3.new(1, 1, 1), ClipsDescendants = true }, parent)
	make("UICorner", { CornerRadius = UDim.new(0, 6) }, f)
	make("UIGradient", { Color = ColorSequence.new(b.a, b.b), Rotation = 20 }, f)
	make("UIStroke", { Color = b.a:Lerp(Color3.new(1, 1, 1), 0.4), Thickness = 1, Transparency = 0.45 }, f)
	-- rayures discrètes (bannières COD)
	for i = 0, 5 do
		make("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.55 + i * 0.09, 0, 0.5, 0), Size = UDim2.new(0, math.max(2, W // 60), 2.2, 0),
			Rotation = 25, BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.9 }, f)
	end
	local s = H - 10
	local em = make("TextLabel", { Name = "Emblem", Position = UDim2.fromOffset(5, 5), Size = UDim2.fromOffset(s, s), BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.55, Text = e.ic, TextScaled = true, Font = Enum.Font.GothamBold, TextColor3 = Color3.new(1, 1, 1) }, f)
	make("UICorner", { CornerRadius = UDim.new(0.5, 0) }, em)
	make("UIStroke", { Color = b.a, Thickness = 2, Transparency = 0.2 }, em)
	make("UIPadding", { PaddingTop = UDim.new(0.14, 0), PaddingBottom = UDim.new(0.14, 0), PaddingLeft = UDim.new(0.14, 0), PaddingRight = UDim.new(0.14, 0) }, em)
	local x = s + 14
	local nameT = tostring(opts.name or "")
	make("TextLabel", { Name = "CardName", Position = UDim2.fromOffset(x, math.floor(H * 0.12)), Size = UDim2.new(1, -x - 50, 0, math.floor(H * 0.42)), BackgroundTransparency = 1,
		Text = nameT, Font = Enum.Font.GothamBlack, TextScaled = true, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = Color3.new(1, 1, 1),
		TextStrokeTransparency = 0.6 }, f)
	local sub = if typeof(opts.title) == "string" and opts.title ~= "" then opts.title else b.n
	make("TextLabel", { Name = "CardTitle", Position = UDim2.fromOffset(x, math.floor(H * 0.58)), Size = UDim2.new(1, -x - 50, 0, math.floor(H * 0.28)), BackgroundTransparency = 1,
		Text = string.upper(sub), Font = Enum.Font.GothamBold, TextScaled = true, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = Color3.fromRGB(255, 230, 160),
		TextTransparency = 0.05 }, f)
	if typeof(opts.level) == "number" then
		local lv = make("TextLabel", { Name = "CardLevel", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0), Size = UDim2.fromOffset(math.floor(H * 0.6), math.floor(H * 0.6)),
			BackgroundColor3 = Color3.fromRGB(255, 196, 58), Text = tostring(opts.level), Font = Enum.Font.GothamBlack, TextScaled = true, TextColor3 = Color3.fromRGB(42, 26, 0) }, f)
		make("UICorner", { CornerRadius = UDim.new(0.5, 0) }, lv)
		make("UIPadding", { PaddingTop = UDim.new(0.18, 0), PaddingBottom = UDim.new(0.18, 0) }, lv)
	end
	-- bannières rares : un reflet passe en boucle (comme les cartes rares du menu)
	if b.fx == "shine" then
		local band = make("Frame", { Name = "Sheen", AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.fromScale(-0.5, 0.5), Size = UDim2.fromScale(0.3, 2),
			Rotation = 18, BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0 }, f)
		make("UIGradient", { Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0.7), NumberSequenceKeypoint.new(1, 1) }) }, band)
		TweenService:Create(band, TweenInfo.new(1.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, false, 2.2), { Position = UDim2.fromScale(1.2, 0.5) }):Play()
	end
	return f
end

return PlayerCard
