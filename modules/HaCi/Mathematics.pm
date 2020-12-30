package HaCi::Mathematics;

use strict;
use constant LOG2 => log(2);
use Net::IPv6Addr;

require Exporter;
our @ISA				= qw(Exporter);
our @EXPORT_OK	= qw(
	dec2net net2dec ip2dec dec2ip getIPFromDec ipv6Parts2NetDec netv6Dec2PartsDec
	getNetaddress getBroadcastFromNet ipv62dec netv6Dec2IpCidr
	getCidrFromNetmask getNetmaskFromCidr getCidrFrom2IPs  netv6Dec2net
	getV6BroadcastIP netv6Dec2ip ipv62Dec2 ipv6Dec2ip getV6BroadcastNet
	netv6Dec2NextNetDec ipv6DecCidr2netv6Dec netv62Dec ipv6DecCidr2NetaddressV6Dec
	getCidrFromNetv6Dec getCidrFromDec
);

our $conf; *conf  = \$HaCi::Conf::conf;

sub getCidrFrom2IPs {
  my $from  = shift;
	my $to    = shift;
	my @froms	= split/\./, $from;
	my @tos		= split/\./, $to;
	my $cidr	= 0;

	for (0 .. 3) {
		next if $tos[$_] - $froms[$_] < 0;
		$cidr += int(log((($tos[$_] - $froms[$_]) + 1))/LOG2);
	}

	return 32 - $cidr;
}

sub getNetaddress {
	my $ipaddress     = shift;
	my $netmask       = shift;
	my $netAddress		= &getNetCacheEntry('NET', "$ipaddress:$netmask", 'getNetaddress');

	unless (defined $netAddress) {
		$ipaddress	= &ip2dec($ipaddress) if $ipaddress =~ /\./;
		$netmask		= &ip2dec($netmask) if $netmask =~ /\./;

		$netAddress	= $ipaddress & $netmask;
		&updateNetcache('NET', "$ipaddress:$netmask", 'getNetaddress', $netAddress);
	}

	return $netAddress;
}

sub getCidrFromNetmask {
	my $netmask	= shift;
	$netmask		= &dec2ip($netmask) unless $netmask =~ /\./;

	my $cidr		= 0;
	foreach (split/\./, $netmask) {
		$cidr	+= log(256 - $_)/LOG2;
	}
	return 32 - $cidr;
}

sub getBroadcastFromNet {
	my $networkDec				= shift;
	my $broadcastFromNet	= &getNetCacheEntry('NET', $networkDec, 'getBroadcastFromNet');

	unless (defined $broadcastFromNet) {
		$networkDec			= &net2dec($networkDec) if $networkDec =~ /\./;
		my $cidr				= $networkDec % 256;
		my $ipaddress		= ($networkDec - $cidr) / 256;
		my $netmask			= &getNetmaskFromCidr($cidr);
		my $netaddress	= &getNetaddress($ipaddress, $netmask);
		my $broadcast		= ($netaddress + (2 ** (32 - $cidr)) - 1);

		$broadcastFromNet	= $broadcast;
		&updateNetcache('NET', $networkDec, 'getBroadcastFromNet', $broadcast);
	}

	return $broadcastFromNet;
}

sub getNetmaskFromCidr {
	my $cidr						= shift;
	my $netmaskFromCidr	= &getNetCacheEntry('NET', $cidr, 'getNetmaskFromCidr');

	unless (defined $netmaskFromCidr) {
		my $netmask	= '';
		for (0 .. 3) {
			$netmask	.= '.' if $netmask ne '';
			if ($cidr > 8) {
				$netmask	.= 255;
				$cidr			-= 8;
			} else {
				$netmask	 .= 256 - (2 ** (8 - $cidr));
				$cidr				= 0;
			}
		}

		$netmaskFromCidr	= $netmask;
		&updateNetcache('NET', $cidr, 'getNetmaskFromCidr', $netmask);
	}

	return $netmaskFromCidr;
}

