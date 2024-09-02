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
      content="0; URL=https://ultrabee.org/cgi-bin/dynamic.pl" />
</head>
<body>
</body>
</html>
EOF
