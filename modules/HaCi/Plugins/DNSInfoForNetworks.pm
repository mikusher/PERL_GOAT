package HaCi::Plugins::DNSInfoForNetworks;

use strict;
use warnings;

use base qw/HaCi::Plugin/;
use HaCi::Mathematics qw/dec2net netv6Dec2net/;
use HaCi::Utils qw/netID2Stuff/;
use HaCi::GUI::gettext qw/_gettext/;

our $INFO	= {
	name				=> 'DNSInfoForNetworks',
	version			=> '0.2',
	recurrent		=> 1,
	onDemand		=> 0,
	description	=> _gettext('This Plugin runs recurrent in background and collects DNS PTR-Records for its associated IP Addresses an saves them in DB. In the Output will all IP Adresses be listet with their corresponding PTR-Records.'),
	api					=> [
		{
			name	=> 'PTR', 
			descr	=> _gettext('DNS PTR-Record for current IP address'),
		},
	],
};

sub run_recurrent {
	my $self			= shift;
	my $networks	= shift;
	my $config		= shift;

	eval {
		require Net::Nslookup;
	};
	if ($@) {
		$self->warnl("Error while loading module 'Net::Nslookup': $@");
		return 0;
	}
	
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

		my $ptr	= '';
		eval {
			$ptr = Net::Nslookup->nslookup(host => $ip, type => "PTR");
		};
		if ($@) {
			$self->warnl("Error while running Net::Nslookup(host => $ip, type => 'PTR'): $@");
			next;
		}

		$ptr  ||= '';
		$self->saveValue($netID, $origin, 'PTR', $ptr);
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
		HEADER	=> "DNS Records (Last updated: $lastUpdated)",
		BODY		=> [
		]
	};

	foreach (sort {$a<=>$b} keys %{$values}) {
		my $netID		= $_;
		my $name		= $values->{$netID}->{NAME} || '';
		my $ptr			= $values->{$netID}->{PTR} || '';
		
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
						value		=> $ptr,
					},
				]
			},
		) if $name ne '';
	}

	return $show;
}

1;
