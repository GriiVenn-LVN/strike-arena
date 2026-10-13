#!/usr/bin/perl
# Mini serveur HTTP local pour tester le jeu : perl tools/serve.pl 8765  puis http://localhost:8765/
use strict;use warnings;use IO::Socket::INET;
$SIG{PIPE}='IGNORE';$|=1;
my $port=shift||8765;
my $root=$0;$root=~s{[\\/]tools[\\/][^\\/]+$}{};$root='.' if $root eq $0;
my $srv=IO::Socket::INET->new(LocalAddr=>'127.0.0.1',LocalPort=>$port,Listen=>10,ReuseAddr=>1) or die "port $port: $!";
my %mime=(html=>'text/html; charset=utf-8',js=>'application/javascript',css=>'text/css',png=>'image/png',json=>'application/json');
print "Serveur sur http://localhost:$port/\n";
$SIG{CHLD}='IGNORE';
while(1){my $c=$srv->accept or next;my $pid=fork();if(!defined $pid||$pid){close $c if $pid;next if $pid;}
eval{
 my $req=<$c>;die "vide
" unless $req;
 while(my $l=<$c>){last if $l=~/^\r?\n$/;}
 my ($path)=$req=~m{^GET\s+(\S+)};$path//='/';$path=~s/\?.*//;$path='/strike-arena.html' if $path eq '/';
 $path=~s/%20/ /g;$path=~s{\.\.}{}g;
 my $file="$root$path";
 if(-f $file){
  open(my $f,'<:raw',$file);local $/;my $d=<$f>;close $f;
  my ($ext)=$file=~/\.(\w+)$/;
  print $c "HTTP/1.1 200 OK\r\nContent-Type: ".($mime{lc($ext//'')}||'application/octet-stream')."\r\nContent-Length: ".length($d)."\r\nCache-Control: no-store\r\nConnection: close\r\n\r\n".$d;
 }else{print $c "HTTP/1.1 404 Not Found\r\nContent-Length: 9\r\nConnection: close\r\n\r\nnot found";}
 close $c;};
 exit 0 if defined $pid;
}
