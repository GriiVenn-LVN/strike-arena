#!/usr/bin/perl
# Envoie un script Python à Blender (extension « MCP for Blender », port 9876) et affiche la réponse.
# Usage : perl tools/bl.pl script.py      ou      perl tools/bl.pl -c "print(1)"
use strict;use warnings;use IO::Socket::INET;
binmode(STDOUT,':utf8');
my $code;
if(@ARGV&&$ARGV[0] eq "-c"){$code=$ARGV[1];}elsif(@ARGV&&$ARGV[0] eq "-t"){$code="";}
else{local $/;open(my $f,'<:utf8',$ARGV[0]) or die "fichier ?";$code=<$f>;close $f;}
sub js{my $s=shift;$s=~s/\\/\\\\/g;$s=~s/"/\\"/g;$s=~s/\n/\\n/g;$s=~s/\r//g;$s=~s/\t/\\t/g;return $s}
my $msg;
if(@ARGV&&$ARGV[0] eq "-t"){$msg='{"type":"'.$ARGV[1].'","params":'.($ARGV[2]||"{}").'}';}
else{$msg='{"type":"execute_code","params":{"code":"'.js($code).'"}}';}
my $s=IO::Socket::INET->new(PeerAddr=>'127.0.0.1',PeerPort=>9876,Timeout=>10) or die "Blender non joignable (port 9876) : $!";
my $bytes=$msg;utf8::encode($bytes);print $s $bytes;
my $buf='';$s->blocking(1);
while(1){my $d;my $n=sysread($s,$d,65536);last if !$n;$buf.=$d;last if $buf=~/\}\s*$/ && eval{1} && balanced($buf);}
sub balanced{my $t=shift;my $o=()=$t=~/\{/g;my $c=()=$t=~/\}/g;return $o==$c}
utf8::decode($buf);
$buf=~s/\\n/\n/g;$buf=~s/\\"/"/g;
print $buf,"\n";
