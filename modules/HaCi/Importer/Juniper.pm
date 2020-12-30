package HaCi::Importer::Juniper;

use warnings;
use strict;
use base qw(Class::Accessor);
HaCi::Importer::Juniper->mk_accessors(qw(error errorStr config status));

use HaCi::Mathematics qw/dec2ip getNetaddress getNetmaskFromCidr ipv6DecCidr2NetaddressV6Dec ipv62dec ipv6Dec2ip/;

sub new {
	my $class	= shift;
	my $self	= {};

	bless $self, $class;
}

sub parse {
	my $self			= shift;
	my $config		= $self->config;
	my $status		= $self->status || 0;
	my $box				= {};
	my $parent		= {};
	my @parents		= ();
	my $lc				= 0;
	my $secName		= 'ROOT';
	my @secNames	= ();

	unless ($config) {
		$self->error(1);
		$self->errorStr('No Config given!');
	}

	foreach (split/\n/, $config) {
		chomp;
		s#/\*.*\*/##;
		$lc	= 0 if $lc && /\*\//;
		next if $lc;

		$lc	= 1 if /\/\*/;
		s#/\*.*##;
		s#.*\*/##;
		s/#.*//;

		next if /^\s*$/;

		if (/^\s*(.+)\s*\{/) {
			push @secNames, $secName;
			$secName	= $1;
			$secName	=~ s/\s+$//;
			push @parents, $parent;
			$parent	= $box;
			$box		= {};
			s/^\s*(.+)\s*\{//;
		}
		if (/\}/) {
			$parent->{$secName}	= $box;
			$box								= $parent;
			$parent							= pop @parents;
			$secName						= pop @secNames;
			s/\}//;
		}
		if (/\s*(\S+)\s(.*)$/) {
			(my $key      = $1) =~ s/;$// if $1;
			(my $descr    = $2) =~ s/;$// if $2;
			$descr				=~ s/^\s*"//;
			$descr				=~ s/"\s*$//;
			$box->{$key}	= $descr if $key;
		}
	}
	$parent->{$secName} = $box;
	$box	= $parent;

	&getInts($self, $box->{ROOT}->{interfaces});
	if (exists $box->{ROOT}->{groups} && ref($box->{ROOT}->{groups}) eq 'HASH') {
		foreach (keys %{$box->{ROOT}->{groups}}) {
			my $group	= $_;
			&getInts($self, $box->{ROOT}->{groups}->{$group}->{interfaces}) 
				if exists $box->{ROOT}->{groups}->{$group}->{interfaces} && ref($box->{ROOT}->{groups}->{$group}->{interfaces}) eq 'HASH';
		}
	}

	return (0, $self->{newNets});
}

sub getInts {
	my $self	= shift;
	my $key		= shift;

	foreach (keys %{$key}) {
		my $int		= $_;
		next unless ref($key->{$int}) eq 'HASH';

		foreach (keys %{$key->{$int}}) {
			next unless ref($key->{$int}->{$_}) eq 'HASH' && /^unit /;

			my $unit				= $_;
			my $descr				= $key->{$int}->{$unit}->{description};
			my $ipv4				= $key->{$int}->{$unit}->{'family inet'}->{address};
			my $ipv6				= $key->{$int}->{$unit}->{'family inet6'}->{address};
			my ($sUnit)			= $unit =~ /unit (.*)/;
			$descr					= $int unless $descr;
			$descr					.= " ($sUnit)" if $sUnit != 0;

			if ($ipv4) {
				($ipv4, my $cidr)	= split(/\//, $ipv4);
				$cidr							= 32 unless defined $cidr;
				my $netaddress		= ($cidr == 32) ? $ipv4 : &dec2ip(&getNetaddress($ipv4, &getNetmaskFromCidr($cidr)));
				&pushNet($self, $ipv4, $netaddress, $cidr, 32, $descr);
			}
			elsif ($ipv6) {
				($ipv6, my $cidr)	= split(/\//, $ipv6);
				$cidr							= 128 unless defined $cidr;
				my $netaddress		= ($cidr == 128) ? $ipv6 : &ipv6Dec2ip(&ipv6DecCidr2NetaddressV6Dec(&ipv62dec($ipv6), $cidr));
				eval {&pushNet($self, Net::IPv6Addr::to_string_preferred($ipv6), Net::IPv6Addr::to_string_preferred($netaddress), $cidr, 128, $descr)};
				warn $@ if $@;
			}

			for ('family inet', 'family inet6') {
				my $type	= $_;
				if (exists $key->{$int}->{$unit}->{$type} && ref($key->{$int}->{$unit}->{$type}) eq 'HASH') {
					foreach (keys %{$key->{$int}->{$unit}->{$type}}) {
						next unless ref($key->{$int}->{$unit}->{$type}->{$_}) eq 'HASH' && /^address /;
						s/^address //;
						my ($ip, $cidr)	= split(/\//);
						my $netaddress	= '';
						if ($ip =~ /^[\d\.]+$/) {
							$cidr					= 32 unless defined $cidr;
							$netaddress		= &dec2ip(&getNetaddress($ip, &getNetmaskFromCidr($cidr)));
							&pushNet($self, $ip, $netaddress, $cidr, 32, $descr);
						} else {
							$cidr					= 128 unless defined $cidr;
							$netaddress		= &ipv6Dec2ip(&ipv6DecCidr2NetaddressV6Dec(&ipv62dec($ip), $cidr));
							eval {&pushNet($self, Net::IPv6Addr::to_string_preferred($ip), Net::IPv6Addr::to_string_preferred($netaddress), $cidr, 128, $descr)};
							warn $@ if $@;
						}
					}
				}
			}
		}
	}
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
