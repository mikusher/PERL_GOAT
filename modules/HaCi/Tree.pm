package HaCi::Tree;

use strict;
use constant LOG2	=> log(2);

use HaCi::Mathematics qw/
	dec2net net2dec getBroadcastFromNet getIPFromDec dec2ip ip2dec netv6Dec2net
	netv6Dec2NextNetDec netv6Dec2ip netv6Dec2IpCidr ipv6DecCidr2netv6Dec getV6BroadcastIP
/;
use HaCi::Utils qw/checkSpelling_Net debug checkRight networkStateID2Name fillHoles nd dn quoteHTML/;
use HaCi::GUI::gettext qw/_gettext/;

our $conf; *conf  = \$HaCi::Conf::conf;

sub new {
	my $class = shift;
	my $self  = {CNTER => 0};

	bless $self, $class;
	return $self;
}

sub setNewRoot {
	my $self		= shift;
	my $rootID	= shift;

	if (exists $self->{TREE}->{$rootID}) {
		&debug("setNewRoot: This rootID '$rootID' allready exists!");
	} else {
		$self->{TREE}->{$rootID}->{ENABLED}	= 1;
	}
}

sub setRootName {
	my $self		= shift;
	my $rootID	= shift;
	my $name		= shift || '';

	if (exists $self->{TREE}->{$rootID}) {
		$self->{TREE}->{$rootID}->{NAME}	= $name;
	} else {
		&debug("setRootName: This rootID '$rootID' doesn't exists!");
	}
}

sub setRootDescr {
	my $self		= shift;
	my $rootID	= shift;
	my $descr		= shift;

	if (exists $self->{TREE}->{$rootID}) {
		$self->{TREE}->{$rootID}->{DESCR}	= $descr;
	} else {
		&debug("setRootDescr: This rootID '$rootID' doesn't exists!");
	}
}

sub setRootExpanded {
	my $self		= shift;
	my $rootID	= shift;
	my $bExp		= shift;

	if (exists $self->{TREE}->{$rootID}) {
		$self->{TREE}->{$rootID}->{EXPANDED}	= $bExp;
	} else {
		&debug("setRootExpanded: This rootID '$rootID' doesn't exists!");
	}
}

sub setRootParent {
	my $self		= shift;
	my $rootID	= shift;
	my $bParent	= shift;

	if (exists $self->{TREE}->{$rootID}) {
		$self->{TREE}->{$rootID}->{PARENT}	= $bParent;
	} else {
		&debug("setRootExpanded: This rootID '$rootID' doesn't exists!");
	}
}

sub setRootV6 {
	my $self		= shift;
	my $rootID	= shift;
	my $v6			= shift;

	if (exists $self->{TREE}->{$rootID}) {
		$self->{TREE}->{$rootID}->{V6}	= $v6;
	} else {
		&debug("setRootV6: This rootID '$rootID' doesn't exists!");
	}
}

sub addNet {
	my $self					= shift;
	my $netID					= shift;
	my $rootID				= shift;
	my $ipv6					= shift;
	my $networkDec		= shift;
	my $descr					= shift;
	my $status				= shift;
	my $parent				= shift || 0;
	my $bFillNet			= shift || 0;
	my $defSubnetSize	= shift || 0;
	my $network				= ($ipv6) ? &netv6Dec2net($networkDec) : &dec2net($networkDec);
	if ($ipv6) {
		my ($ipv6, $cidr)	= split/\//, $network;
		$network	= Net::IPv6Addr::to_string_preferred($ipv6) . '/' . $cidr;
	}

	unless (exists $self->{TREE}->{$rootID}) {
		&debug("setRootDescr: This rootID '$rootID' doesn't exists!");
		return 0;
	}

	unless (defined $network) {
		&debug("addNetwork: you don't give me a network!");
		return 0;
	}

	unless (&checkSpelling_Net($network, $ipv6)) {
		&debug("addNetwork: This doesn't look like a network: $network");
		return 0;
	}

	if (exists $self->{TREE}->{$rootID}->{NETWORKS}->{$networkDec}) {
		&debug("addNetwork: There exists allready such a network '$rootID:$network'");
	}
	
	$self->{TREE}->{$rootID}->{NETWORKS}->{$networkDec}	= {
		NETID					=> $netID,
		NETPARENT			=> $parent,
		IPV6					=> $ipv6,
		NETWORK				=> $network,
		DESCR					=> (defined $descr) ? $descr : '',
		STATUS				=> &networkStateID2Name($status),
		FILLNET				=> (defined $bFillNet && $bFillNet) ? 1 : 0,
		DEFSUBNETSIZE	=> $defSubnetSize,
	};
}