sub dec2net {
	my $networkDec	= shift;

	return 0 unless defined $networkDec;
	return 0 if $networkDec eq '';

	if (ref $networkDec) {
		warn " dec2net for IPv6 (" . (caller)[0] . ':' . (caller)[2] . ")\n";
		return &netv6Dec2net($networkDec);
	} else {
	return
		int($networkDec / 256 ** 4) . '.' .
		int($networkDec % 256 ** 4 / 256 ** 3) . '.' .
		int($networkDec % 256 ** 3 / 256 ** 2) . '.' .
		int($networkDec % 256 ** 2 / 256) . '/' . $networkDec % 256;
	}
}

sub net2dec {
	my $network	= shift;

	if ($network =~ /:/) {
		warn "CANNOT net2dec for IPv6!!!\n";
		return 0;
	} else {
		$network =~ /(\d+)\.(\d+)\.(\d+)\.(\d+)\/(\d+)/;
		return $1 * 256 ** 4 + $2 * 256 ** 3 + $3 * 256 ** 2 + $4 * 256 + $5;
	}
}

sub ip2dec {
	my $ip	= shift;

	unless ($ip && $ip =~ /(\d+)\.(\d+)\.(\d+)\.(\d+)/) {
		warn " Bad ip2dec call (" . (caller)[0] . ':' . (caller)[2] . ")\n";
		return 0;
	}

	return $1 * 256 ** 3 + $2 * 256 ** 2 + $3 * 256 + $4;
}

sub dec2ip {
	return 0 unless defined $_[0];
	return 0 if $_[0] eq '';

	return
		int($_[0] / 256**3) . '.' .
		int($_[0] % 256**3 / 256**2) . '.' .
		int($_[0] % 256**2 / 256**1) . '.' .
		$_[0] % 256
}

sub getIPFromDec {
	my $networkDec	= shift;
	my $cidr				= $networkDec % 256;
	return ($networkDec - $cidr) / 256;
}

sub updateNetcache {
  my $type	= shift;
	my $ID		= shift;
	my $key		= shift;
	my $value	= shift;

	$conf->{var}->{CACHESTATS}->{$type}->{FAIL}++;

	$HaCi::HaCi::netCache->{$type}->{$ID}->{$key}	= $value;
}

sub getNetCacheEntry {
	my $type	= shift;
	my $ID		= shift;
	my $key		= shift;

	my $value = $HaCi::HaCi::netCache->{$type}->{$ID}->{$key} || undef;

	$conf->{var}->{CACHESTATS}->{$type}->{TOTAL}++;

	return $value;
}

sub hex2dec {
	my $hex	= shift;

	return hex($hex);
}

sub dec2hex {
	my $dec	= shift;

	return sprintf("%04x", $dec);
}

sub ipv62dec {
	my $ipv6			= shift;
	my @intArray	= Net::IPv6Addr::to_intarray($ipv6);
	my $base			= 65536;

	my $i0				= Math::BigInt->new($base)->bpow('7')->bmul($intArray[0]);
	my $i1				= Math::BigInt->new($base)->bpow('6')->bmul($intArray[1]);
	my $i2				= Math::BigInt->new($base)->bpow('5')->bmul($intArray[2]);
	my $i3				= Math::BigInt->new($base)->bpow('4')->bmul($intArray[3]);
	my $i4				= Math::BigInt->new($base)->bpow('3')->bmul($intArray[4]);
	my $i5				= Math::BigInt->new($base)->bpow('2')->bmul($intArray[5]);
	my $i6				= Math::BigInt->new($base)->bmul($intArray[6]);
	my $ipv6Dec		= Math::BigInt->new($intArray[7])->badd($i6)->badd($i5)->badd($i4)->badd($i3)->badd($i2)->badd($i1)->badd($i0);

	return $ipv6Dec;
}

