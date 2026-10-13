-- Généré par tools/export_maps_lua.pl depuis le prototype web (src/20_maps.js)
-- 1 case = 2 m ; GB reproduit l'API de construction du prototype.
local MapData = {}

local N = 40
local TY = { OPEN = 0, WALL = 1, CRATE = 2, HOUSE = 3, LOW = 4, BARREL = 5, PLAT = 6, CONT = 7, CONC = 8, PILLAR = 9 }
local TYH = { [0] = 0, 6, 2.6, 4.6, 0.9, 1.1, 3, 2.7, 5.4, 6 }
MapData.N, MapData.TY, MapData.TYH = N, TY, TYH

local function newGrid()
	local g = { type = {}, h = {}, ceil = {}, ramp = {}, tag = {}, ramps = {} }
	for i = 0, N * N - 1 do g.type[i] = 0; g.h[i] = 0; g.ceil[i] = 99; g.ramp[i] = 0; g.tag[i] = 0 end
	local GB = {}
	function GB.rect(t, x1, z1, x2, z2, h)
		local hh = h or TYH[t]
		for z = z1, z2 do for x = x1, x2 do
			if x >= 0 and z >= 0 and x < N and z < N then
				local i = z * N + x; g.type[i] = t; g.h[i] = (t == 0) and 0 or hh; g.ramp[i] = 0
			end
		end end
	end
	function GB.clear(x1, z1, x2, z2)
		for z = z1, z2 do for x = x1, x2 do local i = z * N + x; g.type[i] = 0; g.h[i] = 0; g.ramp[i] = 0; g.ceil[i] = 99 end end
	end
	function GB.ramp(x1, z1, x2, z2, axis, hA, hB)
		table.insert(g.ramps, { x1 = x1, z1 = z1, x2 = x2, z2 = z2, axis = axis, hA = hA, hB = hB })
		local id = #g.ramps
		for z = z1, z2 do for x = x1, x2 do local i = z * N + x; g.type[i] = 0; g.ramp[i] = id; g.h[i] = (hA + hB) / 2 end end
	end
	function GB.ceil(x1, z1, x2, z2, h) for z = z1, z2 do for x = x1, x2 do g.ceil[z * N + x] = h end end end
	function GB.tag(x1, z1, x2, z2, t) for z = z1, z2 do for x = x1, x2 do g.tag[z * N + x] = t end end end
	return g, GB
end

