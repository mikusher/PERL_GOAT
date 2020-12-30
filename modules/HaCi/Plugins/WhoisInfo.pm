package HaCi::Plugins::WhoisInfo;

use strict;
use warnings;
use base qw/HaCi::Plugin/;

use HaCi::Mathematics qw/dec2net netv6Dec2net/;
use HaCi::GUI::gettext qw/_gettext/;

our $conf; *conf  = \$HaCi::Conf::conf;
our $INFO	= {
	name			=> 'WhoisInfo',
	version		=> '0.1',
	onDemand	=> 1,
	description	=> _gettext('This Plugin queries on Demand a whois directory service for the current network and displays the Result.'),
};

sub run_onDemand {
	my $self				= shift;
	my $networkRef	= shift;
	my $networkDec	= $networkRef->{network};
	my $network			= ($networkRef->{ipv6ID}) ? &netv6Dec2net($networkDec) : &dec2net($networkDec);

	unless ($network =~ /^[\w\:\.\/]+$/) {
		$self->warnl("This '$network' doesn't look like a network!");
		return 0;
	}

	unless (-x $conf->{static}->{path}->{whois}) {
		$self->warnl("Whois Executable not found! ($conf->{static}->{path}->{whois})");
		return 0;
	}
	
	my @whois = qx($conf->{static}->{path}->{whois} $network);
	my $route = 0;
	foreach (@whois) {
		push @{$self->{data}}, {key =>$1, value => $2} if $self->{inetnum} && /^([\w\-]+):\s+(.*)$/;
		$self->{inetnum} = $1	if /^inet6?num:\s+(.*)$/ || /^CIDR:\s+(.*)$/;
		last									if $self->{inetnum} && /^\s*$/;
	}

	return 1;
}

sub show {
	my $self	= shift;
	my $show	= {};

	foreach (@{$self->{data}}) {
		push @{$show->{BODY}}, {
			elements  => [
				{
					target  => 'key',
					type    => 'label',
					value   => $_->{key},
				},
				{
					target    => 'value',
					type      => 'label',
					value     => $_->{value},
				}
			]
		};
	}

	$show->{HEADER}	= sprintf(_gettext("Whois Info for %s"), $self->{inetnum});

	return $show;
}

1;
