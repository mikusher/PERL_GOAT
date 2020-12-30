package HaCi::HaCiAPI;

use strict;
use warnings;

use vars qw/$workDir/;

# Polluting Environment for Config::General
$ENV{script_name}	= $ENV{SCRIPT_NAME};

$workDir			= &getWorkDir();
$ENV{workdir}	= $workDir;
unshift @INC, $ENV{workdir} . '/modules';

use HaCi::Conf;
use HaCi::HaCi;
use HaCi::Utils qw/networkStateName2ID getNetID checkNetACL rootName2ID netv6Dec2ipv6ID tmplName2ID tmplEntryDescr2EntryID/;
use HaCi::Log qw/warnl debug/;
use HaCi::Mathematics qw/netv62Dec &net2dec/;
use HaCi::SOAP::Type::network;

our $conf; *conf		= \$HaCi::Conf::conf;

sub getWorkDir {
	my $currDir = `pwd`;
	chomp($currDir);
	my $scriptFile	= $0;
	$scriptFile			= $ENV{SCRIPT_FILENAME} if exists $ENV{SCRIPT_FILENAME};
	(my $scriptDir  = $scriptFile) =~ s/\/[^\/]+$//;
	my $destDir			= ($scriptDir =~ /^\//) ? $scriptDir : $currDir . '/' . $scriptDir;
	chdir "$destDir/../" or die "Cannot change into workdir '$destDir/../': $!\n";
	my $workDir = `pwd`;
	chomp($workDir);

	return $workDir;
}

sub init {
	my @args	= @_;

	map {
		warn "  ARGS: $_\n";
	} @args if 0;

	&HaCi::Conf::init($workDir);
}

sub fillParams {
	my $q				= shift;
	my $params	= shift;

	return unless ref($params) eq 'HASH';

	foreach (keys %{$params}) {
		my $key		= $_;
		my $value	= $params->{$key};
		if (defined $value) {
			$q->delete($key);
			$q->param($key, $value);
			warn "\$q->param($key, $value);\n" if $conf->{static}->{misc}->{debug};
		}
	}
}

=begin WSDL

_IN username        $string  Username
_IN password        $string  Password
_IN searchString    $string  Search String
_IN state           $string  (optional) (One of: UNSPECIFIED, ALLOCATED PA, ALLOCATED PI, ALLOCATED UNSPECIFIED, SUB-ALLOCATED PA, LIR-PARTITIONED PA, LIR-PARTITIONED PI, EARLY-REGISTRATION, NOT-SET, ASSIGNED PA, ASSIGNED PI, ASSIGNED ANYCAST, ALLOCATED-BY-RIR, ALLOCATED-BY-LIR, ASSIGNED, RESERVED, LOCKED, FREE)
_IN exact           $boolean (optional) Search for the Exact search String?
_IN fuzzy           $boolean (optional) Fuzzy search?
_IN template        $string  (optional) isolate your Search by defining a Template
_IN templateQueries $string  (optional) Define special Queries for the specified Template. spererated by semicolon. E.g.: value1=foo;value2=bar
_RETURN	@HaCi::SOAP::Type::network
_DOC	This is a search function

=cut
sub search {
	my ($class, $user, $pass, @funcArgs)	= @_;
	&init();
	&HaCi::HaCi::run(1, [$user, $pass, @funcArgs], \&search_pre, \&search_post);
}

sub search_pre {
	my $funcArgs	= shift;
	my $q					= shift;

	return unless ref($funcArgs) eq 'ARRAY';

	my $searchStr	= $$funcArgs[0] || '';
	my $state			= $$funcArgs[1] || '';
	my $exact			= $$funcArgs[2] || '';
	my $fuzzy			= $$funcArgs[3] || '';
	my $tmplName	= $$funcArgs[4] || '';
	my $tmplQuery	= $$funcArgs[5] || '';
	my $tmplID		= ($tmplName ne '') ? &tmplName2ID($tmplName) : 0;
	unless (defined $tmplID) {
		&warnl("No such Template found! ($tmplName)");
		$tmplID	= -1;
	}

	foreach (split(/;/, $tmplQuery)) {
		my $query	= $_;
		next if !$query || $query !~ /=/;

		my ($key, $value)	= split(/=/, $query, 2);
		my $tmplEntryID		= &tmplEntryDescr2EntryID($tmplID, $key);
		next unless defined $tmplEntryID;

		my $tmplDescr			= 'tmplEntryDescrID_' . $tmplEntryID;
		my $tmplEntry			= 'tmplEntryID_' . $tmplEntryID;
		&fillParams($q, {
			$tmplDescr	=> $key,
		$tmplEntry	=> $value,
		});
	}

	&fillParams($q, {
		searchButton	=> 1,
		search				=> $searchStr || '',
		state					=> (($state eq '') ? -1 : &networkStateName2ID($state) || 0),
		exact					=> $exact || undef,
		fuzzy					=> $fuzzy || undef,
		tmplID				=> $tmplID,
	});
}

sub search_post {
	my $funcArgs	= shift;
	my $q					= shift;
	my $t					= shift;
	my $warnings	= shift;
	my $result		= $t->{V}->{searchResult};

	&dieWarnings($warnings) if $warnings ne '';

	if (defined $result && ref($result) eq 'ARRAY') {
		my $networks	= [];
		foreach (@{$result}) {
			push @{$networks}, new HaCi::SOAP::Type::network($_->{rootName}, $_->{network}, $_->{description}, $_->{state});
		}
		return $networks;
	} else {
		return [];
	}
}


=begin WSDL

_IN username	$string Username
_IN password	$string Password
_IN root			$string	Root Name
_IN supernet	$string	Supernet (e.g. 192.168.0.0/24)
_IN size			$int		Subnet CIDR (e.g. 29)
_IN amount		$int		(optional) Amount of returned Networks (e.g. 1)
_RETURN @HaCi::SOAP::Type::network
_DOC This Service returns all free Subnets of a certain size from a given Supernet

=cut
sub getFreeSubnets {
	my ($class, $user, $pass, @funcArgs)	= @_;
	&init(@funcArgs);
	&HaCi::HaCi::run(1, [$user, $pass, @funcArgs], \&getFreeSubnets_pre, \&getFreeSubnets_post);
}

sub getFreeSubnets_pre {
	my $funcArgs	= shift;
	my $q					= shift;

	return unless ref($funcArgs) eq 'ARRAY';

	my $rootName		= $$funcArgs[0] || 0;
	my $rootID			= &rootName2ID($rootName);
	unless ($rootID) {
		&warnl("No such Root found! ($rootName)");
		return;
	}

	my $network			= $$funcArgs[1] || 0;
	my $ipv6				= ($network =~ /:/) ? 1 : 0;
	my $networkDec  = ($ipv6) ? &netv62Dec($network) : &net2dec($network);
	my $cidr				= $$funcArgs[2] || (($ipv6) ? 128 : 32);
	my $amount			= $$funcArgs[3] || 0;
	my $ipv6ID			= ($ipv6) ? &netv6Dec2ipv6ID($networkDec) : '';
	my $netID				= &getNetID($rootID, $networkDec, $ipv6ID);

	unless ($netID) {
		&warnl("No such network found! ($network)");
		return;
	}
	unless (&checkNetACL($netID, 'r')) {
		&warnl("Not enouph permissions to read this Network");
		return;
	}
	
	&fillParams($q, {
		showSubnets	=> 1,
		netID				=> $netID,
		subnetSize	=> $cidr,
		amount			=> $amount,
	});
}

sub getFreeSubnets_post {
	my $funcArgs	= shift;
	my $q					= shift;
	my $t					= shift;
	my $warnings	= shift;
	my $result		= $t->{V}->{freeSubnets};
	my $amount		= $q->param('amount') || 0;

	&dieWarnings($warnings) if $warnings ne '';
	if (defined $result && ref($result) eq 'ARRAY') {
		my $networks	= [];
		my $cnter			= 0;
		foreach (@{$result}) {
			push @{$networks}, new HaCi::SOAP::Type::network('', $_->{net});
			return $networks if $amount && ++$cnter == $amount;
		}
		return $networks;
	} else {
		return [];
	}
}

sub dieWarnings {
	my $warnings	= shift;

warn "die " . SOAP::Fault->faultcode('HaCiAPI')->faultstring($warnings) . "\n";
#	die SOAP::Fault->faultcode('HaCiAPI')->faultstring($warnings);
	die $warnings;
}

=begin WSDL

_IN username        $string  Username
_IN password        $string  Password
_IN searchString    $string  Search String
_IN state           $string  (optional) (One of: UNSPECIFIED, ALLOCATED PA, ALLOCATED PI, ALLOCATED UNSPECIFIED, SUB-ALLOCATED PA, LIR-PARTITIONED PA, LIR-PARTITIONED PI, EARLY-REGISTRATION, NOT-SET, ASSIGNED PA, ASSIGNED PI, ASSIGNED ANYCAST, ALLOCATED-BY-RIR, ALLOCATED-BY-LIR, ASSIGNED, RESERVED, LOCKED, FREE)
_IN exact           $boolean (optional) Search for the Exact search String?
_IN fuzzy           $boolean (optional) Fuzzy search?
_IN template        $string  (optional) isolate your Search by defining a Template
_IN templateQueries $string  (optional) Define special Queries for the specified Template. spererated by semicolon. E.g.: value1=foo;value2=bar
_IN size            $int     Subnet CIDR (e.g. 29)
_IN amount          $int     (optional) Amount of returned Networks (e.g. 1)
_RETURN	@HaCi::SOAP::Type::network
_DOC This Service returns all free Subnets of a certain size from networks, that fit the search criteria

=cut
sub getFreeSubnetsFromSearch {
	my ($class, $user, $pass, @funcArgs)	= @_;
	&init();
	&HaCi::HaCi::run(1, [$user, $pass, @funcArgs], \&getFreeSubnetsFromSearch_pre, \&getFreeSubnets_post);
}

sub getFreeSubnetsFromSearch_pre {
	my $funcArgs	= shift;
	my $q					= shift;

	return unless ref($funcArgs) eq 'ARRAY';

	my $searchStr	= $$funcArgs[0] || '';
	my $state			= $$funcArgs[1] || '';
	my $exact			= $$funcArgs[2] || '';
	my $fuzzy			= $$funcArgs[3] || '';
	my $tmplName	= $$funcArgs[4] || '';
	my $tmplQuery	= $$funcArgs[5] || '';
	my $size			= $$funcArgs[6] || -1;
	my $amount		= $$funcArgs[7] || 1;
	my $tmplID		= ($tmplName ne '') ? &tmplName2ID($tmplName) : 0;
	unless (defined $tmplID) {
		&warnl("No such Template found! ($tmplName)");
		$tmplID	= -1;
	}
	foreach (split(/;/, $tmplQuery)) {
		my $query	= $_;
		next if !$query || $query !~ /=/;

		my ($key, $value)	= split(/=/, $query, 2);
		my $tmplEntryID		= &tmplEntryDescr2EntryID($tmplID, $key);
		next unless defined $tmplEntryID;

		my $tmplDescr			= 'tmplEntryDescrID_' . $tmplEntryID;
		my $tmplEntry			= 'tmplEntryID_' . $tmplEntryID;
		&fillParams($q, {
			$tmplDescr	=> $key,
			$tmplEntry	=> $value,
		});
	}

	&fillParams($q, {
		searchAndGetFreeSubnets	=> 1,
		search				=> $searchStr || '',
		state					=> (($state eq '') ? -1 : &networkStateName2ID($state) || 0),
		exact					=> $exact || undef,
		fuzzy					=> $fuzzy || undef,
		tmplID				=> $tmplID,
		size					=> $size,
		amount				=> $amount,
	});
}

=begin WSDL

_IN username		$string		Username
_IN password		$string		Password
_IN rootName		$string		Name of Root
_IN ipaddress		$string		IP Address (E.g.: 192.168.0.1)
_IN cidr				$int			CIDR (E.g.: 24)
_IN description	$string		(optional) Description of the Network
_IN state				$string		(optional) The State of the Network.  (One of: UNSPECIFIED, ALLOCATED PA, ALLOCATED PI, ALLOCATED UNSPECIFIED, SUB-ALLOCATED PA, LIR-PARTITIONED PA, LIR-PARTITIONED PI, EARLY-REGISTRATION, NOT-SET, ASSIGNED PA, ASSIGNED PI, ASSIGNED ANYCAST, ALLOCATED-BY-RIR, ALLOCATED-BY-LIR, ASSIGNED, RESERVED, LOCKED, FREE)
_IN defSubnetSize	$int		(optional) Default CIDR for Subnets 
_IN templateName	$string	(optional) Template, which should be linked to the Network 
_RETURN $string	Prints if addition has failed or was successfull
_DOC This function adds a Network

=cut
sub addNet {
	my ($class, $user, $pass, @funcArgs)	= @_;
	&init(@funcArgs);
	&HaCi::HaCi::run(1, [$user, $pass, @funcArgs], \&addNet_pre, \&addNet_post);
}

sub addNet_pre {
	my $funcArgs	= shift;
	my $q					= shift;

	return unless ref($funcArgs) eq 'ARRAY';

	my $rootName	= $$funcArgs[0] || '';
	my $ip				= $$funcArgs[1] || 0;
	my $cidr			= $$funcArgs[2];
	my $descr			= $$funcArgs[3] || '';
	my $state			= (($$funcArgs[1] eq '') ? -1 : &networkStateName2ID($$funcArgs[1]) || 0),
	my $defss			= $$funcArgs[5] || 0;
	my $tmplName	= $$funcArgs[6] || '';
	$cidr					= (($ip =~ /:/) ? 128 : 32) if !defined $cidr || !$cidr;

	my $rootID		= &rootName2ID($rootName);
	unless ($rootID) {
		&warnl("No such Root found! ($rootName)");
		return;
	}

	my $tmplID		= ($tmplName ne '') ? &tmplName2ID($tmplName) : 0;
	unless (defined $tmplID) {
		&warnl("No such Template found! ($tmplName)");
		$tmplID	= 0;
	}
	
	&fillParams($q, {
		submitAddNet	=> 1,
		func					=> 'addNet',
		rootID				=> $rootID,
		netaddress		=> $ip,
		cidr					=> $cidr,
		descr					=> $descr,
		state					=> $state,
		defSubnetSize	=> $defss,
		tmplID				=> $tmplID,
		forceState			=> 1
	});
}

sub addNet_post {
	my $funcArgs	= shift;
	my $q					= shift;
	my $t					= shift;
	my $warnings	= shift;

	my $rootName	= $$funcArgs[0] || '';
	my $ip				= $$funcArgs[1] || 0;
	my $cidr			= $$funcArgs[2];
	$cidr					= (($ip =~ /:/) ? 128 : 32) if !defined $cidr || !$cidr;
	my $network		= $ip . '/' . $cidr;

	if (defined $q->param('func') && $q->param('func') eq 'showAllNets') {
		return "Sucessfully added Network '$network' to Root '$rootName'" . (($warnings) ? " ($warnings)" : '');
	} else {
		return "Error while adding Network '$network' to Root '$rootName': $warnings";
	}
}


=begin WSDL

_IN username	$string Username
_IN password	$string Password
_IN root			$string	Root Name
_IN network		$string	Network (e.g. 192.168.0.0/24)
_RETURN				$string	Prints if deletion has failed or was successfull
_DOC									This function deletes a Network

=cut
sub delNet {
	my ($class, $user, $pass, @funcArgs)	= @_;
	&init(@funcArgs);
	&HaCi::HaCi::run(1, [$user, $pass, @funcArgs], \&delNet_pre, \&delNet_post);
}

sub delNet_pre {
	my $funcArgs	= shift;
	my $q					= shift;

	return unless ref($funcArgs) eq 'ARRAY';

	my $rootName		= $$funcArgs[0] || 0;
	my $rootID			= &rootName2ID($rootName);
	unless ($rootID) {
		&warnl("No such Root found! ($rootName)");
		return;
	}

	my $network			= $$funcArgs[1] || 0;
	my $ipv6				= ($network =~ /:/) ? 1 : 0;
	my $networkDec  = ($ipv6) ? &netv62Dec($network) : &net2dec($network);
	my $ipv6ID			= ($ipv6) ? &netv6Dec2ipv6ID($networkDec) : '';
	my $netID				= &getNetID($rootID, $networkDec, $ipv6ID);

	unless ($netID) {
		&warnl("No such network found! ($network)");
		return;
	}
	unless (&checkNetACL($netID, 'w')) {
		&warnl("Not enouph permissions to delete this Network");
		return;
	}
	
	&fillParams($q, {
		showSubnets		=> 1,
		netID					=> $netID,
		commitDelNet	=> 1, 
		delNet				=> 1,
	});
}

sub delNet_post {
	my $funcArgs	= shift;
	my $q					= shift;
	my $t					= shift;
	my $warnings	= shift;

	my $rootName	= $$funcArgs[0] || '';
	my $network		= $$funcArgs[1] || '0/0';

	if (defined $q->param('func') && $q->param('func') eq 'showAllNets') {
		return "Sucessfully deleted Network '$network' from Root '$rootName'" . (($warnings) ? " ($warnings)" : '');
	} else {
		return "Error while deleting Network '$network' from Root '$rootName': $warnings";
	}
}

=begin WSDL

_IN username	$string Username
_IN password	$string Password
_IN param			$string Parameter
_RETURN				$string	Return Stuff
_DOC									Template

=cut
sub template {
	my ($class, $user, $pass, @funcArgs)	= @_;
	&init(@funcArgs);
	&HaCi::HaCi::run(1, [$user, $pass, @funcArgs], \&template_pre, \&template_post);
}

sub template_pre {
	my $funcArgs	= shift;
	my $q					= shift;

	return unless ref($funcArgs) eq 'ARRAY';

	my $param	= $$funcArgs[0] || 0;
	
	&fillParams($q, {
		param	=> $param,
	});
}

sub template_post {
	my $funcArgs	= shift;
	my $q					= shift;
	my $t					= shift;
	my $warnings	= shift;
}

1;
