#!/usr/bin/perl

# Demo script using all available functions of the HaCi API

use strict;
use warnings;
use Data::Dumper;

use SOAP::Lite
	on_fault => sub {
		my($soap, $res) = @_;
		die (defined $res && ref $res ? $res->faultstring : $soap->transport->status), "\n";
	};

my $haciApiUrl	= 'http://demo.haci.larsux.de/cgi-bin/HaCiAPI.cgi?getWSDL';
my $user		= 'admin';
my $pass		= 'admin';
my $a			= $ARGV[0] || 0;

my $soap	= SOAP::Lite->service($haciApiUrl);
die "Cannot initiate Soap" unless defined $soap;


if ($a == 1) {
	print Dumper($soap->search($user, $pass, 'test'));
}
elsif ($a == 2) {
	print Dumper($soap->getFreeSubnets($user, $pass, 'testRoot', '192.168.0.0/24', 29, 10));
}
elsif ($a == 3) {
	print Dumper($soap->getFreeSubnetsFromSearch($user, $pass, 'HaCiAPI', 0, 0, 0, 'Pool', 'Pool-Typ=DSL', 29, 10));
}
elsif ($a == 4) {
	print Dumper($soap->addNet($user, $pass, 'testRoot', '192.168.0.100', 32, 'HaCiAPI Test Network', 'ASSIGNED PI'));
}
elsif ($a == 5) {
	print Dumper($soap->delNet($user, $pass, 'testRoot', '192.168.0.100/32'));
} else {
	print "USAGE $0 Number

Options:
	Number:
		1: search
		2: getFreeSubnets
		3: getFreeSubnetsFromSearch
		4: addNet
		5: delNet


";
	exit 0;
}

exit 0;
