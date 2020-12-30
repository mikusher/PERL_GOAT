package HaCi::Plugins::PingSNMPNetworks;

use strict;
use warnings;

use base qw/HaCi::Plugin/;
use HaCi::Mathematics qw/dec2net netv6Dec2net/;
use HaCi::Utils qw/netID2Stuff/;
use HaCi::GUI::gettext qw/_gettext/;
use HaCi::SnmpUtils qw/getSNMPSession getSNMPTree/;
use Net::Ping;

our $INFO	= {
	name				=> 'PingSNMPNetworks',
	version			=> '0.1',
	recurrent		=> 1,
	onDemand		=> 0,
	network			=> 1,
	description	=> _gettext('This Plugin will ping associated IP adresses and saves its status in DB. After that, it will collect the corresponding MAC addresses with SNMP from a specific router and save the result in DB, too. In the Output there were all IP addresses listed with their status and MAC address if available. With this method you catch all available Hosts, even if they deny ping.'),
	api					=> [
		{
			name	=> 'STATUS', 
			descr	=> _gettext("Ping Status of current ipaddress (dead|alive)"),
		},
		{
			name	=> 'MAC', 
			descr	=> _gettext('Mac Address related to the IP address'),
		},
	],
	globMenuRecurrent	=> [
		{
			TYPE			=> 'label',
			VALUE			=> 'Ping',
		},
		{
			NAME			=> 'ping_proto',
			DESCR			=> _gettext('Protocoll'),
			TYPE			=> 'popupmenu',
			VALUE			=> ['tcp', 'udp', 'icmp', 'stream', 'syn', 'external'],
			DEFAULT		=> 'tcp',
		},
		{
			NAME			=> 'ping_port',
			DESCR			=> _gettext('Port'),
			TYPE			=> 'textbox',
			SIZE			=> 3,
			MAXLENGTH	=> 5,
			VALUE			=> '7',
		},
		{
			NAME			=> 'ping_timeout',
			DESCR			=> _gettext('Timeout'),
			TYPE			=> 'textbox',
			SIZE			=> 3,
			MAXLENGTH	=> 10,
			VALUE			=> '5',
		},
		{
			NAME			=> 'ping_dataSize',
			DESCR			=> _gettext('Nr of Bytes (0-1024)'),
			TYPE			=> 'textbox',
			SIZE			=> 3,
			MAXLENGTH	=> 4,
			VALUE			=> '',
		},
	],
	menuRecurrent	=> [
		{
			TYPE			=> 'label',
			VALUE			=> 'SNMP',
		},
		{
			NAME			=> 'snmp_router',
			DESCR			=> _gettext('Router for SNMP-Connection'),
			TYPE			=> 'textbox',
			SIZE			=> 15,
			MAXLENGTH	=> 255,
			VALUE			=> '',
		},
		{
			NAME			=> 'snmp_port',
			DESCR			=> _gettext('Port'),
			TYPE			=> 'textbox',
			SIZE			=> 5,
			MAXLENGTH	=> 5,
			VALUE			=> 161,
		},
		{
			NAME			=> 'snmp_community',
			DESCR			=> _gettext('Community'),
			TYPE			=> 'textbox',
			SIZE			=> 10,
			MAXLENGTH	=> 64,
			VALUE			=> 'public',
		},
		{
			NAME			=> 'snmp_version',
			DESCR			=> _gettext('SNMP Version'),
			TYPE			=> 'textbox',
			SIZE			=> 6,
			MAXLENGTH	=> 6,
			VALUE			=> 'snmpv2',
		},
		{
			NAME			=> 'snmp_arp-table',
			DESCR			=> _gettext('SNMP ARP Table (ipNetToMediaPhysAddress)'),
			TYPE			=> 'textbox',
			SIZE			=> 15,
			MAXLENGTH	=> 64,
			VALUE			=> '.1.3.6.1.2.1.4.22.1.2',
		},
	],
};

sub run_recurrent {
	my $self			= shift;
	my $networks	= shift;
	my $config		= shift;

	&pingNetworks($self, $networks, $config);
	&getArpTable($self, $networks, $config);

	return 1;
}

