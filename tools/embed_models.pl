#!/usr/bin/perl
# Intègre les modèles 3D (models/weapons/*.glb + .json + credits.json) dans un fichier JS
# pour que le jeu marche aussi en double-cliquant sur index.html (sans serveur).
# Usage : perl tools/embed_models.pl > build/models_data.js
use strict; use warnings; use MIME::Base64;
binmode(STDOUT, ':raw');
my $dir = 'models/weapons';
opendir(my $d, $dir) or die "pas de $dir";
my @k = sort map { /^(\w+)\.glb$/ ? $1 : () } readdir($d); closedir $d;
print "/* modèles 3D intégrés — généré par tools/embed_models.pl, ne pas modifier */\n";
print "const GLB_DATA={\n";
for my $k (@k) { open(my $f, '<:raw', "$dir/$k.glb") or die; local $/; my $b = <$f>; close $f; print " $k:'", encode_base64($b, ''), "',\n"; }
print "};\nconst GLB_INFO={\n";
for my $k (@k) { open(my $f, '<:raw', "$dir/$k.json") or next; local $/; my $j = <$f>; close $f; $j =~ s/\s+$//; print " $k:$j,\n"; }
print "};\n";
print "const CHAR_DATA={\n";
if (opendir(my $cd, 'models/characters')) {
  for my $fn (sort grep { /_game\.glb$/ } readdir($cd)) {
    my ($ck) = $fn =~ /^(\w+)_game\.glb$/;
    open(my $cf, '<:raw', "models/characters/$fn") or next; local $/; my $b = <$cf>; close $cf;
    print " $ck:'", encode_base64($b, ''), "',\n";
  }
  closedir $cd;
}
print "};\n";
# modèles réalistes texturés (optionnels) : models/weapons_real/*.glb + .json + credits_real.json
my $rd = 'models/weapons_real';
my @rk = ();
if (opendir(my $r, $rd)) { @rk = sort map { /^(\w+)\.glb$/ ? $1 : () } readdir($r); closedir $r; }
print "const GLB_REAL_DATA={\n";
for my $k (@rk) { open(my $f, '<:raw', "$rd/$k.glb") or die; local $/; my $b = <$f>; close $f; print " $k:'", encode_base64($b, ''), "',\n"; }
print "};\nconst GLB_REAL_INFO={\n";
for my $k (@rk) { open(my $f, '<:raw', "$rd/$k.json") or next; local $/; my $j = <$f>; close $f; $j =~ s/\s+$//; print " $k:$j,\n"; }
print "};\n";
sub readcred { my ($p) = @_; open(my $f, '<:raw', $p) or return ''; local $/; my $c = <$f>; close $f; $c =~ s/^\s*\[//; $c =~ s/\]\s*$//; $c =~ s/^\s+|\s+$//g; return $c; }
my @cr = grep { length } (readcred("$rd/credits_real.json"), readcred("$dir/credits.json"));
print "const GLB_CREDITS=[", join(',', @cr), "];\n";