sub setNetExpanded {
	my $self				= shift;
	my $rootID			= shift;
	my $ipv6				= shift;
	my $networkDec	= shift;
	my $bExp				= shift;

	if (exists $self->{TREE}->{$rootID}) {
		if (exists $self->{TREE}->{$rootID}) {
			$self->{TREE}->{$rootID}->{NETWORKS}->{$networkDec}->{EXPANDED}	= $bExp;
		} else {
			my $network	= ($ipv6) ? &netv6Dec2net($networkDec) : &dec2net($networkDec);
			&debug("setNetExpanded: This network '$network' doesn't exists!");
		}
	} else {
		&debug("setNetExpanded: This rootID '$rootID' doesn't exists!");
	}
}

sub setNetParent {
	my $self				= shift;
	my $rootID			= shift;
	my $ipv6				= shift;
	my $networkDec	= shift;
	my $bParent			= shift;

	if (exists $self->{TREE}->{$rootID}) {
		if (exists $self->{TREE}->{$rootID}) {
			$self->{TREE}->{$rootID}->{NETWORKS}->{$networkDec}->{PARENT}	= $bParent;
		} else {
			my $network	= ($ipv6) ? &netv6Dec2net($networkDec) : &dec2net($networkDec);
			&debug("setNetParent: This network '$network' doesn't exists!");
		}
	} else {
		&debug("setNetParent: This rootID '$rootID' doesn't exists!");
	}
}

sub setInvisible {
	my $self				= shift;
	my $rootID			= shift;
	my $ipv6				= shift;
	my $networkDec	= shift;
	my $bInv				= shift;

	if (exists $self->{TREE}->{$rootID}) {
		if (exists $self->{TREE}->{$rootID}) {
			$self->{TREE}->{$rootID}->{NETWORKS}->{$networkDec}->{INVISIBLE}	= $bInv;
		} else {
			my $network	= ($ipv6) ? &netv6Dec2net($networkDec) : &dec2net($networkDec);
			&debug("setInvisible: This network '$network' doesn't exists!");
		}
	} else {
		&debug("setInvisible: This rootID '$rootID' doesn't exists!");
	}
}

sub checkNetworkHoles {
	my $self						= shift;
	my $rootID					= shift;
	my $ipv6						= shift;
	my $networkDecStart	= shift;
	my $broadcastEnd		= shift;
	my $nextNetDec			= ($ipv6) ? &netv6Dec2NextNetDec($broadcastEnd, 128) : &net2dec(&dec2ip(&getIPFromDec($broadcastEnd) + 1) . '/32');
	my $lastNetDec			= ($ipv6) ? $networkDecStart->copy() : $networkDecStart;
	my @netst						= keys %{$self->{TREE}->{$rootID}->{NETWORKS}};
	my @nets						= ();
	my $defSubnetSize		= 0;

	if ($ipv6) {
		@nets	= sort {Math::BigInt->new($a)<=>Math::BigInt->new($b)} @netst;
	} else {
		@nets	= sort {$a<=>$b} @netst;
	}

	foreach (@nets) {
		my $networkDec	= ($ipv6) ? Math::BigInt->new($_) : $_;
		next if $networkDec < $networkDecStart;
		last if $networkDec > $broadcastEnd;
		next if $networkDecStart != $self->{TREE}->{$rootID}->{NETWORKS}->{$networkDec}->{NETPARENT};

		$defSubnetSize		= ($lastNetDec == $networkDecStart) ? 
			((exists $self->{TREE}->{$rootID}->{NETWORKS}->{$lastNetDec}) ? $self->{TREE}->{$rootID}->{NETWORKS}->{$lastNetDec}->{DEFSUBNETSIZE} : 0) :
			((exists $self->{TREE}->{$rootID}->{NETWORKS}->{$networkDecStart}) ? $self->{TREE}->{$rootID}->{NETWORKS}->{$networkDecStart}->{DEFSUBNETSIZE} : 0);

		foreach (&fillHoles($lastNetDec, $networkDec, $ipv6, $defSubnetSize)) {
			&addNet($self, -1, $rootID, $ipv6, $_, '', 0, 1, $networkDecStart, 0);
		}

		$lastNetDec	= ($ipv6) ? &netv6Dec2NextNetDec($networkDec, 0) : &net2dec(&dec2ip(&getBroadcastFromNet($networkDec) + 1) . '/0');
	}

	foreach (&fillHoles($lastNetDec, $nextNetDec, $ipv6, $defSubnetSize)) {
		&addNet($self, -1, $rootID, $ipv6, $_, '', 0, 1, $networkDecStart, 0);
	}
}

