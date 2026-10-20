--!strict
-- ReplicatedStorage/Shared/Icons (ModuleScript, client et serveur)
-- Petites icônes sûres pour l'interface. Les polices de Roblox ne savent pas dessiner tous les symboles du web :
-- croix U+2715, étoile U+2726, crayon U+270E, croix U+271A, barre U+275A, flèches U+27F3 et U+279C (pictogrammes « Dingbats »
-- sans version emoji), pièce U+1FA99, casque U+1FA96, parachute U+1FA82, goutte U+1FA78, pansement U+1FA79 (emoji Unicode 12 et 13),
-- bâtons U+1D378 ou carte U+1F0A1
-- donnaient des carrés vides dans Studio. Règle : dans les textes, seulement des emoji très courants (Unicode 11 au plus)
-- ou des symboles déjà vus à l'écran (⌂ ▸ ▶ ★ ⚙ ● → ·) ; sinon une icône dessinée ici avec des Frames :
--   Icons.coin(parent, taille)    pièce : rond doré, liseré foncé, reflet clair (remplace la pièce U+1FA99 à côté d'un montant)
--   Icons.cross(parent, taille)   croix de fermeture : deux barres en rotation (remplace ✕)
--   Icons.check(parent, taille)   coche : deux barres (remplace ✔, que Roblox dessine en emoji gris sans tenir compte de la couleur)
--   Icons.closeButton(bouton)     enlève le texte du bouton et y centre une croix
-- Icons.COIN : la pièce dans un texte (RichText ne sait pas mettre d'image) : 💰, emoji Unicode 6.
local Icons = {}

Icons.COIN = "💰"
Icons.GOLD = Color3.fromRGB(255, 210, 58)

local function frame(props: { [string]: any }, parent: Instance?): Frame
	local f = Instance.new("Frame")
	f.BorderSizePixel = 0
	f.BackgroundTransparency = 0
	for k, v in pairs(props) do (f :: any)[k] = v end
	if parent then f.Parent = parent end
	return f
end
local function round(o: Instance)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0.5, 0)
	c.Parent = o
end

-- pièce d'or : disque doré en dégradé, liseré brun, anneau intérieur et petit reflet. size en pixels.
function Icons.coin(parent: Instance?, size: number, props: { [string]: any }?): Frame
	local f = frame({ Name = "CoinIcon", Size = UDim2.fromOffset(size, size), BackgroundColor3 = Color3.new(1, 1, 1) }, parent)
	round(f)
	local g = Instance.new("UIGradient")
	g.Color = ColorSequence.new(Color3.fromRGB(255, 226, 110), Color3.fromRGB(230, 150, 20))
	g.Rotation = 120
	g.Parent = f
	local st = Instance.new("UIStroke")
	st.Color = Color3.fromRGB(120, 72, 0); st.Thickness = math.max(1, size / 14); st.Transparency = 0.1
	st.Parent = f
	local inner = frame({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.62, 0.62),
		BackgroundTransparency = 1, ZIndex = f.ZIndex }, f)
	round(inner)
	local ist = Instance.new("UIStroke")
	ist.Color = Color3.fromRGB(176, 104, 0); ist.Thickness = math.max(1, size / 18); ist.Transparency = 0.35
	ist.Parent = inner
	local hl = frame({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.34, 0.3), Size = UDim2.fromScale(0.22, 0.14), Rotation = -35,
		BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.35, ZIndex = f.ZIndex }, f)
	round(hl)
	for _, d in ipairs(f:GetDescendants()) do if d:IsA("GuiObject") then d.Active = false end end
	f.Active = false
	if props then for k, v in pairs(props) do (f :: any)[k] = v end end
	return f
end

-- croix (✕) : deux barres croisées dans un carré de « size » pixels
function Icons.cross(parent: Instance?, size: number, color: Color3?, props: { [string]: any }?): Frame
	local f = frame({ Name = "CrossIcon", Size = UDim2.fromOffset(size, size), BackgroundTransparency = 1 }, parent)
	local th = math.max(2, math.floor(size / 7 + 0.5))
	for _, r in ipairs({ 45, -45 }) do
		local b = frame({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(1.2, 0, 0, th), Rotation = r,
			BackgroundColor3 = color or Color3.new(1, 1, 1), ZIndex = f.ZIndex, Active = false }, f)
		local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, th // 2); c.Parent = b
	end
	f.Active = false
	if props then for k, v in pairs(props) do (f :: any)[k] = v end end
	return f
end

-- coche (✔) : une barre courte et une longue qui se rejoignent en bas, dans un carré de « size » pixels
function Icons.check(parent: Instance?, size: number, color: Color3?, props: { [string]: any }?): Frame
	local f = frame({ Name = "CheckIcon", Size = UDim2.fromOffset(size, size), BackgroundTransparency = 1 }, parent)
	local th = math.max(2, math.floor(size / 6 + 0.5))
	local col = color or Color3.new(1, 1, 1)
	-- Roblox fait tourner un cadre autour de son centre : chaque barre est posée par son milieu.
	-- Coche de (0,18 ; 0,52) à la pointe (0,40 ; 0,74), puis jusqu'à (0,84 ; 0,26) (en fractions du carré).
	for _, seg in ipairs({ { 0.29, 0.63, 0.311, 45 }, { 0.62, 0.50, 0.651, -47.5 } }) do
		local b = frame({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(seg[1], seg[2]), Size = UDim2.new(seg[3], th, 0, th), Rotation = seg[4],
			BackgroundColor3 = col, ZIndex = f.ZIndex, Active = false }, f)
		local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, th // 2); c.Parent = b
	end
	f.Active = false
	if props then for k, v in pairs(props) do (f :: any)[k] = v end end
	return f
end

-- bouton de fermeture : le texte « ✕ » est remplacé par une croix dessinée, centrée
function Icons.closeButton(b: GuiButton, size: number?, color: Color3?): Frame
	if b:IsA("TextButton") then b.Text = "" end
	local s = size or math.floor(math.min(b.AbsoluteSize.X, b.AbsoluteSize.Y) * 0.38 + 0.5)
	if s <= 2 then s = 14 end
	return Icons.cross(b, s, color, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), ZIndex = b.ZIndex + 1 })
end

-- un montant avec la pièce dessinée devant : cadre transparent (icône + texte) ; renvoie le cadre et le texte
function Icons.amount(parent: Instance?, value: string, textSize: number, props: { [string]: any }?): (Frame, TextLabel)
	local f = frame({ Name = "Amount", BackgroundTransparency = 1, Size = UDim2.fromOffset(0, textSize + 6), AutomaticSize = Enum.AutomaticSize.X }, parent)
	local lay = Instance.new("UIListLayout")
	lay.FillDirection = Enum.FillDirection.Horizontal; lay.VerticalAlignment = Enum.VerticalAlignment.Center
	lay.Padding = UDim.new(0, math.max(3, textSize // 3)); lay.SortOrder = Enum.SortOrder.LayoutOrder
	lay.Parent = f
	local ic = Icons.coin(f, math.floor(textSize * 1.05 + 0.5))
	ic.LayoutOrder = 1
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1; t.BorderSizePixel = 0
	t.Font = Enum.Font.GothamBlack; t.TextSize = textSize; t.TextColor3 = Color3.fromRGB(232, 238, 249); t.RichText = true
	t.Text = value; t.AutomaticSize = Enum.AutomaticSize.X; t.Size = UDim2.fromOffset(0, textSize + 6); t.LayoutOrder = 2
	t.Parent = f
	if props then for k, v in pairs(props) do (f :: any)[k] = v end end
	return f, t
end

return Icons
