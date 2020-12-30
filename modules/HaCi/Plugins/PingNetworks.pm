package HaCi::Plugins::PingNetworks;

use strict;
use warnings;

use base qw/HaCi::Plugin/;
use HaCi::Mathematics qw/dec2net netv6Dec2net/;
use HaCi::Utils qw/netID2Stuff/;
use HaCi::GUI::gettext qw/_gettext/;
use Net::Ping;

our $INFO	= {
	name				=> 'PingNetworks',
	version			=> '0.2',
	recurrent		=> 1,
	onDemand		=> 0,
	description	=> _gettext('This Plugin runns recurrent in background and pings all associated IP addresses. In the Output it will display all IP addresses with their Status.'),
	api					=> [
		{
			name	=> 'STATUS', 
			descr	=> _gettext('Ping Status of current ipaddress (dead|alive)'),
		},
	],
	globMenuRecurrent		=> [
		{
			NAME			=> 'proto',
			DESCR			=> 'Protocoll',
			TYPE			=> 'popupmenu',
			VALUE			=> ['tcp', 'udp', 'icmp', 'stream', 'syn', 'external'],
			DEFAULT		=> 'tcp',
		},
		{
			NAME			=> 'port',
			DESCR			=> 'Port',
			TYPE			=> 'textbox',
			SIZE			=> 3,
			MAXLENGTH	=> 5,
			VALUE			=> '7',
		},
		{
			NAME			=> 'timeout',
			DESCR			=> 'Timeout',
			TYPE			=> 'textbox',
			SIZE			=> 3,
			MAXLENGTH	=> 10,
			VALUE			=> '5',
		},
		{
			NAME			=> 'dataSize',
			DESCR			=> 'Nr of Bytes (0-1024)',
			TYPE			=> 'textbox',
			SIZE			=> 3,
			MAXLENGTH	=> 4,
			VALUE			=> '',
		},
	],
};

sub run_recurrent {
	my $self			= shift;
	my $networks	= shift;
	my $config		= shift;
	my $p;

	eval {
		$p	= Net::Ping->new(
			$config->{-1}->{proto} || '',
			$config->{-1}->{timeout} || '',
			$config->{-1}->{dataSize}
		);
	};
	if ($@) {
		$self->warnl($@, 1);
		return 0;
	}

	$p->{port_num}	= $config->{-1}->{port} if $config->{-1}->{port};

	my $lastUpdatedCheck	= {};
	foreach (@$networks) {
		my $netID				= $_->{ID};
		my $origin			= $_->{origin};
		my $ipv6				= (exists $_->{ipv6} && $_->{ipv6}) ? 1 : 0;
		my $networkDec	= $_->{network};
		my $network			= ($ipv6) ? &netv6Dec2net($networkDec) : &dec2net($networkDec);
		my $ip					= (split(/\//, $network, 2))[0];

		$self->saveValue($netID, $origin, 'NAME', $network);
		$self->saveValue(-1, $origin, 'lastUpdated', scalar localtime) unless exists $lastUpdatedCheck->{$origin};
		eval {
			if ($p->ping($ip)) {
				$self->saveValue($netID, $origin, 'STATUS', 'alive');
			} else {
				$self->saveValue($netID, $origin, 'STATUS', 'dead');
			}
		};
		if ($@) {
			$self->warnl($@, 1);
			next;
		}
	}

	return 1;
}

sub show {
	my $self				= shift;
	my $netID				= shift;
	my $values			= $self->getValues($netID);
	my $results			= {};
	my $lastUpdated	= $self->getValue(-1, 'lastUpdated');
	my $show	= {
		HEADER	=> "Ping Statistics (last updated: $lastUpdated)",
		BODY		=> [
		]
	};

	foreach (sort {$a<=>$b} keys %{$values}) {
		my $netID		= $_;
		my $name		= $values->{$netID}->{NAME};
		my $status	= $values->{$netID}->{STATUS};
		
		push @{$show->{BODY}}, (
			{
				elements	=> [
					{
						target	=> 'key',
						type		=> 'label',
						value		=> $name,
					},
					{
						target	=> 'value',
						type		=> 'label',
						value		=> ($status eq 'alive') ? '<font color="#00AA00">alive</font>' : '<font color="#444444">dead</font>',
					},
				]
			},
		) if $name ne '';
	}

	return $show;
}

1;