MapData.village = {
	id = "village", name = "Village", theme = "sand",
	sites = {{n="A",cx=6,cz=5,r=7},{n="B",cx=33,cz=6,r=7}},
	pickups = {{6,7,"shield"},{33,7,"health"},{20,25,"shield"},{4,20,"health"},{36,21,"shield"},{16,12,"ammo"},{24,12,"health"},{9,34,"shield"},{31,34,"health"},{20,6,"ammo"},{10,18,"shield"}},
	spawnCT = {{15,2},{17,2},{19,2},{21,2},{23,2},{24,3},{16,4},{18,4},{20,4},{22,4}},
	spawnT = {{15,37},{17,37},{19,37},{21,37},{23,37},{24,36},{16,35},{20,36},{22,35},{18,36}},
	spawnDM = {{6,5},{33,5},{3,20},{36,20},{16,22},{24,24},{10,18},{30,18},{6,34},{32,34},{20,12},{3,2},{15,12},{27,14},{9,33},{34,28}},
	holdCT = {{5,7},{34,7},{21,12},{3,2},{15,12},{9,6},{36,8},{27,14}},
	roam = {{6,5},{33,5},{4,20},{36,20},{15,12},{24,13},{22,22},{16,25},{9,18},{30,18},{6,34},{32,34},{20,10},{3,2},{27,14},{5,26},{35,26},{20,24},{18,32},{10,7},{34,8}},
	build = function(GB)
		
  local R,T=GB.rect,TY
  R(T.WALL,0,0,39,0) R(T.WALL,0,39,39,39) R(T.WALL,0,0,0,39) R(T.WALL,39,0,39,39)
  R(T.WALL,13,1,13,2) R(T.WALL,13,5,13,10) R(T.WALL,26,1,26,2) R(T.WALL,26,5,26,10)
  R(T.WALL,13,9,20,10) R(T.WALL,23,9,26,10)
  R(T.CRATE,17,6,17,6) R(T.LOW,22,6,23,6) R(T.BARREL,15,6,15,6)
  R(T.WALL,1,11,1,12) R(T.WALL,6,11,8,12) R(T.WALL,11,11,13,12)
  R(T.PLAT,2,1,5,2,2.4) GB.ramp(6,1,8,2,'x',2.4,0)
  R(T.LOW,4,6,5,6) R(T.LOW,7,4,7,5) R(T.CRATE,8,8,8,8) R(T.CRATE,9,8,9,8) R(T.BARREL,2,9,3,9) R(T.BARREL,10,3,10,3) R(T.BARREL,2,5,2,5)
  R(T.WALL,26,11,28,12) R(T.WALL,31,11,31,12) R(T.WALL,36,11,38,12)
  GB.ceil(31,1,35,4,3.4) R(T.PILLAR,33,3,33,3,3.4)
  R(T.CRATE,29,5,29,6) R(T.CRATE,30,6,30,6) R(T.CRATE,36,7,37,7) R(T.CRATE,37,8,37,8)
  R(T.BARREL,28,9,28,9) R(T.BARREL,38,9,38,9) R(T.BARREL,31,8,31,8) R(T.LOW,33,8,34,8)
  R(T.HOUSE,18,16,21,20)
  R(T.PLAT,14,11,16,13,3.0) GB.ramp(17,11,19,12,'x',3.0,0)
  R(T.PLAT,26,13,28,15,3.0) GB.ramp(23,13,25,14,'x',0,3.0)
  R(T.CRATE,15,24,16,24) R(T.LOW,23,22,24,22) R(T.BARREL,14,26,14,26) R(T.BARREL,25,25,25,25) R(T.BARREL,17,26,17,26)
  R(T.CRATE,22,26,23,26) R(T.LOW,15,18,15,19) R(T.LOW,24,17,24,18) R(T.CRATE,16,14,16,14)
  R(T.HOUSE,7,13,13,28) GB.clear(9,13,10,27) GB.clear(7,20,8,21) GB.clear(11,17,13,18)
  R(T.PLAT,7,23,8,26,2.4) GB.ramp(5,24,6,25,'x',0,2.4)
  R(T.CRATE,10,26,10,26) R(T.BARREL,9,15,9,15) R(T.LOW,10,22,10,22)
  R(T.LOW,3,16,4,16) R(T.CRATE,2,19,2,20) R(T.BARREL,5,22,5,22) R(T.LOW,3,26,4,26) R(T.CRATE,1,14,1,14) R(T.LOW,5,17,5,17) R(T.BARREL,2,24,2,24)
  R(T.HOUSE,26,13,32,28) R(T.PLAT,26,13,28,15,3.0) GB.ramp(23,13,25,14,'x',0,3.0)
  GB.clear(29,13,30,28) GB.clear(26,22,28,23) GB.clear(31,19,32,20)
  GB.ceil(33,17,38,24,3.4) R(T.PILLAR,35,20,35,20,3.4)
  R(T.CRATE,34,14,34,14) R(T.LOW,36,15,37,15) R(T.BARREL,38,27,38,27) R(T.CRATE,33,26,34,26) R(T.LOW,36,22,36,22) R(T.BARREL,29,26,29,26) R(T.CRATE,30,16,30,16)
  R(T.WALL,1,29,1,30) R(T.WALL,6,29,13,30) R(T.WALL,14,29,18,30) R(T.WALL,21,29,26,30) R(T.WALL,27,29,28,30) R(T.WALL,31,29,32,30) R(T.WALL,37,29,38,30)
  R(T.WALL,13,31,13,34) R(T.WALL,13,37,13,38) R(T.WALL,26,31,26,34) R(T.WALL,26,37,26,38)
  R(T.CRATE,18,33,18,34) R(T.CRATE,21,33,21,34) R(T.BARREL,15,36,15,36) R(T.LOW,23,37,24,37)
  R(T.CRATE,3,34,4,34) R(T.CRATE,9,32,9,33) R(T.BARREL,6,36,6,36) R(T.LOW,10,36,11,36) R(T.BARREL,2,31,2,31)
  R(T.CRATE,29,34,30,34) R(T.BARREL,35,32,35,32) R(T.LOW,32,36,33,36) R(T.CRATE,37,35,37,36) R(T.BARREL,28,32,28,32)
  GB.tag(14,11,25,28,1) GB.tag(1,1,12,10,2) GB.tag(27,1,38,10,2) GB.tag(14,1,25,8,3) GB.tag(14,31,25,38,4)
  GB.tag(33,17,38,24,5) GB.tag(31,1,35,4,5)
	end,
	post = function(GB)
		
 GB.clear(2,11,5,12) GB.clear(9,11,10,12) GB.clear(29,11,30,12) GB.clear(32,11,35,12)
 GB.clear(2,29,5,30) GB.clear(19,29,20,30) GB.clear(29,29,30,30) GB.clear(33,29,36,30)
 GB.clear(13,3,13,4) GB.clear(26,3,26,4) GB.clear(21,9,22,10) GB.clear(13,35,13,36) GB.clear(26,35,26,36)
	end,
}

