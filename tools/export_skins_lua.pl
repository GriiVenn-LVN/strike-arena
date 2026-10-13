#!/usr/bin/perl
# Met à jour roblox/ReplicatedStorage/Shared/Config.lua avec les skins et tenues du prototype.
use strict; use warnings; use utf8;
local $/;
sub rd{ open(my $f,"<:utf8",$_[0]) or die "open $_[0]"; my $x=<$f>; close $f; return $x }
sub wr{ open(my $f,">:utf8",$_[0]) or die; print $f $_[1]; close $f }

my $sk=rd("src/44_skins.js"); my $of=rd("src/47_outfits.js");
my (@skins,@outs);
if($sk=~/const SKINS=\[(.*?)\n\];/s){
  for my $l (split /\n/,$1){
    next unless $l=~/\{n:'([^']+)'.*?q:(\d)\}/;
    my ($n,$q)=($1,$2+1); my ($tex)=$l=~/tex:'(\w+)'/; $tex//="";
    push @skins, sprintf("\t{ name = \"%s\", rarity = %d, pattern = \"%s\" },",$n,$q,$tex);
  }
}
if($of=~/const OUTFITS=\[(.*?)\n\];/s){
  for my $l (split /\n/,$1){
    next unless $l=~/\{n:'([^']+)'.*?q:(\d)/;
    my ($n,$q)=($1,$2+1); my ($head)=$l=~/head:'(\w+)'/; $head//="team";
    push @outs, sprintf("\t{ name = \"%s\", rarity = %d, head = \"%s\" },",$n,$q,$head);
  }
}
my $cfg=rd("roblox/ReplicatedStorage/Shared/Config.lua");
my $skblock="Config.SKINS = {                                  -- rarity 1..4 ; rarity 1 = gratuit pour toutes les armes ; pattern = nom de la peinture du prototype\n".join("\n",@skins)."\n}\n\n-- Tenues de soldat (rarity 1 = gratuit)\nConfig.OUTFITS = {\n".join("\n",@outs)."\n}\n";
$cfg=~s/Config\.SKINS = \{.*?\n\}\n(?:\n-- Tenues de soldat.*?\nConfig\.OUTFITS = \{.*?\n\}\n)?/$skblock/s or die "block";
wr("roblox/ReplicatedStorage/Shared/Config.lua",$cfg);
print "skins: ".scalar(@skins)." tenues: ".scalar(@outs)."\n";
