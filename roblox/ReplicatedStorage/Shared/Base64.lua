--!strict
-- ReplicatedStorage/Shared/Base64 (ModuleScript)
-- Décode le base64 des données générées par les outils (armes 3D, peintures des skins) en buffer.
local B64: { [number]: number } = {}
do
	local chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
	for i = 1, #chars do B64[string.byte(chars, i)] = i - 1 end
end

return function(s: string): buffer
	local n = #s
	local pad = (if string.sub(s, -2) == "==" then 2 elseif string.sub(s, -1) == "=" then 1 else 0)
	local out = buffer.create(n // 4 * 3 - pad)
	local len = buffer.len(out)
	local o = 0
	for i = 1, n, 4 do
		local a, b, c, d = string.byte(s, i, i + 3)
		local v = bit32.bor(bit32.lshift(B64[a], 18), bit32.lshift(B64[b], 12), bit32.lshift(B64[c] or 0, 6), B64[d] or 0)
		buffer.writeu8(out, o, bit32.rshift(v, 16)); o += 1
		if o < len then buffer.writeu8(out, o, bit32.band(bit32.rshift(v, 8), 255)); o += 1 end
		if o < len then buffer.writeu8(out, o, bit32.band(v, 255)); o += 1 end
	end
	return out
end