sub getArpTable {
	my $self			= shift;
	my $networks	= shift;
	my $config		= shift;
	my $arpTable	= {};

	foreach (@$networks) {
		my $netID					= $_->{ID};
		my $origin				= $_->{origin};
		my $ipv6					= (exists $_->{ipv6} && $_->{ipv6}) ? 1 : 0;
		my $networkDec		= $_->{network};
		my $network				= ($ipv6) ? &netv6Dec2net($networkDec) : &dec2net($networkDec);
		my $ip						= (split(/\//, $network, 2))[0];
		my $host					= $config->{$origin || $netID}->{snmp_router} || '';
		my $comm					= $config->{$origin || $netID}->{snmp_community} || 'public';
		my $version				= $config->{$origin || $netID}->{snmp_version} || 'snmpv2';
		my $port					= $config->{$origin || $netID}->{snmp_port} || 161;
		my $snmpArpTable	= $config->{$origin || $netID}->{'snmp_arp-table'} || '.1.3.6.1.2.1.4.22.1.2';

		next unless $host;

		unless (exists $arpTable->{$host}) {
			my $session		= &getSNMPSession($host, $comm, {
				port 		=> $port,
				version	=> $version
			});
	
			unless (defined $session) {
				$self->warnl("Cannot initiate SNMP-Session for $host\n", 1);
				next;
			}
			$arpTable->{$host}	= &getSNMPTree($session, $snmpArpTable);
			$session->close();
		}
		
		my $ips	= {};
		foreach (keys %{$arpTable->{$host}}) {
			my $key	= $_;
			if ($key =~ /(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})$/) {
				$ips->{$1}	= $arpTable->{$host}->{$key};
			}
		}

		if (exists $ips->{$ip}) {
			my $mac		= '';
			my $cnter	= 2;
			while ($cnter < length($ips->{$ip})) {
				$mac .= ':' if $mac;
				$mac .= substr($ips->{$ip}, $cnter, 2);
				$cnter	+= 2;
			}

			$self->saveValue($netID, $origin, 'MAC', $mac);
		} else {
		}
	}

	return 1;
}

sub pingNetworks {
	my $self			= shift;
	my $networks	= shift;
	my $config		= shift;
	my $p;

	eval {
		$p	= Net::Ping->new(
			$config->{-1}->{ping_proto} || '',
			$config->{-1}->{ping_timeout} || '',
			$config->{-1}->{ping_dataSize}
		);
	};
	if ($@) {
		$self->warnl($@, 1);
		return 0;
	}

	$p->{port_num}	= $config->{-1}->{ping_port} if $config->{-1}->{ping_port};

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
		HEADER	=> "Ping/ARP Statistics (last updated: $lastUpdated)",
		BODY		=> [
			{
				elements	=> [
					{
						target	=> 'single',
						type		=> 'label',
						value		=> 'IP',
						bold		=> 1,
						align		=> 'center',
					},
					{
						target	=> 'single',
						type		=> 'label',
						value		=> 'Ping Status',
						bold		=> 1,
						align		=> 'center',
					},
					{
						target	=> 'single',
						type		=> 'label',
						value		=> _gettext('ARP Entry'),
						bold		=> 1,
						align		=> 'center',
					},
				]
			},
			{
				value => {
					type  	=> 'hline',
					colspan	=> 3,
				}
			},
		]
	};

	my $aliveCnter	= 0;
	my $macCnter		= 0;
	my $total				= 0;
	foreach (sort {$a<=>$b} keys %{$values}) {
		my $netID		= $_;
		my $name		= $values->{$netID}->{NAME} || '';
		my $mac			= $values->{$netID}->{MAC} || '';
		my $status	= $values->{$netID}->{STATUS} || 'dead';
		$aliveCnter++ if $status eq 'alive';
		$macCnter++ if $mac ne '';
		
		if ($name ne '') {
			$total++;
			push @{$show->{BODY}}, (
				{
					elements	=> [
						{
							target	=> 'key',
							type		=> 'label',
							value		=> $name,
						},
						{
							target	=> 'single',
							type		=> 'label',
							value		=> ($status eq 'alive') ? '<font color="#00AA00">alive</font>' : '<font color="#444444">dead</font>',
						},
						{
							target	=> 'value',
							type		=> 'label',
							value		=> "($mac)",
						},
					]
				},
			);
		}
	}

	my $percA	= sprintf("%.2i", (($aliveCnter * 100)/($total||1)));
	my $percM	= sprintf("%.2i", (($macCnter * 100)/($total||1)));
	push @{$show->{BODY}}, (
		{
			value => {
				type  	=> 'hline',
				colspan	=> 3,
			}
		},
		{
			elements	=> [
				{
					target	=> 'single',
					type		=> 'label',
					value		=> $total . ' ' . _gettext("IP addresses"),
					bold		=> 1,
				},
				{
					target	=> 'single',
					type		=> 'label',
					value		=> $aliveCnter . ' ' . _gettext("alive") . " ($percA%)",
					bold		=> 1,
				},
				{
					target	=> 'single',
					type		=> 'label',
					value		=> $macCnter . ' ' . _gettext("MACs found") . " ($percM%)",
					bold		=> 1,
				},
			]
		},
	);

	return $show;
}

1;