MapData.warehouse = {
	id = "warehouse", name = "Entrepôt", theme = "industrial",
	sites = {{n="A",cx=4,cz=19,r=7},{n="B",cx=33,cz=15,r=7}},
	pickups = {{4,22,"shield"},{33,13,"health"},{20,20,"shield"},{3,6,"health"},{35,6,"shield"},{22,12,"ammo"},{7,34,"health"},{33,34,"shield"},{20,6,"health"},{31,25,"ammo"},{14,28,"shield"}},
	spawnCT = {{15,2},{17,2},{19,2},{21,2},{23,2},{24,3},{16,4},{18,4},{20,4},{22,4}},
	spawnT = {{15,37},{17,37},{19,37},{21,37},{23,37},{24,36},{16,36},{20,36},{22,36},{18,36}},
	spawnDM = {{4,19},{33,15},{3,6},{34,6},{20,22},{14,14},{25,16},{5,34},{34,35},{20,36},{20,6},{36,19},{9,25},{22,29},{13,28},{31,26}},
	holdCT = {{4,20},{32,14},{20,12},{13,11},{36,18},{8,18},{25,12},{3,26}},
	roam = {{4,19},{33,15},{3,6},{34,6},{20,22},{14,14},{25,16},{5,34},{34,35},{20,36},{20,6},{36,19},{9,25},{22,29},{13,28},{31,26},{19,12},{7,30},{35,30},{24,20}},
	build = function(GB)
		
  local R,T=GB.rect,TY
  local K=T.CONC
  R(K,0,0,39,0) R(K,0,39,39,39) R(K,0,0,0,39) R(K,39,0,39,39)
  R(K,13,1,13,2) R(K,13,5,13,10) R(K,26,1,26,2) R(K,26,5,26,10) R(K,13,9,18,10) R(K,21,9,26,10)
  R(T.LOW,16,5,17,5) R(T.LOW,22,5,23,5) R(T.CRATE,15,7,15,7)
  R(K,5,11,12,12) R(K,27,11,33,12)
  R(T.LOW,3,4,6,4) R(T.LOW,3,7,6,7) R(T.CRATE,10,8,10,8) R(T.BARREL,2,9,2,9)
  R(T.LOW,29,4,32,4) R(T.LOW,29,7,32,7) R(T.CRATE,36,3,36,3) R(T.BARREL,37,9,37,9) R(T.CRATE,28,9,28,9)
  R(K,10,11,11,30) GB.clear(10,16,11,18) GB.clear(10,24,11,25)
  R(K,28,11,29,30) GB.clear(28,14,29,16) GB.clear(28,23,29,24)
  R(T.PLAT,12,11,18,12,3.2) R(T.PLAT,21,11,27,12,3.2)
  GB.ramp(12,13,13,15,'z',3.2,0) GB.ramp(26,13,27,15,'z',3.2,0)
  R(T.CRATE,15,11,15,11,3.2+1.2) R(T.CRATE,24,11,24,11,3.2+1.2)
  R(T.CONT,13,17,14,22) R(T.CONT,17,14,18,19,5.4) R(T.CONT,21,17,22,22) R(T.CONT,24,18,27,19)
  R(T.CONT,15,25,20,26) R(T.CONT,23,25,26,26) R(T.CRATE,16,22,16,22) R(T.BARREL,12,24,12,24) R(T.BARREL,27,28,27,28) R(T.CRATE,19,29,20,29) R(T.BARREL,12,13,12,13)
  R(K,12,31,12,32) R(K,16,31,18,32) R(K,21,31,23,32) R(K,27,31,27,32)
  R(K,10,31,11,34) R(K,10,37,11,38) R(K,28,31,29,34) R(K,28,37,29,38)
  R(T.CONT,14,34,16,34) R(T.CONT,23,34,25,34) R(T.CRATE,19,35,20,35) R(T.BARREL,13,37,13,37) R(T.BARREL,26,37,26,37)
  R(T.CRATE,3,15,3,18) R(T.CRATE,6,15,6,18) R(T.CRATE,3,21,3,24) R(T.CRATE,6,21,6,24) R(T.LOW,8,19,8,20) R(T.BARREL,1,14,1,14) R(T.BARREL,9,14,9,14) R(T.BARREL,9,26,9,26) R(T.CRATE,1,26,2,26)
  GB.ceil(1,27,9,32,3.4) R(T.PILLAR,5,29,5,29,3.4) R(T.CRATE,2,31,2,31) R(T.CRATE,8,28,8,28) R(T.LOW,3,34,5,34) R(T.CRATE,8,36,8,36) R(T.BARREL,2,37,2,37)
  R(T.PLAT,34,16,38,21,3.0) GB.ramp(34,22,36,24,'z',3.0,0)
  R(T.CRATE,36,17,37,17,3.0+1.2) R(T.LOW,34,16,34,16,3.0+.9)
  R(T.CRATE,31,15,31,16) R(T.CRATE,31,20,32,20) R(T.BARREL,30,13,30,13) R(T.BARREL,38,13,38,13) R(T.LOW,32,17,32,18) R(T.CRATE,37,26,37,27) R(T.BARREL,31,25,31,25)
  GB.ceil(31,29,38,32,3.4) R(T.PILLAR,34,31,34,31,3.4) R(T.CRATE,37,31,37,31) R(T.LOW,31,34,33,34) R(T.CRATE,36,36,36,36) R(T.BARREL,30,37,30,37)
  R(K,27,29,30,30) R(K,34,29,38,30)
  GB.tag(12,11,27,30,1) GB.tag(14,1,25,8,2) GB.tag(1,1,12,10,2) GB.tag(27,1,38,10,2) GB.tag(1,13,9,26,3) GB.tag(30,11,38,28,4) GB.tag(12,33,27,38,5) GB.tag(1,27,9,38,6) GB.tag(30,31,38,38,6)
	end,
	post = function(GB)
		
 
 GB.clear(31,29,33,30)
 GB.clear(10,35,11,36) GB.clear(28,35,29,36)
 GB.clear(1,11,4,12)
 GB.clear(34,11,38,12)
	end,
}

