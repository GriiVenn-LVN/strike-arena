use utf8;
#!/usr/bin/perl
# Convertit les définitions de cartes JS (src/20_maps.js) en module Luau pour Roblox.
# Usage : perl tools/export_maps_lua.pl > roblox/ReplicatedStorage/Shared/MapData.lua
use strict; use warnings;
local $/; my $js=""; for my $fn ("src/20_maps.js","src/21_maps_extra.js"){ open(my $f,"<:utf8",$fn) or die; $js.=<$f>; close $f; }
binmode(STDOUT,":utf8");

sub conv_build {            # corps d'une fonction build() / post()
  my ($b)=@_;
  $b=~s/\/\/[^\n]*//g;                                   # commentaires
  $b=~s/const R=GB\.rect,T=TY,K=T\.CONC,Wl=T\.WALL;/local R,T=GB.rect,TY\n  local K,Wl=T.CONC,T.WALL/;
  $b=~s/const R=GB\.rect,T=TY,K=T\.CONC;/local R,T=GB.rect,TY\n  local K=T.CONC/;
  $b=~s/const R=GB\.rect,T=TY;/local R,T=GB.rect,TY/;
  $b=~s/const R=GB\.rect,T=TY,K=T\.WALL;/local R,T=GB.rect,TY\n  local K=T.WALL/;
  $b=~s/for\(const (\w+) of \[([^\]]*)\]\)([^\n]*)/for _, $1 in ipairs({$2}) do $3 end/g;
  $b=~s/,\)/)/g;                                         # virgule finale
  $b=~s/;\s*(?=\n|$)//g;
  $b=~s/;/ /g;
  return $b;
}
sub conv_val {              # littéraux JS -> Lua
  my ($v)=@_;
  $v=~s/\[/{/g; $v=~s/\]/}/g;
  $v=~s/'([^']*)'/"$1"/g;
  $v=~s/(\w+):/$1=/g;
  return $v;
}

my @maps=('village','warehouse','station','harbor','metro','jungle','range');
print "-- Généré par tools/export_maps_lua.pl depuis le prototype web (src/20_maps.js)\n";
print "-- 1 case = 2 m ; GB reproduit l'API de construction du prototype.\n";
print "local MapData = {}\n\n";
print <<'LUA';
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

LUA

for my $id (@maps){
  $js=~/MAPS\.$id=\{(.*?)\n\};\s*\n/s or die "map $id";
  my $obj=$1;
  my ($theme)=$obj=~/theme:'(\w+)'/;
  my ($name)=$obj=~/\bn:'([^']+)'/;
  $obj=~/build\(\)\{(.*?)\n \},\n sites:/s or die "build $id";
  my $build=conv_build($1);
  print "MapData.$id = {\n\tid = \"$id\", name = \"$name\", theme = \"$theme\",\n";
  for my $k (qw(sites pickups spawnCT spawnT spawnDM holdCT roam arches)){
    if($obj=~/\n $k:(.*?)(?=,\n [a-zA-Z]+:|\n\};?$)/s){ my $v=$1; $v=~s/\s+$//; print "\t$k = ".conv_val($v).",\n"; }
  }
  print "\tbuild = function(GB)\n\t\t$build\n\tend,\n";
  # post
  if($js=~/MAPS\.$id\.post=function\(\)\{(.*?)\n\};/s){ my $p=conv_build($1); print "\tpost = function(GB)\n\t\t$p\n\tend,\n"; }
  print "}\n\n";
}
print <<'LUA';
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
LUA
