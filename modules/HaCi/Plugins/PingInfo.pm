package HaCi::Plugins::PingInfo;

use strict;
use warnings;

use HaCi::Mathematics qw/dec2net/;
use HaCi::GUI::gettext qw/_gettext/;

require Exporter;
our @ISA        = qw(Exporter);
our @EXPORT_OK  = qw( $INFO );

our $INFO	= {
	name				=> 'PingInfo',
	version			=> '0.1',
	onDemand		=> 1,
	recurrent		=> 0,
	description	=> _gettext('This Plugins pings the current IP adress on Demand and displays its status.'),
};

sub new {
	my $class	= shift;
	my $self	= {};

	bless $self, $class;

	return $self;
}

sub run_onDemand {
	my $self				= shift;
	my $networkRef	= shift;
	my $networkDec  = $networkRef->{network};
	my $network     = ($networkRef->{ipv6ID}) ? &netv6Dec2net($networkDec) : &dec2net($networkDec);
	my $ip					= (split(/\//, $network, 2))[0];

	unless ($ip =~ /^[\w\:\.]+$/) {
		&warnl($self, "This IP '$ip' is not a valid IP Address!");
		return 0;
	}
	
	$self->{IP}	= $ip;

	eval {
		require Net::Ping;
	};

	if ($@) {
		&warnl($self, "Error while loading module 'Net::Ping': $@");
		return 0;
	}
	my $p	= Net::Ping->new();
	$self->{ALIVE}	= ($p->ping($ip)) ? 1 : 0;
	$p->close();
}

sub show {
	my $self	= shift;

	my $show = {
		HEADER	=> sprintf(_gettext("Ping Info for %s"), $self->{IP}),
		BODY		=> [
			{
				elements	=> [
					{
						target	=> 'key',
						type		=> 'label',
						value		=> _gettext("Status of Host"),
					},
					{
						target		=> 'value',
						type			=> 'label',
						value			=> (($self->{ALIVE}) ? _gettext("Alive") : _gettext('Dead')),
						color			=> (($self->{ALIVE}) ? '#00AA00' : '#AA0000'),
					}
				]
			},
		]
	};

	return $show;
}

sub warnl {
	my $self		= shift;
	my $msg			= shift;
	my $toUser	= shift;
	$toUser			= 0 unless defined $toUser;

	unless ($toUser) {
		warn $msg;
		return;
	}

	$self->{ERRORSTR}	.= "\n" if $self->{ERROR};
	$self->{ERROR}		= 1;
	$self->{ERRORSTR}	.= $msg;
}

1;
