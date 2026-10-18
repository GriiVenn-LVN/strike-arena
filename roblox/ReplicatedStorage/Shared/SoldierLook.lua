--!strict
-- ReplicatedStorage/Shared/SoldierLook (ModuleScript, client et serveur)
-- Qui porte quoi, et le squelette des soldats du jeu web posé sur le R15 :
--   look(model)    : soldat réaliste de l'équipe (T / CT / chacun-pour-soi, comme cfg.realChars du web)
--                    ou tenue de la boutique (soldat procédural, attribut « Outfit » du joueur posé par SoldierService)
--   rest(rig)      : repère de repos de chaque membre (B, en mètres, repère du soldat : pieds en 0, regard vers -Z)
--                    et point d'articulation (pivot) utilisé par le ragdoll du serveur
--   natural(char)  : repère « naturel » de chaque pièce R15 dans le repère du soldat (studs), d'après les Motor6D
-- Un membre R15 suit son os par la même différence de pose : cible = os(t) · B⁻¹ · naturel. Les maillages du web
-- sont soudés aux pièces R15 avec un décalage fixe (naturel⁻¹ · B · centre) : ragdoll et kill-cam marchent tels quels.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Rig = require(ReplicatedStorage.Shared.SoldierMeshes.Rig) :: any

local Look = {}
Look.K = 2.9                 -- studs par mètre du soldat (même valeur que l'arme tenue, WeaponService.WORLD_SCALE)
Look.Rig = Rig

export type LookInfo = { rig: string, key: string, tex: string, outfit: number?, acc: Color3, tone: Color3, colorIndex: number }

local function hex(s: string): Color3
	local n = tonumber(string.sub(s, 2), 16) or 0
	return Color3.fromRGB(bit32.rshift(n, 16), bit32.band(bit32.rshift(n, 8), 255), bit32.band(n, 255))
end
Look.hex = hex

local function hash(s: string): number
	local h = 5381
	for i = 1, #s do h = (h * 33 + string.byte(s, i)) % 2147483647 end
	return h
end

-- équipe d'un soldat : nom d'équipe Roblox (joueur) ou attribut Team (bot)
local function teamOf(model: Model): string?
	local p = Players:GetPlayerFromCharacter(model)
	if p then return if p.Team then p.Team.Name else nil end
	local t = model:GetAttribute("Team")
	return if typeof(t) == "string" then t else nil
end

function Look.look(model: Model): LookInfo
	local p = Players:GetPlayerFromCharacter(model)
	local seed = hash(if p then tostring(p.UserId) else model.Name)
	local ci = seed % #Rig.PALETTE + 1
	local info: LookInfo = { rig = "real", key = "ffa", tex = "ffa", outfit = nil, acc = hex(Rig.PALETTE[ci]),
		tone = hex(Rig.TONES[seed // 7 % #Rig.TONES + 1]), colorIndex = ci }
	local team = teamOf(model)
	if team == "Attaquants" then info.key = "t"; info.tex = "t"; info.acc = hex(Rig.PALETTE[6])
	elseif team == "Défenseurs" then info.key = "ct"; info.tex = "ct"; info.acc = hex(Rig.PALETTE[2]) end
	-- tenue équipée (Config.OUTFITS, 1 = « Équipe » : le soldat de l'équipe)
	local o = p and p:GetAttribute("Outfit")
	if typeof(o) == "number" and o > 1 and Config.OUTFITS[o] then
		local def = Rig.OUTFITS[Config.OUTFITS[o].name]
		if def then info.rig = "proc"; info.outfit = def.web; info.key = "o" .. def.web end
	end
	return info
end

-- ---------- squelette au repos ----------
local DOWN = Vector3.new(0, -1, 0)
local function fromTo(a: Vector3, b: Vector3): CFrame
	local d = a:Dot(b)
	if d > 0.999999 then return CFrame.identity end
	if d < -0.999999 then
		local ax = a:Cross(Vector3.xAxis)
		if ax.Magnitude < 1e-3 then ax = a:Cross(Vector3.yAxis) end
		return CFrame.fromAxisAngle(ax.Unit, math.pi)
	end
	return CFrame.fromAxisAngle(a:Cross(b).Unit, math.acos(d))
end
Look.fromTo = fromTo

export type Rest = { B: { [string]: CFrame }, pivot: { [string]: Vector3 }, dir: { [string]: Vector3 } }
local restCache: { [string]: Rest } = {}

function Look.rest(rig: string): Rest
	if restCache[rig] then return restCache[rig] end
	local B, piv, dir = {}, {}, {}
	if rig == "real" then
		local b = Rig.real.bones
		B.LowerTorso = CFrame.new(b.pelvis); B.UpperTorso = CFrame.new(b.spine); B.Head = CFrame.new(b.head)
		piv.LowerTorso = b.pelvis; piv.UpperTorso = b.spine; piv.Head = b.neck
		for _, s in ipairs({ "Left", "Right" }) do
			local k = string.sub(s, 1, 1)
			B[s .. "UpperLeg"] = CFrame.new(b["thigh" .. k]); B[s .. "LowerLeg"] = CFrame.new(b["calf" .. k]); B[s .. "Foot"] = CFrame.new(b["foot" .. k])
			piv[s .. "UpperLeg"] = b["thigh" .. k]; piv[s .. "LowerLeg"] = b["calf" .. k]; piv[s .. "Foot"] = b["foot" .. k]
			-- bras du modèle en croix au repos : la référence est le bras pendant (comme le R15)
			local A = Rig.real.arm[k]
			local sh = b["uarm" .. k]
			local el = sh + DOWN * A.la
			local wr = el + DOWN * A.lb
			B[s .. "UpperArm"] = CFrame.new(sh) * fromTo(A.dU, DOWN)
			B[s .. "LowerArm"] = CFrame.new(el) * fromTo(A.dF, DOWN)
			B[s .. "Hand"] = CFrame.new(wr) * fromTo(A.dF, DOWN)
			piv[s .. "UpperArm"] = sh; piv[s .. "LowerArm"] = el; piv[s .. "Hand"] = wr
		end
	else
		local P = Rig.proc.piv
		for _, n in ipairs({ "LowerTorso", "UpperTorso", "Head", "LeftUpperLeg", "LeftLowerLeg", "LeftFoot", "RightUpperLeg", "RightLowerLeg", "RightFoot" }) do
			B[n] = CFrame.new(P[n]); piv[n] = P[n]
		end
		piv.Head = Rig.proc.neck
		for _, s in ipairs({ "Left", "Right" }) do
			local sh = Rig.proc.spine + Rig.proc.S[string.sub(s, 1, 1)]
			B[s .. "UpperArm"] = CFrame.new(sh); B[s .. "LowerArm"] = CFrame.new(sh + DOWN * 0.29)
			B[s .. "Hand"] = CFrame.new(sh + DOWN * 0.56) * CFrame.Angles(-math.pi / 2, 0, 0)   -- main pendante, doigts vers le bas
			piv[s .. "UpperArm"] = sh; piv[s .. "LowerArm"] = sh + DOWN * 0.29; piv[s .. "Hand"] = sh + DOWN * 0.56
		end
	end
	for n in pairs(piv) do dir[n] = if n == "UpperTorso" or n == "Head" or n == "LowerTorso" then Vector3.yAxis else DOWN end
	local r: Rest = { B = B, pivot = piv, dir = dir }
	restCache[rig] = r
	return r
end

-- ---------- repères naturels des pièces R15 ----------
-- C0 d'origine : WeaponService lève les épaules en changeant C0 et garde l'original dans l'attribut BaseC0
local function baseC0(m: Motor6D): CFrame
	local b = m:GetAttribute("BaseC0")
	return if typeof(b) == "CFrame" then b else m.C0
end
Look.baseC0 = baseC0

-- position de la racine (HumanoidRootPart) dans le repère du soldat (pieds au sol)
function Look.rootOffset(hum: Humanoid, hrp: BasePart): CFrame
	return CFrame.new(0, hum.HipHeight + hrp.Size.Y / 2, 0)
end

export type Joint = { m: Motor6D, p0: BasePart, p1: BasePart }
-- renvoie les repères naturels (studs) et les Motor6D dans l'ordre parent -> enfant
function Look.natural(char: Model, hum: Humanoid, hrp: BasePart): ({ [BasePart]: CFrame }, { Joint })
	local N: { [BasePart]: CFrame } = { [hrp] = Look.rootOffset(hum, hrp) }
	local byP0: { [BasePart]: { Motor6D } } = {}
	for _, d in ipairs(char:GetDescendants()) do
		if d:IsA("Motor6D") and d.Part0 and d.Part1 then
			local p0 = d.Part0 :: BasePart
			byP0[p0] = byP0[p0] or {}
			table.insert(byP0[p0], d)
		end
	end
	local order: { Joint } = {}
	local queue = { hrp }
	local qi = 1
	while qi <= #queue do
		local p = queue[qi]; qi += 1
		for _, m in ipairs(byP0[p] or {}) do
			local c = m.Part1 :: BasePart
			if not N[c] then
				N[c] = N[p] * baseC0(m) * m.C1:Inverse()
				table.insert(order, { m = m, p0 = p, p1 = c })
				table.insert(queue, c)
			end
		end
	end
	return N, order
end

return Look