sub ipv62dec2 {
	my $ipv6			= shift;
	my @intArray	= Net::IPv6Addr::to_intarray($ipv6);
	my $base			= 65536;

	my $n0				= Math::BigInt->new($base)->bpow('3')->bmul($intArray[0]);
	my $n1				= Math::BigInt->new($base)->bpow('2')->bmul($intArray[1]);
	my $n2				= Math::BigInt->new($base)->bmul($intArray[2]);
	my $netDec		= Math::BigInt->new($intArray[3])->badd($n2)->badd($n1)->badd($n0);

	my $h4			= Math::BigInt->new($base)->bpow('3')->bmul($intArray[4]);
	my $h5			= Math::BigInt->new($base)->bpow('2')->bmul($intArray[5]);
	my $h6			= Math::BigInt->new($base)->bmul($intArray[6]);
	my $hostDec	= Math::BigInt->new($intArray[7])->badd($h6)->badd($h5)->badd($h4);

	return ($netDec, $hostDec);
}

sub ipv6Dec2ip {
	my $nett	= shift;
	my $hostt	= shift;
	my $base	= Math::BigInt->new(65536);

	unless (defined $hostt) {
		return 0 unless ref $nett;

		my $ipv6	= &getNetCacheEntry('NET', "$nett:-1", 'ipv6Dec2ip');
		unless (defined $ipv6) {
			my $net	= $nett->copy();
			my $i8	= $net->copy()->bmod($base);
			$ipv6		= &dec2hex($i8);
			my $i7	= $net->bsub($i8)->copy()->bdiv($base)->bmod($base);
			$ipv6		= &dec2hex($i7) . ':' . $ipv6;
			my $i6	= $net->bsub($i7->bmul($base))->copy()->bdiv($base->copy()->bpow(2))->bmod($base);
			$ipv6		= &dec2hex($i6) . ':' . $ipv6;
			my $i5	= $net->bsub($i6->bmul($base->copy()->bpow(2)))->copy()->bdiv($base->copy()->bpow(3))->bmod($base);
			$ipv6		= &dec2hex($i5) . ':' . $ipv6;
			my $i4	= $net->bsub($i5->bmul($base->copy()->bpow(3)))->copy()->bdiv($base->copy()->bpow(4))->bmod($base);
			$ipv6		= &dec2hex($i4) . ':' . $ipv6;
			my $i3	= $net->bsub($i4->bmul($base->copy()->bpow(4)))->copy()->bdiv($base->copy()->bpow(5))->bmod($base);
			$ipv6		= &dec2hex($i3) . ':' . $ipv6;
			my $i2	= $net->bsub($i3->bmul($base->copy()->bpow(5)))->copy()->bdiv($base->copy()->bpow(6))->bmod($base);
			$ipv6		= &dec2hex($i2) . ':' . $ipv6;
			my $i1	= $net->bsub($i2->bmul($base->copy()->bpow(6)))->copy()->bdiv($base->copy()->bpow(7))->bmod($base);
			$ipv6		= &dec2hex($i1) . ':' . $ipv6;

			&updateNetcache('NET', "$nett:-1", 'ipv6Dec2ip', $ipv6);
		}

		return $ipv6;
	}

	return 0 unless ref $nett && ref $hostt;

	my $ipv6	= &getNetCacheEntry('NET', "$nett:$hostt", 'ipv6Dec2ip');
	unless (defined $ipv6) {
		my $net		= $nett->copy();
		my $host	= $hostt->copy();
		my $h4		= $host->copy()->bmod($base);
		$ipv6			= &dec2hex($h4);
		my $h3		= $host->bsub($h4)->copy()->bdiv($base)->bmod($base);
		$ipv6			= &dec2hex($h3) . ':' . $ipv6;
		my $h2		= $host->bsub($h3->bmul($base))->copy()->bdiv($base ** 2)->bmod($base);
		$ipv6			= &dec2hex($h2) . ':' . $ipv6;
		my $h1		= $host->bsub($h2->bmul($base ** 2))->copy()->bdiv($base ** 3)->bmod($base);
		$ipv6			= &dec2hex($h1) . ':' . $ipv6;
	
		my $n4	= $net->copy()->bmod($base);
		$ipv6		= &dec2hex($n4) . ':' . $ipv6;
		my $n3	= $net->bsub($n4)->copy()->bdiv($base)->bmod($base);
		$ipv6		= &dec2hex($n3) . ':' . $ipv6;
		my $n2	= $net->bsub($n3->bmul($base))->copy()->bdiv($base ** 2)->bmod($base);
		$ipv6		= &dec2hex($n2) . ':' . $ipv6;
		my $n1	= $net->bsub($n2->bmul($base ** 2))->copy()->bdiv($base ** 3)->bmod($base);
		$ipv6		= &dec2hex($n1) . ':' . $ipv6; 

		&updateNetcache('NET', "$nett:$hostt", 'ipv6Dec2ip', $ipv6);
	}

	return $ipv6;
}

