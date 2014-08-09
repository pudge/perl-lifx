#!/usr/bin/perl -w


use strict;
use IO::Socket;
use strict;
use Data::Dumper;
use IO::Select;

my $port = 56700;

my $GET_PAN_GATEWAY = 0x02;
my $PAN_GATEWAY = 0x03;
my $GET_POWER_STATE = 0x14;
my $SET_POWER_STATE = 0x15;
my $POWER_STATE = 0x16;
my $GET_WIFI_INFO = 0x10;
my $WIFI_INFO = 0x11;
my $GET_WIFI_FIRMWARE_STATE = 0x12;
my $WIFI_FIRMWARE_STATE = 0x13;
my $GET_WIFI_STATE = 0x12D;
my $SET_WIFI_STATE = 0x12E;
my $WIFI_STATE = 0x12F;
my $GET_ACCESS_POINTS = 0x130;
my $SET_ACCESS_POINT = 0x131;
my $ACCESS_POINT = 0x132;
my $GET_BULB_LABEL = 0x17;
my $SET_BULB_LABEL = 0x18;
my $BULB_LABEL = 0x19;
my $GET_TAGS = 0x1A;
my $SET_TAGS = 0x1B;
my $TAGS = 0x1C;
my $GET_TAG_LABELS = 0x1D;
my $SET_TAG_LABELS = 0x1E;
my $TAG_LABELS = 0x1F;
my $GET_LIGHT_STATE = 0x65;
my $SET_LIGHT_COLOR = 0x66;
my $SET_WAVEFORM = 0x67;
my $SET_DIM_ABSOLUTE = 0x68;
my $SET_DIM_RELATIVE = 0x69;
my $LIGHT_STATUS = 0x6B;
my $GET_TIME = 0x04;
my $SET_TIME = 0x05;
my $TIME_STATE = 0x06;
my $GET_RESET_SWITCH = 0x07;
my $RESET_SWITCH_STATE = 0x08;
my $GET_DUMMY_LOAD = 0x09;
my $SET_DUMMY_LOAD = 0x0A;
my $DUMMY_LOAD = 0x0B;
my $GET_MESH_INFO = 0x0C;
my $MESH_INFO = 0x0D;
my $GET_MESH_FIRMWARE = 0x0E;
my $MESH_FIRMWARE_STATE = 0x0F;
my $GET_VERSION = 0x20;
my $VERSION_STATE = 0x21;
my $GET_INFO = 0x22;
my $INFO = 0x23;
my $GET_MCU_RAIL_VOLTAGE = 0x24;
my $MCU_RAIL_VOLTAGE = 0x25;
my $REBOOT = 0x26;
my $SET_FACTORY_TEST_MODE = 0x27;
my $DISABLE_FACTORY_TEST_MODE = 0x28;

# $Data::Dumper::Indent = 0;

=begin
header
{
0 0,1  uint16 size;              // LE
1 2,3  uint16 protocol;
2 4,7  uint32 reserved1;         // Always 0x0000
3 8,13  byte   target_mac_address[6];
4 14,15  uint16 reserved2;         // Always 0x00
5 16,21  byte   site[6];           // MAC address of gateway PAN controller bulb
6 22,23  uint16 reserved3;         // Always 0x00
7 24,31  uint64 timestamp;
8 32,33  uint16 packet_type;       // LE
9 34,35  uint16 reserved4;         // Always 0x0000
}

=cut

my $socket = IO::Socket::INET->new(Proto=>'udp', LocalPort=>$port) ||
                 die "Could not create listen socket: $!\n";

autoflush $socket 1;

my $msg = {
    size => 0x00,
    protocol => 0x1400,
    reserved1 => 0x00,
    target_mac_address => 0x000000,
    reserved2 => 0x00,
    site => 'LIFXV2',
    reserved3 => 0x01,
    timestamp => 0x00,
    packet_type => 0x00,
    reserved4 => 0x00,
};


sub packHeader($)
{
    my ($header) = @_;

    my @header = (
        $header->{size},
        $header->{protocol},
        $header->{reserved1},
        $header->{target_mac_address},
        $header->{reserved2},
        $header->{site},
        $header->{reserved3},
        $header->{timestamp},
        $header->{packet_type},
        $header->{reserved4},
    );
    my $packed = pack('SSLa6Sa6SQvS', @header);
}

# 26 00
# 00 54
# 00 00 00 00
# d0 73 d5 01 0f e0
# 00 00
# 4c 49 46 58 56 32
# 00 00
# 00 00 00 00 00 00 00 00
# 15 00
# 00 00
# 00 00

