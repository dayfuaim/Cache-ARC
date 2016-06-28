#!/usr/bin/env perl
use strict;
use warnings;

use FindBin qw/$RealBin/;
use lib $RealBin.'./lib';

use Cache::ARC;
use Time::HiRes qw/time/;

$|++;

# my $statm = statm();
my $time = time();
my $cache = Cache::ARC->new(2000);
my $hits = 0;
my $count = 0;
while (<STDIN>) {
    # chomp;
    $count++;
    # last if $count++==200000;
    if ($cache->get($_)) {
        $hits++;
    }
    else {
        $cache->set($_, ($_ x 2));
    }
    # print "$count... " if $count % 1000 == 0;
}

# $statm = statm() - $statm;
$time = time() - $time;
printf "worked out %d keys\n", $count;
printf "\thit rate:\t%0.3f %%\n", (100*$hits/$count);
# printf "\tmemory:\t\t%0.3f Mb\n", ($statm/1024/1024);
printf "\ttime:\t\t%0.3f s\n", ($time);

sub statm {
    my $pages = (join('', `cat /proc/$$/statm`) =~ /^\d+\s+(\d+)/)[0];
    my $page_size = (join('', `getconf PAGESIZE`) =~ /^(\d+)/)[0];
    return $pages*$page_size;
}
