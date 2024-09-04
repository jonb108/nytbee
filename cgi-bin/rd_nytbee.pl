#!/usr/bin/env perl
use strict;
use warnings;
use CGI;
my $q = CGI->new();
my $uuid = $q->cookie('uuid');
# redirect to ultrabee.org
print $q->header();
print <<"EOF";
<html>
<head>
<meta http-equiv="refresh" 
      content="0; URL=https://ultrabee.org/cgi-bin/nytbee.pl/ID$uuid" />
</head>
<body>
</body>
</html>
EOF
open my $out, '>>', 'redirects.txt';
print {$out} scalar(localtime), " nytbee\n";
close $out;