sub print_html {
	my $self				= shift;
	my $html				= [];
	my $session			= $HaCi::HaCi::session;

	my $sortBox	= {};
	foreach (keys %{$self->{TREE}}) {
		my $rootID						= $_;
		my $rootName					= $self->{TREE}->{$rootID}->{NAME} || '';
		$sortBox->{$rootName}	= $rootID;
	}

	foreach (sort keys %{$sortBox}) {
		my $rootName	= $_;
		my $rootID		= $sortBox->{$rootName};
		my $tmp				= &print_html_root($self, $rootID);
		my $networks	= &print_html_networks($self, $rootID);
		@{$tmp->{networks}}	= @{$networks};
		push @{$html}, $tmp;
	}
	return $html;
}

sub print_html_root {
	my $self					= shift;
	my $rootID				= shift;
	my $rootName			= &quoteHTML($self->{TREE}->{$rootID}->{NAME}) || '???';
	my $rootDescr			= &quoteHTML($self->{TREE}->{$rootID}->{DESCR}) || '';
	my $rootExpanded	= $self->{TREE}->{$rootID}->{EXPANDED};
	my $rootParent		= $self->{TREE}->{$rootID}->{PARENT};
	my $ipv6					= $self->{TREE}->{$rootID}->{V6};
	my $rootColor			= $self->{user}->{gui}->{colors}->{root};
	my $bEditTree			= (defined $HaCi::HaCi::q->param('editTree') && $HaCi::HaCi::q->param('editTree')) ? 1 : 0;
	my $bShowRoot			= &checkRight('showRootDet');
	my $thisScript		= $conf->{var}->{thisscript} || '';

	my $picUrl	= (($rootExpanded) ? 'reduceRoot' : 'expandRoot') . "(['args__$rootID', 'args__$bEditTree', 'NO_CACHE'], ['$rootID'], 'POST');";
	my $root	= {
		space			=> 0,
		ID				=> $rootID,
		name			=> $rootName,
		descr			=> $rootDescr,
		expanded	=> $rootExpanded,
		parent		=> $rootParent,
		picTitle	=> sprintf(_gettext((($rootExpanded) ? 'Reduce ' : 'Expand ') . "Root '%s'"), $rootName),
		picUrl		=> $picUrl,
		rootUrl		=> ($bShowRoot) ? "$thisScript?func=showRoot&rootID=$rootID" : '',
		rootPic		=> ($ipv6) ? 'ipv6.png' : '',
		rootAlt		=> ($ipv6) ? 'IPv6' : '',
		color			=> $rootColor,
		ipv6			=> $ipv6,
	};

	return $root;
}