MapData.station = {
	id = "station", name = "Station polaire", theme = "snow",
	sites = {{n="A",cx=6,cz=7,r=7},{n="B",cx=32,cz=8,r=7}},
	pickups = {{6,8,"shield"},{32,9,"health"},{19,18,"shield"},{5,20,"health"},{35,22,"shield"},{18,13,"ammo"},{22,24,"health"},{7,34,"shield"},{32,34,"health"},{20,5,"ammo"},{8,16,"shield"}},
	spawnCT = {{15,2},{17,2},{19,3},{21,2},{23,2},{24,3},{16,5},{18,5},{22,5},{20,4}},
	spawnT = {{15,37},{17,37},{19,37},{21,37},{23,37},{24,36},{16,36},{20,36},{22,36},{18,36}},
	spawnDM = {{6,7},{32,8},{5,20},{35,22},{19,18},{22,24},{8,17},{31,17},{7,34},{33,34},{20,5},{2,5},{2,17},{37,8},{16,28},{24,16}},
	holdCT = {{6,9},{31,9},{19,12},{2,9},{37,8},{9,5},{30,6},{20,15}},
	roam = {{6,7},{32,8},{5,20},{35,22},{19,18},{22,24},{8,17},{31,17},{7,34},{33,34},{20,5},{2,17},{37,8},{16,28},{24,16},{4,26},{34,28},{19,12},{10,5},{30,5}},
	build = function(GB)
		
  local R,T=GB.rect,TY
  local K,Wl=T.CONC,T.WALL
  R(Wl,0,0,39,0) R(Wl,0,39,39,39) R(Wl,0,0,0,39) R(Wl,39,0,39,39)
  R(T.PLAT,14,1,25,6,1.5)
  R(K,13,1,13,2) R(K,13,5,13,8) R(K,26,1,26,2) R(K,26,5,26,8)
  R(T.LOW,14,7,18,7,2.4) R(T.LOW,21,7,25,7,2.4)
  R(T.CRATE,17,3,17,3,1.5+1.3) R(T.CRATE,22,3,22,3,1.5+1.3) R(T.LOW,19,2,20,2,1.5+.9)
  GB.ramp(19,7,20,9,'z',1.5,0) GB.ramp(11,3,13,4,'x',0,1.5) GB.ramp(26,3,28,4,'x',1.5,0)
  R(Wl,11,1,12,2) R(Wl,11,5,12,12)
  R(K,1,13,1,14) R(K,5,13,7,14) R(K,10,13,12,14)
  R(T.CONT,2,2,5,3) R(T.CONT,8,2,9,5) R(T.LOW,3,6,5,6) R(T.CRATE,2,10,3,10) R(T.BARREL,9,9,9,9) R(T.BARREL,10,12,10,12) R(T.CRATE,6,11,6,11)
  R(T.PLAT,1,8,3,11,2.4) GB.ramp(4,9,6,10,'x',2.4,0) R(T.LOW,1,8,1,8,2.4+.9)
  R(Wl,27,1,28,2) R(Wl,27,5,28,12)
  R(K,27,13,28,14) R(K,31,13,33,14) R(K,37,13,38,14)
  GB.ceil(33,1,38,5,3.4) R(T.CONT,34,2,35,3) R(T.PILLAR,37,4,37,4,3.4) R(T.BARREL,36,2,36,2) R(T.BARREL,38,2,38,2)
  R(T.PLAT,36,7,38,10,3.0) GB.ramp(33,8,35,9,'x',0,3.0) R(T.CRATE,37,8,37,8,3.0+1.3)
  R(T.LOW,30,7,30,8) R(T.BARREL,29,11,29,11) R(T.BARREL,29,6,29,6) R(T.CRATE,31,11,31,11) R(T.LOW,32,5,32,5)
  R(T.HOUSE,12,15,15,19) R(T.HOUSE,24,15,27,19) R(T.HOUSE,12,26,15,30) R(T.HOUSE,24,26,27,30)
  R(Wl,11,15,11,30) GB.clear(11,21,11,23) R(Wl,28,15,28,30) GB.clear(28,21,28,23)
  R(T.CONT,18,21,21,22) R(T.CRATE,16,17,16,17) R(T.CRATE,23,28,23,28) R(T.LOW,17,25,19,25) R(T.LOW,21,18,23,18) R(T.BARREL,14,23,14,23) R(T.BARREL,25,23,25,23) R(T.LOW,16,28,17,28) R(T.CRATE,21,16,22,16)
  R(T.PLAT,1,16,3,18,3.0) GB.ramp(4,16,6,17,'x',3.0,0)
  R(T.LOW,5,20,5,22) R(T.CRATE,2,22,3,22) R(T.BARREL,8,25,8,25) R(T.LOW,4,26,6,26) R(T.CRATE,9,17,9,17) R(T.LOW,8,29,9,29) R(T.BARREL,2,28,2,28)
  GB.ceil(31,20,38,26,3.4) R(T.PILLAR,34,23,34,23,3.4) R(T.CONT,36,16,37,17) R(T.LOW,31,17,32,17) R(T.CRATE,35,28,36,28) R(T.BARREL,30,19,30,19) R(T.LOW,36,22,36,22) R(T.CRATE,31,24,31,24) R(T.BARREL,38,26,38,26)
  R(K,11,31,13,32) R(K,16,31,18,32) R(K,21,31,23,32) R(K,26,31,28,32)
  R(K,13,33,13,34) R(K,13,37,13,38) R(K,26,33,26,34) R(K,26,37,26,38)
  R(T.CONT,16,34,17,34) R(T.CONT,22,34,23,34) R(T.CRATE,19,35,20,35) R(T.BARREL,15,37,15,37) R(T.BARREL,24,37,24,37)
  R(T.CRATE,3,34,4,34) R(T.LOW,7,36,9,36) R(T.BARREL,2,31,2,31) R(T.CRATE,9,32,9,33) R(T.CRATE,29,34,30,34) R(T.LOW,33,36,35,36) R(T.BARREL,36,32,36,32) R(T.CRATE,38,35,38,36)
  GB.tag(14,1,25,6,4) GB.tag(1,1,10,12,3) GB.tag(29,1,38,12,3) GB.tag(16,19,23,25,2) GB.tag(14,33,25,38,5) GB.tag(31,20,38,26,1) GB.tag(11,15,28,30,0)
	end,
	post = function(GB)
		
 GB.clear(2,13,4,14) GB.clear(8,13,9,14) GB.clear(29,13,30,14) GB.clear(34,13,36,14)
 GB.clear(14,31,15,32) GB.clear(19,31,20,32) GB.clear(24,31,25,32) GB.clear(13,35,13,36) GB.clear(26,35,26,36)
	end,
}

