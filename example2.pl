#!/usr/bin/perl -w

use strict;
use Device::LIFX;
use Device::LIFX::Constants;
use Data::Dumper;

my $lifx = Device::LIFX->new();

($#ARGV == 0) || die "Usage: $0 <label>";

my $bulb = undef;
while(!defined($bulb)) {
    my $msg = $lifx->next_message(1);
    $bulb   = $lifx->get_bulb_by_label($ARGV[0]);
}

my $now = $bulb->color();

my @night = (0,0,5,2500);
print "Going to 2500K at 5% brightness over 5 seconds\n";
$bulb->color(\@night,5);
sleep(6);

my @day = (0,0,100,6500);
print "Going to 6500K at 100% brightness over 10 seconds\n";
$bulb->color(\@day,10);
sleep(11);

print "Restoring bulb to the original state\n";
$bulb->color($now,0);
