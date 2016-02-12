#!/usr/bin/perl

use strict;
use warnings;

my $pre_filename = "topo_update-pre.sql";
my $cmd = "perl topo_common-pre.pl $pre_filename";

print "\nStart $cmd \n";
#system "$cmd" ;
print "\nDone $cmd \n";