MapData.harbor = {
	id = "harbor", name = "Port de nuit", theme = "night",
	sites = {{n="A",cx=7,cz=4,r=7},{n="B",cx=33,cz=8,r=7}},
	pickups = {{7,6,"shield"},{33,7,"health"},{20,25,"shield"},{4,22,"health"},{35,22,"shield"},{20,10,"ammo"},{24,13,"health"},{8,34,"shield"},{31,34,"health"},{20,5,"ammo"}},
	spawnCT = STD_CT,spawnT=STD_T,
	spawnDM = {{7,4},{33,8},{4,20},{35,20},{20,12},{16,24},{22,24},{6,34},{32,34},{3,6},{36,3},{19,19},{24,11},{9,33},{30,30},{12,10}},
	holdCT = {{7,6},{33,9},{20,12},{3,6},{24,11},{9,6},{36,3},{16,10}},
	roam = {{7,4},{33,8},{4,20},{35,20},{20,12},{16,24},{22,24},{6,34},{32,34},{3,6},{36,3},{19,19},{24,11},{9,33},{30,30},{12,10},{20,26},{5,27},{36,27}},
	build = function(GB)
		
  local R,T=GB.rect,TY
  local K=T.CONC
  R(K,0,0,39,0) R(K,0,39,39,39) R(K,0,0,0,39) R(K,39,0,39,39)
  R(K,13,1,13,2) R(K,13,5,13,8) R(K,26,1,26,2) R(K,26,5,26,8) R(K,13,7,15,8) R(K,18,7,21,8) R(K,24,7,26,8)
  R(T.CRATE,15,3,15,3) R(T.CRATE,24,4,24,4) R(T.LOW,19,5,20,5)
  R(K,1,11,3,12) R(K,8,11,12,12) R(K,13,9,13,12)
  R(T.CONT,2,2,5,3) R(T.PLAT,2,5,5,8,2.7) GB.ramp(6,6,8,7,'x',2.7,0)
  R(T.CRATE,9,3,9,4) R(T.BARREL,10,8,10,8) R(T.CRATE,7,10,7,10) R(T.BARREL,11,5,11,5) R(T.LOW,3,10,5,10)
  R(K,26,11,29,12) R(K,34,11,38,12) R(K,26,9,26,12)
  GB.ceil(28,1,38,8,3.6) R(T.CRATE,30,2,30,5) R(T.CRATE,33,2,33,5) R(T.CRATE,36,2,36,5) R(T.BARREL,29,7,29,7) R(T.CRATE,35,8,36,8)
  R(T.LOW,31,9,32,9) R(T.BARREL,37,10,37,10)
  R(T.CONT,15,13,16,18) R(T.CONT,23,13,24,18) R(T.CONT,18,21,21,22) R(T.CRATE,19,16,20,16) R(T.BARREL,14,24,14,24) R(T.CRATE,24,25,25,25) R(T.LOW,16,26,18,26) R(T.CRATE,21,26,21,27)
  R(T.PLAT,23,10,25,12,2.7) GB.ramp(21,10,22,11,'x',0,2.7)
  R(K,9,13,13,28) GB.clear(9,19,13,20) GB.clear(9,24,13,25)
  R(K,26,13,30,28) GB.clear(26,19,30,20) GB.clear(26,24,30,25)
  R(T.CONT,2,16,3,21) R(T.CRATE,5,15,6,15) R(T.LOW,5,22,6,22) R(T.BARREL,7,19,7,19) R(T.CRATE,2,25,3,25) R(T.LOW,6,27,7,27)
  GB.ceil(31,20,38,26,3.4) R(T.PILLAR,34,23,34,23,3.4) R(T.CONT,36,14,37,17) R(T.CRATE,31,15,32,15) R(T.LOW,33,18,33,18) R(T.BARREL,38,28,38,28) R(T.CRATE,34,27,35,27)
  R(K,1,29,1,30) R(K,6,29,18,30) R(K,21,29,32,30) R(K,37,29,38,30)
  R(K,13,31,13,34) R(K,13,37,13,38) R(K,26,31,26,34) R(K,26,37,26,38) R(T.CONT,16,34,17,34) R(T.CONT,22,34,23,34) R(T.CRATE,19,35,20,35)
  R(T.CONT,3,33,6,34) R(T.CRATE,9,36,9,36) R(T.BARREL,2,37,2,37) R(T.CRATE,29,33,30,33) R(T.CONT,33,35,36,36) R(T.BARREL,38,32,38,32)
  GB.tag(14,9,25,28,1) GB.tag(14,1,25,6,2) GB.tag(1,1,12,10,3) GB.tag(27,1,38,10,4) GB.tag(14,31,25,38,5) GB.tag(1,13,8,30,6) GB.tag(31,13,38,30,6)
	end,
}