sub tellBulb($$$$)
{
    my ($mac, $gateway, $type, $payload) = @_;

    my ($port, $iaddr) = sockaddr_in($gateway);
    my $from_str = inet_ntoa($iaddr);

print "Telling: $from_str:$port\n";

    $msg->{size} = 36+length($payload),
    $msg->{target_mac_address}  = $mac,
    $msg->{packet_type} = $type;

    my $header = packHeader($msg);
    my $packet = $header.$payload;

my @packet = unpack('C*', $packet);
print "\nTELL: ";
printPacket(@packet);
$socket->send($packet, 0, $gateway);

sleep(4);
}


my %byLabel;
my %byMAC;

sub setBulbPower($$)
{
    my ($bulb,$on);
    my $header;

    $header->{packet_type} = 0x15;
    my $onoff  = pack('S',$on);

    send($socket,0,1);
}

sub MAC2Str($)
{
    my @mac = unpack('C6',$_[0]);
    @mac = map {sprintf("%02x",$_)} @mac;
    return join(':', @mac);
}

sub getHeader($)
{
    my ($header) = @_;

    my @header = unpack('SSLa6Sa6SQSS', $header);
    $header = {
        size               => $header[0],
        protocol           => $header[1],
        reserved1          => $header[2],
        target_mac_address => $header[3],
        reserved2          => $header[4],
        site               => $header[5],
        reserved3          => $header[6],
        timestamp          => $header[7],
        packet_type        => $header[8],
        reserved4          => $header[9],
    };
    return $header;
}

sub getLightStatus($)
{
    my ($payload) = @_;

    my @payload = unpack('SSSSSSA32Q',$payload);
    my $bulb = {
        "hue"        => $payload[0],
        "saturation" => $payload[1],
        "brightness" => $payload[2],
        "kelvin"     => $payload[3],
        "dim"        => $payload[4],
        "power"      => $payload[5],
        "label"      => $payload[6],
        "tags"       => $payload[7],
    };
    $bulb->{label} =~ s/\s+$//;

    return $bulb;
}

sub decodePacket($$)
{
    my ($from,$packet) = @_;

    my ($port, $iaddr) = sockaddr_in($from);
    my $from_str = inet_ntoa($iaddr);

    my @header = unpack('SSLa6Sa6SQSS', $packet);

    my $header = getHeader($packet);
    my $type   = $header->{packet_type};
    my $mac    = $header->{target_mac_address};

    my $decoded->{header} = $header;

    # print "$from_str ".MAC2Str($mac)." ";

    if ($type == 0x02) {
        print "Get PAN gateway\n";
    }
    elsif ($type == 0x03) {
        print "PAN gateway\n";
        my ($service,$port) = unpack('aL', substr($packet,36));
        print "$service $port\n";
    }
    elsif ($type == 0x06) {
        print "Bulb Time\n";
        my $time = unpack('Q', substr($packet,36,8));
        print "$time\n";
    }
    elsif ($type == 0x16) {
        print "Power State\n";
        my $onoff = unpack('S', substr($packet,36,2));
        if ($onoff == 0x0000) {
            print "OFF\n";
        } elsif ($onoff == 0xffff) {
            print "ON\n";
        }
        else {
            print "?\n";
        }
    }
    elsif ($type == 0x1f) {
        print "Tag Labels\n";
        my ($tags, $label) = unpack('Qa*', substr($packet,36));
    }
    elsif ($type == 0x6b) {
        my $status = getLightStatus(substr($packet,36));
        my $header = getHeader($packet);
        my $label  = $status->{label};
        $byMAC{$mac} = $header;
        $byLabel{$label} = $header;

        if ($label eq 'Study') {
            my $payload;

            $payload = pack('C(SSSSL)<', (0,0xaaaa,0x8888,0x00,0x00,1000));
            tellBulb($mac, $from, $SET_LIGHT_COLOR, $payload);
            sleep(10);

            $payload = pack('S', 0);
            tellBulb($mac, $from, $SET_POWER_STATE, $payload);
            sleep(2);

            $payload = pack('S', 0xFFFF);
            tellBulb($mac, $from, $SET_POWER_STATE, $payload);
            sleep(2);
exit(0);
        }

        print "Light Status ".$label."\n";;
    }
    else {
        printf("Unknown(%x)\n", $header[8]);
    }
    return $decoded;
}

sub printPacket(@)
{
    my @packet = @_;

    foreach my $h (@packet) {
        printf("%02x ", $h);
    }
    print "\n";
}



my $select = IO::Select->new($socket);

print "Listening\n";
my $subscribed = 0;
my $packet;
while(1) {
    my @ready = $select->can_read(0);
    foreach my $fh (@ready) {
        my $from = recv($fh, $packet,1024,0);

        my @data = unpack("C*", $packet);
        # printPacket(@data);
        my $decoded = decodePacket($from,$packet);
    }
}