sub ipv6Parts2NetDec {
	my $net			= shift;
	my $host		= shift;
	my $cidr		= shift;
	my $network	= Math::BigInt->new();
	my $nett		= Math::BigInt->new(65536);
	my $hostt		= Math::BigInt->new(65536);
	$nett->bpow(5)->bmul($net);
	$hostt->bmul($host);
	$network->badd($cidr);
	$network->badd($nett);
	$network->badd($hostt);

	return $network;
}

sub netv6Dec2IpCidr {
	my $netv6Dect		= shift;
	return 0 unless ref $netv6Dect;

	my ($ipv6Dec, $cidr);
	my $ipv6DecCidr	= &getNetCacheEntry('NET', $netv6Dect, 'netv6Dec2IpCidr');
	unless (defined $ipv6DecCidr) {
		my $netv6Dec	= $netv6Dect->copy();

		my $base	= 65536;
		$ipv6Dec	= $netv6Dec->copy();
		$cidr			= $netv6Dec->bmod($base)->copy();

		($ipv6Dec->bsub($cidr))->bdiv($base);

		&updateNetcache('NET', $netv6Dect, 'netv6Dec2IpCidr', ["$ipv6Dec", $cidr]);
	} else {
		$ipv6Dec	= Math::BigInt->new(${$ipv6DecCidr}[0]);
		$cidr			= ${$ipv6DecCidr}[1];
	}

	return ($ipv6Dec, $cidr);
}

sub getV6BroadcastIP {
	my $netv6Dec	= shift;
	
	return 0 unless ref $netv6Dec;

	my ($ipv6Dec, $cidr)	= &netv6Dec2IpCidr($netv6Dec);
	my $two								= Math::BigInt->new(2);
	my $add								= $two->bpow((128 - $cidr))->bsub(1);
	$ipv6Dec->badd($add);

	return $ipv6Dec;
}

sub getV6BroadcastNet {
	my $netv6Dec		= shift;
	my $targetCidr	= shift;
	
	unless (ref $netv6Dec) {
		warn "Calling 'getV6BroadcastNet' without Math::Bigint Reference! (" . (caller(0))[0] . '->' . (caller(0))[2] . ")\n";
		return 0;
	}

	my ($ipv6Dec, $cidr)	= &netv6Dec2IpCidr($netv6Dec);
	$targetCidr						= $cidr unless defined $cidr;
	my $two								= Math::BigInt->new(2);
	my $add								= $two->bpow(128 - $cidr)->bsub(1);
	$ipv6Dec->badd($add);
	my $netv6DecNew				= &ipv6DecCidr2netv6Dec($ipv6Dec, $targetCidr);

	return $netv6DecNew;
}