MapData.metro = {
	id = "metro", name = "Métro", theme = "metro",
	sites = {{n="A",cx=6,cz=20,r=7},{n="B",cx=33,cz=20,r=7}},
	pickups = {{6,22,"shield"},{33,22,"health"},{20,12,"shield"},{20,26,"health"},{4,8,"ammo"},{35,8,"shield"},{5,34,"health"},{34,34,"shield"},{20,5,"ammo"},{20,21,"health"}},
	spawnCT = STD_CT,spawnT=STD_T,
	spawnDM = {{6,20},{33,20},{5,5},{34,5},{19,12},{19,26},{5,34},{34,34},{20,22},{3,13},{36,13},{8,27},{31,27},{20,5},{20,36},{10,10}},
	holdCT = {{6,22},{33,22},{19,12},{4,6},{35,6},{22,12},{10,14},{30,14}},
	roam = {{6,20},{33,20},{5,5},{34,5},{19,12},{19,26},{5,34},{34,34},{20,22},{3,13},{36,13},{8,27},{31,27},{20,5},{20,36},{10,10},{28,10},{11,30}},
	build = function(GB)
		
  local R,T=GB.rect,TY
  local K=T.CONC
  GB.ceil(1,1,38,38,4.4)
  R(K,0,0,39,0) R(K,0,39,39,39) R(K,0,0,0,39) R(K,39,0,39,39)
  R(K,13,1,13,2) R(K,13,5,13,8) R(K,26,1,26,2) R(K,26,5,26,8) R(K,14,8,18,8) R(K,21,8,25,8) GB.ramp(19,8,20,9,'z',0,1.2)
  R(T.LOW,16,4,17,4) R(T.LOW,22,4,23,4) R(T.CRATE,15,6,15,6)
  R(T.PLAT,13,10,26,15,1.2) R(T.PLAT,13,23,26,28,1.2)
  GB.ramp(11,11,12,12,'x',0,1.2) GB.ramp(27,11,28,12,'x',1.2,0) GB.ramp(11,24,12,25,'x',0,1.2) GB.ramp(27,24,28,25,'x',1.2,0) GB.ramp(19,29,20,30,'z',1.2,0)
  R(T.PILLAR,17,12,17,12,4.4) R(T.PILLAR,22,12,22,12,4.4) R(T.PILLAR,17,26,17,26,4.4) R(T.PILLAR,22,26,22,26,4.4)
  R(T.CONT,14,18,18,20) R(T.CONT,20,18,24,20) R(T.LOW,15,16,16,16) R(T.LOW,23,22,24,22)
  R(K,13,29,18,30) R(K,21,29,26,30)
  R(K,11,9,12,10) R(K,11,13,12,23) R(K,11,26,12,30) R(K,27,9,28,10) R(K,27,13,28,23) R(K,27,26,28,30)
  R(T.LOW,3,12,6,12) R(T.LOW,3,26,6,26) R(K,2,16,4,18,3.0) R(T.PILLAR,7,15,7,15,4.4) R(T.PILLAR,7,25,7,25,4.4) R(T.PILLAR,9,20,9,20,4.4) R(T.CRATE,8,12,8,12) R(T.CRATE,2,22,3,22) R(T.BARREL,9,28,9,28)
  R(T.CRATE,3,3,4,3) R(T.BARREL,8,5,8,5) R(T.LOW,6,7,10,7) R(T.CRATE,10,2,10,2)
  R(T.CRATE,3,33,4,33) R(T.LOW,8,35,10,35) R(T.BARREL,2,37,2,37)
  R(T.CONT,31,13,32,16) R(T.CONT,35,24,36,27) R(T.PILLAR,31,20,31,20,4.4) R(T.PILLAR,36,20,36,20,4.4) R(T.PILLAR,33,28,33,28,4.4) R(T.CRATE,37,12,37,12) R(T.CRATE,29,22,29,23) R(T.LOW,33,24,34,24)
  R(T.CRATE,30,3,31,3) R(T.CRATE,35,5,36,6) R(T.LOW,28,7,31,7) R(T.BARREL,37,2,37,2)
  R(T.CRATE,35,33,36,33) R(T.LOW,30,35,32,35) R(T.BARREL,38,37,38,37)
  R(K,13,31,13,34) R(K,13,37,13,38) R(K,26,31,26,34) R(K,26,37,26,38) R(T.CRATE,17,33,18,33) R(T.CRATE,21,33,22,33) R(T.LOW,15,36,15,36)
  GB.tag(13,10,26,15,1) GB.tag(13,23,26,28,1) GB.tag(14,1,25,8,2) GB.tag(1,1,12,30,3) GB.tag(27,1,38,30,4) GB.tag(14,31,25,38,5) GB.tag(13,16,26,22,6)
	end,
}

