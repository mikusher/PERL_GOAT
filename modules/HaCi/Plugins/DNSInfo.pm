package HaCi::Plugins::DNSInfo;

use strict;
use warnings;

use base qw/HaCi::Plugin/;

use HaCi::Mathematics qw/dec2net netv6Dec2net/;
use HaCi::GUI::gettext qw/_gettext/;

our $INFO	= {
	name				=> 'DNSInfo',
	version			=> '0.1',
	onDemand		=> 1,
	recurrent		=> 0,
	description	=> _gettext('This Plugin queries on demand the DNS PTR-Record for the current IP adress and displays it.')
};

sub run_onDemand {
	my $self				= shift;
	my $networkRef	= shift;
	my $networkDec	= $networkRef->{network};
	my $network			= ($networkRef->{ipv6ID}) ? &netv6Dec2net($networkDec) : &dec2net($networkDec);
	my $ip					= (split(/\//, $network))[0];

	unless ($ip =~ /^[\w\.\:]+$/) {
		$self->warnl("'$ip' is not a valid ip address!");
		return 0;
	}

	$self->{IP}	= $ip;

	eval {
		require Net::Nslookup;
	};
	if ($@) {
		$self->warnl("Error while loading module 'Net::Nslookup': $@");
		return 0;
	}

	my $ptr = Net::Nslookup->nslookup(host => $ip, type => "PTR");
	$ptr  ||= '';
	$self->{PTR}	= $ptr;

	return 1;
}

sub show {
	my $self	= shift;
	my $show	= {
		HEADER	=> sprintf(_gettext("DNS Info for %s"), $self->{IP}),
		BODY		=> [
			{
				elements	=> [
					{
						target	=> 'key',
						type		=> 'label',
						value		=> _gettext("Reverse DNS lookup"),
					},
					{
						target		=> 'value',
						type			=> 'label',
						value			=> $self->{PTR},
					}
				]
			},
		]
	};

	return $show;
}

1;