sub netv6Dec2NextNetDec {
	my $netv6Dec		= shift;
	my $targetCidr	= shift;
	
	return 0 unless ref $netv6Dec;

	my ($ipv6Dec, $cidr)	= &netv6Dec2IpCidr($netv6Dec);
	$targetCidr						= $cidr unless defined $targetCidr;
	my $two								= Math::BigInt->new(2);
	my $add								= $two->bpow(128 - $cidr);
	$ipv6Dec->badd($add);
	my $netv6DecNew				= &ipv6DecCidr2netv6Dec($ipv6Dec, $targetCidr);

	return $netv6DecNew;
}

sub netv62Dec {
	my $netv6					= shift;
	my ($ipv6, $cidr)	= split/\//, $netv6;
	my $ipv6Dec				= Math::BigInt->new(&ipv62dec($ipv6));

	return &ipv6DecCidr2netv6Dec($ipv6Dec, $cidr);
}

sub ipv6DecCidr2netv6Dec {
	my $ipv6Dec		= shift;
	my $cidr			= shift;
	my $netv6Dec	= Math::BigInt->new();
	my $ipv6Dect	= Math::BigInt->new(65536);

	return 0 unless ref $ipv6Dec;

	$ipv6Dect->bmul($ipv6Dec);
	$netv6Dec->badd($ipv6Dect);
	$netv6Dec->badd($cidr);

	return $netv6Dec;
}

sub netv6Dec2ip {
	my $netv6Dect	= shift;

	return 0 unless ref $netv6Dect;
	my $netv6Dec					= $netv6Dect->copy();
	my ($ipv6Dec, $cidr)	= &netv6Dec2IpCidr($netv6Dec);
	my $ipv6							= &ipv6Dec2ip($ipv6Dec);

	return $ipv6;
}

sub netv6Dec2net {
	my $netv6Dect					= shift;

	unless (ref $netv6Dect) {
		warn "Calling 'netv6Dec2net' without Math::Bigint Reference!\n";
		return 0;
	}

	my $netv6Dec					= $netv6Dect->copy();
	my ($ipv6Dec, $cidr)	= &netv6Dec2IpCidr($netv6Dec);
	my $ipv6							= &ipv6Dec2ip($ipv6Dec);

	return $ipv6 . '/' . $cidr;
}

sub getCidrFromDec {
	my $dec		= shift;
	my $cidr	= $dec % 256;

	return $cidr;
}

sub getCidrFromNetv6Dec {
	my $netv6Dect	= shift;

	return 0 unless ref $netv6Dect;
	my $netv6Dec	= $netv6Dect->copy();

	my $base		= 65536;
	my $cidr		= $netv6Dec->copy()->bmod($base);

	return $cidr;
}

sub netv6Dec2PartsDec {
	my $netv6Dect	= shift;

	return 0 unless ref $netv6Dect;
	my $netv6Dec	= $netv6Dect->copy();

	my $base		= 65536;
	my $temp		= Math::BigInt->new($base);
	my $cidr		= $netv6Dec->copy()->bmod($base);
	($netv6Dec->bsub($cidr))->bdiv($base);
	
	$temp->bpow(4);
	my $host		= $netv6Dec->copy()->bmod($temp);
	($netv6Dec->bsub($host))->bdiv($temp);

	$temp->bpow(2);
	my $net		= $netv6Dec->copy()->bmod($temp);

	return ($net, $host, $cidr);
}

sub ipv6DecCidr2NetaddressV6Dec {
	my $ipv6Dect	= shift;
	my $cidr			= shift;

	return 0 unless ref $ipv6Dect;
	my $ipv6Dec	= $ipv6Dect->copy();
	
	my $base	= Math::BigInt->new(2);
	$base->bpow(128 - $cidr);
	my $tooMuch	= $ipv6Dec->copy()->bmod($base);
	$ipv6Dec->bsub($tooMuch);
	return $ipv6Dec;
}

1;

# vim:ts=2:sw=2:sws=2