MapData.jungle = {
	id = "jungle", name = "Temple perdu", theme = "jungle",
	sites = {{n="A",cx=7,cz=8,r=7},{n="B",cx=33,cz=8,r=7}},
	pickups = {{7,7,"shield"},{33,7,"health"},{20,19,"shield"},{4,22,"health"},{35,22,"shield"},{20,10,"ammo"},{11,24,"health"},{28,24,"ammo"},{8,34,"shield"},{31,34,"health"}},
	spawnCT = STD_CT,spawnT=STD_T,
	spawnDM = {{7,8},{33,8},{4,20},{35,20},{20,19},{11,22},{28,22},{6,34},{32,34},{3,5},{36,4},{20,10},{19,26},{9,14},{30,15},{20,5}},
	holdCT = {{7,9},{33,9},{20,11},{3,6},{36,6},{11,13},{28,13},{20,10}},
	roam = {{7,8},{33,8},{4,20},{35,20},{20,19},{11,22},{28,22},{6,34},{32,34},{3,5},{36,4},{20,10},{19,26},{9,14},{30,15},{20,5},{12,30},{27,30}},
	build = function(GB)
		
  local R,T=GB.rect,TY
  local K=T.WALL
  R(K,0,0,39,0) R(K,0,39,39,39) R(K,0,0,0,39) R(K,39,0,39,39)
  R(K,13,1,13,2) R(K,13,5,13,8) R(K,26,1,26,2) R(K,26,5,26,8) R(K,13,7,18,8) R(K,21,7,26,8)
  R(T.PILLAR,16,3,16,3,3.2) R(T.PILLAR,23,3,23,3,3.2) R(T.LOW,18,5,21,5)
  R(K,1,11,4,12) R(K,9,11,13,12) R(K,13,9,13,12)
  R(T.PLAT,2,2,5,4,1.5) GB.ramp(6,3,7,4,'x',1.5,0) R(T.PILLAR,3,8,3,8,2.5) R(T.PILLAR,8,6,8,6,2.5) R(T.CRATE,9,3,10,3) R(T.LOW,3,6,5,6) R(T.CRATE,10,9,10,9)
  R(K,26,11,29,12) R(K,34,11,38,12) R(K,26,9,26,12)
  GB.ceil(31,1,38,5,3.8) R(T.PILLAR,34,3,34,3,3.8) R(T.PILLAR,37,3,37,3,3.8) R(T.PLAT,32,1,33,2,1.2)
  R(T.CRATE,29,5,29,6) R(T.LOW,30,8,32,8) R(T.CRATE,36,8,37,8) R(T.PILLAR,28,9,28,9,2.5)
  R(T.PLAT,15,14,24,23,1.2) R(T.PLAT,16,15,23,22,2.4) R(T.PLAT,17,16,22,21,3.6)
  GB.ramp(19,12,20,13,'z',0,1.2) GB.ramp(19,14,20,14,'z',1.2,2.4) GB.ramp(19,15,20,15,'z',2.4,3.6)
  GB.ramp(19,22,20,22,'z',3.6,2.4) GB.ramp(19,23,20,23,'z',2.4,1.2) GB.ramp(19,24,20,25,'z',1.2,0)
  GB.ramp(23,18,23,19,'x',3.6,2.4) GB.ramp(24,18,24,19,'x',2.4,1.2) GB.ramp(25,18,26,19,'x',1.2,0)
  GB.ramp(16,18,16,19,'x',2.4,3.6) GB.ramp(15,18,15,19,'x',1.2,2.4) GB.ramp(13,18,14,19,'x',0,1.2)
  R(K,5,17,8,18) R(K,2,23,6,24) R(K,9,26,12,27) R(K,31,17,34,18) R(K,33,23,37,24) R(K,27,26,30,27)
  R(T.CRATE,3,15,3,15) R(T.LOW,9,20,10,21) R(T.PILLAR,6,29,6,29,2.5) R(T.CRATE,36,14,36,15) R(T.LOW,29,21,30,22) R(T.PILLAR,33,29,33,29,2.5) R(T.CRATE,12,10,12,10) R(T.CRATE,27,10,27,10)
  R(K,1,29,1,30) R(K,6,29,18,30) R(K,21,29,32,30) R(K,37,29,38,30)
  R(K,13,31,13,34) R(K,13,37,13,38) R(K,26,31,26,34) R(K,26,37,26,38) R(T.CRATE,17,33,18,33) R(T.CRATE,21,33,22,33) R(T.LOW,15,36,15,36)
  R(T.CRATE,3,33,4,34) R(T.LOW,8,36,10,36) R(T.CRATE,29,33,30,34) R(T.LOW,33,36,35,36) R(T.PILLAR,2,37,2,37,2.5) R(T.PILLAR,37,37,37,37,2.5)
  GB.tag(15,14,24,23,1) GB.tag(14,1,25,8,2) GB.tag(1,1,12,10,3) GB.tag(27,1,38,10,4) GB.tag(14,31,25,38,5)
	end,
}

