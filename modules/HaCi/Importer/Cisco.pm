package HaCi::Importer::Cisco;

use warnings;
use strict;
use base qw(Class::Accessor);
HaCi::Importer::Cisco->mk_accessors(qw(error errorStr config status));

use HaCi::Mathematics qw/getCidrFromNetmask dec2ip getNetaddress getNetmaskFromCidr ipv6DecCidr2NetaddressV6Dec ipv62dec ipv6Dec2ip/;

sub new {
	my $class	= shift;
	my $self	= {};

	bless $self, $class;
}

sub parse {
	my $self			= shift;
	my $config		= $self->config;
	my $status		= $self->status || 0;

	unless ($config) {
		$self->error(1);
		$self->errorStr('No Config given!');
	}

	my $hostname	= '';
	my $bInt			= 0;
	my $intName		= '';
	my $intDescr	= '';
	foreach (split/\n/, $config) {
		chomp;
		next if /^\s*$/;
		$hostname	= $1 if /^hostname\s+([[:alpha:]][[:alnum:]\-_]+[[:alnum:]])\s*$/;  # http://www.cisco.com/en/US/docs/ios/fundamentals/command/reference/cf_f1.html#wp1015617 + '_'
		if ($bInt && /^!/) {
			$bInt			= 0;
			$intName	= '';
			$intDescr	= '';
		}
		if (!$bInt && /^interface\s+(.*)/) {
			$bInt			= 1;
			$intName	= $1;
		}
		$intDescr	= $1 if $bInt && /^\s+description\s+(.*)/;
		if ($bInt) {
			if (/^\s+ip address\s+(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})\s+(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})/) {
				my ($ip, $netmask)	= ($1, $2);
				my $cidr						= &getCidrFromNetmask($netmask);
				my $netaddress			= ($cidr == 32) ? $ip : &dec2ip(&getNetaddress($ip, &getNetmaskFromCidr($cidr)));

				&pushNet($self, $ip, $netaddress, $cidr, 32, ($intDescr ne '') ? $intDescr : $intName);
			}
			elsif (/^\s+ipv6 address\s+([\w\d:]+)\/(\d{1,3})/) {
				my ($ip, $cidr)	= ($1, $2);
				my $netaddress	= &ipv6Dec2ip(&ipv6DecCidr2NetaddressV6Dec(&ipv62dec($ip), $cidr));
				eval {&pushNet($self, Net::IPv6Addr::to_string_preferred($ip), Net::IPv6Addr::to_string_preferred($netaddress), $cidr, 128, ($intDescr ne '') ? $intDescr : $intName)};
				warn $@ if $@;
			}
		}
	}

	return ($hostname, $self->{newNets});
}

sub pushNet {
	my $self				= shift;
	my $ip					= shift;
	my $netaddress	= shift;
	my $cidr				= shift;
	my $cidrDef			= shift;
	my $descr				= shift;

	if ($ip eq $netaddress) {
		unless (exists $self->{newNetCheck}->{"$netaddress/$cidr"}) {
			$self->{newNetCheck}->{"$netaddress/$cidr"}	= 1;
			push @{$self->{newNets}}, {
				ip		=> $netaddress,
				cidr	=> $cidr,
				descr	=> $descr
			};
		}
	} else {
		unless (exists $self->{newNetCheck}->{"$netaddress/$cidr"}) {
			$self->{newNetCheck}->{"$netaddress/$cidr"}	= 1;
			push @{$self->{newNets}}, {
				ip		=> $netaddress,
				cidr	=> $cidr,
				descr	=> ''
			};
		}
		unless (exists $self->{newNetCheck}->{"$ip/$cidrDef"}) {
			$self->{newNetCheck}->{"$ip/$cidrDef"}	= 1;
			push @{$self->{newNets}}, {
				ip		=> $ip,
				cidr	=> $cidrDef,
				descr	=> $descr
			};
		}
	}
}

1;

# vim:ts=2:sw=2:sws=2
