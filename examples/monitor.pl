#!/usr/bin/perl -w

use strict;
use Device::LIFX;
use Device::LIFX::Constants;
use Data::Dumper;

my $lifx = Device::LIFX->new();

my $bulb = undef;
while(1) {
    my $msg = $lifx->next_message(1);
    if (defined($msg)) {
        print $msg->type_as_string(),": ";
        my $mac = $msg->bulb_mac();
        $bulb = $lifx->get_bulb_by_mac($mac);
        if (defined($bulb)) {
            print $bulb->label(),"\n";
        } else {
            print "No Bulb ?\n";
        }
    }
    else {
        print "Timeout\n";
    }
}
