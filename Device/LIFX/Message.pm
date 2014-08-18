
package Device::LIFX::Message;

use strict;
use warnings;
use Carp;
use IO::Socket;
use Device::LIFX::Constants qw(/.*/);
use Data::Dumper;

my %msg_template = (
    size        => 0x00, protocol           => 0x00,
    reserved1   => 0x00, target_mac_address => "\0\0\0\0\0\0",
    reserved2   => 0x00, site               => "LIFXV2",
    reserved3   => 0x00, timestamp          => 0x00,
    packet_type => 0x00, reserved4          => 0x00,
);

sub _decode_header($)
{
    my ($packet) = @_;

    my @header = unpack('(SS)<La6Sa6SQSS', $packet);
    my $header = {
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

sub _decode_light_status($)
{
    my ($payload) = @_;

    my @decoded = unpack('(SSSSS)<SA32Q',$payload);
    my $color   = [
        $decoded[0],
        $decoded[1]/65535.0*100.0,
        $decoded[2]/65535.0*100.0,
        $decoded[3]
    ];
    my $dim   = $decoded[4];
    my $power = ($decoded[5] == 0xFFFF) ? 1 : 0;
    my $label = $decoded[6];
    my $tags  = $decoded[7];
    $label    =~ s/\s+$//;

    return ($color,$dim,$power,$label,$tags);
}

sub _decode_packet($)
{
    my ($packet) = @_;

    my $decoded        = {};
    $decoded->{header} = _decode_header($packet);
    my $type           = $decoded->{header}->{packet_type};
    my $payload        = substr($packet, 36);

    if ($type == PAN_GATEWAY) {
        my ($service,$port) = unpack('aL', $payload);
        $decoded->{service} = $service;
        $decoded->{port}    = $port;
    }
    elsif ($type == TIME_STATE) {
        $decoded->{time} = unpack('Q', $payload);
    }
    elsif ($type == WIFI_INFO) {
        my @payload = unpack('(fLLs)<', $payload);
        $decoded->{signal}          = $payload[0];
        $decoded->{tx}              = $payload[1];
        $decoded->{rx}              = $payload[2];
        $decoded->{mcu_temperature} = $payload[3];
    }
    elsif ($type == POWER_STATE) {
        $decoded->{power} = unpack('S', $payload);
    }
    elsif ($type == TAG_LABELS) {
        my ($tags, $label) = unpack('Qa*', $payload);
        $decoded->{tags}   = $tags;
        $decoded->{label}  = $label;
    }
    elsif ($type == LIGHT_STATUS) {
        my ($color,$dim,$power,$label,$tags) = _decode_light_status($payload);
        $decoded->{color} = $color;
        $decoded->{dim}   = $dim;
        $decoded->{power} = $power;
        $decoded->{label} = $label;
        $decoded->{tags}  = $tags;
    }
    return $decoded;
}

sub _pack_message($$$$)
{
    my ($type, $scope, $mac, $payload) = @_;

    my @header = (
        36+length($payload),
        $scope,
        0x01,
        $mac,
        0x0,
        "LIFXV2",
        0x0,
        0x0,
        $type,
        0x0,
    );
    my $packed = pack('(SS)<La6Sa6SQvS', @header);

    return $packed.$payload;
}


sub new($$)
{
    my $class = shift(@_);

    my $self = {};
    if ($#_ == 1) {
        my ($from,$packet) = @_;
        $self->{packet}    = $packet;
        $self->{decoded}   = _decode_packet($packet);
        my ($port, $iaddr) = sockaddr_in($from);
        $self->{from_addr} = $iaddr;
        $self->{from_port} = $port;
    } else {
        my ($type,$scope,$mac,$data) = @_;
        if ($type == GET_PAN_GATEWAY) {
            $self->{packet} = _pack_message($type, $scope, $mac, "");
        } elsif ($type == GET_WIFI_INFO) {
            $self->{packet} = _pack_message($type, $scope, $mac, "");
        } elsif ($type == SET_POWER_STATE) {
            my $payload     = pack('S<', $data);
            $self->{packet} = _pack_message($type, $scope, $mac, $payload);
        } elsif ($type == SET_LIGHT_COLOR) {
            my @payload     = @{$data};
            my $payload     = pack('(CSSSSL)<', @payload);
            $self->{packet} = _pack_message($type, $scope, $mac, $payload);
        } elsif ($type == GET_LIGHT_STATE) {
            $self->{packet} = _pack_message($type, $scope, $mac, "");
        }
        if (defined($self->{packet})) {
            $self->{decoded} = _decode_packet($self->{packet});
        }
    }
    return bless $self, $class;
}

sub as_hex_string($)
{
    my ($self) = @_;

    my @packet = unpack('C*', $self->{packet});
    @packet    = map {sprintf("%02x", $_)} @packet;

    return join(" ", @packet);
}

sub type($)
{
    my ($self) = @_;

    return $self->{decoded}->{header}->{packet_type};
}

sub type_as_string($)
{
    my ($self) = @_;

    my $type = $self->{decoded}->{header}->{packet_type};

    return Device::LIFX::Constants::type2str($type);
}

sub color($)
{
    my ($self) = @_;

    return $self->{decoded}->{color};
}

sub power($)
{
    my ($self) = @_;

    return $self->{decoded}->{power};
}

sub label($)
{
    my ($self) = @_;

    return $self->{decoded}->{label};
}

sub bulb_mac($)
{
    my ($self) = @_;

    return $self->{decoded}->{header}->{target_mac_address};
}

sub signal($)
{
    my ($self) = @_;

    return $self->{decoded}->{signal};
}
sub tx($)
{
    my ($self) = @_;

    return $self->{decoded}->{tx};
}

sub rx($)
{
    my ($self) = @_;

    return $self->{decoded}->{rx};
}

sub mcu_temperature($)
{
    my ($self) = @_;

    return $self->{decoded}->{mcu_temperature};
}

sub from_ip($)
{
}

sub from_port($)
{
}

1;