MapData.range = {
	id = "range", name = "Stand de tir", theme = "range",
	sites = {{n="A",cx=8,cz=10,r=6},{n="B",cx=32,cz=10,r=6}},
	pickups = {{20,32,"ammo"},{10,34,"shield"}},
	spawnCT = {{18,36},{20,36},{22,36},{16,36},{24,36},{14,36},{26,36},{19,34},{21,34},{23,34}},
	spawnT = {{18,36},{20,36},{22,36},{16,36},{24,36},{14,36},{26,36},{19,34},{21,34},{23,34}},
	spawnDM = {{20,36},{10,36},{30,35},{4,34},{18,34}},
	holdCT = {{20,34}},
	roam = {{20,20},{10,10},{30,10},{20,34}},
	build = function(GB)
		
  local R,T=GB.rect,TY
  local K=T.CONC
  R(K,0,0,39,0) R(K,0,39,39,39) R(K,0,0,0,39) R(K,39,0,39,39) R(K,1,1,38,2)
  for _, x in ipairs({8,16,24,32}) do R(T.LOW,x,9,x,28)  end
  R(T.CRATE,5,18,6,18) R(T.CRATE,13,22,14,22) R(T.CRATE,21,14,22,14) R(T.CRATE,29,20,30,20) R(T.BARREL,36,26,36,26) R(T.BARREL,2,12,2,12)
  R(T.PLAT,2,32,6,37,2.4) GB.ramp(7,34,8,35,'x',2.4,0)
  R(T.PLAT,30,33,37,37,1.2) GB.ramp(28,34,29,35,'x',0,1.2)
  R(T.LOW,12,31,27,31)
  GB.tag(1,3,38,30,1) GB.tag(1,32,38,38,3)
	end,
}

-- Construit la grille d'une carte
function MapData.buildGrid(id)
	local m = MapData[id]
	local g, GB = newGrid()
	m.build(GB)
	if m.post then m.post(GB) end
	g.map = m
	return g
end

return MapData