sub print_html_networks {
	my $self						= shift;
	my $rootID					= shift;
	my $newLevel				= shift || 0;
	my $origNetworkDec	= shift || 0;
	my $networks				= [];
	my $ipv6						= $self->{TREE}->{$rootID}->{V6};
	$origNetworkDec			= Math::BigInt->new($origNetworkDec) if $ipv6;

	my $thisScript			= $conf->{var}->{thisscript} || '';
	my $session					= $HaCi::HaCi::session;
	my $bEditTree				= (defined $HaCi::HaCi::q->param('editTree') && $HaCi::HaCi::q->param('editTree')) ? 1 : 0;
	my $bShowNet				= &checkRight('showNetDet');
	my $bAddNet					= &checkRight('addNet');
	my $level						= 1 + $newLevel;
	my $offset					= 19;
	my $lastBroadcast		= 0;
	my $lastCidr				= 0;
	my $parentBroadcast	= 0;
	my $parentCidr			= 0;
	my @broadcasts			= ();
	my @parentCidrs			= ();
	my $bNoDiv					= 0;
	my @netst						= keys %{$self->{TREE}->{$rootID}->{NETWORKS}};
	my @nets						= ();
	if ($ipv6) {
		@nets	= sort {Math::BigInt->new($a)<=>Math::BigInt->new($b)} @netst;
	} else {
		@nets	= sort {$a<=>$b} @netst;
	}

	my $netCnter			= 0;
	my $lastParents		= {};
	my $parentMarker	= {};
	foreach (@nets) {
		my $networkDec		= $_;
		my $network				= $self->{TREE}->{$rootID}->{NETWORKS}->{$networkDec}->{NETWORK};
		my $netID					= $self->{TREE}->{$rootID}->{NETWORKS}->{$networkDec}->{NETID};
		my $descr					= &quoteHTML($self->{TREE}->{$rootID}->{NETWORKS}->{$networkDec}->{DESCR});
		my $expanded			= $self->{TREE}->{$rootID}->{NETWORKS}->{$networkDec}->{EXPANDED};
		my $parent				= $self->{TREE}->{$rootID}->{NETWORKS}->{$networkDec}->{PARENT};
		my $fillNet				= $self->{TREE}->{$rootID}->{NETWORKS}->{$networkDec}->{FILLNET} || 0;
		my $status				= $self->{TREE}->{$rootID}->{NETWORKS}->{$networkDec}->{STATUS} || 'assigned';
		my $invisible			= $self->{TREE}->{$rootID}->{NETWORKS}->{$networkDec}->{INVISIBLE} || 0;
		my $defSubnetSize	= $self->{TREE}->{$rootID}->{NETWORKS}->{$networkDec}->{DEFSUBNETSIZE} || 0;
		$ipv6							= $self->{TREE}->{$rootID}->{NETWORKS}->{$networkDec}->{IPV6};
		my $bJumpTo				= (defined $session->param('jumpTo') && $session->param('jumpToNet') == $networkDec && $session->param('jumpToRoot') == $rootID) ? 1 : 0;
		$networkDec				= Math::BigInt->new($networkDec) if $ipv6;
		my $broadcast			= ($ipv6) ? &getV6BroadcastIP($networkDec) : &getBroadcastFromNet($networkDec);
		my $lastNet				= 1 if $netCnter++ == $#nets;

		my ($ipaddressDec, $cidr);
		if ($ipv6) {
			($ipaddressDec, $cidr)	= &netv6Dec2IpCidr($networkDec);
		} else {
			(my $ipaddress, $cidr)	= split/\//, $network;
			$ipaddressDec						= &ip2dec($ipaddress);
		}

		my $netColor			= '#' . (
			($invisible) ? $conf->{user}->{gui}->{colors}->{network}->{invisible} : 
			($fillNet) ? $conf->{user}->{gui}->{colors}->{network}->{new} : 
			($conf->{user}->{gui}->{colors}->{network}->{(lc($status))}) ? $conf->{user}->{gui}->{colors}->{network}->{(lc($status))} : $conf->{user}->{gui}->{colors}->{network}->{assigned});
		$netColor					= '#000000' unless $netColor;

		my $bgColor				= ($bJumpTo) ? $conf->{user}->{gui}->{colors}->{network}->{searched} : '';
		if ($lastBroadcast > $ipaddressDec) {
			$level++;
			push @broadcasts, $lastBroadcast;
			$parentBroadcast	= $lastBroadcast;
			push @parentCidrs, $lastCidr;
			$parentCidr				= $lastCidr;
		} else {
			foreach (reverse @broadcasts) {
				if ($_ < $ipaddressDec) {
					$level--;
					$parentBroadcast	= pop @broadcasts;
					$parentCidr				= pop @parentCidrs;
					my $net						= pop @{$networks};
					$net->{parentBroadcast}	= 1;
					push @{$networks}, $net;
				}
			}
		}
		
		if ($fillNet && $cidr == (($ipv6) ? 128 : 32)) {
			if (!($ipaddressDec % (2 ** ((($ipv6) ? 128 : 32) - $parentCidr)))) {
				$descr	= '[netaddress]';
				$netColor	= '#' . $conf->{user}->{gui}->{colors}->{network}->{netborder};
			}
			elsif ($parentBroadcast == $ipaddressDec) {
				$descr	= '[broadcast]';
				$netColor	= '#' . $conf->{user}->{gui}->{colors}->{network}->{netborder};
			}
		}
		
		my $picUrl	= ($invisible) ? '' : (($expanded) ? 'reduceNetwork' : 'expandNetwork') . "(['args__$rootID', 'args__$networkDec', 'args__" . ($level - 1) . "', 'args__$bEditTree', 'NO_CACHE'], ['${rootID}.$networkDec'], 'POST');showStatus(1);";
		$bNoDiv		= 1 if $networkDec == $origNetworkDec;
		my $statePic	= 0;
		my $stateAlt	= '';
		if (uc($status) eq 'LOCKED') {
			$statePic	= 'key_small.png';
			$stateAlt	= _gettext("This Network is locked");
		}
		elsif (uc($status) eq 'RESERVED') {
			$statePic	= 'reserved_small.png';
			$stateAlt	= _gettext("This Network is reserved");
		}
		elsif (uc($status) eq 'FREE') {
			$statePic	= 'free_small.png';
			$stateAlt	= _gettext("This Network is free");
		}

		$lastParents->{$level}			= $netCnter;
		$parentMarker->{$netCnter}	= $level if $parent && $level > ($newLevel + 1);
		my $lastParent	= 0;
		if ($origNetworkDec == $networkDec) {
# don't set lastParent, because it doesn't work probably
			$lastParent	= 0; #($HaCi::HaCi::netcache->{GUI}->{$rootID}->{$origNetworkDec}->{LASTPARENT}) ? $level : 0;
		}

		push @{$networks}, {
			rootID			=> $rootID,
			space				=> $level * $offset,
			level				=> $level,
			network			=> $network,
			networkDec	=> $networkDec,
			descr				=> ($invisible) ? _gettext("[ permission denied ]") : $descr,
			expanded		=> $expanded,
			parent			=> ($invisible) ? 0 : $parent,
			fillNet			=> $fillNet,
			picTitle		=> sprintf(_gettext((($expanded) ? 'Reduce ' : 'Expand ') . "Network '%s'"), $network),
			picUrl			=> $picUrl,
			netUrl			=> 
				($invisible) ? '' : 
				($fillNet && $bAddNet) ?  "a('addNet', 0, '$rootID', '$networkDec', 1);" : 
				(!$fillNet && $bShowNet) ?  "a('showNet', '$netID', 0, 0, 0);" : '',
			color				=> $netColor,
			bgColor			=> $bgColor,
			noDiv				=> ($networkDec == $origNetworkDec) ? 1 : 0,
			statePic		=> $statePic,
			stateAlt		=> $stateAlt,
			invisible		=> $invisible,
			ipv6				=> $ipv6,
			editPic			=> 'edit_small.png',
			editAlt			=> _gettext('Edit'),
			editNetUrl	=> "a('editNet', '$netID',0,0,0);",
			delPic			=> 'del_small.png',
			delAlt			=> _gettext('Delete'),
			delNetUrl		=> "a('delNet', '$netID',0,0,0);",
			defSubnetSize	=> $defSubnetSize,
			gettext_defSubnetSize	=> _gettext("Default Subnet CIDR"),
			lastNet			=> $lastNet,
			lastParent	=> $lastParent,
			GUINetCache	=> ((exists $HaCi::HaCi::netcache->{GUI}->{$rootID}->{$networkDec}->{noLines}) ? $HaCi::HaCi::netcache->{GUI}->{$rootID}->{$networkDec}->{noLines} : []),
		};
		$lastBroadcast	= $broadcast;
		$lastCidr				= $cidr;
	}

	foreach (sort {$a<=>$b} keys %{$parentMarker}) {
		my $netCnter	= $_;
		my $level			= $parentMarker->{$netCnter};
		my $net				= ${$networks}[($netCnter - 1)];
		if ($lastParents->{$level} == $netCnter) {
# don't set lastParent, because it doesn't work probably
			$net->{lastParent}						= 0; #$level;
			${$networks}[($netCnter - 1)]	= $net;
			$HaCi::HaCi::netcache->{GUI}->{$rootID}->{$net->{networkDec}}->{LASTPARENT}	= 1;
		} else {
			$HaCi::HaCi::netcache->{GUI}->{$rootID}->{$net->{networkDec}}->{LASTPARENT}	= 0;
		}
	}

	if ($level > 1) {
		my $net									= pop @{$networks};
		$net->{parentBroadcast}	= ($level - 1);
		$net->{parentBroadcast}-- if $bNoDiv;
		push @{$networks}, $net;
	}
	return $networks;
}

1;
