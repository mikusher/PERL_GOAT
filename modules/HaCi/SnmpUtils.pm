package HaCi::SnmpUtils;

use warnings;
use strict;
use Net::SNMP qw(:snmp);

use HaCi::Log qw/warnl debug/;

require Exporter;
our @ISA				= qw(Exporter);
our @EXPORT_OK	= qw(
	getSNMPSession getSNMPTree getSNMPValue
);

our $conf; *conf  = \$HaCi::Conf::conf;

sub getSNMPSession {
	my $host			= shift;
	my $comm			= shift;
	my $opts			= shift || {};
	my $port			= $opts->{port} || 161;
	my $nBlocking	= $opts->{nBlocking} || 1;
	my $version		= $opts->{version} || 'snmpv2';
	my $timeout		= $opts->{timeout} || 10;
  $version			= 'snmpv' . $version unless $version =~ /^snmpv/;

	my ($session, $error) = Net::SNMP->session(
		-hostname			=> $host,
		-port					=> $port,
		-community		=> $comm,
		-version			=> $version,
		-nonblocking	=> $nBlocking,
		-timeout			=> $timeout
	);
	if (!defined($session)) {
		&warnl("Cannot initiate Session for " . $host . ": $error! Abort...", 1);
		return undef;
	}

	return $session;
}

sub getSNMPTree {
  my $session = shift;
	my $oid			= shift;
	my $results	= {};
  my $result  = undef;
	my $version	= $session->version;

  if ($version == 0) {
    $result = $session->get_next_request(
      -callback     => [\&snmpCB, $results, $oid],
      -delay        => 0,
      -varbindlist  => [$oid]
    );
  }
  elsif ($version == 1 || $version == 3) {
    $result = $session->get_bulk_request(
      -callback       => [\&snmpCB, $results, $oid],
      -maxrepetitions => 10,
      -delay          => 0,
      -varbindlist    => [$oid]
    );
  }
  else {
    &warnl("Bad SNMP Version '$version'!", 1);
    return undef;
  }

  if (!defined($result)) {
    &warnl("Cannot retrieve any Results for System: " . $session->hostname . ": " . $session->error, 1);
    return undef;
  } 
    
  snmp_dispatcher();
  
  return $results;
}

sub snmpCB {
	my ($session, $results, $query)	= @_;
	my $version											= $session->version;

	if (!defined($session->var_bind_list)) {
		&warnl("SNMP-Error: " . $session->error, 1);
	} else {
		my $next  = undef;
		foreach my $oid (oid_lex_sort(keys(%{$session->var_bind_list}))) {
			if (!oid_base_match($query, $oid)) {
				$next = undef;
				last;
			}
			$next							= $oid; 
			my $value					= $session->var_bind_list->{$oid};
			$results->{$oid}	= $value;
		}
		if (defined($next)) {
			my $result  = undef;
			if ($version == 0) {
				$result = $session->get_next_request(
					-callback     => [\&snmpCB, $results, $query],
					-delay        => 0,
					-varbindlist  => [$next]
				);
		  }
			elsif ($version == 1 || $version == 3) {
				$result = $session->get_bulk_request(
					-callback       => [\&snmpCB, $results, $query],
					-maxrepetitions => 10,
					-delay          => 0,
					-varbindlist    => [$next]
				);
			} else {
        &warnl("Bad SNMP Version '$version'!", 1);
      }
      if (!defined($result)) {
        &warnl("SNMP-Errro: " . $session->error, 1);
      }
    }
  }
}

sub getSNMPValue {
	my $session = shift;
	my $snmpOID = shift;
	my $result	= $session->get_request(
		-varbindlist  => [$snmpOID] 
	);  
	if (!defined($result)) {
		&warnl("SNMP-Error: " . $session->error, 1) unless $session->error =~ /noSuchName/;
		return undef;
	}
	return (ref $result eq 'HASH') ? $result->{$snmpOID} : undef;
}

1;
