--!strict
-- ServerScriptService/Stores (ModuleScript)
-- Accès aux DataStore avec une solution de secours : tant que le jeu n'est pas publié (ou que
-- « Enable Studio Access to API Services » est coupé), Roblox refuse GetDataStore et tout le serveur
-- s'arrêterait. Dans ce cas on renvoie un magasin en mémoire : le jeu tourne, rien n'est sauvegardé.
local DataStoreService = game:GetService("DataStoreService")

local Stores = {}
Stores.offline = false

local warned = false
local function warnOnce(err: any)
	Stores.offline = true
	if warned then return end
	warned = true
	warn("[Stores] DataStore indisponible, sauvegarde coupée pour cette session :", err,
		"\n→ Publie le jeu puis active Game Settings > Security > Enable Studio Access to API Services.")
end

local function memoryStore(): any
	local data: { [string]: any } = {}
	local store = {}
	function store:GetAsync(key: string) return data[key] end
	function store:SetAsync(key: string, value: any) data[key] = value end
	function store:UpdateAsync(key: string, fn: (any) -> any)
		local v = fn(data[key]); if v ~= nil then data[key] = v end
		return data[key]
	end
	function store:IncrementAsync(key: string, n: number?)
		data[key] = (data[key] or 0) + (n or 1); return data[key]
	end
	function store:RemoveAsync(key: string) local v = data[key]; data[key] = nil; return v end
	function store:GetSortedAsync(ascending: boolean, pageSize: number)
		local list = {}
		for k, v in pairs(data) do if typeof(v) == "number" then table.insert(list, { key = k, value = v }) end end
		table.sort(list, function(a, b) if ascending then return a.value < b.value else return a.value > b.value end end)
		local page = {}
		for i = 1, math.min(pageSize, #list) do page[i] = list[i] end
		return {
			IsFinished = true,
			GetCurrentPage = function(_) return page end,
			AdvanceToNextPageAsync = function(_) end,
		}
	end
	return store
end

local function get(kind: string, name: string): any
	local ok, res = pcall(function()
		if kind == "ordered" then return DataStoreService:GetOrderedDataStore(name) end
		return DataStoreService:GetDataStore(name)
	end)
	if ok and res then return res end
	warnOnce(res)
	return memoryStore()
end

local cache: { [string]: any } = {}
local function cached(kind: string, name: string): any
	local k = kind .. ":" .. name
	if not cache[k] then cache[k] = get(kind, name) end
	return cache[k]
end

function Stores.get(name: string): DataStore return cached("normal", name) end
function Stores.ordered(name: string): OrderedDataStore return cached("ordered", name) end

return Stores
