package HaCi::Utils;

use warnings;
use strict;
use File::Temp qw/tempfile/;
use Net::IPv6Addr;
use Time::Local;
use Config::General qw(ParseConfig);
use Net::CIDR;
use Digest::SHA;
use Encode;
use Encode::Guess;
use HTML::Entities;
use POSIX qw(strftime);
use Data::Dumper qw/Dumper/;

#use Time::HiRes qw/gettimeofday tv_interval/;
#my $t0	= undef;

use HaCi::Conf qw/getConfigValue/;
use HaCi::Mathematics qw/
	net2dec dec2net ip2dec dec2ip getCidrFrom2IPs getBroadcastFromNet getNetmaskFromCidr 
	getNetaddress getCidrFromNetmask getIPFromDec ipv62dec ipv6Parts2NetDec  netv6Dec2PartsDec
	getV6BroadcastIP getV6BroadcastNet netv6Dec2ip ipv62Dec2 ipv6Dec2ip netv6Dec2net netv62Dec
	netv6Dec2IpCidr ipv6DecCidr2netv6Dec netv6Dec2NextNetDec ipv6DecCidr2NetaddressV6Dec
/;
use HaCi::Authentication::internal qw/getCryptPassword lwe bin2dec/;
use HaCi::GUI::gettext qw/_gettext/;
use HaCi::Log qw/warnl debug/;
use HaCi::Importer::Cisco;
use HaCi::Importer::Juniper;
use HaCi::Importer::Foundry;

require Exporter;
our @ISA				= qw(Exporter);
our @EXPORT_OK	= qw(
	warnl debug importCSV compare checkDB newWindow prNewWindows getID getStatus setStatus
	addRoot addNet getRoots checkSpelling_Net importASNRoutes getNextDBNetwork getConfig
	getWHOISData getNSData rootID2Name rootName2ID getNrOfChilds getMaintInfosFromRoot
	getMaintInfosFromNet editRoot delNet genRandBranch delRoot copyNetsTo delNets search
	checkSpelling_IP checkSpelling_CIDR networkStateName2ID networkStateID2Name getNetworkTypes
	getTemplate saveTmpl prWarnl getTemplateEntries tmplID2Name delTmpl getTemplateData
	getGroups getGroup saveGroup groupID2Name delGroup getUsers getUser userID2Name saveUser
	currDate lwd dec2bin checkRight importDNSTrans importDNSLocal fillHoles _gettext getParam
	netID2Stuff getNetworkParentFromDB importConfig delUser getRights parseCSVConfigfile
	removeStatus expand splitNet combineNets getDBNetworkBefore getNetID getPlugins updatePluginDB
	getPluginsForNet pluginID2Name getTable checkTables updatePluginLastRun rootID2ipv6
	checkRootACL checkNetACL checkNetworkACTable netv6Dec2ipv6ID getPluginInfos getPluginConfMenu
	mkPluginConfig getNetworksForPlugin getPluginConfValues getNetworkChilds initTables initCache
	finalizeTables getPluginLastRun pluginName2ID getPluginValue getHaCidInfo nd dn quoteHTML
	getFreeSubnets pluginID2File chOwnPW getSettings userName2ID updSettings updateSettingsInSession
	flushACLCache flushNetCache getConfigValue tmplName2ID tmplEntryDescr2EntryID searchAndGetFreeSubnets
);

our $conf; *conf  = \$HaCi::Conf::conf;

sub prWarnl {
	warn 'SUB: ' . (caller(0))[3] . ' (' . (caller(1))[3] . ")\n" if $conf->{var}->{showsubs};
	my $plain			= shift || 0;
	my $t					= $HaCi::GUI::init::t;
	my $ret				= ($plain) ? '' : 0;
	
	if ($#{$conf->{var}->{warnl}} > -1) {
		$ret	= ($plain) ? join('', @{$conf->{var}->{warnl}}) : 1;
		map {s/\\n/\n/g;$_ = &quoteHTML($_)} @{$conf->{var}->{warnl}};

		$t->{V}->{warnlHeader}	= _gettext("Infos / Warnings / Errors");
		push @{$t->{V}->{warnlMenu}}, (
			{
				elements	=> [
					{
						target	=> 'single',
						type		=> 'label',
						width		=> 500,
						align		=> 'left',
						value		=> '<pre>' . join("\n", @{$conf->{var}->{warnl}}) . '</pre>'
					},
				]
			},
			{
				value	=> {
					type		=> 'hline'
				}
			},
			{
				elements	=> [
					{
						target	=> 'single',
						type		=> 'buttons',
						align		=> 'center',
						buttons	=> [
							{
								name		=> 'statusInfoCloser',
								onClick	=> "hideWarnl()",
								value		=> '1',
								img			=> 'cancel_small.png',
								picOnly	=> 1,
								title		=> _gettext("Close Info"),
							},
						],
					},
				]
			}
		);
	}

	return $ret;
}

sub checkSpelling_Net {
	warn 'SUB: ' . (caller(0))[3] . ' (' . (caller(1))[3] . ")\n" if $conf->{var}->{showsubs};

	my $net		= shift;
	my $ipv6	= shift;

	if ($net =~ /([\w\.\:]+)\/(\d{1,3})/) {
		return 0 unless &checkSpelling_IP($1, $ipv6);
		return 0 unless &checkSpelling_CIDR($2, $ipv6);
		return 1;
	} else {
		return 0;
	}
}

sub checkSpelling_IP {
	warn 'SUB: ' . (caller(0))[3] . ' (' . (caller(1))[3] . ")\n" if $conf->{var}->{showsubs};
	my $address	= shift;
	my $ipv6		= shift;

	if ($ipv6) {
		eval {
			Net::IPv6Addr::ipv6_parse($address)
		};
		if ($@) {
			warn $@;
			return 0;
		} else {
			return 1;
		}
	} else {
		if ($address =~ /^(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})$/) {
			foreach (split/\./, $1) {
				return 0 if $_  < 0 || $_ > 255;
			}
			return 1;
		} else {
			return 0;
		}
	}
}

sub checkSpelling_CIDR {
	warn 'SUB: ' . (caller(0))[3] . ' (' . (caller(1))[3] . ")\n" if $conf->{var}->{showsubs};

	my $cidr	= shift;
	my $ipv6	= shift;

	if ($ipv6) {
		if ($cidr =~ /^(\d{1,3})$/) {
			return 0 if $1  < 0 || $1 > 128;
			return 1;
		} else {
			return 0;
		}
	} else {
		if ($cidr =~ /^(\d{1,2})$/) {
			return 0 if $1  < 0 || $1 > 32;
			return 1;
		} else {
			return 0;
		}
	}
}

sub addRoot {
	warn 'SUB: ' . (caller(0))[3] . ' (' . (caller(1))[3] . ")\n" if $conf->{var}->{showsubs};
	my $name			= shift;
	my $descr			= shift;
	my $ipv6			= shift;
	my $rootID		= shift;
	my $q					= $HaCi::HaCi::q;
	my $session		= $HaCi::HaCi::session;
	my $editRoot	= (defined $q->param('editRoot') && $q->param('editRoot')) ? 1 : 0;
	my $bImp			= (defined $q->param('submitImportASNRoutes') && $q->param('submitImportASNRoutes')) ? 1 : 0;
	$bImp				||= (defined $q->param('submitImportDNS') && $q->param('submitImportDNS')) ? 1 : 0;
	$descr			||= '';
	$ipv6				||= 0;

	unless (defined $name && $name) {
		&warnl(sprintf(_gettext("Sorry, you have to give me a %s!"), 'name'));
		return 0;
	}

	my $rootTable	= $conf->{var}->{TABLES}->{root};
	unless (defined $rootTable) {
		warn "Cannot add Route. DB Error (root)\n";
		return 0;
	}
	$rootTable->clear();
	$rootTable->name($name);
	$rootTable->description($descr);
	$rootTable->ipv6($ipv6);

	if (defined $rootID && $rootID) {
		my $root	= ($rootTable->search(['ID', 'name'], {ID => $rootID}))[0];
		if (defined $root && !$editRoot) {
			&warnl(sprintf(_gettext("Sorry, this Root '%s' allready exists!"), $root->{name}));
			return 0;
		}
		$rootTable->modifyFrom($session->param('username'));
		$rootTable->modifyDate(&currDate('datetime'));
		unless ($rootTable->update({ID => $rootID})) {
			&warnl("Cannot update Root: " . $rootTable->errorStrs, $bImp);
			return 0;
		}
	} else {
		my $DBROOT	= ($rootTable->search(['ID', 'name'], {name => $name}))[0];
		if (defined $DBROOT) {
			unless ($editRoot) {
				&warnl(sprintf(_gettext("Sorry, this Root '%s' allready exists!"), $DBROOT->{name}));
				return 0;
			}
			$rootTable->modifyFrom($session->param('username'));
			$rootTable->modifyDate(&currDate('datetime'));
			&debug("Change Root-Entry for '$name'\n");
			unless ($rootTable->update({ID => $DBROOT->{'ID'}})) {
				&warnl("Cannot update Root: " . $rootTable->errorStrs, $bImp);
				return 0;
			}
		} else {
			$rootTable->ID(undef);
			$rootTable->createFrom($session->param('username'));
			$rootTable->createDate(&currDate('datetime'));
			unless ($rootTable->insert()) {
				&warnl("Cannot insert new Root: " . $rootTable->errorStrs, $bImp);
				return 0;
			}
		}
	}
	$rootID	= &rootName2ID($name);
	my $errors	= '';
	my $rootACTable	= $conf->{var}->{TABLES}->{rootAC};
	unless (defined $rootACTable) {
		warn "Cannot add Root ACL. DB Error (rootAC)\n";
	} else {
		my @acls	= $rootACTable->search(['ID', 'groupID'], {rootID => $rootID});
		foreach (@acls) {
			$rootACTable->clear();
			unless ($rootACTable->delete({ID => $_->{ID}})) {
				$errors	.= $rootACTable->errorStrs() unless $bImp;
			}
			&removeACLEntry($rootID, 'root', $_->{groupID});
		}
		&warnl($errors) if $errors;

		my $box	= {};
		foreach (split(/, /, $session->param('groupIDs'))) {
			s/\D//g;
			$box->{$_}	= 3;
		}

		foreach ($q->param) {
			if (/accGroup_([rwi])_(\d+)/) {
				my $right		= $1;
				my $groupID	= $2;
				if ($right eq 'i') {
					$box->{$groupID}	= 0;
				} else {
					$box->{$groupID} += ($right eq 'r') ? 1 : ($right eq 'w') ? 2 : 0;
				}
			}
		}

		$errors	= '';
		foreach (keys %{$box}) {
			$rootACTable->clear();
			$rootACTable->rootID($rootID);
			$rootACTable->ID(undef);
			$rootACTable->groupID($_);
			$rootACTable->ACL($box->{$_});
			unless ($rootACTable->insert()) {
				$errors	.= $rootACTable->errorStrs unless $bImp;
			}
			&removeACLEntry($rootID, 'root', $_);
		}
		&warnl("Errors while setting Root ACLs: " . $errors, $bImp) if $errors;
	}

	warn "Successfully created Root $name";
	
	return 1;
}

sub currDate {
	warn 'SUB: ' . (caller(0))[3] . ' (' . (caller(1))[3] . ")\n" if $conf->{var}->{showsubs};

	my $type	= shift;
	my $time	= shift;

	if ($type eq 'datetime') {
		return strftime "%F %T", ((defined $time) ? localtime($time) : localtime);
	}
}

sub addNet {
	warn 'SUB: ' . (caller(0))[3] . ' (' . (caller(1))[3] . ")\n" if $conf->{var}->{showsubs};
	my $netID					= shift;
	my $rootID				= shift;
	my $netaddress		= shift;
	my $cidr					= shift;
	my $descr					= shift;
	my $state					= shift;
	my $tmplID				= shift;
	my $defSubnetSize	= shift || 0;
	my $forceState		= shift || 0;
	my $q							= $HaCi::HaCi::q;
	my $session				= $HaCi::HaCi::session;
	my $bImp					= (defined $q->param('submitImportASNRoutes') && $q->param('submitImportASNRoutes')) ? 1 : 0;
	$bImp						||= (defined $q->param('submitImpDNSTrans') && $q->param('submitImpDNSTrans')) ? 1 : 0;
	$bImp						||= (defined $q->param('submitImpDNSLocal') && $q->param('submitImpDNSLocal')) ? 1 : 0;
	$bImp						||= (defined $q->param('submitImpConfig') && $q->param('submitImpConfig')) ? 1 : 0;
	$bImp						||= (defined $q->param('submitImpCSV') && $q->param('submitImpCSV')) ? 1 : 0;
	my $onlyNew				= (defined $q->param('onlyNew') && $q->param('onlyNew')) ? 1 : 0;
	my $editNet				= (defined $q->param('editNet') && $q->param('editNet')) ? 1 : 0;
	my @netPluginActives	= (defined $q->param('netPluginActives')) ? $q->param('netPluginActives') : ();
	my @netPluginNewLines	= (defined $q->param('netPluginNewLines')) ? $q->param('netPluginNewLines') : ();
	my $rootInfos  				= &getMaintInfosFromRoot($rootID);
	my $ipv6							= $rootInfos->{ipv6};
	my $ipv6ID						= '';
	eval {
		$netaddress						= Net::IPv6Addr::to_string_preferred($netaddress) if $ipv6 && $netaddress =~ /::/;
	};
	if ($@) {
		&warnl($@);
		return 0;
	}

	unless (&checkSpelling_IP($netaddress, $ipv6)) {
		&warnl("This Netaddress '$netaddress' is incorrect!");
		return 0;
	}

	unless (&checkSpelling_CIDR($cidr, $ipv6)) {
		&warnl("This Cidr '$cidr' is incorrect!");
		return 0;
	}

	my $networkTable	= $conf->{var}->{TABLES}->{network};
	unless (defined $networkTable) {
		warn "Cannot add Network. DB Error (network)\n";
		return 0;
	}
	my $networkV6Table	= $conf->{var}->{TABLES}->{networkV6};
	unless (defined $networkV6Table) {
		warn "Cannot add NetworkV6. DB Error (networkV6)\n";
		return 0;
	}

	unless (defined $rootID && $rootID) {
		&warnl(sprintf(_gettext("Sorry, you have to give me a %s!"), 'rootID'), $bImp);
		return 0;
	}

	unless (defined $netaddress && $netaddress) {
		&warnl(sprintf(_gettext("Sorry, you have to give me a %s!"), 'netaddress'), $bImp);
		return 0;
	}

	$cidr	= (($ipv6) ? 128 : 32) unless defined $cidr;

	my $netaddressT	= ($ipv6) ? &ipv6Dec2ip(&ipv6DecCidr2NetaddressV6Dec(&ipv62dec($netaddress), $cidr)) : &dec2ip(&getNetaddress($netaddress, &getNetmaskFromCidr($cidr)));
	if ($ipv6) {
		eval {
			$netaddressT	= Net::IPv6Addr::to_string_preferred($netaddressT);
			$netaddress		= Net::IPv6Addr::to_string_preferred($netaddress);
		};
		if ($@) {
			&warnl($@);
			return 0;
		}
	}

	if (lc($netaddress) ne lc($netaddressT)) {
		&warnl(sprintf(_gettext("Sorry, this is not a correct Network: %s!"), $netaddress . '/' . $cidr), $bImp);
		return 0;
	}
	my $network	= $netaddress	 . '/' . $cidr;

	&debug((($editNet) ? 'Edit' : 'Add') . " Network $network on " . &rootID2Name($rootID));

	unless (&checkSpelling_Net($network, $ipv6)) {
		&warnl(sprintf(_gettext("Sorry, this doesn't look like a %s: '%s'!"), 'network', $network), $bImp);
		return 0;
	}
	my $networkDec	= ($ipv6) ? &netv62Dec($network) : &net2dec($network);

	if ($bImp) {
		$ipv6ID		= Net::IPv6Addr::to_string_base85($netaddress) . sprintf("%x", $cidr) if $ipv6;
		my $DBNET	= ($networkTable->search(['ID'], {rootID => $rootID, network => (($ipv6) ? 0 : $networkDec), ipv6ID => $ipv6ID}))[0];
		if (defined $DBNET) {
			$editNet	= 1 unless $onlyNew;
			$netID		= $DBNET->{ID};
		}
	}

	unless ($forceState) {
		return 0 unless &checkStateRules($netID, $rootID, $networkDec, $state, $cidr, $ipv6);
	}

	if ($editNet) {
		if (defined $netID) {
			my ($rootID, $networkDec, undef)	= &netID2Stuff($netID);
			my $network												= ($ipv6) ? &netv6Dec2net($networkDec) : &dec2net($networkDec);

			unless (&checkNetACL($netID, 'w')) {
				&warnl(sprintf(_gettext("Not enough rights to edit this Network '%s'"), $network), $bImp);
				return 0;
			}
			unless ($q->param('submitImpCSV')) {
				&debug("Flushing Cache for: " . &rootID2Name($rootID));
				&removeFromNetcache($rootID);
			}
		} else {
			&warnl("Without a netID I cannot edit this Net!", $bImp);
			return 0;
		}
	}

	unless ($editNet) {
		my $parent			= &getNetworkParentFromDB($rootID, $networkDec);
		my $parentDec		= (defined $parent) ? $parent->{network} : 0;
		my $parentID		= (defined $parent) ? $parent->{ID} : 0;
	
		unless (($parentID && &checkNetACL($parentID, 'w')) || (!$parentID && &checkRootACL($rootID, 'w'))) {
			my $parent	= ($ipv6) ? &netv6Dec2net($parentDec) : &dec2net($parentDec);
			&warnl(sprintf(_gettext("Not enough rights to add this Network '%s' under '%s'"), $network, $parent), $bImp);
			return 0;
		}
	}

	if ($ipv6) {
		my $networkV6Table	= $conf->{var}->{TABLES}->{networkV6};
		unless (defined $networkV6Table) {
			warn "Cannot add NetworkV6. DB Error (networkV6)\n";
			return 0;
		}

		$ipv6ID						= Net::IPv6Addr::to_string_base85($netaddress) . sprintf("%x", $cidr);
		my ($net, $host)	= &HaCi::Mathematics::ipv62dec2($netaddress);

		$networkV6Table->clear();
		$networkV6Table->ID($ipv6ID);
		$networkV6Table->rootID($rootID);
		$networkV6Table->networkPrefix($net);
		$networkV6Table->hostPart($host);
		$networkV6Table->cidr($cidr);
	}

	$networkTable->clear();
	$networkTable->rootID($rootID);
	$networkTable->network(($ipv6) ? 0 : $networkDec);
	$networkTable->description($descr);
	$networkTable->state($state);
	$networkTable->tmplID($tmplID);
	$networkTable->ipv6ID($ipv6ID);
	$networkTable->defSubnetSize($defSubnetSize);

	my $origTmplID	= undef;
	if ($editNet) {
		my $DBNET	= ($networkTable->search(['ID', 'tmplID', 'ipv6ID'], {ID => $netID}))[0];
		unless (defined $DBNET) {
			&warnl("Cannot update Net: No such Network exists ($netID)", $bImp);
			return 0;
		}
		$origTmplID	= $DBNET->{'tmplID'};
		$networkTable->modifyFrom($session->param('username'));
		$networkTable->modifyDate(&currDate('datetime'));
		unless ($networkTable->update({ID => $netID})) {
			&warnl("Cannot update Net: " . $networkTable->errorStrs, $bImp);
			return 0;
		}
		if ($ipv6) {
			unless (defined $DBNET) {
				&warnl("Cannot update Net: No such Network exists ($netID)", $bImp);
				return 0;
			}
			unless ($networkV6Table->update({ID => $DBNET->{'ipv6ID'}, rootID => $rootID})) {
				&warnl("Cannot update V6 Net: " . $networkV6Table->errorStrs, $bImp);
				return 0;
			}
		}
		unless ($q->param('submitImpCSV')) {
			&debug("Flushing Cache for: " . &rootID2Name($rootID));
			&removeFromNetcache($rootID);
		}
	} else {
		my $DBNET	= ($networkTable->search(['ID'], {network => $networkDec, rootID => $rootID, ipv6ID => $ipv6ID}))[0];
		if (defined $DBNET) {
			&warnl(sprintf(_gettext("This Network '%s' allready exists!"), $network), $bImp);
			return 0;
		}

		$networkTable->ID(undef);
		$networkTable->createFrom($session->param('username'));
		$networkTable->createDate(&currDate('datetime'));
		unless ($networkTable->insert()) {
			&warnl("Cannot add Net: " . $networkTable->errorStrs, $bImp);
			return 0;
		}
		if ($ipv6) {
			unless ($networkV6Table->insert()) {
				&warnl("Cannot add V6 Net: " . $networkV6Table->errorStrs, $bImp);
				return 0;
			}
		}
		unless ($q->param('submitImpCSV')) {
			&debug("Flushing Cache for: " . &rootID2Name($rootID));
			&removeFromNetcache($rootID);
		}
	}

	$netID	= &getNetID($rootID, $networkDec, $ipv6ID) unless $editNet;

	my $networkACTable	= $conf->{var}->{TABLES}->{networkAC};
	unless (defined $networkACTable) {
		warn "Cannot add Network ACL. DB Error (networkAC)\n";
	} else {
		my @acls	= $networkACTable->search(['ID', 'groupID'], {netID => $netID});
		my $errors			= '';
		foreach (@acls) {
			&debug("Deleting NetworkACL ID: " . $_->{ID} . "\n");
			my $groupID	= $_->{groupID};

			$networkACTable->clear();
			unless ($networkACTable->delete({ID => $_->{ID}})) {
				$errors	.= $networkACTable->errorStrs() unless $bImp;
			}
			&removeACLEntry($netID, 'net', $groupID);
		}
		&warnl($errors) if $errors;

		my $box	= {};
		foreach (split(/, /, $session->param('groupIDs'))) {
			s/\D//g;
			my $acl			= &checkNetACL($netID, 'ACL', $_);
			$box->{$_}	= ($acl == 3) ? -1 : 3;
		}

		foreach ($q->param('accGroup')) {
			my $groupID	= $_;
			my $acl			= &checkNetACL($netID, 'ACL', $groupID);
			$box->{$groupID}	= 0;
			foreach ('r', 'w') {
				my $right	= $_;
				if ($q->param('accGroup_' . $right . '_' . $groupID)) {
					$box->{$groupID} += (($right eq 'r') ? 1 : (($right eq 'w') ? 2 : 0));
				}
			}
			$box->{$groupID} = -1 if $box->{$groupID} == $acl;
		}

		$errors	= '';
		foreach (keys %{$box}) {
			my $groupID	= $_;
			next if $box->{$groupID} == -1;

			$networkACTable->clear();
			$networkACTable->netID($netID);
			$networkACTable->ID(undef);
			$networkACTable->groupID($groupID);
			$networkACTable->ACL($box->{$_});
			unless ($networkACTable->insert()) {
				$errors	.= $networkACTable->errorStrs unless $bImp;
			}
			&removeACLEntry($netID, 'net', $groupID);
		}
		&warnl("Errors while setting Network ACLs: " . $errors, $bImp) if $errors;
	}

	if ($tmplID) {
		my $tmplValueTable	= $conf->{var}->{TABLES}->{templateValue};
		unless (defined $tmplValueTable) {
			warn "Cannot add Template Value. DB Error (templateValue)\n";
			return 0;
		}

		foreach ($q->param) {
			if (/^tmplEntryID_(\d+)$/) {
				my $tmplEntryID	= $1;
				next unless $tmplEntryID;
				$tmplValueTable->clear();
				$tmplValueTable->netID($netID);
				$tmplValueTable->tmplID($tmplID);
				$tmplValueTable->tmplEntryID($tmplEntryID);
				$tmplValueTable->value(&getParam(1, '', $q->param('tmplEntryID_' . $tmplEntryID)));

				my $DB	= ($tmplValueTable->search(['ID'], {netID => $netID, tmplID	=> $tmplID, tmplEntryID => $tmplEntryID}))[0];
				if ($DB) {
					&debug("Change Template-Value for '$rootID:$network $tmplID:$tmplEntryID'\n");
					unless ($tmplValueTable->update({ID => $DB->{'ID'}})) {
						&warnl("Cannot update Template Value: " . $tmplValueTable->errorStrs);
						return 0;
					}
				} else {
					$tmplValueTable->ID(undef);
					unless ($tmplValueTable->insert()) {
						&warnl("Cannot add Template Value: " . $tmplValueTable->errorStrs);
						return 0;
					}
				}
			}
		}
	}

	if (defined $origTmplID && $origTmplID != $tmplID && $origTmplID) {
		my $tmplValueTable	= $conf->{var}->{TABLES}->{templateValue};
		unless (defined $tmplValueTable) {
			warn "Cannot remove old Template Values. DB Error (templateValue)\n";
			return 1;
		}
		my @oldEntries	= $tmplValueTable->search(['ID'], {netID => $netID, tmplID => $origTmplID});
		my $errors			= '';
		foreach (@oldEntries) {
			&debug("Deleting Template Value for ID: " . $_->{ID} . "\n");
			$tmplValueTable->errorStrs('');
			unless ($tmplValueTable->delete({ID => $_->{ID}})) {
				$errors	.= $tmplValueTable->errorStrs();
			}
		}
		&warnl($errors) if $errors;
	}

	my $networkPluginTable	= $conf->{var}->{TABLES}->{networkPlugin};
	unless (defined $networkPluginTable) {
		warn "Cannot update PluginDB. DB Error (networkPlugin)\n";
		return 0;
	}
	$networkPluginTable->clear();

	my $netPlugins		= {};
	my $availPlugins	= &getPlugins();
	my $pluginsForNet	= &getPluginsForNet($netID);
	foreach (keys %{$pluginsForNet}) {
		$netPlugins->{$_}->{ACTIVE}	= 1;# unless $availPlugins->{$_}->{DEFAULT};
	}
	my $errors	= '';
	foreach (@netPluginActives) {
		my $pluginID		= $_;
		my $pluginOrder	= &getParam(1, 0, $q->param('pluginOrder_' . $pluginID));
		my $entry				= ($networkPluginTable->search(['ID'], {netID => $netID, pluginID => $pluginID}))[0];

		$networkPluginTable->clear();
		$networkPluginTable->netID($netID);
		$networkPluginTable->pluginID($pluginID);
		$networkPluginTable->sequence($pluginOrder);
		$networkPluginTable->newLine(scalar grep {/^$pluginID$/} @netPluginNewLines);
		unless (defined $entry) {
			&debug("Adding Plugin '$availPlugins->{$pluginID}->{NAME}' for network '$network'\n");
			unless ($networkPluginTable->insert()) {
				$errors	.= "Cannot insert Network Plugin Entry for '$availPlugins->{$pluginID}->{NAME}': " . $networkPluginTable->errorStrs();
			}
		} else {
			my $ID	= $entry->{ID};
			&debug("Updating Plugin '$availPlugins->{$pluginID}->{NAME}' for network '$network'\n");
			unless ($networkPluginTable->update({ID => $ID})) {
				$errors	.= "Cannot update Network Plugin Entry for '$availPlugins->{$pluginID}->{NAME}': " . $networkPluginTable->errorStrs();
			}
		}
		delete $netPlugins->{$pluginID};
	}
	foreach (keys %{$netPlugins}) {
		my $pluginID	= $_;
		my $entry			= ($networkPluginTable->search(['ID'], {netID => $netID, pluginID => $pluginID}))[0];

		if (defined $entry) {
			&debug("Deleting Plugin '$availPlugins->{$pluginID}->{NAME}' from network '$network'\n");
			$networkPluginTable->clear();
			$networkPluginTable->delete({netID => $netID, pluginID => $pluginID});
			if ($networkPluginTable->error) {
				$errors .= '\n' . sprintf(_gettext("Error while deleting '%s' from '%s': %s"), $availPlugins->{$pluginID}->{NAME}, $network, $networkPluginTable->errorStrs);
			}
		}
	}

	&warnl($errors) if $errors;
	
	return 1;
}

sub getRoots {
	warn 'SUB: ' . (caller(0))[3] . ' (' . (caller(1))[3] . ")\n" if $conf->{var}->{showsubs};
	my $rootTable	= $conf->{var}->{TABLES}->{root};
	unless (defined $rootTable) {
		warn "Cannot get Roots. DB Error (root)\n";
		return [];
	}
	my @rootst	= $rootTable->search(['ID', 'name', 'ipv6']);
	my $rootst	= {};
	foreach (@rootst) {
		$rootst->{$_->{name}}	= {
			ID		=> $_->{ID},
			ipv6	=> $_->{ipv6},
		};
	}

	my $roots	= [];
	foreach (sort keys %{$rootst}) {
		push @$roots, {
			name	=> $_, 
			ID		=> $rootst->{$_}->{ID},
			ipv6	=> $rootst->{$_}->{ipv6},
		};
	}
	
	return $roots;
}

sub importASNRoutes {
	warn 'SUB: ' . (caller(0))[3] . ' (' . (caller(1))[3] . ")\n" if $conf->{var}->{showsubs};
	my $asn			= shift;
	my $q				= $HaCi::HaCi::q;
	my $delOld	= (defined $q->param('delOld') && $q->param('delOld')) ? 1 : 0;
	$asn				= 'AS' . $asn unless $asn =~ /^AS/;
	my $status	= $conf->{var}->{STATUS};
	$status->{TITLE} = "Importing Routes for '$asn'..."; $status->{STATUS} = 'Runnung...'; $status->{PERCENT} = 0; &setStatus();

	unless ($asn =~ /^AS\d{1,5}$/) {
		&warnl(sprintf(_gettext("Sorry, this doesn't look like a %s: '%s'!"), 'AS Number', $asn));
		return 0;
	}

	my $rootTable	= $conf->{var}->{TABLES}->{root};
	unless (defined $rootTable) {
		warn "Cannot import ASNRoutes. DB Error (root)\n";
		return 0;
	}

	my $root		= ($rootTable->search(['ID'], {name => $asn}))[0];
	my $rootV6	= ($rootTable->search(['ID'], {name => $asn . '_IPv6'}))[0];
	if ($delOld) {
		$status->{DATA}	= 'removing old Roots'; $status->{PERCENT}	= 1; &setStatus();
		if (defined $root && exists $root->{ID}) {
			return 0 unless &delRoot($root->{ID});
			$root		= ($rootTable->search(['ID'], {name => $asn}))[0];
		}
		if (defined $rootV6 && exists $rootV6->{ID}) {
			return 0 unless &delRoot($rootV6->{ID});
			$rootV6	= ($rootTable->search(['ID'], {name => $asn . '_IPv6'}))[0];
		}
	}

	$status->{DATA}	= "Getting ASR Name for '$asn'";$status->{PERCENT}	= 5; &setStatus();
	my $asnName	= &getASRName($asn);
	unless (defined $root && exists $root->{ID}) {
		unless (&addRoot($asn, $asnName)) {
			warn "AddRoot failed!\n";
			return 0;
		}
	}

	unless (defined $rootV6 && exists $rootV6->{ID}) {
		unless (&addRoot($asn . '_IPv6', $asnName . ' (IPv6)', 1)) {
			warn "AddRoot failed!\n";
			return 0;
		}
	}

	my $rootID	= {
		V4	=> &rootName2ID($asn),
		V6	=> &rootName2ID($asn . '_IPv6'),
	};

	$status->{DATA}	= "Getting Routes for '$asnName'";$status->{PERCENT}	= 10; &setStatus();
	my $box					= &getASRoutes($asn);
	my $nrOfRoutes	= 0;
	my $nrOfINs			= 0;
	my $nrOfSaves		= 0;
	my @routes			= keys %{$box};
	
	my $ipv4Used	= 0;
	my $ipv6Used	= 0;
	foreach (@routes) {
		my $route	= $_;
		my $ipv6	= $box->{$route}->{IPV6};
		my $descr	= $box->{$route}->{DESCR};
		my $state	= &networkStateName2ID(&getRouteState($route));
		$nrOfINs++;

		if ($ipv6) {
			$ipv6Used	= 1;
		} else {
			$ipv4Used	= 1;
		}
	
		my $statPerc		= (10 + int((90 / ($#routes + 1)) * $nrOfRoutes));
		$status->{DATA}	= "Getting Inetnums for '$route'";$status->{PERCENT}	= $statPerc; &setStatus();
		$nrOfRoutes++;
		&debug("found Route: $route");
		my ($na, $c)	= split/\//, $route;
		$nrOfSaves++ if &addNet(0, $rootID->{(($ipv6) ? 'V6' : 'V4')}, $na, $c, $descr, $state, 0, 0, 1);

		my $box				= &getInetnums($route, $ipv6);
		my @inets			= keys %{$box};
		my $statCnter	= 0;
		foreach (@inets) {
			my $inetnum	= $_;
			my @cidrs		= Net::CIDR::range2cidr($inetnum);
			foreach (@cidrs) {
				my ($from, $cidr)	= split/\//, $_, 2;
				$statCnter++;
				$nrOfINs++;
				&debug("found Inetnum: $from/$cidr");
				my $statPerc1		= (100 / ($#inets + 1)) * $statCnter;
				$status->{DATA}	= "Saving Inetnum '$from/$cidr'";$status->{PERCENT}	= int($statPerc + ((1 / ($#routes + 1)) * $statPerc1)); &setStatus();
				next unless &addNet(0, $rootID->{(($ipv6) ? 'V6' : 'V4')}, $from, $cidr, $box->{$inetnum}->{DESCR}, &networkStateName2ID($box->{$inetnum}->{STATUS}), 0, 0, 1);
				$nrOfSaves++;
			}
		}
	}

	unless ($ipv4Used) {
		my $root	= ($rootTable->search(['ID'], {name => $asn}))[0];
		$rootTable->delete({ID => $root->{ID}}) if defined $root && exists $root->{ID};
	}
	unless ($ipv6Used) {
		my $rootV6	= ($rootTable->search(['ID'], {name => $asn . '_IPv6'}))[0];
		$rootTable->delete({ID => $rootV6->{ID}}) if defined $rootV6 && exists $rootV6->{ID};
	}

	&warnl(sprintf(_gettext("%i Routes found. Saved %i new Inetnums of %i found"), $nrOfRoutes, $nrOfSaves, $nrOfINs));
	
	$status->{STATUS}	= 'FINISH'; $status->{DATA}	= ''; $status->{PERCENT} = 100; &setStatus();
	return 1;
}

sub getRouteState {
	warn 'SUB: ' . (caller(0))[3] . ' (' . (caller(1))[3] . ")\n" if $conf->{var}->{showsubs};
	my $route		= shift;

	return '' unless $route =~ /^[\w\.:\/]+$/;
	
	unless (-x $conf->{static}->{path}->{whois}) {
		&warnl(sprintf(_gettext("Program Whois '%s' isn't executable"), $conf->{static}->{path}->{whois}));
		return '';
	}
	my @whois	= qx($conf->{static}->{path}->{whois} -h $conf->{static}->{misc}->{ripedb} -- $route);

	foreach (@whois) {
		return $1	if /^status:\s+(.*)$/;
	}
	return '';
}

sub getASRName {
	warn 'SUB: ' . (caller(0))[3] . ' (' . (caller(1))[3] . ")\n" if $conf->{var}->{showsubs};
	my $asn		= shift;

	return '' unless $asn =~ /^AS\d+$/;
	
	unless (-x $conf->{static}->{path}->{whois}) {
		&warnl(sprintf(_gettext("Program Whois '%s' isn't executable"), $conf->{static}->{path}->{whois}));
		return '';
	}
	my @whois	= qx($conf->{static}->{path}->{whois} -h $conf->{static}->{misc}->{ripedb} -- $asn);

	foreach (@whois) {
		return $1	if /^as-name:\s+(.*)$/;
	}
	return '';
}

sub getASRoutes {
	warn 'SUB: ' . (caller(0))[3] . ' (' . (caller(1))[3] . ")\n" if $conf->{var}->{showsubs};
	my $asn		= shift;

	return {} unless $asn =~ /^AS\d+$/;
	
	unless (-x $conf->{static}->{path}->{whois}) {
		&warnl(sprintf(_gettext("Program Whois '%s' isn't executable"), $conf->{static}->{path}->{whois}));
		return {};
	}
	my @whois	= qx($conf->{static}->{path}->{whois} -h $conf->{static}->{misc}->{ripedb} -- -i origin $asn);
	my $route	= 0;
	my $box		= {};
	foreach (@whois) {
		$route									= $1	if /^route6?:\s+(.*)$/;
		$box->{$route}->{DESCR}	= $1	if /^descr:\s+(.*)$/;
		$box->{$route}->{IPV6}	= 1		if /^route6:\s+/;
	}
	return $box;
}

sub getInetnums {
	warn 'SUB: ' . (caller(0))[3] . ' (' . (caller(1))[3] . ")\n" if $conf->{var}->{showsubs};
	my $route		= shift;
	my $ipv6		= shift;

	return {} unless &checkSpelling_Net($route, $ipv6);
	
	unless (-x $conf->{static}->{path}->{whois}) {
		&warnl(sprintf(_gettext("Program Whois '%s' isn't executable"), $conf->{static}->{path}->{whois}));
		return {};
	}
	my @whois		= qx($conf->{static}->{path}->{whois} -h $conf->{static}->{misc}->{ripedb} -- -M $route);
	my $inetnum	= 0;
	my $box			= {};
	foreach (@whois) {
		$inetnum										= $1 if /^inet6?num:\s+(.*)$/;
		$box->{$inetnum}->{DESCR}		= $1 if /^netname:\s+(.*)$/;
		$box->{$inetnum}->{STATUS}	= $1 if /^status:\s+(.*)$/;
	}
	return $box;
}

sub importDNSTrans {
	warn 'SUB: ' . (caller(0))[3] . ' (' . (caller(1))[3] . ")\n" if $conf->{var}->{showsubs};
	my $q							= $HaCi::HaCi::q;
	my $nsServer			= &getParam(1, '', $q->param('nameserver'));
	my $domain				= &getParam(1, '', $q->param('domain'));
	my $status				= &getParam(1, 0, $q->param('state'));
	my $origin				= &getParam(1, '', $q->param('origin'));
	my $targetRootID	= &getParam(1, -1, $q->param('targetRoot'));
	my $stat					= $conf->{var}->{STATUS};
	$stat->{TITLE}		= "Importing DNS Zonefile from Server '$nsServer'";$stat->{STATUS}	= 'Running...'; $stat->{PERCENT}	= 0; &setStatus();

	unless ($nsServer =~ /^[\d\w\.\-]+$/) {
		&warnl(sprintf(_gettext("Sorry, this doesn't look like a %s: '%s'!"), 'Nameserver', $nsServer));
		$stat->{DATA}	= ""; $stat->{PERCENT} = 100; $stat->{STATUS} = 'ERROR'; &setStatus();
		return 0;
	}

	unless ($domain =~ /^[\d\w\.\-]+$/) {
		&warnl(sprintf(_gettext("Sorry, this doesn't look like a %s: '%s'!"), 'Domain', $domain));
		$stat->{DATA}	= ""; $stat->{PERCENT} = 100; $stat->{STATUS} = 'ERROR'; &setStatus();
		return 0;
	}
	
	my $zoneFile	= &zoneTrans($nsServer, $domain);
	if ($#{$zoneFile} < 0) {
		$stat->{DATA}	= ""; $stat->{PERCENT} = 100; $stat->{STATUS} = 'ERROR'; &setStatus();
		return 0;
	}

	my $r	= &parseZonefile($zoneFile, $domain, $status, $origin, $targetRootID);
	$stat->{DATA}	= ""; $stat->{PERCENT} = 100; $stat->{STATUS} = 'FINISH'; &setStatus();
	return $r;
}

sub zoneTrans {
	warn 'SUB: ' . (caller(0))[3] . ' (' . (caller(1))[3] . ")\n" if $conf->{var}->{showsubs};
	my $nsServer	= shift;
	my $domain		= shift;
	my $zoneFile	= [];

	&debug("Retrieving Zonefile '$domain' from '$nsServer'");

	eval {
		require Net::DNS;
	};
	if ($@) {
		warn $@;
		return []
	} else {
		open OLDOUT, ">&STDOUT";
		open STDOUT, ">&STDERR";

		my $res	= Net::DNS::Resolver->new(
			debug	=> $conf->{static}->{misc}->{debug},
		);
		$res->tcp_timeout(10);
		$res->udp_timeout(10);
		$res->nameservers($nsServer);
				  
		my @zone = $res->axfr($domain);
		unless (@zone) {
			&warnl(sprintf(_gettext("Zone transfer failed: %s"), $res->errorstring));
		} else {
			foreach my $rr (@zone) {
				push @$zoneFile, $rr->string;
			}
		}

		close STDOUT;
		open STDOUT, ">&OLDOUT";
		close OLDOUT;

		return $zoneFile;
	}
}

sub importConfig {
	warn 'SUB: ' . (caller(0))[3] . ' (' . (caller(1))[3] . ")\n" if $conf->{var}->{showsubs};
	my $q							= $HaCi::HaCi::q;
	my $file					= &getParam(1, undef, $q->param('config'));
	my $source				= &getParam(1, undef, $q->param('source'));
	my $state					= &getParam(1, 0, $q->param('state'));
	my $targetRootID	= &getParam(1, -1, $q->param('targetRoot'));
	my $configFile		= '';
	my $data					= '';
	my $session				= $HaCi::HaCi::session;
	my $status				= $conf->{var}->{STATUS};
	$status->{DATA}		= "Retrieving File '$file'";$status->{STATUS}	= 'Running...'; $status->{PERCENT}	= 0; &setStatus();

	unless (defined $file) {
		&warnl(_gettext("No File given!"));
		$q->delete('source');
		return 0;
	}

	unless (defined $source) {
		&warnl(_gettext("No source given!"));
		$q->delete('source');
		return 0;
	}

	unless (binmode $file) {
		&warnl(sprintf(_gettext("Cannot open File in Binmode: %s"), $!));
		$q->delete('source');
		return 0;
	}

	while(read $file,$data,1024) {
		$configFile	.= $data;
	}

	my ($rootName, $box)	= ();
	if ($source eq 'csv') {
		my $id	= $session->id();
		unless (open EXPORT, '>' . $conf->{static}->{path}->{spoolpath} . '/' . "$id.tmp") {
			&warnl("Cannot open Temp File '$conf->{static}->{path}->{spoolpath}/$id.tmp' for writing: $!");
			return 0;
		}
		print EXPORT $configFile;
		close EXPORT;
		$conf->{var}->{exportID}	= $id;
		return 0;
	}
	elsif ($source eq 'cisco') {
		my $ic	= new HaCi::Importer::Cisco;
		$ic->config($configFile);
		$ic->status($state);
		($rootName, $box)	= $ic->parse();
		if ($ic->error) {
			&warnl('Error (HaCi::Importer::Cisco): ' . _gettext($ic->errorStr));
			return 0;
		}
	}
	elsif ($source eq 'juniper') {
		my $ij	= new HaCi::Importer::Juniper;
		$ij->config($configFile);
		$ij->status($state);
		($rootName, $box)	= $ij->parse();
		if ($ij->error) {
			&warnl('Error (HaCi::Importer::Juniper): ' . _gettext($ij->errorStr));
			return 0;
		}
	}
	elsif ($source eq 'foundry') {
		my $if	= new HaCi::Importer::Foundry;
		$if->config($configFile);
		$if->status($state);
		($rootName, $box)	= $if->parse();
		if ($if->error) {
			&warnl('Error (HaCi::Importer::Foundry): ' . _gettext($if->errorStr));
			return 0;
		}
	}

	$rootName		= (($targetRootID == -1) ? $rootName : &rootID2Name($targetRootID));
	$rootName		=~ s/_v6$//;
	$rootName	||= $file;
	my @cnter	= (0, 0);
	if ($#$box > -1) {
		my $rootID		= -1;
		my $rootIDv4	= &rootName2ID($rootName) || -1;
		my $rootIDv6	= &rootName2ID($rootName . '_v6') || -1;
		my $v4				= 1;
		foreach my $entry (@$box) {
			if ($entry->{ip} =~ /^[\d\.]+$/) {
				if ($rootIDv4 == -1) {
					unless (&addRoot($rootName)) {
						warn "AddRoot failed!\n";
						return 0;
					}
					$rootIDv4	= &rootName2ID($rootName);
				}
				$rootID	= $rootIDv4;
				$v4			= 1;
			} 
			elsif ($entry->{ip} =~ /^[\w\:]+$/) {
				if ($rootIDv6 == -1) {
					unless (&addRoot($rootName . '_v6', '', 1)) {
						warn "AddRoot failed!\n";
						return 0;
					}
					$rootIDv6	= &rootName2ID($rootName . '_v6');
				}
				$rootID	= $rootIDv6;
				$v4			= 0;
			} else {
				warn "Cannot add Network '" . $entry->{ip} . "' because it's malformed!\n";
				next;
			}
			if(&addNet(0, $rootID, $entry->{ip}, $entry->{cidr}, $entry->{descr}, $status, 0, 0, 1)) {
				($v4) ? $cnter[0]++ : $cnter[1]++;
			}
		}
	}

	&warnl(sprintf(_gettext("Added %i IPv4 and %i IPv6 Networks"), $cnter[0], $cnter[1]));

	return 1;
}

sub importCSV {
	warn 'SUB: ' . (caller(0))[3] . ' (' . (caller(1))[3] . ")\n" if $conf->{var}->{showsubs};
	my $q							= $HaCi::HaCi::q;
	my $configFileID	= &getParam(1, undef, eval{$q->param('configFileID')});
	my $fileName			= &getParam(1, undef, $q->param('config'));
	my $status				= &getParam(1, 0, $q->param('status'));
	my $targetRootID	= &getParam(1, -1, $q->param('targetRoot'));
	my $tmplID				= &getParam(1, 0, $q->param('tmplID'));
	my $stat					= $conf->{var}->{STATUS};
	$stat->{TITLE} = "Importing CSV '$fileName'";$stat->{STATUS}	= 'Running...'; $stat->{PERCENT}	= 0; &setStatus();

	my @data					= &parseCSVConfigfile($configFileID, 0);
	unlink "$conf->{static}->{path}->{spoolpath}/$configFileID.tmp";
	$stat						= $conf->{var}->{STATUS};
	$stat->{TITLE}	= "Importing CSV '$fileName'";$stat->{STATUS}	= 'Initializing...'; $stat->{PERCENT}	= 9; &setStatus();

	unless (defined $configFileID) {
		warn "No configFileID passed!\n";
		$stat->{STATUS}	= 'ERROR'; $stat->{DATA}	= ''; $stat->{PERCENT} = 100; &setStatus();
		return 0;
	}

	unless (defined $fileName) {
		warn "No config passed!\n";
		$stat->{STATUS}	= 'ERROR'; $stat->{DATA}	= ''; $stat->{PERCENT} = 100; &setStatus();
		return 0;
	}

	my $cnv						= {};

	my $rootTable	= $conf->{var}->{TABLES}->{root};
	unless (defined $rootTable) {
		warn "Cannot add Root. DB Error (root)\n";
		$stat->{STATUS}	= 'ERROR'; $stat->{DATA}	= ''; $stat->{PERCENT} = 100; &setStatus();
		return 0;
	}

	foreach ($q->param) {
		if (/^COL_(\d+)$/) {
			$cnv->{$1}	= $q->param($_);
		}
	}

	my $colCnter	= 0;
	my @cnter			= (0, 0);
	my $rootIDs		= {};
	foreach (@data) {
		my $cnter				= 0;
		my @cols				= @{$_};
		my $network			= '';
		my $status			= 0;
		my $description	= '';
		my $percent			= int(($colCnter++ / ($#data + 1)) * 100);
		foreach (@cols) {
			$cnter++;
			$network			= $_ if $cnv->{$cnter} == -1;
			$status				= $_ if $cnv->{$cnter} == -2;
			$description	= $_ if $cnv->{$cnter} == -3;
			if ($cnv->{$cnter} > 0) {
				$q->delete('tmplEntryID_' . $cnv->{$cnter}); 
				$q->param('tmplEntryID_' . $cnv->{$cnter}, $_);
			}
		}
		next unless $network;
		$stat->{DATA}	= "Importing Network '$network' ($description)"; $stat->{PERCENT}	= $percent; &setStatus();
		my ($ip, $cidr)	= split/\//, $network;

		my $rootName		= (($targetRootID == -1) ? $fileName : &rootID2Name($targetRootID));
		$rootName		=~ s/_v6$//;
		my $rootID		= -1;
		my $rootIDv4	= &rootName2ID($rootName) || -1;
		my $rootIDv6	= &rootName2ID($rootName . '_v6') || -1;
		my $v					= 4;
		if (&checkSpelling_Net($network, 0)) {
			if ($rootIDv4 == -1) {
				unless (&checkIfRootExists($rootName)) {
					unless (&addRoot($rootName, '', 0)) {
						warn "AddRoot failed!\n";
						$stat->{STATUS}	= 'ERROR'; $stat->{DATA}	= ''; $stat->{PERCENT} = 100; &setStatus();
						return 0;
					}
				}
				$rootIDv4	= &rootName2ID($rootName);
			}
			$rootID	= $rootIDv4;
			$v			= 4;
		}
		elsif (&checkSpelling_Net($network, 1)) {
			if ($rootIDv6 == -1) {
				unless (&checkIfRootExists($rootName . '_v6')) {
					unless (&addRoot($rootName . '_v6', '', 1)) {
						warn "AddRoot failed!\n";
						$stat->{STATUS}	= 'ERROR'; $stat->{DATA}	= ''; $stat->{PERCENT} = 100; &setStatus();
						return 0;
					}
				}
				$rootIDv6	= &rootName2ID($rootName . '_v6');
			}
			$rootID	= $rootIDv6;
			$v			= 6;
		} else {
			warn "Bad Network: $ip/$cidr ($description)\n";
			next;
		}

		my $netaddress	= '';
		my $stdCidr			= 32;
		if ($v == 4) {
			$netaddress	= ($cidr == 32) ? $ip : &dec2ip(&getNetaddress($ip, &getNetmaskFromCidr($cidr)));
		} else {
			$netaddress	= &ipv6Dec2ip(&ipv6DecCidr2NetaddressV6Dec(&ipv62dec($ip), $cidr));
			$stdCidr		= 128;
			eval {
				$ip					= Net::IPv6Addr::to_string_preferred($ip);
				$netaddress	= Net::IPv6Addr::to_string_preferred($netaddress);
			};
			if ($@) {
				warn $@;
				next;
			}
		}

		$rootIDs->{$rootID}	= 1;
		if ($ip eq $netaddress) {
			$cnter[0 + (($v == 6) ? 1 : 0)]++ if &addNet(0, $rootID, $ip, $cidr, $description, $status, $tmplID, 0, 1);
		} else {
			$cnter[0 + (($v == 6) ? 1 : 0)]++ if &addNet(0, $rootID, $netaddress, $cidr, '', 0, $tmplID, 0, 1);
			$cnter[0 + (($v == 6) ? 1 : 0)]++ if &addNet(0, $rootID, $ip, $stdCidr, $description, $status, $tmplID, 0, 1);
		}
	}
	foreach (keys %{$rootIDs}) {
		&debug("Flushing Cache for: " . &rootID2Name($_));
		&removeFromNetcache($_);
	}
	$stat->{DATA}	= ""; $stat->{PERCENT} = 100; $stat->{STATUS} = 'FINISH'; &setStatus();
	&warnl(sprintf(_gettext("Added %i IPv4 and %i IPv6 Networks"), $cnter[0], $cnter[1]));

	$stat->{STATUS}	= 'FINISH'; $stat->{DATA}	= ''; $stat->{PERCENT} = 100; &setStatus();
	return 1;
}

sub parseCSVConfigfile {
	warn 'SUB: ' . (caller(0))[3] . ' (' . (caller(1))[3] . ")\n" if $conf->{var}->{showsubs};
	my $configFileID	= shift;
	my $bPreview			= shift || 0;
	my $q							= $HaCi::HaCi::q;
	my $sep						= &getParam(1, undef, $q->param('sep'));
	my @box						= [];
	my $nrOfCols			= 0;
	my $stat					= $conf->{var}->{STATUS};

	$stat->{TITLE} = "Parsing CSV file."; $stat->{STATUS} = 'Runnung...'; $stat->{PERCENT} = 5; &setStatus();

	unless (defined $sep) {
		$sep	= ';';
		$q->param('sep', ';');
	}

	eval {
		require Text::CSV_XS;
	};
	if ($@) {
		warn $@;
		return ();
	}
	my $csv	= Text::CSV_XS->new({
		'sep_char'	=> $sep
	});

	unless (open EXPORT, $conf->{static}->{path}->{spoolpath} . '/' . "$configFileID.tmp") {
		&warnl("Cannot open Temp File '$conf->{static}->{path}->{spoolpath}/$configFileID.tmp' for reading: $!");
		return ();
	}
	my $config	= join('', <EXPORT>);
	close EXPORT;

	my $cnter		= 0;
	my $error		= '';
	my $line		= 1;
	my @conf		= split(/[\n\r]/, $config);
	my $maxLines	= ($bPreview) ? 30 : $#conf + 1;
	foreach (@conf) {
		my $status = $csv->parse($_);
		if ($status) {
			$cnter++;
			last if $bPreview && $cnter > $maxLines;
			my @fields	= $csv->fields();
			map {s/^\s+//; s/\s+$//} @fields;
			$nrOfCols		= ($#fields + 1) if $nrOfCols < ($#fields + 1);
			push @box, \@fields;
		} else {
			$error	= 1;
			&warnl("CVS Error in line $line: " . $csv->error_diag());
		}
		unless ($line % ($maxLines / 4)) {
			$stat->{TITLE} = "Parsing CSV file." . '.' x (int($line * 4 / $maxLines)); $stat->{STATUS} = 'Runnung...'; $stat->{PERCENT} = (5 + (int($line * 4 / $maxLines))); &setStatus();
		}
		$line++;
	}
	&warnl(_gettext("Error while parsing CSV: Invalid Line")) if $error;
	$conf->{var}->{nrOfCols}	= $nrOfCols;
	return @box;
}

sub parseCiscoConfigfile {
	warn 'SUB: ' . (caller(0))[3] . ' (' . (caller(1))[3] . ")\n" if $conf->{var}->{showsubs};
	my $config		= shift;
	my $fileName	= shift;
	my $status		= shift;
	my $box				= [];

	my $hostname	= '';
	my $bInt			= 0;
	my $intName		= '';
	my $intDescr	= '';
	foreach (split/\n/, $config) {
		chomp;
		next if /^\s*$/;
		$hostname	= $1 if /^hostname\s+(\w+)/;
		if ($bInt && /^!/) {
			$bInt			= 0;
			$intName	= '';
			$intDescr	= '';
		}
		if (!$bInt && /^interface\s+(.*)/) {
			$bInt			= 1;
			$intName	= $1;
		}
		$intDescr	= $1 if $bInt && /^\s+description\s+(.*)/;
		if ($bInt && /^\s+ip address\s+(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})\s+(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})/) {
			my $cidr	= &getCidrFromNetmask($2);
			push @$box, {
				ip		=> $1,
				cidr	=> $cidr,
				descr	=> ($intDescr ne '') ? $intDescr : $intName
			};
		}
	}
	my $rootName	= ($hostname ne '') ? $hostname : $fileName;
	if ($#$box > -1) {
		unless (&addRoot($rootName)) {
			warn "AddRoot failed!\n";
			return 0;
		}
		
		my $rootID	= &rootName2ID($rootName);
		foreach my $entry (@$box) {
			&addNet(0, $rootID, $entry->{ip}, $entry->{cidr}, $entry->{descr}, $status, 0, 0, 1) if $entry->{ip}  =~ /^[\d\.]+$/;
		}
	}
	return 1;
}

sub importDNSLocal {
	warn 'SUB: ' . (caller(0))[3] . ' (' . (caller(1))[3] . ")\n" if $conf->{var}->{showsubs};
	my $q							= $HaCi::HaCi::q;
	my $file					= &getParam(1, undef, $q->param('zonefile'));
	my $status				= &getParam(1, 0, $q->param('state'));
	my $origin				= &getParam(1, '', $q->param('origin'));
	my $targetRootID	= &getParam(1, -1, $q->param('targetRoot'));
	my $zoneFileT			= '';
	my $data					= '';
	my $stat					= $conf->{var}->{STATUS};
	$stat->{TITLE}		= "Importing local DNS Zonefile '$file'";$stat->{STATUS}	= 'Running...'; $stat->{PERCENT}	= 0; &setStatus();

	return 0 unless $file;
	
	return 0 unless binmode $file;
	while(read $file,$data,1024) {
		$zoneFileT	.= $data;
	}
	my $zoneFile	= [split/\n/, $zoneFileT];

	my $ret	= &parseZonefile($zoneFile, $file, $status, $origin, $targetRootID);

	$stat->{DATA}	= ""; $stat->{PERCENT} = 100; $stat->{STATUS} = 'FINISH'; &setStatus();
	return $ret;
}

sub parseZonefile {
	warn 'SUB: ' . (caller(0))[3] . ' (' . (caller(1))[3] . ")\n" if $conf->{var}->{showsubs};
	my $zoneFile			= shift;
	my $domain				= shift;
	my $status				= shift;
	my $origin				= shift;
	my $targetRootID	= shift;
	my $stat					= $conf->{var}->{STATUS};
	my $box						= {};
	my $cnter					= 0;
	my $originOrig		= $origin;
	$stat->{TITLE}		= "Parsing Zonefile";$stat->{STATUS}	= 'Running...'; $stat->{PERCENT}	= 10; &setStatus();
	
	eval {
		require DNS::ZoneParse;
	};
	if ($@) {
		warn $@;
		return 0;
	} else {
		my $zft			= join("\n", @$zoneFile);
		my $zf			= DNS::ZoneParse->new(\$zft);
		my $soa			= $zf->soa();
		$origin			= $soa->{origin} unless $origin;
		$originOrig	= $origin;
		$originOrig	=~ s/\.$//;

		if ($origin	=~ /in-addr\.arpa\.?/) {
			my $ip	= $origin;
			$ip			=~ s/\.in-addr\.arpa\.?//g;
			$origin	= join('.', reverse(split/\./, $ip));
			$origin	.= '.';
		}

		my $as	= $zf->a();
		foreach my $r (@$as) {
			unless ($r->{name} =~ /\.$/) {
				$r->{name}	.= '.' . $origin if length($origin) > 1;
			}

			$r->{name}	=~ s/\.$//;
			&debug("NEW A ENTRY: name => $r->{name}, host => $r->{host}\n");
			if (&checkSpelling_IP($r->{host}, 0)) {
				$cnter++;
				$box->{V4}->{$r->{host}}	= $r->{name};
			}
		}

		my $a4s	= $zf->aaaa();
		foreach my $r (@$a4s) {
			unless ($r->{name} =~ /\.$/) {
				$r->{name}	.= '.' . $origin if length($origin) > 1;
			}

			$r->{name}	=~ s/\.$//;
			&debug("NEW AAAA ENTRY: name => $r->{name}, host => $r->{host}\n");
			if (&checkSpelling_IP($r->{host}, 1)) {
				$cnter++;
				$box->{V6}->{$r->{host}}	= $r->{name};
			}
		}

		my $ptrs	= $zf->ptr();
		foreach my $r (@$ptrs) {
			unless ($r->{name} =~ /\.$/) {
				$r->{name}	= $origin . $r->{name} if length($origin) > 1;
			} else {
				if ($r->{name}	=~ /in-addr\.arpa\.?/) {
					my $ip			= $r->{name};
					$ip					=~ s/\.in-addr\.arpa\.?//g;
					$r->{name}	= join('.', reverse(split/\./, $ip));
				}
			}

			$r->{host}	=~ s/\.$//;
			&debug("NEW PTR ENTRY: name => $r->{name}, host => $r->{host}\n");
			if (&checkSpelling_IP($r->{name}, ($r->{name} =~ /:/) ? 1 : 0)) {
				$cnter++;
				if ($r->{name}	=~ /:/) {
					$box->{V6}->{$r->{name}}	= $r->{host};
				} else {
					$box->{V4}->{$r->{name}}	= $r->{host};
				}
			}
		}
	}

	unless (length($origin) > 1) {
		&warnl(_gettext("No Origin given or found!"));
		return 0;
	}

	my $targetRoot	= (($targetRootID == -1) ? $originOrig : &rootID2Name($targetRootID));
	my $targetRootV6	= $targetRoot . '_IPv6';

	my @v4s	= keys %{$box->{V4}};
	my @v6s	= keys %{$box->{V6}};

	my $saveCnter	= 0;
	if ($#v4s > -1) {
		my $rootOK	= 1;
		unless (&checkIfRootExists($targetRoot)) {
			unless (&addRoot($targetRoot, $originOrig)) {
				warn "AddRoot failed!\n";
				$rootOK	= 0;
			}
		}

		if ($rootOK) {
			my $rootID		= &rootName2ID($targetRoot);
			my $colCnter	= 0;
			foreach (@v4s) {
				my $host	= $_;
				my $name	= $box->{V4}->{$host};
				if ($host	=~ /^[\d\.]+$/) {
					my $percent		= int(($colCnter / ($#v4s + 1)) * 100);
					$stat->{DATA}	= "Importing Network '$host' ($name)"; $stat->{PERCENT}	= $percent; &setStatus();
					$saveCnter++ if &addNet(0, $rootID, $host, '32', $name, $status, 0, 0, 1) 
				}
				$colCnter++;
			}
		}
	}

	if ($#v6s > -1) {
		my $rootOK	= 1;
		unless (&checkIfRootExists($targetRootV6)) {
			unless (&addRoot($targetRootV6, $originOrig, 1)) {
				warn "AddRoot failed!\n";
				$rootOK	= 0;
			}
		}
		if ($rootOK) {
			my $rootID		= &rootName2ID($targetRootV6);
			my $colCnter	= 0;
			foreach (@v6s) {
				my $host	= $_;
				my $name	= $box->{V6}->{$host};
				if ($host	=~ /^[\w:]+$/) {
					my $percent		= int(($colCnter / ($#v6s + 1)) * 100);
					$stat->{DATA}	= "Importing Network '$host' ($name)"; $stat->{PERCENT}	= $percent; &setStatus();
					$saveCnter++ if &addNet(0, $rootID, $host, '128', $name, $status, 0, 0, 1);
				}
				$colCnter++;
			}
		}
	}
		
  if ($cnter > 0) {
		&warnl(sprintf(_gettext("%i IP Addresses found for Origin '%s'. %i were successfully saved under Root '%s'"), $cnter, $originOrig, $saveCnter, $targetRoot . (($#v6s > -1) ? '/' . $targetRootV6 : '')));
	} else {
		&warnl(sprintf(_gettext("No IP Addresses found for Origin '%s'."), $originOrig));
	}


	return 1;
}

sub getNextDBNetwork {
	warn 'SUB: ' . (caller(0))[3] . ' (' . (caller(1))[3] . ")\n" if $conf->{var}->{showsubs};
	my $rootID				= shift;
	my $ipv6					= shift;
	my $networkDec		= shift;
	my $inNetwork			= shift || 0;
	my $nextNet				= &getNetCacheEntry('DB', $rootID, "$networkDec:$inNetwork");

	warn "getNextDBNetwork: " . &rootID2Name($rootID) . "-($ipv6)-" . (($ipv6) ? &netv6Dec2net($networkDec) : &dec2net($networkDec)) . " (" . (caller)[0] . ':' . (caller)[2] . ")\n" if 0;

	unless (defined $nextNet) {
		my $networkTable	= $conf->{var}->{TABLES}->{network};
		unless (defined $networkTable) {
			warn "Cannot get Next Network. DB Error (network)\n";
			return undef;
		}
		
		my $networkT	= undef;
		if ($ipv6) {
			my ($net, $host, $cidr)	= (0, 0, 0);
			if ($networkDec) {
				if (ref $networkDec) {
					($net, $host, $cidr)	= &netv6Dec2PartsDec($networkDec);
				} else {
					&debug("V6 NetworkDec ($networkDec) should be an Math::BigInt Reference!");
				}
			}
			my $broadcastStr		= '';
			my $networkV6Table	= $conf->{var}->{TABLES}->{networkV6};
			unless (defined $networkV6Table) {
				warn "Cannot get Next Network. DB Error (networkV6)\n";
				return undef;
			}

			if ($inNetwork) {
				my $broadcastNetDec				= &getV6BroadcastNet($networkDec, 128);
				my ($bNet, $bHost, undef)	= &netv6Dec2PartsDec($broadcastNetDec);
				$broadcastStr							= "AND (networkPrefix < $bNet || (networkPrefix = $bNet AND hostPart < $bHost) || (networkPrefix = $bNet AND hostPart = $bHost AND cidr <= 128))";
			}

			$networkT  = ($networkV6Table->search(
				['ID', 'networkPrefix', 'hostPart', 'cidr'],
				{rootID => $rootID}, 0,
				"AND (
					(networkPrefix > $net) OR 
					(networkPrefix = $net AND hostPart > $host) OR 
					(networkPrefix = $net AND hostPart = $host AND cidr > $cidr)
				) $broadcastStr ORDER BY networkPrefix, hostPart, cidr LIMIT 1")
			)[0];
			if (defined $networkT) {
				$networkT->{ipv6}			= 1;
				$networkT->{network}	= &ipv6Parts2NetDec($networkT->{networkPrefix}, $networkT->{hostPart}, $networkT->{cidr});
				my $networkT1 				= ($networkTable->search(['ID', 'network', 'description', 'state', 'defSubnetSize'], {ipv6ID => $networkT->{ID}, rootID => $rootID, network => 0}, 0))[0];
				if (defined $networkT1) {
					$networkT->{ID}							= $networkT1->{ID};
					$networkT->{description}		= $networkT1->{description};
					$networkT->{state}					= $networkT1->{state};
					$networkT->{defSubnetSize}	= $networkT1->{defSubnetSize};
				} else {
					$networkT	= undef;
				}
			}
		} else {
			my $broadcastStr	= '';
			if ($inNetwork) {
				my $broadcast	= &net2dec(&dec2ip(&getBroadcastFromNet($networkDec)) . '/32');
				# <= damit /32er auch in einem /31er angezeigt werden
				$broadcastStr	= "AND network <= $broadcast";
			}
		
			$networkT  = ($networkTable->search(
				['ID', 'network', 'description', 'state', 'defSubnetSize'],
				{rootID => $rootID, ipv6ID => ''}, 0,
				"AND network > $networkDec $broadcastStr ORDER BY network LIMIT 1")
			)[0];
			$networkT->{ipv6}	= 0 if defined $networkT;
		}

		$nextNet	= (defined $networkT) ? $networkT : undef;
		&updateNetcache('DB', $rootID, "$networkDec:$inNetwork", ((defined $networkT) ? $networkT : -1));
	}

	$nextNet	= undef if defined $nextNet && $nextNet == -1;

	warn " Next: " . ((defined $nextNet) ? (($ipv6) ? &netv6Dec2net($nextNet->{network}) : &dec2net($nextNet->{network}) . "\n") : '') if 0;

	return $nextNet;
}

sub getDBNetworkBefore {
	warn 'SUB: ' . (caller(0))[3] . ' (' . (caller(1))[3] . ")\n" if $conf->{var}->{showsubs};
	my $rootID				= shift;
	my $networkDec		= shift;
	my $ipv6					= shift;
	my $inNetwork			= shift || 0;

	my $networkTable	= $conf->{var}->{TABLES}->{network};
	unless (defined $networkTable) {
		warn "Cannot get Next Network. DB Error (network)\n";
		return undef;
	}

	my $networkT;
	if ($ipv6) {
		warn "No IPV6 Reference ($networkDec) [getDBNetworkBefore]\n" unless ref $networkDec;
		my ($net, $host, $cidr)	= &netv6Dec2PartsDec($networkDec);
		my $networkV6Table			= $conf->{var}->{TABLES}->{networkV6};
		unless (defined $networkV6Table) {
			warn "Cannot get Next Network. DB Error (networkV6)\n";
			return undef;
		}

		$networkT  = ($networkV6Table->search(
			['ID', 'networkPrefix', 'hostPart', 'cidr'],
			{rootID => $rootID}, 0,
			"AND (
				(networkPrefix < $net) OR 
				(networkPrefix = $net AND hostPart < $host) OR 
				(networkPrefix = $net AND hostPart = $host AND cidr < $cidr)
			) ORDER BY networkPrefix DESC, hostPart DESC, cidr DESC LIMIT 1")
		)[0];
		if (defined $networkT) {
			my $currNetworkDec		= &ipv6Parts2NetDec($networkT->{networkPrefix}, $networkT->{hostPart}, $networkT->{cidr});
			$networkT->{ipv6}			= 1;
			$networkT->{network}	= $currNetworkDec;
			if ($inNetwork) {
				my $parent			= &getNetworkParentFromDB($rootID, $networkDec, $ipv6);
				my $currParent	= &getNetworkParentFromDB($rootID, $networkT->{network}, $ipv6);
				return undef if $parent->{network} != $currParent->{network};
			}

			if (0) { # needless...
				my $networkT1	= ($networkTable->search(['ID', 'network', 'description', 'state', 'defSubnetSize'], {ipv6ID => $networkT->{ID}, network => 0, rootID => $rootID}, 0))[0];
				if (defined $networkT1) {
					$networkT->{ID}							= $networkT1->{ID};
					$networkT->{description}		= $networkT1->{description};
					$networkT->{state}					= $networkT1->{state};
					$networkT->{defSubnetSize}	= $networkT1->{defSubnetSize};
				}
			}
		}
	} else {
		$networkT  = ($networkTable->search(
			['ID', 'network'],
			{rootID => $rootID, ipv6ID => ''}, 0,
			"AND network < $networkDec ORDER BY network DESC LIMIT 1")
		)[0];
		if (defined $networkT && $inNetwork) {
			my $parent			= &getNetworkParentFromDB($rootID, $networkDec, $ipv6);
			my $currParent	= &getNetworkParentFromDB($rootID, $networkT->{network}, $ipv6);
			return undef if $parent->{network} != $currParent->{network};
		}
	}

	return (defined $networkT) ? $networkT->{network} : undef;
}

sub updateNetcache {
	warn 'SUB: ' . (caller(0))[3] . ' (' . (caller(1))[3] . ")\n" if $conf->{var}->{showsubs};
	my $type		= shift;
	my $ID			= shift;
	my $key			= shift;
	my $value		= shift;

	$conf->{var}->{CACHESTATS}->{$type}->{FAIL}++;
	$HaCi::HaCi::netCache->{$type}->{$ID}->{$key}	= $value;
}

sub removeFromNetcache {
	warn 'SUB: ' . (caller(0))[3] . ' (' . (caller(1))[3] . ")\n" if $conf->{var}->{showsubs};
	my $rootID	= shift;

	delete $HaCi::HaCi::netCache->{DB}->{$rootID};
}

sub getConfig {
	warn 'SUB: ' . (caller(0))[3] . ' (' . (caller(1))[3] . ")\n" if $conf->{var}->{showsubs};
	my $file						=	$conf->{static}->{path}->{configfile};
	my $configFile			= $conf->{static}->{path}->{workdir} . '/etc/' . $file if -f $conf->{static}->{path}->{workdir} . '/etc/' . $file;
	$configFile					= '/etc/' . $file if -f '/etc/' . $file; 
	if (-d $conf->{static}->{path}->{workdir} . '/CVS') {
		$configFile	.= '.dev';
		warn "Seems to be a development Branch. Extending '.dev' to the ConfigFile: '$configFile'\n";
		$conf->{static}->{misc}->{debug}	= 1;
	}
	return unless $configFile;

	my %config;
	eval {
		%config = ParseConfig(
			-ConfigFile					=> $configFile, 
			-LowerCaseNames			=> 1,
			-UseApacheInclude		=> 1,
			-IncludeRelative		=> 1,
			-IncludeDirectories	=> 1,
			-IncludeGlob				=> 1,
			-AutoTrue						=> 1,
			-InterPolateVars		=> 1,
			-InterPolateEnv			=> 1,
		);
	};
	if ($@) {
		&warnl("Error while parsing Configfile '$configFile': $@");
	}

	if (exists $config{'db::dbhost'}) {
		warn "You are using a deprecated Configfile format. Please consider to upgrade it (Example: 'etc/HaCi.conf.sample')\n";
		&getConfigOld($configFile);
	} else {
		$conf->{user}	= \%config;
	}

	$conf->{var}->{STATUS}	= {};
}

sub getConfigOld {
	warn 'SUB: ' . (caller(0))[3] . ' (' . (caller(1))[3] . ")\n" if $conf->{var}->{showsubs};

	my $configFile	= shift;

	unless (open CONF, $configFile) {
		warn sprintf(_gettext("Cannot read ConfigFile '%s': %s"), $configFile, $!);
		return 0;
	}
	my @CONF	= <CONF>;
	close CONF;

	foreach (@CONF) {
		s/#.*//;
		next if /^\s+$/;
		if (/^([\w:]+)\s+=\s+(.*)$/) {
			my $key						= $1;
			my $value					= $2;
			next unless $key	=~ /^[\w|:]+$/;
			$value						=~ s/'//g;
			$key							=~ s/::/}->{/g;
			$key							= lc($key);
			$key							= '$conf->{user}->{' . $key . '} = ' . "'$value'";
			eval "$key";
			if ($@) {
				warn "Error while evaluating Configkey: $@\n";
			}
		}
	}
}

sub getWHOISData {
	warn 'SUB: ' . (caller(0))[3] . ' (' . (caller(1))[3] . ")\n" if $conf->{var}->{showsubs};
	my $network	= shift;

	return {data=>[
		{key=>_gettext('Error'),value=>sprintf(_gettext("This doesn't look like a network '%s'."), $network)}
	]} unless &checkSpelling_Net($network, 0);
	return {data=>[
		{key=>_gettext('Error'),value=>sprintf(_gettext("Program Whois '%s' isn't executable"), $conf->{static}->{path}->{whois})}
	]} unless -x $conf->{static}->{path}->{whois};
	
	my @whois	= qx($conf->{static}->{path}->{whois} -h $conf->{static}->{misc}->{ripedb} -- $network);
	my $route	= 0;
	my $box		= {};
	foreach (@whois) {
		push @{$box->{data}},	{key =>$1, value => $2}	if $box->{inetnum} && /^([\w\-]+):\s+(.*)$/;
		$box->{inetnum}	= $1	if /^inetnum:\s+(.*)$/;
		last 									if $box->{inetnum} && /^\s*$/;
	}
	return $box;
}

sub getNSData {
	warn 'SUB: ' . (caller(0))[3] . ' (' . (caller(1))[3] . ")\n" if $conf->{var}->{showsubs};
	my $ip	= shift;

	return {data=>_gettext('Error') . ': ' . sprintf(_gettext("This doesn't look like an IP address '%s'."), $ip)} unless &checkSpelling_IP($ip, 0);

	eval {
		require Net::Nslookup;
	};
	if ($@) {
		warn $@;
		return {
			ipaddress	=> $ip,
			data			=> 'unknown'
		};
	} else {
		my $ptr	= Net::Nslookup->nslookup(host => $ip, type => "PTR");
		$ptr	||= '';
		return {
			ipaddress	=> $ip,
			data			=> $ptr
		};
	}
}

sub rootID2Name {
	warn 'SUB: ' . (caller(0))[3] . ' (' . (caller(1))[3] . ")\n" if $conf->{var}->{showsubs};
	my $rootID	= shift;

	my $rootTable	= $conf->{var}->{TABLES}->{root};
	unless (defined $rootTable) {
		warn "Cannot convert RootID to name. DB Error (root)\n";
		return '';
	}

	my $root	= ($rootTable->search(['ID', 'name'], {ID => $rootID}))[0];
	return $root->{name} || '';
}

sub rootName2ID {
	warn 'SUB: ' . (caller(0))[3] . ' (' . (caller(1))[3] . ")\n" if $conf->{var}->{showsubs};
	my $rootName	= shift;

	my $rootTable	= $conf->{var}->{TABLES}->{root};
	unless (defined $rootTable) {
		warn "Cannot convert RootName to ID. DB Error (root)\n";
		return '';
	}

	my $root	= ($rootTable->search(['ID'], {name => $rootName}))[0];
	return $root->{ID} || 0;
}

sub rootID2ipv6 {
	warn 'SUB: ' . (caller(0))[3] . ' (' . (caller(1))[3] . ")\n" if $conf->{var}->{showsubs};
	my $rootID	= shift;

	my $rootTable	= $conf->{var}->{TABLES}->{root};
	unless (defined $rootTable) {
		warn "Cannot get ipv6 Flag for RootID. DB Error (root)\n";
		return 0;
	}

	my $root	= ($rootTable->search(['ID', 'ipv6'], {ID => $rootID}))[0];
	return $root->{ipv6} || 0;
}


sub netID2Stuff {
	warn 'SUB: ' . (caller(0))[3] . ' (' . (caller(1))[3] . ")\n" if 0 || $conf->{var}->{showsubs};
	my $netID	= shift;

	my $netTable	= $conf->{var}->{TABLES}->{network};
	unless (defined $netTable) {
		warn "Cannot get Network. DB Error (network)\n";
		return ();
	}

	my $network	= ($netTable->search(['rootID', 'network', 'ipv6ID'], {ID => $netID}))[0];
	return () unless defined $network;

	if ($network->{ipv6ID}) {
		my $netTableV6	= $conf->{var}->{TABLES}->{networkV6};
		unless (defined $netTableV6) {
			warn "Cannot get Network. DB Error (networkV6)\n";
			return ();
		}
		my $networkV6	= ($netTableV6->search(['networkPrefix', 'hostPart', 'cidr'], {ID => $network->{ipv6ID}}))[0];
		$network->{network}	= &ipv6Parts2NetDec($networkV6->{networkPrefix}, $networkV6->{hostPart}, $networkV6->{cidr});
	}

	$network->{network}	= Math::BigInt->new($network->{network}) if $network->{ipv6ID};

	return ($network->{rootID}, $network->{network}, ($network->{ipv6ID}) ? 1 : 0);
}

sub tmplID2Name {
	warn 'SUB: ' . (caller(0))[3] . ' (' . (caller(1))[3] . ")\n" if $conf->{var}->{showsubs};
	my $tmplID	= shift;

	return 'other' unless $tmplID;

	my $tmplTable	= $conf->{var}->{TABLES}->{template};
	unless (defined $tmplTable) {
		warn "Cannot convert TmplID to name. DB Error (template)\n";
		return '';
	}

	my $tmpl	= ($tmplTable->search(['ID', 'name'], {ID => $tmplID}))[0];
	return $tmpl->{name} || '';
}

sub tmplName2ID {
	warn 'SUB: ' . (caller(0))[3] . ' (' . (caller(1))[3] . ")\n" if $conf->{var}->{showsubs};
	my $tmplName	= shift;

	return undef unless $tmplName;

	my $tmplTable	= $conf->{var}->{TABLES}->{template};
	unless (defined $tmplTable) {
		warn "Cannot convert TmplName to ID. DB Error (template)\n";
		return undef;
	}

	my $tmpl	= ($tmplTable->search(['ID'], {name	=> $tmplName}))[0];
	return (defined $tmpl && exists $tmpl->{ID}) ? $tmpl->{ID} : undef;
}

sub groupID2Name {
	warn 'SUB: ' . (caller(0))[3] . ' (' . (caller(1))[3] . ")\n" if $conf->{var}->{showsubs};
	my $groupID	= shift;

	my $groupTable	= $conf->{var}->{TABLES}->{group};
	unless (defined $groupTable) {
		warn "Cannot convert GroupID to name. DB Error (group)\n";
		return '';
	}

	my $group	= ($groupTable->search(['ID', 'name'], {ID => $groupID}))[0];
	return $group->{name} || '';
}

sub userID2Name {
	warn 'SUB: ' . (caller(0))[3] . ' (' . (caller(1))[3] . ")\n" if $conf->{var}->{showsubs};
	my $userID	= shift;

	my $userTable	= $conf->{var}->{TABLES}->{user};
	unless (defined $userTable) {
		warn "Cannot convert UserID to name. DB Error (user)\n";
		return '';
	}

	my $user	= ($userTable->search(['ID', 'username'], {ID => $userID}))[0];
	return $user->{username} || '';
}

sub userName2ID {
	warn 'SUB: ' . (caller(0))[3] . ' (' . (caller(1))[3] . ")\n" if $conf->{var}->{showsubs};
	my $userName	= shift;

	my $userTable	= $conf->{var}->{TABLES}->{user};
	unless (defined $userTable) {
		warn "Cannot convert Username to ID. DB Error (user)\n";
		return -1;
	}

	my $user	= ($userTable->search(['ID'], {username => $userName}))[0];
	return $user->{ID} || -1;
}

sub getNetworkChilds {
	warn 'SUB: ' . (caller(0))[3] . ' (' . (caller(1))[3] . ")\n" if $conf->{var}->{showsubs};

	my $netID									= shift;
	my $onlyRoot							= shift;
	my $withParent						= shift;
	$onlyRoot								||= 0;

	my $networkTable	= $conf->{var}->{TABLES}->{network};
	unless (defined $networkTable) {
		warn "Cannot get Number of Parents. DB Error (network)\n";
		return ();
	}
	
	my $networkV6Table	= undef;
	$networkV6Table	= $conf->{var}->{TABLES}->{networkV6};
	unless (defined $networkV6Table) {
		warn "Cannot get NetworkV6 Parent. DB Error (networkV6)\n";
		return ();
	}
	
	my $currLevel	= 0;
	my @childs		= ();
	if ($onlyRoot) {
		if (&rootID2ipv6($netID)) {
			@childs	= $networkV6Table->search( ['ID', 'networkPrefix', 'hostPart', 'cidr'], {rootID => $netID});
			if (@childs) {
				my @newChilds	= ();
				foreach (@childs) {
					my $child				= $_;
					my $net					= ($networkTable->search(['ID', 'network', 'state'], {ipv6ID => $child->{ID}, network => 0, rootID => $netID}))[0];
					$net->{network}	= &ipv6Parts2NetDec($child->{networkPrefix}, $child->{hostPart}, $child->{cidr});
					push @newChilds, $net;
				}
				@childs	= @newChilds;
			}
		} else {
			@childs	= $networkTable->search(['ID', 'network', 'state'], {rootID => $netID});
		}
	} else {
		my ($rootID, $networkDec, $ipv6)	= &netID2Stuff($netID);
		return () if !defined $rootID || !defined $networkDec;

		my $broadcast	= ($ipv6) ? &getV6BroadcastNet($networkDec, 128) : &net2dec(&dec2ip(&getBroadcastFromNet($networkDec)) . '/32');

		if ($ipv6) {
			my ($net, $host, $cidr)			= &netv6Dec2PartsDec($networkDec);
			my ($netB, $hostB, $cidrB)	= &netv6Dec2PartsDec($broadcast);
	
			@childs	= $networkV6Table->search(
				['ID', 'networkPrefix', 'hostPart', 'cidr'],
				{rootID => $rootID}, 0,
				"AND (
					(networkPrefix > $net) OR 
					(networkPrefix = $net AND hostPart > $host) OR 
					(networkPrefix = $net AND hostPart = $host AND cidr >" . (($withParent) ? '=' : '') . " $cidr)
				) AND (
					(networkPrefix < $netB) OR 
					(networkPrefix = $netB AND hostPart < $hostB) OR 
					(networkPrefix = $netB AND hostPart = $hostB AND cidr <= $cidrB)
				) ORDER BY networkPrefix, hostPart, cidr");

			if (@childs) {
				my @newChilds	= ();
				foreach (@childs) {
					my $child				= $_;
					my $net					= ($networkTable->search(['ID', 'network', 'state'], {ipv6ID => $child->{ID}, network => 0, rootID => $rootID}))[0];
					$net->{network}	= &ipv6Parts2NetDec($child->{networkPrefix}, $child->{hostPart}, $child->{cidr});
					push @newChilds, $net;
				}
				@childs	= @newChilds;
			}
		} else {
			@childs	= $networkTable->search(['ID', 'network', 'state'], {rootID => $rootID, ipv6ID => ''}, 0, "AND network >" . (($withParent) ? '=' : '') . " $networkDec AND network <= $broadcast");
		}
	}
	return (@childs) ? @childs : ();
}

sub getNrOfChilds {
	warn 'SUB: ' . (caller(0))[3] . ' (' . (caller(1))[3] . ")\n" if $conf->{var}->{showsubs};
	my $networkDec		= shift;
	my $rootID				= shift;
	my $ipv6					= shift;
	$ipv6							= &rootID2ipv6($rootID) unless defined $ipv6;
	my $broadcast			= ($ipv6) ? &getV6BroadcastNet($networkDec, 128) : &net2dec(&dec2ip(&getBroadcastFromNet($networkDec)) . '/32');
	my @nrs						= ();

	my $networkTable	= $conf->{var}->{TABLES}->{network};
	unless (defined $networkTable) {
		warn "Cannot get Number of Parents. DB Error (network)\n";
		return 0;
	}
	
	unless ($networkDec) {
		@nrs	= $networkTable->search(['ID'], {rootID => $rootID});
		return ($#nrs + 1) || 0;
	}

	if ($ipv6) {
		my ($net, $host, $cidr)			= &netv6Dec2PartsDec($networkDec);
		my ($netB, $hostB, $cidrB)	= &netv6Dec2PartsDec($broadcast);
		my $networkV6Table	= $conf->{var}->{TABLES}->{networkV6};
		unless (defined $networkV6Table) {
			warn "Cannot get NetworkV6 Parent. DB Error (networkV6)\n";
			return undef;
		}

		@nrs	= $networkV6Table->search(
			['ID'],
			{rootID => $rootID}, 0,
			"AND (
				(networkPrefix > $net) OR 
				(networkPrefix = $net AND hostPart > $host) OR 
				(networkPrefix = $net AND hostPart = $host AND cidr > $cidr)
			) AND (
				(networkPrefix < $netB) OR 
				(networkPrefix = $netB AND hostPart < $hostB) OR 
				(networkPrefix = $netB AND hostPart = $hostB AND cidr <= $cidrB)
			) ORDER BY networkPrefix, hostPart, cidr");
	} else {
		@nrs	= $networkTable->search(['ID'], {rootID => $rootID, ipv6ID => ''}, 0, "AND network > $networkDec AND network <= $broadcast");
	}

	return ($#nrs + 1) || 0;
}

sub getMaintInfosFromNet {
	warn 'SUB: ' . (caller(0))[3] . ' (' . (caller(1))[3] . ")\n" if $conf->{var}->{showsubs};
	my $netID					= shift;
	my $networkTable  = $conf->{var}->{TABLES}->{network};

	return {} unless defined $netID;

	unless (defined $networkTable) {
		warn "Cannot get Maintenance Infos for Network. DB Error (network)\n";
		return {};
	}
	
	my $net	= ($networkTable->search(['*'], {ID => $netID}))[0];

	if (defined $net) {
		if ($net->{ipv6ID}) {
			my $netTableV6	= $conf->{var}->{TABLES}->{networkV6};
			unless (defined $netTableV6) {
				warn "Cannot get Network. DB Error (networkV6)\n";
				return ();
			}
			my $netV6	= ($netTableV6->search(['networkPrefix', 'hostPart', 'cidr'], {ID => $net->{ipv6ID}}))[0];
			if (defined $netV6) {
				$net->{network}	= &ipv6Parts2NetDec($netV6->{networkPrefix}, $netV6->{hostPart}, $netV6->{cidr});
				$net->{ipv6}		= 1;
			}
		}
		else {
			$net->{ipv6}	= 0;
		}
	}

	return (defined $net) ? $net : {};
}

sub getV6Net {
	my $ipv6ID	= shift;

	my $netTableV6	= $conf->{var}->{TABLES}->{networkV6};
	unless (defined $netTableV6) {
		warn "Cannot get Network. DB Error (networkV6)\n";
		return ();
	}
	my $netV6	= ($netTableV6->search(['*'], {ID => $ipv6ID}))[0];

	return $netV6;
}

sub getMaintInfosFromRoot {
	warn 'SUB: ' . (caller(0))[3] . ' (' . (caller(1))[3] . ")\n" if $conf->{var}->{showsubs};
	my $rootID		= shift;
	my $box				= {};
	my $rootTable	= $conf->{var}->{TABLES}->{root};
	  unless (defined $rootTable) {
		warn "Cannot get Maintenance Infos for Root. DB Error (root)\n";
		return {};
	}
	
	my $root	= ($rootTable->search(['*'], {ID => $rootID}))[0];

	return $root || {};
}

sub delNet {
	warn 'SUB: ' . (caller(0))[3] . ' (' . (caller(1))[3] . ")\n" if $conf->{var}->{showsubs};
	my $netID					= shift;
	my $bWithSubnets	= shift || 0;
	my $bLocal				= shift || 0;
	my $errors				= '';
	my $ipv6					= 0;
	return '' unless defined $netID;
	
	my ($rootID, $networkDec)	= ();
	if ($bWithSubnets == -1) {
		$rootID				= $netID;
		$ipv6					= &rootID2ipv6($rootID);
		$bWithSubnets	= 0;
		$networkDec		= -1;
	} else {
		($rootID, $networkDec, $ipv6)	= &netID2Stuff($netID);
	}
	my $rootName	= &rootID2Name($rootID);

	my $networkTable	= $conf->{var}->{TABLES}->{network};
	unless (defined $networkTable) {
		my $err	= 'Cannot delete Network. DB Error (network)\n';
		&warnL($err) unless $bLocal;
		return ($bLocal) ? $err : 0;
	}
	my $networkACTable	= $conf->{var}->{TABLES}->{networkAC};
	unless (defined $networkACTable) {
		my $err	= "Cannot delete Network. DB Error (networkAC)\n";
		&warnl($err) unless $bLocal;
		return ($bLocal) ? $err : 0;
	}
	my $tmplValueTable	= $conf->{var}->{TABLES}->{templateValue};
	unless (defined $tmplValueTable) {
		my $err	= "Cannot delete Network. DB Error (templateValue)";
		&warnl($err) unless $bLocal;
		return ($bLocal) ? $err : 0;
	}
	
	my $rows		= 0;
	my @netIDs	= ();
	if ($bWithSubnets) {
		my @tmp	= &getNetworkChilds($netID, 0, 1);
		map {push @netIDs, [$_->{ID}, $_->{network}]} @tmp;
	} else {
		if ($networkDec == -1) {
			my @tmp	= &getNetworkChilds($rootID, 1, 0);
			map {push @netIDs, [$_->{ID}, $_->{network}]} @tmp;
		} else {
			push @netIDs, [$netID, $networkDec];
		}
	}

	foreach (reverse @netIDs) {
		my $netID				= $$_[0];
		my $networkDec	= $$_[1];
		$networkDec			= Math::BigInt->new($networkDec) if $ipv6;
		my $network			= ($ipv6) ? &netv6Dec2net($networkDec) : &dec2net($networkDec);

		&debug("Delete Network " . (($ipv6) ? &netv6Dec2net($networkDec) : &dec2net($networkDec)) . " from $rootName");

		unless (&checkNetACL($netID, 'w')) {
			$errors	.= "\n" . (($ipv6) ? &netv6Dec2net($networkDec) : &dec2net($networkDec)) . ": Not enouph permissions (write) to delete this Network";
			next;
		}

		if ($ipv6) {
			my $networkV6Table	= $conf->{var}->{TABLES}->{networkV6};
			unless (defined $networkV6Table) {
				my $err	= 'Cannot delete Network. DB Error (networkV6)\n';
				&warnL($err) unless $bLocal;
				return ($bLocal) ? $err : 0;
			}
			my $net	= ($networkTable->search(['ipv6ID', 'rootID'], {ID => $netID}))[0];
			unless (defined $net) {
				$errors .= '\n' . sprintf(_gettext("Error while deleting '%s' from '%s': %s"), $network, $rootName, "Network not found!");
				next;
			}
			$networkV6Table->clear();
			$networkV6Table->delete({ID => $net->{ipv6ID}, rootID => $net->{rootID}});
			if ($networkV6Table->error) {
				$errors .= '\n' . sprintf(_gettext("Error while deleting V6 '%s' from '%s': %s"), $network, $rootName, $networkV6Table->errorStrs);
				next;
			}
		}
		$networkTable->clear();
		$networkTable->delete({ID => $netID});
		if ($networkTable->error) {
			$errors .= '\n' . sprintf(_gettext("Error while deleting '%s' from '%s': %s"), $network, $rootName, $networkTable->errorStrs);
			next;
		}
		$rows++;
		$networkACTable->clear();
		$networkACTable->delete({netID => $netID});
		if ($networkACTable->error) {
			warn sprintf("Error while deleting ACLs for '%s' from '%s': %s", $network, $rootName, $networkACTable->errorStrs);
		}

		$tmplValueTable->clear();
		$tmplValueTable->delete({netID => $netID});
		if ($tmplValueTable->error) {
			warn sprintf("Error while deleting Templates for '%s' from '%s': %s", $network, $rootName, $tmplValueTable->errorStrs);
		}
	}
	&removeFromNetcache($rootID);
	
	if ($errors) {
		&warnl($errors) unless $bLocal;
		return ($bLocal) ? $errors : 0;
	} else {
		$rows	=~ s/0E0/0/;
		unless ($networkDec == -1) {
			my $network			= ($ipv6) ? &netv6Dec2net($networkDec) : &dec2net($networkDec);
			&warnl(sprintf(_gettext("Successfully deleted '%s' from '%s' (%i Networks deleted)"), $network, $rootName, $rows));
		}
		return ($bLocal) ? $rows : 1;
	}
}

sub genRandBranch {
	warn 'SUB: ' . (caller(0))[3] . ' (' . (caller(1))[3] . ")\n" if $conf->{var}->{showsubs};
	my $rootName	= '';
	my $rootDescr	= '';

	for (0 .. 5) {
		$rootName		.= chr(97 + int(rand(25)));
		$rootDescr	.= chr(97 + int(rand(25)));
	}
	&addRoot($rootName, $rootDescr);
	my $rootID	= &rootName2ID($rootName);

	for (0 .. 500) {
		my $ipaddress	= '192.168';
		for (0 .. 2) {
			$ipaddress	.= '.';
			$ipaddress	.= 1 + int(rand(255));
		}
		my $cidr	= 32 - 16 + int(rand(15));
		my $descr	= '';
		for (0 .. 5) {
			$descr	.= chr(97 + int(rand(25)));
		}
		
		my $netmask			= &getNetmaskFromCidr($cidr);
		my $netaddress	= &dec2ip(&getNetaddress($ipaddress, $netmask));
		&addNet(0, $rootID, $netaddress, $cidr, $descr, 0, 0, 0, 1) if $netaddress;
	}
}

sub delRoot {
	warn 'SUB: ' . (caller(0))[3] . ' (' . (caller(1))[3] . ")\n" if $conf->{var}->{showsubs};
	my $rootID				= shift;
	my $rootName			= &rootID2Name($rootID);
	my $rootTable			= $conf->{var}->{TABLES}->{root};
	my $rootACTable		= $conf->{var}->{TABLES}->{rootAC};
	
	unless (defined $rootTable) {
		warn "Cannot delete Root. DB Error (root)\n";
		return 0;
	}
	unless (defined $rootACTable) {
		warn "Cannot delete Root. DB Error (rootAC)\n";
		return 0;
	}
	
	my $rows	= &delNet($rootID, -1, 1);
	if ($rows !~ /^\d+$/) {
		&warnl(sprintf(_gettext("Error while deleting '%s': %s"), $rootName, $rows));
		return 0;
	} else {
		$rootTable->clear();
		$rootTable->delete({ID => $rootID});
		if ($rootTable->error) {
			&warnl(sprintf(_gettext("Error while deleting '%s': %s"), $rootName, $rootTable->errorStrs));
			return 0;
		} else {
			&removeFromNetcache($rootID);
			$rootACTable->clear();
			$rootACTable->delete({rootID => $rootID});
			if ($rootACTable->error) {
				&warnl(sprintf(_gettext("Error while deleting '%s': %s"), $rootName, $rootACTable->errorStrs));
			} else {
				&debug("$rows netAC Entries removed");
			}
			&warnl(sprintf(_gettext("Successfully deleted '%s' (%i Networks deleted)"), $rootName, $rows));
		}
	}

	return 1;
}

sub copyNetsTo {
	warn 'SUB: ' . (caller(0))[3] . ' (' . (caller(1))[3] . ")\n" if $conf->{var}->{showsubs};
	my $targetRootID		= shift;
	my $networks				= shift;
	my $bDel						= shift || 0;
	my $bSingle					= shift || 0;
	my $targetIPv6			= &rootID2ipv6($targetRootID);
	my $s								= $HaCi::HaCi::session;
	my $expands					= $s->param('expands') || {};
	my $networkTable		= $conf->{var}->{TABLES}->{network};
	unless (defined $networkTable) {
		warn "Cannot copy Networks. DB Error (network)\n";
		return 0;
	}
	my $networkV6Table	= $conf->{var}->{TABLES}->{networkV6};
	unless (defined $networkV6Table) {
		warn "Cannot copy Networks. DB Error (networkV6)\n";
		return 0;
	}
	my $networkACTable	= $conf->{var}->{TABLES}->{networkAC};
	unless (defined $networkACTable) {
		warn "Cannot copy Networks. DB Error (networkAC)\n";
		return 0;
	}
	my $tmplValueTable	= $conf->{var}->{TABLES}->{templateValue};
		unless (defined $tmplValueTable) {
		&warnl("Cannot delete Template. DB Error (templateValue)");
		return 0;
	}

	my $error	= 'Error while copying:';
	foreach (@$networks) {
		my ($network, $rootID)	= split/_/;
		my $ipv6								= &rootID2ipv6($rootID);
		if (($ipv6 && !$targetIPv6) || (!$ipv6 && $targetIPv6)) {
			$error	.= "\n" . "$network: Cannot copy " . (($ipv6) ? 'IPv6 ' : 'IPv4') . 
				" Net into an " . (($ipv6) ? 'IPv4 ' : 'IPv6') . " Root!";
			next;
		}
		my $networkDec	= ($ipv6) ? &netv62Dec($network) : &net2dec($network);
		my @networks		= ();

		if ($bSingle || $expands->{network}->{$rootID}->{$networkDec}) {
			push @networks, $networkDec;
		} else {
			my $ipv6ID		= ($ipv6) ? &netv6Dec2ipv6ID($networkDec) : '';
			my $netID			= &getNetID($rootID, $networkDec, $ipv6ID);
			my $broadcast	= ($ipv6) ? &getV6BroadcastNet($networkDec, 128) : &net2dec(&dec2ip(&getBroadcastFromNet($networkDec)) . '/32');
			my @childs		= &getNetworkChilds($netID, 0, 1);
			if (@childs) {
				foreach (@childs) {
					push @networks, $_->{network};
				}
			}
		}

		foreach (@networks) {
			my $networkDec	= $_;
			my $ipv6ID			= ($ipv6) ? &netv6Dec2ipv6ID($networkDec) : '';
			my $netID				= &getNetID($rootID, $networkDec, $ipv6ID);
			my $networkt		= &getMaintInfosFromNet($netID);

			next unless defined $networkt;
			my $origNetID	= $networkt->{ID};

			unless (&checkNetACL($origNetID, 'r')) {
				$error	.= "\n" . (($ipv6) ? &netv6Dec2net($networkDec) : &dec2net($networkDec)) . ": Not enouph permissions (source:read) to copy this Network";
				next;
			}

			my $parent		= &getNetworkParentFromDB($targetRootID, $networkDec, $targetIPv6);
			my $parentDec	= (defined $parent) ? $parent->{network} : 0;
			my $parentID	= (defined $parent) ? $parent->{ID} : 0;
			unless (($parentID && &checkNetACL($parentID, 'w')) || (!$parentID && &checkRootACL($rootID, 'w'))) {
				$error	.= "\n" . (($ipv6) ? &netv6Dec2net($networkDec) : &dec2net($networkDec)) . ": Not enouph permissions (target:write) to copy this Network";
				next;
			}

			if ($bDel) {
				$networkTable->clear();
				$networkTable->rootID($targetRootID);
				$networkTable->modifyFrom($s->param('username'));
				$networkTable->modifyDate(&currDate('datetime'));
				$networkTable->update({ID => $networkt->{ID}});
				if ($networkTable->error) {
					$error	.= "\n$network: " . $networkTable->errorStrs();
					next;
				};
				if ($ipv6) {
					$networkV6Table->clear();
					$networkV6Table->rootID($targetRootID);
					$networkV6Table->update({ID => $networkt->{ipv6ID}, rootID => $rootID});
					if ($networkV6Table->error) {
						$error	.= "\n$network: " . $networkV6Table->errorStrs();
						$networkTable->clear();
						$networkTable->rootID($rootID);
						$networkTable->modifyFrom($s->param('username'));
						$networkTable->modifyDate(&currDate('datetime'));
						$networkTable->update({ID => $networkt->{ID}});
						next;
					};
				}
				&removeFromNetcache($rootID);
				&removeFromNetcache($targetRootID);
			} else {
				$networkTable->clear();
				foreach (keys %{$networkt}) {
					if ($_ eq 'rootID') {
						$networkTable->rootID($targetRootID);
					}
					elsif ($_ eq 'ipv6') {
					}
					elsif ($_ eq 'ID') {
						$networkTable->ID(undef);
					}
					elsif ($_ eq 'network' && $ipv6) {
						$networkTable->network(0);
					} else {
						if ($networkTable->can($_)) {
							$networkTable->$_($networkt->{$_});
						} else {
							warn " copyNetsTo: networkTable hasn't this method: $_\n";
						}
					}
				}
				$networkTable->createFrom($s->param('username'));
				$networkTable->createDate(&currDate('datetime'));
				$networkTable->insert();
				if ($networkTable->error) {
					$error	.= "\n$network: " . $networkTable->errorStrs;
					next;
				};
				my $newNetID	= &getNetID($targetRootID, $networkDec, $networkt->{ipv6ID});

				if ($ipv6) {
					my $ipv6Error	= 0;
					my $v6Net			= ($networkV6Table->search(['ID', 'networkPrefix', 'hostPart', 'cidr'], {ID => $networkt->{ipv6ID}, rootID => $rootID}, 0))[0];
					if (defined $v6Net) {
						$networkV6Table->clear();
						$networkV6Table->ID($networkt->{ipv6ID});
						$networkV6Table->rootID($targetRootID);
						$networkV6Table->networkPrefix($v6Net->{networkPrefix});
						$networkV6Table->hostPart($v6Net->{hostPart});
						$networkV6Table->cidr($v6Net->{cidr});
						$networkV6Table->insert();
						if ($networkV6Table->error) {
							$error			.= "\n$network: " . $networkV6Table->errorStrs;
							$ipv6Error	= 1;
						}
					} else {
						$ipv6Error	= 1;
					}
					if ($ipv6Error) {
						&delNet($newNetID, 0, 1);
						next;
					}
				}

				&removeFromNetcache($targetRootID);
				my $netID	= &getNetID($targetRootID, $networkDec, $networkt->{ipv6ID});
				unless (defined $netID) {
					$error	.= "\n" . (($ipv6) ? &netv6Dec2net($networkDec) : &dec2net($networkDec)) . ": Cannot set Access/TmplValues. No netID found";
				}

				my @networkACs	= $networkACTable->search(['*'], {netID	=> $origNetID});
				foreach (@networkACs) {
					my $networkAC	= $_;
					$networkACTable->clear();
					foreach (keys %{$networkAC}) {
						if ($_ eq 'rootID') {
						}
						elsif ($_ eq 'network') {
						}
						elsif ($_ eq 'netID') {
							$networkACTable->netID($netID);
						}
						elsif ($_ eq 'ID') {
							$networkACTable->ID(undef);
						} else {
							$networkACTable->$_($networkAC->{$_});
						}
					}
					$networkACTable->insert();
					if ($networkACTable->error) {
						$error	.= "\n$network: " . $networkACTable->errorStrs();
					}
				}

				my @tmplValues	= $tmplValueTable->search(['*'], {netID	=> $origNetID});
				foreach (@tmplValues) {
					my $tmplValue	= $_;
					$tmplValueTable->clear();
					foreach (keys %{$tmplValue}) {
						if ($_ eq 'netID') {
							$tmplValueTable->netID($netID);
						}
						elsif ($_ eq 'ID') {
							$tmplValueTable->ID(undef);
						} else {
							$tmplValueTable->$_($tmplValue->{$_});
						}
					}
					$tmplValueTable->insert();
					if ($tmplValueTable->error()) {
						$error	.= "\n" . (($ipv6) ? &netv6Dec2net($networkDec) : &dec2net($networkDec)) . ": Cannot insert TmplValue: " . $tmplValueTable->errorStrs();
					}
				}
			}
		}
	}
	if ($error ne 'Error while copying:') {
		&warnl($error);
		return 0;
	} else {
		return 1;
	}
}

sub delNets {
	warn 'SUB: ' . (caller(0))[3] . ' (' . (caller(1))[3] . ")\n" if $conf->{var}->{showsubs};
	my $networks				= shift;
	my $s								= $HaCi::HaCi::session;
	my $expands					= $s->param('expands') || {};
	my $networkTable		= $conf->{var}->{TABLES}->{network};
	unless (defined $networkTable) {
		warn "Cannot delete Networks. DB Error (network)\n";
		return 0;
	}

	my $error	= 'Error while deleting:';
	foreach (@$networks) {
		my ($network, $rootID)	= split/_/;
		my $ipv6								= &rootID2ipv6($rootID);
		my $networkDec					= ($ipv6) ? &netv62Dec($network) : &net2dec($network);
		my $ipv6ID							= ($ipv6) ? &netv6Dec2ipv6ID($networkDec) : '';
		my $netID								= &getNetID($rootID, $networkDec, $ipv6ID);

		if ($expands->{network}->{$rootID}->{$networkDec}) {
			my $rows	= &delNet($netID, 0, 1);
			$error	.= $rows if $rows !~ /^\d+$/;
		} else {
			my $rows	= &delNet($netID, 1, 1);
			$error	.= $rows if $rows !~ /^\d+$/;
		}
	}
	if ($error ne 'Error while deleting:') {
		&warnl($error);
		return 0;
	} else {
		return 1;
	}
}

sub search {
	warn 'SUB: ' . (caller(0))[3] . ' (' . (caller(1))[3] . ")\n" if $conf->{var}->{showsubs};
	my $q						= $HaCi::HaCi::q;
	my $search			= &getParam(1, '', $q->param('search'));
	my $bLike				= (defined $q->param('exact') ? 0 : 1);
	my $bFuzzy			= (defined $q->param('fuzzy') ? 1 : 0);
	my $state				= &getParam(1, undef, $q->param('state'));
	my $tmplID			= &getParam(1, -1, $q->param('tmplID'));
	my $searchLimit	= $conf->{static}->{misc}->{searchlimit} || 1000;
	$bLike					= (defined $bLike) ? $bLike : 1;
	return unless $search;

	my $tmplBox	= {};
	if ($tmplID > 0) {
		foreach ($q->param) {
			$tmplBox->{$1}	= $q->param($_) if /^tmplEntryID_(\d+)$/ && $q->param($_) ne '';
		}
	}

	my $tmplResultBox	= {};
	if ($tmplID ne -1) {
		my $tmplSearch	= '0';
		foreach (keys %{$tmplBox}) {
			my $search	= $tmplBox->{$_};
			$search			=~ s/'/\\'/g;
			$search			=~ s/"/\\"/g;
			$search			=~ s/;/\\;/g;
			$search			=~ s/%/\\%/g;
			$search			=~ s/([^\\]|^)\*/%/g;
			$tmplSearch	.= " OR (tmplEntryID=$_ AND CONVERT(value USING latin1) " . (($bLike) ? "like '%$search%'" : "='$search'") . ')';
		}

		my $tmplValueTable	= $conf->{var}->{TABLES}->{templateValue};
		unless (defined $tmplValueTable) {
			&warnl("Cannot get Template Values. DB Error (templateValue)");
			return '';
		}
		my @results	= $tmplValueTable->search(['netID', 'tmplEntryID'], $tmplSearch);
		foreach (@results) {
			$tmplResultBox->{$_->{netID}}->{$_->{tmplEntryID}}	= 1;
		}
	}

	my $t				= $HaCi::GUI::init::t;
	my $bNet		= 1 if &checkSpelling_Net($search, 0);
	my $bIP			= 1 if &checkSpelling_IP($search, 0);
	my $ipv6		= 1 if $search =~ /\:/;
	$search			.= (($ipv6) ? '/128' : '/32') if $bIP;
	$search			= (($ipv6) ? &netv62Dec($search) : &net2dec($search)) if $bNet || $bIP;
	$search			=~ s/'/\\'/g;
	$search			=~ s/"/\\"/g;
	$search			=~ s/;/\\;/g;
	$search			=~ s/%/\\%/g;
	$search			=~ s/([^\\]|^)\*/%/g;
	$search			= '%' . $search . '%' if $bLike && !$bFuzzy;
	$state			= ($state eq '-1') ? undef : int($state);
	my $fuzzySearch	= 
		'(substring(soundex(description), 2) LIKE ' . 
		(($bLike) ? "concat('%',  " : '') . 
		"substring(soundex('$search'), 2)" . 
		(($bLike) ? ", '%')" : '') . 
			(($bNet || $bIP) ? (
				') OR (substring(soundex(network), 2) LIKE ' . 
				(($bLike) ? "concat('%',  " : '') . 
				"substring(soundex('$search'), 2)" . 
				(($bLike) ? ", '%')" : '') . ')') : 
			')');
	$fuzzySearch	.= " AND state='$state'" if defined $state;
	$fuzzySearch	.= " AND tmplID='$tmplID'" unless $tmplID == -1;

	my $normSearch	= "(description LIKE '$search'";
	$normSearch			.= " OR network LIKE '$search'" if $bNet || $bIP;
	$normSearch			.= ')';
	$normSearch			.= " AND state='$state'" if defined $state;
	$normSearch			.= " AND tmplID='$tmplID'" unless $tmplID == -1;

	$t->{V}->{'gettext_rootName'}	= _gettext("Root Name");

	my $networkTable	= $conf->{var}->{TABLES}->{network};
	unless (defined $networkTable) {
		warn "Cannot search. DB Error (network)\n";
		return 0;
	}

	my $networkV6Table	= $conf->{var}->{TABLES}->{networkV6};
	unless (defined $networkV6Table) {
		warn "Cannot search. DB Error (networkV6)\n";
		return 0;
	}

	my $qryRef	= ($bFuzzy) ? $fuzzySearch : $normSearch;
	
	my @results	= $networkTable->search(
		['ID', 'network', 'description', 'rootID', 'ipv6ID', 'state'], $qryRef, $bLike, "ORDER BY network LIMIT $searchLimit"
	);

	my $tmp				= {};
	my $tmplInfos	= {};
	foreach (@results) {
		my $net			= $_;
		my $rootID	= $net->{rootID};
		my $ipv6		= &rootID2ipv6($rootID);
		if ($tmplID ne -1) {
			my $tmplResult	= 0;
			foreach (keys %{$tmplBox}) {
				$tmplResult	= 1 unless $tmplResultBox->{$net->{ID}}->{$_};
			}
			next if $tmplResult;
			$tmplInfos->{$net->{ID}}	= &getTemplateData($net->{ID}, $tmplID, 1);
		}
		if ($ipv6) {
			my $v6Net	= ($networkV6Table->search(['ID', 'networkPrefix', 'hostPart', 'cidr'], {ID => $net->{ipv6ID}, rootID => $rootID}, 0))[0];
			if (defined $v6Net) {
				$net->{network}	= &ipv6Parts2NetDec($v6Net->{networkPrefix}, $v6Net->{hostPart}, $v6Net->{cidr});
			}
		}

		$tmp->{A}->{$rootID}->{NETS}->{$net->{network}}	= $net;
		$tmp->{A}->{$rootID}->{IPV6}										= $ipv6;
	}
	
	foreach my $rootID (keys %{$tmp->{A}}) {
		my $ipv6		= $tmp->{A}->{$rootID}->{IPV6};
		my @nets		= ();
		if ($ipv6) {
			@nets	= sort {Math::BigInt->new($a)<=>Math::BigInt->new($b)} keys %{$tmp->{A}->{$rootID}->{NETS}};
		} else {
			@nets	= sort {$a<=>$b} keys %{$tmp->{A}->{$rootID}->{NETS}};
		}
		foreach (@nets) {
			next unless $tmp->{A}->{$rootID}->{NETS}->{$_}->{network};
			next if !&checkRootACL($rootID, 'r') || !&checkNetACL($tmp->{A}->{$rootID}->{NETS}->{$_}->{ID}, 'r');
			
			my $network		= ($ipv6) ? &netv6Dec2net($tmp->{A}->{$rootID}->{NETS}->{$_}->{network}) : &dec2net($tmp->{A}->{$rootID}->{NETS}->{$_}->{network});
			my $ipaddress	= (split/\//, $network)[0];
			my $rootName	= &rootID2Name($rootID);
			if ($rootName ne '') {
				push @{$tmp->{B}}, {
					netID				=> $tmp->{A}->{$rootID}->{NETS}->{$_}->{ID},
					network			=> $network,
					description	=> &quoteHTML($tmp->{A}->{$rootID}->{NETS}->{$_}->{description}),
					url					=> "$conf->{var}->{thisscript}?jumpToButton=1&rootIDJump=$rootID&jumpTo=$ipaddress",
					rootName		=> &quoteHTML($rootName),
					state				=> &networkStateID2Name($tmp->{A}->{$rootID}->{NETS}->{$_}->{state}),
				}
			}
		}
	}
	
	if ($#{$tmp->{B}} == -1) {
		$t->{V}->{searchResult}							=	{};
		$t->{V}->{noSearchResult}						= 1;
		$t->{V}->{'gettext_nothing_found'}	= _gettext("Nothing found");
		return;
	}

	$t->{V}->{searchResult}	= $tmp->{B};
	$t->{V}->{tmplInfos}		= $tmplInfos if $tmplID ne -1;
	$t->{V}->{tmplDescr}		= &getTemplateEntries($tmplID, 0, 0, 1, 0, 1) if $tmplID ne -1;
}

sub networkStateName2ID {
	warn 'SUB: ' . (caller(0))[3] . ' (' . (caller(1))[3] . ")\n" if $conf->{var}->{showsubs};
	my $name	= shift;
	
	if (exists $conf->{var}->{misc}->{networkstates}->{name}->{$name}) {
		return $conf->{var}->{misc}->{networkstates}->{name}->{$name} || 0;
	}
	
	my $states	= $conf->{static}->{misc}->{networkstates};
	foreach (@$states) {
		if ($name eq $_->{name}) {
			$conf->{var}->{misc}->{networkstates}->{name}->{$name}	= $_->{id};
			return $_->{id};
		}
	}
	return 0;
}

sub networkStateID2Name{
	warn 'SUB: ' . (caller(0))[3] . ' (' . (caller(1))[3] . ")\n" if $conf->{var}->{showsubs};
	my $ID	= shift;

	if (exists $conf->{var}->{misc}->{networkstates}->{id}->{$ID}) {
		return $conf->{var}->{misc}->{networkstates}->{id}->{$ID};
	}

	my $states	= $conf->{static}->{misc}->{networkstates};
	foreach (@$states) {
		if ($ID eq $_->{id}) {
			$conf->{var}->{misc}->{networkstates}->{id}->{$ID}	= $_->{name};
			return $_->{name};
		}
	}
	return '';
}

sub getNetworkTypes {
	warn 'SUB: ' . (caller(0))[3] . ' (' . (caller(1))[3] . ")\n" if $conf->{var}->{showsubs};
	my $bOther		= shift || 0;
	my $types			= [];
	my $tmplTable	= $conf->{var}->{TABLES}->{template};

	push @{$types}, {ID	=> 0, name	=> 'other'} if $bOther;

	unless (defined $tmplTable) {
		warn "Cannot get Network Types. DB Error (template)\n";
		return $types;
	}
	
	my @netTypes	= $tmplTable->search(['ID', 'name'], {type	=> 'Nettype'}, 0, "ORDER BY `name`");
	foreach (@netTypes) {
		push @{$types}, {ID	=> $_->{ID}, name	=> $_->{name}};
	}

	return $types;
}

sub getTemplate {
	warn 'SUB: ' . (caller(0))[3] . ' (' . (caller(1))[3] . ")\n" if $conf->{var}->{showsubs};
	my $tmplID			= shift;
	my $return			= {};
	my $returnFail	= {
		Positions	=> [
			{ID	=> 0, name	=> 1}
		],
		MaxPosition	=> 0,
	};

	return $returnFail unless defined $tmplID;
	
	my $tmplTable	= $conf->{var}->{TABLES}->{template};
	unless (defined $tmplTable) {
		warn "Cannot get Template. DB Error (template)\n";
		return $returnFail;
	}

	my $tmpl	= ($tmplTable->search(['*'], {ID => $tmplID}))[0];
	$return	= $tmpl;

	unless (defined $tmpl) {
		&warnl(sprintf(_gettext("No Template for this ID '%i' available!"), $tmplID));
		return $returnFail;
	}

	my $tmplEntryTable	= $conf->{var}->{TABLES}->{templateEntry};
	unless (defined $tmplEntryTable) {
		warn "Cannot get Template. DB Error (templateEntry)\n";
		return $returnFail;
	}

	my @entries	= $tmplEntryTable->search(['ID'], {tmplID	=> $tmplID});
	return $returnFail if $#entries < 0;
	
	for (0 .. ($#entries + 1)) {
		push @{$return->{Positions}}, {ID	=> (($#entries + 1) - $_), name	=> (($#entries + 2) - $_)};
	}

	$return->{MaxPosition}	= ($#entries + 1);

	return $return;
}

sub saveTmpl {
	warn 'SUB: ' . (caller(0))[3] . ' (' . (caller(1))[3] . ")\n" if $conf->{var}->{showsubs};
	my $type			= shift || 0;
	my $q					= $HaCi::HaCi::q;
	my $s					= $HaCi::HaCi::session;
	my $tmplID		= &getParam(1, -1, $q->param('tmplID'));
	my $tmplType	= &getParam(1, undef, $q->param('tmplType'));
	my $tmplTable	= $conf->{var}->{TABLES}->{template};
	my $position	= &getParam(1, 0, $q->param('position'));
	unless (defined $tmplTable) {
		&warnl("Cannot save Template. DB Error (template)");
	}
	my $tmplEntryTable	= $conf->{var}->{TABLES}->{templateEntry};
	unless (defined $tmplEntryTable) {
		&warn("Cannot save Template. DB Error (templateEntries)");
		return 0;
	}
	unless (defined $tmplType) {
		&warnl("Cannot save Template. No Template Type given!");
	}

	if ($tmplID < 0) {
		unless (defined $q->param('tmplName')) {
			&warnl(_gettext('Sorry, you have to give me a Name!'));
			return 0;
		}
		my $tmplName	= &getParam(1, '', $q->param('tmplName'));

		$tmplTable->clear();
		$tmplTable->name($tmplName);
		$tmplTable->type($tmplType);

		my $DB	= ($tmplTable->search(['ID'], {name => $tmplName}))[0];
		if ($DB) {
			$tmplTable->modifyFrom($s->param('username'));
			$tmplTable->modifyDate(&currDate('datetime'));
			&debug("Change Template-Entry for '$tmplName'\n");
			unless ($tmplTable->update({ID => $DB->{'ID'}})) {
				&warnl("Cannot update Template-Entry '$tmplName': " . $tmplTable->errorStrs());
			}
		} else {
			$tmplTable->ID(undef);
			$tmplTable->createFrom($s->param('username'));
			$tmplTable->createDate(&currDate('datetime'));
			unless ($tmplTable->insert()) {
				&warnl("Cannot create Template-Entry '$tmplName': " . $tmplTable->errorStrs());
			}
		}
		my $newTmpl	= ($tmplTable->search(['ID'], {name	=> $tmplName}))[0];
		$tmplID			= $newTmpl->{ID};
	}
	
	if ($type == 2) {
		my $tmplEntryID	= &getParam(1, undef, $q->param('tmplEntryID'));
		if (!defined $tmplEntryID || $tmplEntryID eq '') {
			&warnl("No Template Entry ID!");
			return $tmplID;
		}
		$tmplEntryTable->clear();
		my $nrs	= $tmplEntryTable->delete({ID => $tmplEntryID});
		if ($tmplEntryTable->error) {
			&warnl("Error: " . $tmplEntryTable->errorStrs);
			return $tmplID;
		}
		&debug("$nrs Entries from Template deleted!\n");

		my @entries	= $tmplEntryTable->search(['ID', 'position'], {tmplID => $tmplID}, 0, "AND position > $position");
		foreach (@entries) {
			$tmplEntryTable->clear();
			$tmplEntryTable->position(($_->{position} - 1));
			unless ($tmplEntryTable->update({ID => $_->{ID}})) {
				warn "Cannot update TmplEntryTable: " . $tmplEntryTable->errorStrs();
			}
		}
	} else {
		unless ($type) {
			my @entries	= $tmplEntryTable->search(['ID', 'position'], {tmplID => $tmplID}, 0, "AND position >= $position");
			foreach (@entries) {
				$tmplEntryTable->clear();
				$tmplEntryTable->position(($_->{position} + 1));
				unless ($tmplEntryTable->update({ID => $_->{ID}})) {
					warn "Cannot update TmplEntryTable: " . $tmplEntryTable->errorStrs();
				}
			}
		}
	
		my $tmpl	= ($tmplTable->search(['*'], {ID	=> $tmplID}))[0];
		$tmplEntryTable->clear();
		$tmplEntryTable->tmplID($tmplID);
		$tmplEntryTable->type(&getParam(1, 0, $q->param('TmplEntryType')));
		$tmplEntryTable->position($position);
		$tmplEntryTable->description(&getParam(1, '', $q->param('TmplEntryParamDescr')));
		$tmplEntryTable->size(&getParam(1, 1, $q->param('TmplEntryParamSize')));
		$tmplEntryTable->entries(&getParam(1, '', $q->param('TmplEntryParamEntries')));
		$tmplEntryTable->rows(&getParam(1, 1, $q->param('TmplEntryParamRows')));
		$tmplEntryTable->cols(&getParam(1, 1, $q->param('TmplEntryParamCols')));

		my $bError	= 0;
		if ($type == 1) {
			my $tmplEntryID	= &getParam(1, undef, $q->param('tmplEntryID'));
			unless (defined $tmplEntryID) {
				&warnl("No Template Entry ID!");
				return $tmplID;
			}
			unless ($tmplEntryTable->update({ID => $tmplEntryID})) {
				&warnl("Cannot update Template-Entry for Template '$tmpl->{name}': " . $tmplEntryTable->errorStrs());
				$bError	= 1;
			}
		} else {
			$tmplEntryTable->ID(undef);
			unless ($tmplEntryTable->insert()) {
				&warnl("Cannot insert Template-Entry for Template '$tmpl->{name}': " . $tmplEntryTable->errorStrs());
				$bError	= 1;
			}
		}
		unless ($bError) {
			$tmplTable->modifyFrom($s->param('username'));
			$tmplTable->modifyDate(&currDate('datetime'));
			&debug("Change Template-Entry for '$tmpl->{name}'\n");
			$tmplTable->errorStrs('');
			unless ($tmplTable->update({ID => $tmpl->{ID}})) {
				&warnl("Cannot update Template-Entry '$tmpl->{name}': " . $tmplTable->errorStrs());
			}
		}
	}

	return $tmplID;
}

sub getTemplateEntries {
	warn 'SUB: ' . (caller(0))[3] . ' (' . (caller(1))[3] . ")\n" if $conf->{var}->{showsubs};
	my $tmplID					= shift;
	my $bWithValues			= shift || 0;
	my $bWithChecks			= shift || 0;
	my $bOnlyDescrs			= shift || 0;
	my $bWithALLInMenus	= shift || 0;
	my $bQuoteHTML			= shift || 0;
	my $q								= $HaCi::HaCi::q;
	my $tmplEntries			= [];
	my $tmplEntryTable	= $conf->{var}->{TABLES}->{templateEntry};
	my $tmplPos2IDs			= [];
	my $descrs					= {};
	unless (defined $tmplEntryTable) {
		&warn("Cannot show Template. DB Error (templateEntries)");
		return 0;
	}
	
	my @entries	= $tmplEntryTable->search(['*'], {tmplID	=> $tmplID});
	foreach (&sortDBEntriesBy(\@entries, 'position', 1)) {
		my $ID					= $_->{ID};
		my $type				= $_->{type};
		my $descr				= $_->{description};
		my $size				= $_->{size};
		my $entries			= $_->{entries};
		my $rows				= $_->{rows};
		my $cols				= $_->{cols};
		my $pos					= $_->{position};
		my $title				= $type;
		$descr					= &quoteHTML($descr) if $bQuoteHTML;
		$descrs->{$ID}	= $descr if $descr && (!$bOnlyDescrs || ($bOnlyDescrs && $type != 0 && $type != 4));
		next if $bOnlyDescrs;

		push @$tmplPos2IDs, (
		 {
				name	=> 'tmplEntryPos2ID_' . $pos,
				value => (($type == 4) ? 'tmplEntryDescrID_' : 'tmplEntryID_') . $ID
			}
		);
	
		my $popupValues	= [];
		foreach (split(/\s*;\s*/, $entries)) {
			push @{$popupValues}, {
				ID	=> $_, name	=> $_
			};
		}
		unshift @{$popupValues}, {
				ID	=> '', name	=> '[ALL]'
		} if $bWithALLInMenus;
		
		if ($type == 0) {
			push @{$tmplEntries}, {
				onClick		=> ($bWithChecks) ? "updTmplParamsFromPreview($ID, 0, $pos)" : '',
				value			=> {
					type		=> 'hline',
					name		=> 'tmplEntryID_' . $ID,
					title		=> $title,
					colspan	=> 2,
				}
			};
		}
		elsif ($type == 1) {
			my $value	= (($bWithValues && defined $q->param('tmplEntryID_' . $ID)) ? $q->param('tmplEntryID_' . $ID) : '');
			$value		=~ s/"/&#34;/g;
			push @{$tmplEntries}, {
				onClick		=> ($bWithChecks) ? "javascript:updTmplParamsFromPreview($ID, 1, $pos)" : '',
				elements	=> [
					{
						target	=> 'key',
						type		=> 'label',
						value		=> $descr,
						name		=> 'tmplEntryDescrID_' . $ID,
						hidden	=> 1
					},
					{
						target	=> 'value',
						type		=> 'textfield',
						name		=> 'tmplEntryID_' . $ID,
						size		=> $size,
						title		=> $title,
						value		=> $value,
					}
				]
			};
		}
		elsif ($type == 2) {
			my $value	= (($bWithValues && defined $q->param('tmplEntryID_' . $ID)) ? $q->param('tmplEntryID_' . $ID) : '');
			$value		=~ s/"/&#34;/g;
			push @{$tmplEntries}, {
				onClick		=> ($bWithChecks) ? "javascript:updTmplParamsFromPreview($ID, 2, $pos)" : '',
				elements	=> [
					{
						target	=> 'key',
						type		=> 'label',
						value		=> $descr,
						name		=> 'tmplEntryDescrID_' . $ID,
						hidden	=> 1
					},
					{
						target	=> 'value',
						type		=> 'textarea',
						name		=> 'tmplEntryID_' . $ID,
						rows		=> $rows,
						cols		=> $cols,
						value		=> $value,
						title		=> $title,
					}
				]
			};
		}
		elsif ($type == 3) {
			push @{$tmplEntries}, {
				onClick		=> ($bWithChecks) ? "javascript:updTmplParamsFromPreview($ID, 3, $pos)" : '',
				elements	=> [
					{
						target	=> 'key',
						type		=> 'label',
						value		=> $descr,
						name		=> 'tmplEntryDescrID_' . $ID,
						hidden	=> 1
					},
					{
						target		=> 'value',
						type			=> 'popupMenu',
						name			=> 'tmplEntryID_' . $ID,
						size			=> $size,
						values		=> $popupValues,
						selected	=> (($bWithValues && defined $q->param('tmplEntryID_' . $ID)) ? [$q->param('tmplEntryID_' . $ID)] : []),
						title			=> $title,
					}
				]
			};
		}
		elsif ($type == 4) {
			push @{$tmplEntries}, {
				onClick		=> ($bWithChecks) ? "javascript:updTmplParamsFromPreview($ID, 4, $pos)" : '',
				elements	=> [
					{
						target	=> 'single',
						type		=> 'label',
						value		=> $descr,
						name		=> 'tmplEntryDescrID_' . $ID,
						title		=> $title,
						hidden	=> 1,
						colspan	=> 2,
						align		=> 'center',
					},
				]
			}
		}
	}

	if ($bOnlyDescrs) {
		return $descrs;
	} else {
		return ($tmplEntries, $tmplPos2IDs);
	}
}

sub sortDBEntriesBy {
	warn 'SUB: ' . (caller(0))[3] . ' (' . (caller(1))[3] . ")\n" if $conf->{var}->{showsubs};
	my $dbEntries	= shift;
	my $sortCol		= shift;
	my $num				= shift || 0;
	my $ipv6			= shift || 0;
	my $hash			= {};

	map {
		$hash->{$_->{$sortCol}} = $_
	} @{$dbEntries};

	my @array	= ();
	if ($num) {
		if ($ipv6) {
			map {push @array, $hash->{$_}} sort {Math::BigInt->new($a)<=>Math::BigInt->new($b)} keys %{$hash};
		} else {
			map {push @array, $hash->{$_}} sort {$a<=>$b} keys %{$hash};
		}
		return @array;
	} else {
		map {push @array, $hash->{$_}} sort keys %{$hash};
		return @array;
	}
}

sub delTmpl {
	warn 'SUB: ' . (caller(0))[3] . ' (' . (caller(1))[3] . ")\n" if $conf->{var}->{showsubs};
	my $tmplID		= shift;
	my $tmplName	= &tmplID2Name($tmplID);

	unless (defined $tmplID) {
		&warnl("No Template ID given!");
		return 0;
	}


	my $tmplEntryTable	= $conf->{var}->{TABLES}->{templateEntry};
	unless (defined $tmplEntryTable) {
		&warnl("Cannot delete Template. DB Error (templateEntry)");
		return '';
	}

	my $tmplValueTable	= $conf->{var}->{TABLES}->{templateValue};
	unless (defined $tmplValueTable) {
		&warnl("Cannot delete Template. DB Error (templateValue)");
		return '';
	}

	my @values	= $tmplValueTable->search(['ID', 'netID'], {tmplID => $tmplID}, 0, "Group by tmplID");
	my $nets		= '';
	foreach (@values) {
		my ($rootID, $network, $ipv6)	= &netID2Stuff($_->{netID});
		$nets	.= ', ' . &rootID2Name($rootID) . ':' . (($ipv6) ? &netv62Dec($network) : &dec2net($network));
	}
	if ($#values > -1) {
		&warnl(sprintf(_gettext("There are still Entries for this Template left. Please delete them first! (%s)"), $nets));
		return '';
	}

	my @entries	= $tmplEntryTable->search(['ID'], {tmplID => $tmplID});
	my $cnter	= 0;
	foreach (@entries) {
		$tmplEntryTable->clear();
		my $nrs	= $tmplEntryTable->delete({ID => $_->{ID}});
		if ($tmplEntryTable->error) {
			&warnl("Error: " . $tmplEntryTable->errorStrs);
			return 0;
		} else {
			$cnter++ if $nrs ne '0E0';
		}
	}
	&debug("$cnter Entries from Template deleted!\n");

	my $tmplTable	= $conf->{var}->{TABLES}->{template};
	unless (defined $tmplTable) {
		warn "Cannot delete Template. DB Error (template)\n";
		return '';
	}

	$tmplTable->clear();
	my $nrs	= $tmplTable->delete({ID => $tmplID});
	if ($tmplTable->error) {
		&warnl("Error: " . $tmplTable->errorStrs);
	} else {
		if ($nrs eq '0E0') {
			&warnl(_gettext("No Templates deleted. Nothing found!"))
		} else {
			&warnl(sprintf(_gettext("Successfully deleted Template '%s'"), $tmplName));
		}
	}
}

sub getTemplateData {
	warn 'SUB: ' . (caller(0))[3] . ' (' . (caller(1))[3] . ")\n" if $conf->{var}->{showsubs};
	my $netID				= shift;
	my $tmplID			= shift;
	my $onlyNV			= shift || 0; # Only Hash of Name => Value
	my $tmplEntries	= [];

	if (0 && $tmplID	== 0) {
		push @{$tmplEntries}, {
			elements	=> [
				{
					target	=> 'single',
					type		=> 'label',
					value		=> _gettext("None"),
					colspan	=> 2,
				},
			]
		};
	}

	my $tmplName				= &tmplID2Name($tmplID);
	push @{$tmplEntries}, (
		{
			elements	=> [
				{
					target	=> 'key',
					type		=> 'label',
					value		=> _gettext("Type"),
				},
				{
					target	=> 'value',
					type		=> 'label',
					value		=> $tmplName
				},
			],
		},
		{
			value	=> {
				type		=> 'hline',
				colspan	=> 2,
			},
		},
	);

	my $tmplEntryTable	= $conf->{var}->{TABLES}->{templateEntry};
	unless (defined $tmplEntryTable) {
		warn "Cannot show Template Data. (Entries) DB Error (templateEntry)\n";
		return [];
	}
	my $tmplValueTable	= $conf->{var}->{TABLES}->{templateValue};
	unless (defined $tmplValueTable) {
		warn "Cannot show Template Data. (Values) DB Error (templateValue)\n";
		return [];
	}

	my @tmplEntries	= $tmplEntryTable->search(['*'], {tmplID	=> $tmplID});
	my $box					= {};
	foreach (@tmplEntries) {
		my $tmplEntryID	= $_->{ID};
		my $pos					= $_->{position};
		my $valueT			= ($tmplValueTable->search(['value'], {netID	=> $netID, tmplID	=> $tmplID, tmplEntryID	=> $tmplEntryID}))[0];
		$box->{$pos}->{TMPLENTRY}	= $_;
		$box->{$pos}->{VALUE}			= (defined $valueT) ? $valueT->{value} : '';
	}

	my $nvHash	= {};
	foreach (sort {$a<=>$b} keys %{$box}) {
		my $tmplEntry	= $box->{$_}->{TMPLENTRY};
		my $value			= $box->{$_}->{VALUE};
		my $ID				= $tmplEntry->{ID};
		my $type			= $tmplEntry->{type};
		my $descr			= $tmplEntry->{description};
		my $size			= $tmplEntry->{size};
		my $entries		= $tmplEntry->{entries};
		my $rows			= $tmplEntry->{rows};
		my $cols			= $tmplEntry->{cols};

		$nvHash->{$descr}	= $value if $descr && $type != 0 && $type != 4;
		next if $onlyNV;

		if ($type == 0) {
			push @{$tmplEntries}, {
				value	=> {
					type		=> 'hline',
					colspan	=> 2,
				}
			};
		}
		elsif ($type == 4) {
			push @{$tmplEntries}, {
				elements	=> [
					{
						target	=> 'single',
						type		=> 'label',
						value		=> $descr,
						colspan	=> 2,
					},
				]
			}
		}
		else {
			$value	=~ s/\n/<br>/g;
			push @{$tmplEntries}, {
				elements	=> [
					{
						target	=> 'key',
						type		=> 'label',
						value		=> $descr
					},
					{
						target	=> 'value',
						type		=> 'label',
						value		=> $value
					},
				]
			};
		}
	}

	return (($onlyNV) ? $nvHash : $tmplEntries);
}

sub getGroups {
	warn 'SUB: ' . (caller(0))[3] . ' (' . (caller(1))[3] . ")\n" if $conf->{var}->{showsubs};
	my $groups			= [];
	my $groupTable	= $conf->{var}->{TABLES}->{group};
	unless (defined $groupTable) {
		warn "Cannot get Groups. DB Error (group)\n";
		return [];
	}

	my @groups	= $groupTable->search(['*']);
	foreach (@groups) {
		push @$groups, {
			ID		=> $_->{ID},
			name	=> $_->{name}
		};
	}
	return $groups;
}

sub getGroup {
	warn 'SUB: ' . (caller(0))[3] . ' (' . (caller(1))[3] . ")\n" if $conf->{var}->{showsubs};
	my $groupID			= shift;

	unless (defined $groupID) {
		warn "No Group ID given!";
		return {};
	}

	my $groupTable	= $conf->{var}->{TABLES}->{group};
	unless (defined $groupTable) {
		warn "Cannot get Groups. DB Error (group)\n";
		return [];
	}

	my $group	= ($groupTable->search(['*'], {ID	=> $groupID}))[0];
	return $group || {};
}

sub saveGroup {
	warn 'SUB: ' . (caller(0))[3] . ' (' . (caller(1))[3] . ")\n" if $conf->{var}->{showsubs};
	my $q						= $HaCi::HaCi::q;
	my $s						= $HaCi::HaCi::session;
	my $groupID			= &getParam(1, -1, $q->param('groupID'));
	my $groupTable	= $conf->{var}->{TABLES}->{group};
	unless (defined $groupTable) {
		&warnl("Cannot save Group. DB Error (group)");
	}

	if ($groupID < 0) {
		unless (defined $q->param('groupName')) {
			&warnl(_gettext('Sorry, you have to give me a Name!'));
			return undef;
		}
	}
	my $groupName	= &getParam(1, '', $q->param('groupName'));

	my $permStr	= '1';
	foreach (sort {$a<=>$b} keys %{$conf->{static}->{rights}}) {
		$permStr	.= ($groupName eq 'Administrator') ? 1 : (defined $q->param('groupPerm_' . $_) && $q->param('groupPerm_' . $_)) ? 1 : 0;
	}
	my $cryptStr	= &lwe(&bin2dec($permStr));

	$groupTable->clear();
	$groupTable->name($groupName);
	$groupTable->description(&getParam(1, '', $q->param('groupDescr')));
	$groupTable->permissions('1' . $cryptStr);

	my $DB	= ($groupTable->search(['ID'], {name => $groupName}))[0];
	if ($DB) {
		$groupTable->modifyFrom($s->param('username'));
		$groupTable->modifyDate(&currDate('datetime'));
		&debug("Change Group for '$groupName'\n");
		unless ($groupTable->update({ID => $DB->{'ID'}})) {
			&warnl("Cannot update Group '$groupName': " . $groupTable->errorStrs());
		}
	} else {
		$groupTable->ID(undef);
		$groupTable->createFrom($s->param('username'));
		$groupTable->createDate(&currDate('datetime'));
		unless ($groupTable->insert()) {
			&warnl("Cannot create Group '$groupName': " . $groupTable->errorStrs());
		}
	}
	my $newGroup	= ($groupTable->search(['ID'], {name	=> $groupName}))[0];
	if (defined $newGroup) {
		return $newGroup->{ID};
	} else {
		return undef;
	}
}

sub delGroup {
	warn 'SUB: ' . (caller(0))[3] . ' (' . (caller(1))[3] . ")\n" if $conf->{var}->{showsubs};
	my $groupID		= shift;
	my $groupName	= &groupID2Name($groupID);

	unless (defined $groupID) {
		&warnl("No Group ID given!");
		return 0;
	}


	my $groupTable	= $conf->{var}->{TABLES}->{group};
	unless (defined $groupTable) {
		&warnl("Cannot delete Group. DB Error (Group/Squat)");
		return 0;
	}

	my $userTable	= $conf->{var}->{TABLES}->{user};
	unless (defined $userTable) {
		&warnl("Cannot delete Group. DB Error (User)");
		return 0;
	}

	my @users	= $userTable->search(['username'], {groupIDs => ' ' . $groupID . ';'}, 1);
	my $users	= '';
	foreach (@users) {
		$users	.= ', ' . $_->{username};
	}
	if ($#users > -1) {
		&warnl(sprintf(_gettext("There are still Users in this Group left. Please remove them from this Group first! (%s)"), $users));
		return '';
	}

	$groupTable->clear();
	my $nrs	= $groupTable->delete({ID => $groupID});
	if ($groupTable->error) {
		&warnl("Error: " . $groupTable->errorStrs);
	} else {
		if ($nrs eq '0E0') {
			&warnl(_gettext("No Group deleted. Nothing found!"))
		} else {
			&warnl(sprintf(_gettext("Successfully deleted Group '%s'"), $groupName));
		}
	}
}

sub delUser {
	warn 'SUB: ' . (caller(0))[3] . ' (' . (caller(1))[3] . ")\n" if $conf->{var}->{showsubs};
	my $userID		= shift;
	my $userName	= &userID2Name($userID);

	unless (defined $userID) {
		&warnl("No User ID given!");
		return 0;
	}


	my $userTable	= $conf->{var}->{TABLES}->{user};
	unless (defined $userTable) {
		&warnl("Cannot delete User. DB Error (user)");
		return 0;
	}

	$userTable->clear();
	my $nrs	= $userTable->delete({ID => $userID});
	if ($userTable->error) {
		&warnl("Error: " . $userTable->errorStrs);
	} else {
		if ($nrs eq '0E0') {
			&warnl(_gettext("No User deleted. Nothing found!"))
		} else {
			&warnl(sprintf(_gettext("Successfully deleted User '%s'"), $userName));
		}
	}
}

sub getUsers {
	warn 'SUB: ' . (caller(0))[3] . ' (' . (caller(1))[3] . ")\n" if $conf->{var}->{showsubs};
	my $users			= [];
	my $userTable	= $conf->{var}->{TABLES}->{user};
	unless (defined $userTable) {
		warn "Cannot get Users. DB Error (user)\n";
		return [];
	}

	my @users	= $userTable->search(['*']);
	foreach (@users) {
		push @$users, {
			ID		=> $_->{ID},
			name	=> $_->{username}
		};
	}
	return $users;
}

sub getUser {
	warn 'SUB: ' . (caller(0))[3] . ' (' . (caller(1))[3] . ")\n" if $conf->{var}->{showsubs};
	my $userID	= shift;

	unless (defined $userID) {
		warn "No User ID given!";
		return {};
	}

	my $userTable	= $conf->{var}->{TABLES}->{user};
	unless (defined $userTable) {
		warn "Cannot get User. DB Error (user)\n";
		return {};
	}

	my $user	= ($userTable->search(['*'], {ID	=> $userID}))[0];
	return $user || {};
}

sub getUserFromName {
	warn 'SUB: ' . (caller(0))[3] . ' (' . (caller(1))[3] . ")\n" if $conf->{var}->{showsubs};
	my $userName	= shift;

	unless (defined $userName) {
		warn "No Username given!";
		return {};
	}

	my $userTable	= $conf->{var}->{TABLES}->{user};
	unless (defined $userTable) {
		warn "Cannot get User. DB Error (user)\n";
		return {};
	}

	my $user	= ($userTable->search(['*'], {username	=> $userName}))[0];
	return $user || {};
}

sub saveUser {
	warn 'SUB: ' . (caller(0))[3] . ' (' . (caller(1))[3] . ")\n" if $conf->{var}->{showsubs};
	my $q						= $HaCi::HaCi::q;
	my $s						= $HaCi::HaCi::session;
	my $userID			= &getParam(1, -1, $q->param('userID'));
	my $userTable		= $conf->{var}->{TABLES}->{user};
	unless (defined $userTable) {
		&warnl("Cannot save User. DB Error (user)");
	}

	if ($userID < 0) {
		unless (defined $q->param('userName')) {
			&warnl(_gettext('Sorry, you have to give me a Name!'));
			return undef;
		}
	}
	my $userName	= &getParam(1, '', $q->param('userName'));

	my $groupStr	= '';
	foreach ($q->param) {
		if (/^userGroup_(\d+)/) {
			my $userID	= $1;
			$groupStr	.= ' ' . $userID . ',';
		}
	}

	my $pw	= &getParam(1, undef, $q->param('password1'));
	my $pw1	= &getParam(1, undef, $q->param('password2'));

	$userTable->clear();
	if ($userID > 0 && (!defined $pw || $pw eq '')) {
		&debug("Okay, no Password Change!");
	} else {
		unless ($pw && $pw) {
			&warnl("No Password given");
			return undef;
		}

		if ($pw ne $pw1) {
			&warnl("Passwords are not equal");
			return undef;
		}

		my $crypt	= &getCryptPassword($pw);
		$userTable->password($crypt);
	}

	$userTable->username($userName);
	$userTable->description(&getParam(1, '', $q->param('userDescr')));
	$userTable->groupIDs($groupStr);

	my $DB	= ($userTable->search(['ID'], {username => $userName}))[0];
	if ($DB) {
		$userTable->modifyFrom($s->param('username'));
		$userTable->modifyDate(&currDate('datetime'));
		&debug("Change User '$userName'\n");
		unless ($userTable->update({ID => $DB->{'ID'}})) {
			&warnl("Cannot update User '$userName': " . $userTable->errorStrs());
		}
	} else {
		$userTable->ID(undef);
		$userTable->createFrom($s->param('username'));
		$userTable->createDate(&currDate('datetime'));
		unless ($userTable->insert()) {
			&warnl("Cannot create User '$userName': " . $userTable->errorStrs());
		}
	}
	my $newUser	= ($userTable->search(['ID'], {username	=> $userName}))[0];
	if (defined $newUser) {
		return $newUser->{ID};
	} else {
		return undef;
	}
}

sub dec2bin {
	warn 'SUB: ' . (caller(0))[3] . ' (' . (caller(1))[3] . ")\n" if $conf->{var}->{showsubs};
	my $dec			= shift;
	my $bin			= '';
	my $log2		= log(2);
	my $hash		= {};
	my $highest	= 0;

	while ($dec) {
		my $curr	= int(log($dec)/$log2);
		$dec		 -= 2 ** $curr;
		$highest	= $curr unless $highest;
		$hash->{$curr}	= 1;
	}
	for (0 .. $highest) {
		$bin	.= (exists $hash->{$_}) ? 1 : 0;
	}
	$bin	= reverse $bin;

	return $bin;
}

sub lwd {
	warn 'SUB: ' . (caller(0))[3] . ' (' . (caller(1))[3] . ")\n" if $conf->{var}->{showsubs};
	my $crypt	= shift;
	my $clear	= '';
	my @nrs	= split//, reverse $crypt;
	
	my $first	= '';
	for (0 .. $#nrs) {
		my $new	= (($nrs[$_] - (($_ == $#nrs) ? $first : $nrs[($_ + 1)])) + 10) % 10;
		$clear .= $new;
		$first	= $new if $first eq '';
	}
	$clear	= reverse $clear;

	return $clear;
}

sub checkRight {
	warn 'SUB: ' . (caller(0))[3] . ' (' . (caller(1))[3] . ")\n" if $conf->{var}->{showsubs};
	my $right			= shift;
	my $groupID		= shift || 0;
	my $hasRight	= 0;

	if ($groupID) {
		my $s				= $HaCi::HaCi::session;
		my $rights	= $s->param('rights_' . $groupID);
		unless (defined $rights) {
			$rights	= &getRights($groupID);
			$s->param('rights_' . $groupID, $rights);
		}
		$hasRight		= (exists $rights->{$right} && $rights->{$right}) ? 1 : 0;
	} else {
		my $s				= $HaCi::HaCi::session;
		my $rights	= $s->param('rights');
		$hasRight		= (exists $rights->{$right} && $rights->{$right}) ? 1 : 0;
	}
	return $hasRight;
}

sub getACLCacheEntry {
	warn 'SUB: ' . (caller(0))[3] . ' (' . (caller(1))[3] . ")\n" if $conf->{var}->{showsubs};
	my $type	= shift;

	my $acl	= $HaCi::HaCi::aclCache->{$type};

	return $acl;
}

sub checkNetACL {
	warn 'SUB: ' . (caller(0))[3] . ' (' . (caller(1))[3] . ")\n" if $conf->{var}->{showsubs};
	my $netID					= shift;
	my $right					= shift;
	my $groupID				= shift;
	my $checkGroupID	= 1 if defined $groupID;
	my $acls					= &getACLCacheEntry('net');
	my $s							= $HaCi::HaCi::session;
	my @groupIDs			= ($groupID) ? ($groupID) : split(/, /, $s->param('groupIDs'));
	my $return				= 0;
	my $fromDB				= 0;
	my $rootID				= 0;

	return 1 if !defined $groupID && $s->param('bAdmin');

	my $networkACTable	= $conf->{var}->{TABLES}->{networkAC};
	unless (defined $networkACTable) {
		warn "Cannot check ACL. DB Error (networkAC)\n";
		return 0;
	} 

	foreach (@groupIDs) {
		s/\D//g;
		my $groupID			= $_;
		my $currReturn	= 0;

		unless ($checkGroupID) {
			next unless &checkRight('showNets', $groupID);
		}

		if (!exists $acls->{$netID}->{$groupID}->{$right}) {
			$fromDB															= 1;
			$acls->{$netID}->{$groupID}->{r}		= 0;
			$acls->{$netID}->{$groupID}->{w}		= 0;
			$acls->{$netID}->{$groupID}->{ACL}	= 0;
			my $acl	= undef;
			$acl		= ($networkACTable->search(['ACL'], {netID => $netID, groupID => $groupID}))[0];
			unless (defined $acl) {
				($rootID, my $networkDec, my $ipv6)	= &netID2Stuff($netID);
				my $parent													= &getNetworkParentFromDB($rootID, $networkDec, $ipv6);
				if (defined $parent) {
					$acl->{ACL}	= &checkNetACL($parent->{ID}, 'ACL', $groupID);
				}
			}

			if (defined $acl) {
				if ($acl->{ACL} == 1 || $acl->{ACL} == 3) {
					$acls->{$netID}->{$groupID}->{r}	||= 1;
				}
				if ($acl->{ACL} == 2 || $acl->{ACL} == 3) {
					$acls->{$netID}->{$groupID}->{w}	||= 1;
				}
			} else {
				$acls->{$netID}->{$groupID}->{r}	||= &checkRootACL($rootID, 'r', $groupID);
				$acls->{$netID}->{$groupID}->{w}	||= &checkRootACL($rootID, 'w', $groupID);
			}

			my $newACL	= 0;
			$newACL			+= 1 if $acls->{$netID}->{$groupID}->{r};
			$newACL			+= 2 if $acls->{$netID}->{$groupID}->{w};
			$acls->{$netID}->{$groupID}->{ACL}	= $newACL if $acls->{$netID}->{$groupID}->{ACL} < $newACL;

			$currReturn = $acls->{$netID}->{$groupID}->{$right};

			&updateACLCache($acls, 'net');
		} else {
			$currReturn	= $acls->{$netID}->{$groupID}->{$right};
		}
		$return ||= $currReturn;
	}

	$return	||= 0;
	&debug("netAC ($netID	:@groupIDs	:$right [$fromDB]): $return\n") if 0;

	return $return;
}

sub checkRootACL {
	warn 'SUB: ' . (caller(0))[3] . ' (' . (caller(1))[3] . ")\n" if $conf->{var}->{showsubs};
	my $rootID		= shift;
	my $right			= shift;
	my $groupID		= shift;
	my $acls			= &getACLCacheEntry('root');
	my $s					= $HaCi::HaCi::session;
	my @groupIDs	= ($groupID) ? ($groupID) : split(/, /, $s->param('groupIDs'));
	my $ok				= 0;
	my $fromDB		= 0;

	return 1 if !defined $groupID && $s->param('bAdmin');

	my $rootACTable	= $conf->{var}->{TABLES}->{rootAC};
	unless (defined $rootACTable) {
		warn "Cannot check ACL. DB Error (rootAC)\n";
		return 0;
	} 

	foreach (@groupIDs) {
		s/\D//g;
		my $groupID	= $_;
		my $currOK	= 0;

		next unless &checkRight('showRoots', $groupID);

		if (!exists $acls->{$rootID}->{$groupID}->{$right}) {
			$fromDB															= 1;
			$acls->{$rootID}->{$groupID}->{r}	||= 0;
			$acls->{$rootID}->{$groupID}->{w}	||= 0;

			my $acl	= ($rootACTable->search(['ACL'], {rootID => $rootID, groupID => $groupID}))[0];

			if (defined $acl) {			
				if ($acl->{ACL} == 1 || $acl->{ACL} == 3) {
					$acls->{$rootID}->{$groupID}->{r}	||= 1;
				}
				if ($acl->{ACL} == 2 || $acl->{ACL} == 3) {
					$acls->{$rootID}->{$groupID}->{w}	||= 1;
				}
			}
			$currOK	= $acls->{$rootID}->{$groupID}->{$right};

			&updateACLCache($acls, 'root');
		} else {
			$currOK	= $acls->{$rootID}->{$groupID}->{$right};
		}
		$ok	||= $currOK;
	}

	$ok	||= 0;
	&debug("rootAC ($rootID	:@groupIDs	:$right [$fromDB]): $ok\n") if 0;

	return $ok;
}

sub updateACLCache {
	warn 'SUB: ' . (caller(0))[3] . ' (' . (caller(1))[3] . ")\n" if $conf->{var}->{showsubs};
	my $acls	= shift;
	my $type	= shift;

	$HaCi::HaCi::aclCache->{$type}	= $acls;
}

sub removeACLEntry {
	warn 'SUB: ' . (caller(0))[3] . ' (' . (caller(1))[3] . ")\n" if $conf->{var}->{showsubs};
	my $ID			= shift;
	my $type		= shift;
	my $groupID	= shift;
	my $acls		= &getACLCacheEntry($type);
	
	if ($groupID) {
		if (exists $acls->{$ID}->{$groupID}) {
			delete $acls->{$ID}->{$groupID};
		}
	} else {
		if (exists $acls->{$ID}) {
			delete $acls->{$ID};
		}
	}
	my @childs	= &getNetworkChilds($ID, (($type eq 'root') ? 1 : 0), 0);
	foreach (@childs) {
		my $ID	= $_->{ID};
		if ($groupID) {
			if (exists $acls->{$ID}->{$groupID}) {
				delete $acls->{$ID}->{$groupID};
			}
		} else {
			if (exists $acls->{$ID}) {
				delete $acls->{$ID};
			}
		}
	}
	&updateACLCache($acls, $type);
}

sub getNetworkParentFromDB {
	warn 'SUB: ' . (caller(0))[3] . ' (' . (caller(1))[3] . ")\n" if $conf->{var}->{showsubs};
	my $rootID			= shift;
	my $networkDec	= shift;
	my $ipv6				= shift;
	$ipv6						= &rootID2ipv6($rootID) unless defined $ipv6;
	my $parent			= undef;
		
	my $networkTable	= $conf->{var}->{TABLES}->{network};
	unless (defined $networkTable) {
		warn "Cannot get Parent Network. DB Error (network)\n";
		return undef;
	}

	if ($ipv6) {
		my $broadcast		= &getV6BroadcastNet($networkDec, 128);
		my ($net, $host, $cidr)	= (0, 0, 0);
		if ($networkDec && ref $networkDec) {
			($net, $host, $cidr)	= &netv6Dec2PartsDec($networkDec);
		} else {
			&debug("V6 NetworkDec ($networkDec) should be an Math::BigInt Reference!");
		}
		my $networkV6Table	= $conf->{var}->{TABLES}->{networkV6};
		unless (defined $networkV6Table) {
			warn "Cannot get NetworkV6 Parent. DB Error (networkV6)\n";
			return undef;
		}

		my @potParents	= $networkV6Table->search(
			['ID', 'networkPrefix', 'hostPart', 'cidr'],
			{rootID => $rootID}, 0,
			"AND (
				(networkPrefix < $net) OR 
				(networkPrefix = $net AND hostPart < $host) OR 
				(networkPrefix = $net AND hostPart = $host AND cidr < $cidr)
			) ORDER BY networkPrefix DESC, hostPart DESC, cidr DESC");

		return $parent unless @potParents;

		foreach (@potParents) {
			my $potParent					= $_;
			$potParent->{network}	= &ipv6Parts2NetDec($potParent->{networkPrefix}, $potParent->{hostPart}, $potParent->{cidr});
		}

		foreach (reverse &sortDBEntriesBy(\@potParents, 'network', 1, 1)) {
			my $potParent			= $_;
			$networkDec				= $potParent->{network};
			my $potBroadcast	= &getV6BroadcastNet($networkDec, 128);
			if ($potBroadcast >= $broadcast) {
				$parent							= $potParent;
				$parent->{ipv6}			= 1;
				my $network 				= ($networkTable->search(['ID', 'network', 'description', 'state', 'defSubnetSize'], {ipv6ID => $parent->{ID}, rootID => $rootID, network => 0}, 0))[0];
				if (defined $network) {
					$parent->{ID}							= $network->{ID};
					$parent->{description}		= $network->{description};
					$parent->{state}					= $network->{state};
					$parent->{defSubnetSize}	= $network->{defSubnetSize};
					last;
				} else {
					warn "NetV6 found ($parent->{ID}) with no matching network!\n";
					$parent	= undef;
				}
			}
		}
	} else {
		my $broadcast		= &getBroadcastFromNet($networkDec);
# warn "BROADCAST (" . &dec2net($networkDec) . "): " . &dec2ip($broadcast) . "\n";
		$parent					= ($networkTable->search(['ID', 'network', 'description', 'state', 'defSubnetSize'], "rootID='$rootID' AND ipv6ID='' AND network<'$networkDec' AND (FLOOR(network / 256) + power(2, (32 - MOD(network, 256))) > $broadcast) ORDER BY network DESC LIMIT 1"))[0];
	}

	return $parent;
}

sub getRights {
	warn 'SUB: ' . (caller(0))[3] . ' (' . (caller(1))[3] . ")\n" if $conf->{var}->{showsubs};
	my $groupID		= shift || 0;

	my $session		= $HaCi::HaCi::session;
	my $userTable	= $conf->{var}->{TABLES}->{user};
	unless (defined $userTable) {
		&warnl("Cannot get Rights. DB Error (user)");
		return {};
	}

	my $groupTable	= $conf->{var}->{TABLES}->{group};
	unless (defined $groupTable) {
		&warnl("Cannot get Rights. DB Error (group)");
		return {};
	}

	unless (defined $session->param('groupIDs')) {
		my $user	= ($userTable->search(['ID', 'groupIDs'], {username	=> $session->param('username')}))[0];
		unless (defined $user) {
			&warnl("Cannot get Rights. No such User '" . $session->param('username') . "' in Database");
			return {};
		}
		$session->param('groupIDs', $user->{groupIDs});
	}
	my $groupIDs	= $session->param('groupIDs');

	my $rights	= {};
	$session->clear('bAdmin') unless $groupID;
	my @groupIDs	= ($groupID) ? ($groupID) : split(/, /, $groupIDs);
	foreach (@groupIDs) {
		s/\D//g;
		my $group	= ($groupTable->search(['ID', 'permissions', 'name'], {ID	=> $_}))[0];
		next unless defined $group;

		$session->param('bAdmin', 1) if !$groupID && $group->{name} eq 'Administrator';
		
		my $cnter			= 0;
		my $cryptStr	= substr($group->{permissions}, 1, length($group->{permissions}) - 1);
		my $permStr		= &dec2bin(&lwd($cryptStr));
		foreach (split//, substr($permStr, 1, length($permStr) - 1)) {
			if (exists $conf->{static}->{rights}->{$cnter}) {
				my $right	= ($_ eq '1') ? 1 : 0;
				$rights->{$conf->{static}->{rights}->{$cnter}->{short}}	||= $right;
			}
			$cnter++;
		}
	}

	$session->param('rights', $rights) unless $groupID;

	return $rights	if $groupID;
}

sub getNetID {
	warn 'SUB: ' . (caller(0))[3] . ' (' . (caller(1))[3] . ")\n" if $conf->{var}->{showsubs};
	my $rootID			= shift;
	my $networkDec	= shift;
	my $ipv6ID			= shift;
	$ipv6ID					= '' unless defined $ipv6ID;
	$networkDec			= 0 if $ipv6ID;

	my $networkTable	= $conf->{var}->{TABLES}->{network};
	unless (defined $networkTable) {
		warn "Cannot get netID Network. DB Error (network)\n";
		return undef;
	}

	my $network	= ($networkTable->search(['ID'], {rootID => $rootID, network => $networkDec, ipv6ID => $ipv6ID}))[0];
	if (defined $network && exists $network->{ID}) {
		return $network->{ID};
	} else {
		return undef;
	}
}

sub getAllNets {
	my $rootID	= shift;
	my $ipv6		= shift;
	$ipv6				= &rootID2ipv6($rootID) unless defined $ipv6;
	my @nets		= ();

	my $networkTable	= $conf->{var}->{TABLES}->{network};
	unless (defined $networkTable) {
		warn "Cannot compare. DB Error (network)\n";
		return 0;
	}

	@nets	= $networkTable->search(['ID', 'network', 'ipv6ID'], {rootID => $rootID});
	
	if ($ipv6) {
		my $networkV6Table	= $conf->{var}->{TABLES}->{networkV6};
		unless (defined $networkV6Table) {
			warn "Cannot get NetworkV6 Parent. DB Error (networkV6) \n";
			return undef;
		}

		foreach (@nets) {
			my $v6Net	= &getV6Net($_->{ipv6ID});
			if (defined $v6Net) {
				$_->{network}	= &ipv6Parts2NetDec($v6Net->{networkPrefix}, $v6Net->{hostPart}, $v6Net->{cidr});
			}
		}
	}

	return @nets;
}

sub compare {
	warn 'SUB: ' . (caller(0))[3] . ' (' . (caller(1))[3] . ")\n" if $conf->{var}->{showsubs};
	my $q					= $HaCi::HaCi::q;
	my $leftID		= &getParam(1, undef, $q->param('leftRootID'));
	my $rightID		= &getParam(1, undef, $q->param('rightRootID'));
	my $rootName	= &getParam(1, undef, $q->param('resultName'));
	my $leftName	= &rootID2Name($leftID);
	my $rightName	= &rootID2Name($rightID);
	my $ipv6L			= &rootID2ipv6($leftID);
	my $ipv6R			= &rootID2ipv6($rightID);
	my $status		= $conf->{var}->{STATUS};
	$status->{TITLE}	= "Comparing '$leftName' <-> '$rightName'"; $status->{STATUS}	= 'Runnging...'; $status->{PERCENT}	= 0; &setStatus();

	if (($ipv6R && !$ipv6L) || (!$ipv6R && $ipv6L)) {
		&warnl("Cannot compare an IPv4 Root with an IPv6!");
		return 0;
	}

	unless ($rootName) {
		$rootName	= $leftName . ' - ' . $rightName;
	}

	$status->{DATA}	= "Adding Root '$rootName'"; $status->{PERCENT}	= 10; &setStatus();
	unless (&addRoot($rootName, "These Networks are missing in $rightName", $ipv6L)) {
		warn "AddRoot failed!\n";
		return 0;
	}
	my $rootID	= &rootName2ID($rootName);

	my $box				= {};
	my $statCnter	= 25;
	@{$box->{NETS}->{LEFT}}		= &getAllNets($leftID);
	@{$box->{NETS}->{RIGHT}}	= &getAllNets($rightID);

	foreach ('LEFT', 'RIGHT') {
		my $type	= $_;
		$status->{DATA}	= "Compare $type Side...!"; $status->{PERCENT}	= $statCnter; &setStatus();
		$statCnter	+= 25;
		foreach (@{$box->{NETS}->{$type}}) {
			return unless $_->{network};
			my $key	= $_->{network} . '_' . $_->{ipv6ID};
			$box->{RESULT}->{$key}->{$type}	= $_->{ID};
		}
	}

	$status->{DATA}	= "Processing Result...!"; $status->{PERCENT}	= $statCnter; &setStatus();
	foreach (keys %{$box->{RESULT}}) {
		my $key										= $_;
		my ($networkDec, $ipv6ID)	= split/_/, $key;
		my $netIDL								= $box->{RESULT}->{$key}->{LEFT};
		my $netIDR								= $box->{RESULT}->{$key}->{RIGHT};
		$networkDec								= Math::BigInt->new($networkDec) if $ipv6ID;
		my $network								= ($ipv6ID) ? &netv6Dec2net($networkDec) : &dec2net($networkDec);
		next unless (
			((defined $netIDL && &checkNetACL($netIDL, 'r')) || (!defined $netIDL && &checkRootACL($leftID, 'r'))) && 
			((defined $netIDR && &checkNetACL($netIDR, 'r')) || (!defined $netIDR && &checkRootACL($rightID, 'r')))
		);

		if (exists $box->{RESULT}->{$key}->{LEFT} && !exists $box->{RESULT}->{$key}->{RIGHT}) {
			&copyNetsTo($rootID, ["${network}_$leftID"], 0, 1);
		}
	}
	$status->{DATA}	= "FINISH"; $status->{PERCENT} = 100; $status->{STATUS} = 'FINISH'; &setStatus();
	return;
}

sub checkDB {
	warn 'SUB: ' . (caller(0))[3] . ' (' . (caller(1))[3] . ")\n" if $conf->{var}->{showsubs};
	my $networkTable	= $conf->{var}->{TABLES}->{network};
	unless (defined $networkTable) {
		warn "Cannot search. DB Error (network)\n";
		return 0;
	}
	
	my @results	= $networkTable->search();

	warn "CheckDB. Checking " . ($#results + 1) . " Results...\n";

	my $tmp	= {};
	foreach (@results) {
		my $networkDec	= $_->{network};
		my $netID				= $_->{ID};
		my ($ip, $cidr)	= split(/\//, &dec2net($networkDec));
		my $netaddress	= &dec2ip(&getNetaddress($ip, &getNetmaskFromCidr($cidr)));
		if ($ip ne $netaddress) {
			my $newNetwork	= &net2dec($netaddress . '/' . $cidr);
			$networkTable->clear();
			$networkTable->network($newNetwork);
			unless ($networkTable->update({ID => $netID})) {
				&warnl("Cannot update Net: " . $networkTable->errorStrs);
				if ($networkTable->errorStrs =~ /Duplicate entry/) {
					my $newNetwork2	= &net2dec($ip . '/' . 32);
					$networkTable->clear();
					$networkTable->network($newNetwork2);
					unless ($networkTable->update({ID => $netID})) {
						&warnl("Cannot update Net: " . $networkTable->errorStrs);
					}
				}
			}
		}
	}
	
}

sub newWindow {
	warn 'SUB: ' . (caller(0))[3] . ' (' . (caller(1))[3] . ")\n" if $conf->{var}->{showsubs};
	my $type	= shift;

	if ($type eq 'showStatus') {
		push @{$conf->{var}->{newWindows}}, {
			URL			=> "$conf->{var}->{thisscript}?func=showStatus",
			WIDTH		=> 200,
			HEIGHT	=> 150,
			TITLE		=> 'Status'
		}
	}
}

sub prNewWindows {
	warn 'SUB: ' . (caller(0))[3] . ' (' . (caller(1))[3] . ")\n" if $conf->{var}->{showsubs};
	my $retString	= shift || 0;
	my $ret				= '';

	foreach (@{$conf->{var}->{newWindows}}) {
		my $hash	= $_;
		$ret			.= "<script>window.open($hash->{URL}, \"$hash->{TITLE}\",\"width=$hash->{WIDTH},height=$hash->{HEIGHT},dependent=yes,location=no,menubar=no,scrollbars=no,status=no,toolbar=no\")</script>";
	}

	if ($retString) {
		return $ret;
	} else {
		print $ret;
	}
}

sub getID {
	warn 'SUB: ' . (caller(0))[3] . ' (' . (caller(1))[3] . ")\n" if $conf->{var}->{showsubs};

	my $ID	= Digest::MD5::md5_hex(time . $$);

	return $ID;
}

sub setStatus {
	warn 'SUB: ' . (caller(0))[3] . ' (' . (caller(1))[3] . ")\n" if $conf->{var}->{showsubs};
	my $status		= shift;

	$status				= $conf->{var}->{STATUS} unless ref $status eq 'HASH';
	my $statID		= $HaCi::HaCi::session->id();
	my $statFile	= $conf->{static}->{path}->{statusfile} . '_' . $statID . '.stat';

	return unless ref $status;

	eval {
		Storable::lock_store($status, $statFile) or warn "Cannot store Status ($statFile)!\n";
	};
	if ($@) {
		warn $@;
	};
}

sub removeStatus {
	warn 'SUB: ' . (caller(0))[3] . ' (' . (caller(1))[3] . ")\n" if $conf->{var}->{showsubs};
	my $statID		= $HaCi::HaCi::session->id();

	unlink $conf->{static}->{path}->{statusfile} . '_' . $statID . '.stat';
}

sub getStatus {
	warn 'SUB: ' . (caller(0))[3] . ' (' . (caller(1))[3] . ")\n" if $conf->{var}->{showsubs};

	my $statID		= $HaCi::HaCi::session->id();
	my $statFile	= $conf->{static}->{path}->{statusfile} . '_' . $statID . '.stat';
	return {} unless -f $statFile;
	
	my $status	= {};
	eval {
		$status	= Storable::lock_retrieve($statFile);
	};
	if ($@) {
		warn $@;
	};
	
	return $status;
}

sub expand {
	warn 'SUB: ' . (caller(0))[3] . ' (' . (caller(1))[3] . ")\n" if $conf->{var}->{showsubs};
	my $type		= shift;
	my $target	= shift;
	my $value		= shift;
	my $rootID	= shift;
	my $s				= $HaCi::HaCi::session;
	my $expands	= $s->param('expands');
	
	$s->clear('expands');

	if ($type eq '-' && $target eq 'ALL' && $value eq 'ALL') {
		$expands	= {};
	} else {
		if ($target eq 'root') {
			$expands->{$target}->{$value}	= ($type eq '+') ? 1 : 0;
		} else {
			my $ipv6		= &rootID2ipv6($rootID);
			$value			= Math::BigInt->new($value) if $ipv6 && !ref $value;
			my $parent	= &getNextDBNetwork($rootID, $ipv6, $value, 1);
			if (defined $parent) {
				$expands->{$target}->{$rootID}->{$value}	= ($type eq '+') ? 1 : 0;
			}
		}
	}
	
	$s->param('expands', $expands);
}

sub splitNet {
	warn 'SUB: ' . (caller(0))[3] . ' (' . (caller(1))[3] . ")\n" if $conf->{var}->{showsubs};
	my $netID			= shift;
	my $splitCidr	= shift;
	my $descrTmpl	= shift;
	my $state			= shift;
	my $tmplID		= shift;
	my $delParent	= shift;
	$conf->{var}->{STATUS}  = {TITLE => 'Splitting Network...', STATUS => 'Runnung...'}; &setStatus();

	my ($rootID, $networkDec, $ipv6)	= &netID2Stuff($netID);
	my $netaddressDec									= ($ipv6) ? (&netv6Dec2IpCidr($networkDec))[0] : &getIPFromDec($networkDec);
	my $broadcast											= ($ipv6) ? &getV6BroadcastIP($networkDec) : &getBroadcastFromNet($networkDec);
	my $adder													= Math::BigInt->new(2);
	my $mul														= (($ipv6) ? 128 : 32);
	$mul															-= $splitCidr;	
	$adder->bpow($mul);

	my $cnter	= 0;
	while ($netaddressDec <= $broadcast) {
		$cnter++;
		my $descr				= $descrTmpl;
		$descr					=~ s/\%d/$cnter/g;
		my $netaddress	= ($ipv6) ? &ipv6Dec2ip($netaddressDec) : &dec2ip($netaddressDec);
		$conf->{var}->{STATUS}->{DATA}	= $netaddress; &setStatus();
		&addNet(0, $rootID, $netaddress, $splitCidr, $descr, $state, $tmplID, 0, 1);
		if ($ipv6) {
			$netaddressDec->badd($adder);
		} else {
			$netaddressDec	+= 2 ** $mul;
		}
	}

	&delNet($netID) if $delParent;
	$conf->{var}->{STATUS}->{STATUS}	= 'FINISH'; &setStatus();
}

sub combineNets {
	warn 'SUB: ' . (caller(0))[3] . ' (' . (caller(1))[3] . ")\n" if $conf->{var}->{showsubs};
	my $q	= $HaCi::HaCi::q;
	
	foreach ($q->param('combineNetsNr')) {
		my $cnter	= $_;
		my $rootID							= $q->param('combineNets_' . $cnter . '_rootID');
		my $networkDec					= $q->param('combineNets_' . $cnter . '_result');
		my @sources							= $q->param('combineNets_' . $cnter . '_source');
		my $descr								= $q->param('combineNets_' . $cnter . '_descr');
		my $state								= $q->param('combineNets_' . $cnter . '_state');
		my $tmplID							= $q->param('combineNets_' . $cnter . '_tmplID');
		my $ipv6								= &rootID2ipv6($rootID);
		$networkDec							= Math::BigInt->new($networkDec) if $ipv6;
		my $network							= ($ipv6) ? &netv6Dec2net($networkDec) : &dec2net($networkDec);
		my ($ipaddress, $cidr)	= split(/\//, $network, 2);

		if (&addNet(0, $rootID, $ipaddress, $cidr, $descr, $state, $tmplID, 0, 1)) {
			foreach (@sources) {
				my $networkDec	= $_;
				$networkDec			= Math::BigInt->new($networkDec) if $ipv6;
				my $ipv6ID			= ($ipv6) ? &netv6Dec2ipv6ID($networkDec) : '';
				my $netID				= &getNetID($rootID, $networkDec, $ipv6ID);
				&delNet($netID);
			}
		}
	}
}

sub getPlugins {
	warn 'SUB: ' . (caller(0))[3] . ' (' . (caller(1))[3] . ")\n" if $conf->{var}->{showsubs};

	my $type	= shift;

	my $pluginInfos	= {};

	my $pluginDir	= $conf->{static}->{path}->{plugins};
	return {} unless -d $pluginDir;

	&warnl("Cannot open Directory '$pluginDir': $!") unless opendir DIR, $pluginDir;
	my @plugins	= grep { /\.pm$/ && -f "$pluginDir/$_" } readdir(DIR);
	closedir DIR;

	foreach (@plugins) {
		my $pluginFile							= $_;
		(my $pluginFilename					= $pluginFile) =~ s/\.pm//;
		my ($pluginID, $pluginInfo)	= &getPluginInfos($pluginFilename);
		next unless exists $pluginInfo->{ACTIVE} || defined $pluginID;
		if (defined $type) {
			next unless $pluginInfo->{uc($type)};
		}

		$pluginInfos->{$pluginID}	= $pluginInfo;
	}
	
	return $pluginInfos;
}

sub getPluginInfos {
	my $pluginFilename	= shift;
	my $pluginDir				= $conf->{static}->{path}->{plugins};
	my $pluginFullFile	= $pluginDir . '/' . $pluginFilename . '.pm';
	my $pluginInfos			= {};

	unless (open PLUG, $pluginFullFile) {
		my $error	= "Cannot open Plugin '$pluginFullFile' for reading: $!\n";
		warn $error;
		return (undef, {ERROR=>$error});
	}

	my $pluginTable	= $conf->{var}->{TABLES}->{plugin};
	unless (defined $pluginTable) {
		my $error	= "Cannot get Plugins. DB Error (plugin)\n";
		warn $error;
		return (undef, {ERROR=>$error});
	}

	my $networkPluginTable	= $conf->{var}->{TABLES}->{networkPlugin};
	unless (defined $networkPluginTable) {
		my $error	= "Cannot get Plugins. DB Error (networkPlugin)\n";
		warn $error;
		return (undef, {ERROR=>$error});
	}

	my $package	= '';
	foreach (<PLUG>) {
		if (/[^#]*package\s([^;]+)/) {
			$package	= $1;
			last;
		}
	}
	close PLUG;

	unless ($package) {
		my $error	= "$pluginFilename: Cannot determine Package! Next...\n";
		warn $error;
		return (undef, {ERROR=>$error});
	}

	(my $packageFile	= $package) =~ s/::/\//g;
	eval {
		require $packageFile . '.pm';
	};
	if ($@) {
		my $error	= "Cannot load module $package: $@\n";
		warn $error;
		return (undef, {ERROR=>$error});
	}
	unless ($package->can('new')) {
		my $error	= "Cannot load module $package: No constructor available!\n";
		warn $error;
		return (undef, {ERROR=>$error});
	}

	my $id	= 0;

	{
		no strict qw/refs/;
		my $file			= $pluginFilename;
		my $name			= ${"${package}::INFO"}->{name};
		my $version		= ${"${package}::INFO"}->{version};
		my $recurrent	= ${"${package}::INFO"}->{recurrent} || 0;
		my $onDemand	= ${"${package}::INFO"}->{onDemand} || 0;
		my $api				= ${"${package}::INFO"}->{api};
		my $descr			= ${"${package}::INFO"}->{description};
		my $dbPlug		= ($pluginTable->search(['*'], {name => $name}))[0];
		my $globMenuRecurrent	= ${"${package}::INFO"}->{globMenuRecurrent};
		my $globMenuOnDemand	= ${"${package}::INFO"}->{globMenuOnDemand};
		my $menuRecurrent			= ${"${package}::INFO"}->{menuRecurrent};
		my $menuOnDemand			= ${"${package}::INFO"}->{menuOnDemand};

		unless ($dbPlug) {
			$pluginTable->clear();
			$pluginTable->name($name);
			$pluginTable->filename($file);
			$pluginTable->active(0);
			unless ($pluginTable->insert()) {
				&warnl("Cannot create Plugin Entry for '$name': " . $pluginTable->errorStrs());
			}
			$dbPlug	= ($pluginTable->search(['*'], {name => $name}))[0];
		}
		$dbPlug	= {
			ID			=> 0,
			active	=> 0,
		} unless defined $dbPlug;

		unless ($dbPlug->{filename} eq $file) {
			warn "Updating Plugin Database...\n";
			$pluginTable->clear();
			$pluginTable->filename($file);
			unless ($pluginTable->update({ID => $dbPlug->{ID}})) {
				warn "Cannot create Plugin Entry for '$name': " . $pluginTable->errorStrs() . "\n";
			}
		}

		my $plugDefault	= ($networkPluginTable->search(['*'], {netID => -1, pluginID => $dbPlug->{ID}}))[0];
		$id							= $dbPlug->{ID};
		$pluginInfos		= {
			FILE			=> $file,
			NAME			=> $name,
			VERSION		=> $version,
			ACTIVE		=> $dbPlug->{active},
			RECURRENT	=> $recurrent,
			ONDEMAND	=> $onDemand,
			PACKAGE		=> $package,
			LASTRUN		=> $dbPlug->{lastRun},
			RUNTIME		=> $dbPlug->{runTime},
			LASTERROR	=> $dbPlug->{lastError} || '',
			API				=> $api,
			DESCR			=> $descr,
			DEFAULT		=> (defined $plugDefault && $plugDefault) ? 1 : 0,
			GLOBMENURECURRENT	=> $globMenuRecurrent || [],
			GLOBMENUONDEMAND	=> $globMenuOnDemand || [],
			MENURECURRENT			=> $menuRecurrent || [],
			MENUONDEMAND			=> $menuOnDemand || [],
		}
	}

	return ($id, $pluginInfos);
}

sub updatePluginDB {
	warn 'SUB: ' . (caller(0))[3] . ' (' . (caller(1))[3] . ")\n" if $conf->{var}->{showsubs};

	my $q	= $HaCi::HaCi::q;

	my $pluginTable	= $conf->{var}->{TABLES}->{plugin};
	unless (defined $pluginTable) {
		warn "Cannot update PluginDB. DB Error (plugin)\n";
		return 0;
	}

	my $networkPluginTable	= $conf->{var}->{TABLES}->{networkPlugin};
	unless (defined $networkPluginTable) {
		warn "Cannot update PluginDB. DB Error (networkPlugin)\n";
		return 0;
	}
	
	my $box			= {};

	foreach ($q->param('pluginActives')) {
		$box->{$_}->{ACTIVE}	= 1; 
	}
	foreach ($q->param('pluginDefaults')) {
		$box->{$_}->{DEFAULT}	= 1;
	}

	my @plugins	= $pluginTable->search();
	return unless @plugins;

	foreach (@plugins) {
		my $ID					= $_->{ID};
		my $name				= $_->{name};
		my $active			= $_->{active};
		my $plugDefault	= ($networkPluginTable->search(['*'], {netID => -1, pluginID => $ID}))[0];
		my $default			= (defined $plugDefault) ? 1 : 0;

		if ($active	&& !exists $box->{$ID}->{ACTIVE} || !$active && exists $box->{$ID}->{ACTIVE}) {
			my $newActive	= (exists $box->{$ID}->{ACTIVE}) ? 1 : 0;
			$pluginTable->clear();
			$pluginTable->active($newActive);
			unless ($pluginTable->update({ID => $ID})) {
				&warnl("Cannot update Plugin Entry for '$name': " . $pluginTable->errorStrs());
			}
		}

		if ($default && !exists $box->{$ID}->{DEFAULT} || !$default && exists $box->{$ID}->{DEFAULT}) {
			if (exists $box->{$ID}->{DEFAULT}) {
				$networkPluginTable->clear();
				$networkPluginTable->ID(undef);
				$networkPluginTable->netID(-1);
				$networkPluginTable->pluginID($ID);
				$networkPluginTable->errorStrs('');
				unless ($networkPluginTable->replace()) {
					&warnl("Cannot update Network Plugin Entry for '$name': " . $networkPluginTable->errorStrs());
				}
			} else {
				$networkPluginTable->clear();
				$networkPluginTable->delete({netID => -1, pluginID => $ID});
				if ($networkPluginTable->error) {
					&warnl("Error: " . $networkPluginTable->errorStrs);
				} 
			}
		}
	}
}

sub pluginID2File {
	warn 'SUB: ' . (caller(0))[3] . ' (' . (caller(1))[3] . ")\n" if $conf->{var}->{showsubs};
	
	my $pluginID	= shift;

	my $pluginTable	= $conf->{var}->{TABLES}->{plugin};
	unless (defined $pluginTable) {
		warn "Cannot get PluginName. DB Error (plugin)\n";
		return 0;
	}

	my $plugin	= ($pluginTable->search(['filename'], {ID => $pluginID}))[0];
	return (defined $plugin) ? $plugin->{filename} : '';
}

sub pluginID2Name {
	warn 'SUB: ' . (caller(0))[3] . ' (' . (caller(1))[3] . ")\n" if $conf->{var}->{showsubs};
	
	my $pluginID	= shift;

	my $pluginTable	= $conf->{var}->{TABLES}->{plugin};
	unless (defined $pluginTable) {
		warn "Cannot get PluginName. DB Error (plugin)\n";
		return 0;
	}

	my $plugin	= ($pluginTable->search(['name'], {ID => $pluginID}))[0];
	return (defined $plugin) ? $plugin->{name} : '';
}

sub pluginName2ID {
	warn 'SUB: ' . (caller(0))[3] . ' (' . (caller(1))[3] . ")\n" if $conf->{var}->{showsubs};
	
	my $name	= shift;

	my $pluginTable	= $conf->{var}->{TABLES}->{plugin};
	unless (defined $pluginTable) {
		warn "Cannot get PluginName. DB Error (plugin)\n";
		return 0;
	}

	my $plugin	= ($pluginTable->search(['ID'], {name => $name}))[0];
	return (defined $plugin) ? $plugin->{ID} : '';
}

sub getNetworksForPlugin {
	warn 'SUB: ' . (caller(0))[3] . ' (' . (caller(1))[3] . ")\n" if $conf->{var}->{showsubs};

	my $pluginID		= shift;
	my @return			= ();

	my $networkPluginTable	= $conf->{var}->{TABLES}->{networkPlugin};
	unless (defined $networkPluginTable) {
		warn "Cannot get Networks. DB Error (networkPlugin)\n";
		return 0;
	}

	my @networks	= $networkPluginTable->search(['netID'], {pluginID => $pluginID});
	return @return unless @networks;

	foreach (@networks) {
		push @return, $_->{netID};
	}

	return @return;
}

sub getPluginsForNet {
	warn 'SUB: ' . (caller(0))[3] . ' (' . (caller(1))[3] . ")\n" if $conf->{var}->{showsubs};

	my $netID		= shift;
	my $return	= ();

	my $networkPluginTable	= $conf->{var}->{TABLES}->{networkPlugin};
	unless (defined $networkPluginTable) {
		warn "Cannot get Plugins. DB Error (networkPlugin)\n";
		return $return;
	}

	my @plugins	= $networkPluginTable->search(['*'], "netID='$netID' OR netID='-1'", 0, 0, 1);
	return $return unless @plugins;

	foreach (@plugins) {
		$return->{$_->{pluginID}}	= $_ unless $_->{netID} == -1 && exists $return->{$_->{pluginID}};
	}

	return $return;
}

sub getTable {
	warn 'SUB: ' . (caller(0))[3] . ' (' . (caller(1))[3] . ")\n" if $conf->{var}->{showsubs};
	my $name	= shift;

	return if $conf->{var}->{DatabaseNotExist};

	eval {
		require "HaCi/Tables/$name.pm";
	};
	if ($@) {
		warn "Error while loading Table '$name': $@\n";
		return;
	}

	if (exists $conf->{var}->{TABLES}->{$name}) {
		my $dbh	= $conf->{var}->{TABLES}->{$name}->dbh();
		if (ref($dbh) && $dbh->can('ping') && $dbh->ping()) {
			return;
		} else {
			&closeTable($name);
		}
	}

	$DBIEasy::lastError	= '';
	$conf->{var}->{TABLES}->{$name}	= "HaCi::Tables::$name"->new($conf->{user}->{db});
	if ($DBIEasy::lastError =~ /Unknown database (.*)/) {
		&warnl("Database $1 is not available! Perhaps you have to create it?");
		$conf->{var}->{DatabaseNotExist}	= 1;
	} elsif ($DBIEasy::lastError =~ /Access denied for user (.*)/) {
		&warnl("User ($1) is not allowed to access! Is the User created and has it permission to access the Database?");
		$conf->{var}->{DatabaseNotExist}	= 1;
	} else {
		warn ($DBIEasy::lastError) if $DBIEasy::lastError;
	}
	$DBIEasy::lastError	= '';
}

sub closeTable {
	warn 'SUB: ' . (caller(0))[3] . ' (' . (caller(1))[3] . ")\n" if $conf->{var}->{showsubs};
	my $name	= shift;

	return if $conf->{var}->{DatabaseNotExist};

	$DBIEasy::lastError	= '';
	if (exists $conf->{var}->{TABLES}->{$name}) {
		my $dbh	= $conf->{var}->{TABLES}->{$name}->dbh();
		$dbh->disconnect() or warn "Cannot disconnect from DB!\n";
		undef $dbh;
		delete $conf->{var}->{TABLES}->{$name};
	}
	if ($DBIEasy::lastError =~ /Unknown database (.*)/) {
		&warnl("Database $1 is not available! Perhaps you have to create it?");
		$conf->{var}->{DatabaseNotExist}	= 1;
	} elsif ($DBIEasy::lastError =~ /Access denied for user (.*)/) {
		&warnl("User ($1) is not allowed to access! Is the User created and has it permission to access the Database?");
		$conf->{var}->{DatabaseNotExist}	= 1;
	} else {
		warn ($DBIEasy::lastError) if $DBIEasy::lastError;
	}
	$DBIEasy::lastError	= '';
}

sub getPluginLastRun {
	warn 'SUB: ' . (caller(0))[3] . ' (' . (caller(1))[3] . ")\n" if $conf->{var}->{showsubs};

	my $pluginID		= shift;

	my $pluginTable	= $conf->{var}->{TABLES}->{plugin};
	unless (defined $pluginTable) {
		warn "Cannot get PluginName. DB Error (plugin)\n";
		return 0;
	}

	my $plugin	= ($pluginTable->search(['lastRun'], {ID => $pluginID}))[0];
	my $lastRun	= $plugin->{lastRun};

	$lastRun	= 0 unless defined $lastRun;
	$lastRun	= &convDatetime2time($lastRun);

	return $lastRun;
}

sub updatePluginLastRun {
	warn 'SUB: ' . (caller(0))[3] . ' (' . (caller(1))[3] . ")\n" if $conf->{var}->{showsubs};
	my $pluginID	= shift;
	my $lastRun		= shift;
	my $runTime		= shift;
	my $error			= shift;

	$lastRun	= &currDate('datetime', ((defined $lastRun) ? $lastRun : undef)) if $lastRun ne '-1';
	$runTime	= 0 unless defined $runTime;
	$error		= '' unless defined $error;

	my $pluginTable	= $conf->{var}->{TABLES}->{plugin};
	unless (defined $pluginTable) {
		warn "Cannot get PluginName. DB Error (plugin)\n";
		return 0;
	}

	$pluginTable->clear();
	$pluginTable->lastRun($lastRun) if $lastRun ne '-1';
	$pluginTable->runTime($runTime) if $runTime > -1;
	$pluginTable->lastError($error) if defined $error;
	unless ($pluginTable->update({ID => $pluginID})) {
		return 0;
	}
}

sub getHashFromFile {
	my $filename	= shift;
	return '' unless -f $filename;

	my $sha	= Digest::SHA->new(1);
	$sha->addfile($filename);
	my $digest	= $sha->b64digest;
	undef($sha);

	return $digest;
}

sub getTableHashes {
	my $tableHashFile	= $conf->{static}->{path}->{tablehashfile};
	return {} unless -f $tableHashFile;
	

	my $tableHashes	= {};
	eval {
		$tableHashes	= Storable::lock_retrieve($tableHashFile);
	};
	if ($@) {
		warn $@;
	};

	return $tableHashes;
}

sub setTableHashes {
	my $tableHashes		= shift || {};
	my $tableHashFile	= $conf->{static}->{path}->{tablehashfile};

	eval {
		Storable::lock_store($tableHashes, $tableHashFile) or warn "Cannot store TableHashFile ($tableHashFile)!\n";
	};
	if ($@) {
		warn $@;
	};
}

sub diffTable {
	my $table				= shift;
	my $tableName		= $table->TABLE();
	&debug("Checking Table: $tableName");

	my $alterCnter	= 0;
	my $errorCnter	= 0;
	my $dbh					= $table->getDBConn();
	my $orig				= ${${$dbh->selectall_arrayref("SHOW CREATE TABLE `$tableName`")}[0]}[1] . ";\n";
	my $newTable		= "CREATE TABLE `$tableName` (" . $table->CREATETABLE() . ");\n";
	$newTable				=~ s/\t/ /g;
	my $t1					= SQL::Translator->new(parser=>'MySQL', show_warnings=>0);
	my $t2					= SQL::Translator->new(parser=>'MySQL', show_warnings=>0);

	my $diff;
	{
		BEGIN { $^W = 0 }
		$diff	= SQL::Translator::Diff::schema_diff(
			$t1->translate(\$orig), 'MySQL',
			$t2->translate(\$newTable), 'MySQL',
			{
				ignore_index_names			=> 1,
				ignore_constraint_names	=> 1,
				ignore_missing_methods	=> 1,
				no_batch_alters					=> 1
			}
		);
	}

	$diff	=~ s/.*BEGIN;/BEGIN;/ms;
	$diff	=~ s/COMMIT;.*/COMMIT;/ms;
	return 0 if $diff =~ /^\s*BEGIN;\s*ALTER TABLE\s*$tableName\s*;\s*COMMIT;\s*$/ms;

	&debug("Altering Table $tableName...");
	foreach (split/\n/, $diff) {
		s/\s*--.*//;
		next if /^\s*$/;
		next if /^\s*ALTER TABLE\s*$tableName\s*;\s*$/;
		$alterCnter++ if /^\s*ALTER\s/;
		&debug("  $_");
		$table->clear();
		$table->alter($_);
		if ($table->error()) {
			&warnl(sprintf(_gettext("Cannot update Table '%s': %s. Please correct this issue by hand (i.e.: remove duplicate entries)!"), $tableName, $table->errorStrs()));
			$errorCnter++;
		}
	}

	&warnl(sprintf(_gettext("Successfully updated Table '%s'."), $tableName)) if $alterCnter > 0 && $errorCnter == 0;

	return $alterCnter;
}

sub checkTables {
	warn 'SUB: ' . (caller(0))[3] . ' (' . (caller(1))[3] . ")\n" if $conf->{var}->{showsubs};

	my $checkForce	= shift || 0;
	my $tableHashes	= &getTableHashes();

	my $bChanged	= 0;
	my $errorTold	= 0;
	$errorTold		= 1 if $conf->{user}->{misc}->{ignoreupgradefailures};

	my $modError	= '';
	if ($conf->{user}->{misc}->{autoupgradedatabase}) {
		eval {
			require SQL::Translator;
			require	SQL::Translator::Diff;
		};
		if ($@) {
			$modError	= sprintf(_gettext("Cannot upgrade tables automatically. Required modules are not available (%s)."), $@);
		}
	} else {
		$modError	= _gettext("Automatic upgrade of database disabled. Please upgrade the database schema by hand.");
	}

	&debug("Checking Tables...\n");

	foreach (keys %{$conf->{var}->{TABLES}}) {
		my $tableFileName	= $_;
		&debug("Checking Table $tableFileName...\n") if 0;

		my $tableFile	= $conf->{static}->{path}->{workdir} . "/modules/HaCi/Tables/$tableFileName.pm";
		unless (-f $tableFile) {
			warn "Configured Table '$tableFileName' doesnt't exists? ($tableFile: $!)\n";
		}
		my $hash	= &getHashFromFile($tableFile);
		if (!$checkForce && exists $tableHashes->{$tableFileName} && $tableHashes->{$tableFileName} eq $hash) {
			&debug("Table $tableFileName is okay") if 0;
		} else {
			warn "Table $tableFileName NOT okay\n";
			if ($modError) {
				&warnl($modError) unless $errorTold;
				$errorTold	= 1;
				next;
			}
			next unless $conf->{user}->{misc}->{autoupgradedatabase};

			unless (defined $conf->{var}->{TABLES}->{$tableFileName}) {
				warn "Cannot check Table '$tableFileName'. Tablemodule is not loaded!\n";
				next;
			}
			my $table		= $conf->{var}->{TABLES}->{$tableFileName};
			my $changes	= &diffTable($table);
			unless ($changes) {
				$tableHashes->{$tableFileName}	= $hash;
				$bChanged	= 1;
			}
		}
	}

	if ($bChanged) {
		&debug("Updating TableHashes...");
		&setTableHashes($tableHashes);
	}
}

sub writeTmpFile {
	warn 'SUB: ' . (caller(0))[3] . ' (' . (caller(1))[3] . ")\n" if $conf->{var}->{showsubs};

	my $content					= shift;
	my ($fh, $filename) = tempfile();

	print $fh $content;
	close $fh;

	return $filename;
}

sub checkNetworkACTable {
	warn 'SUB: ' . (caller(0))[3] . ' (' . (caller(1))[3] . ")\n" if $conf->{var}->{showsubs};

	&debug ("Checking Network Access Table...\n");
	my $networkACTable	= $conf->{var}->{TABLES}->{networkAC};
	unless (defined $networkACTable) {
		warn "Cannot check ACL. DB Error (networkAC)\n";
		return 0;
	} 
	
	my $netAC	= ($networkACTable->search(['ID', 'ACL'], {ACL => 4}))[0];
	unless (defined $netAC) {
		&debug("Network Access Table out of date! Updating...\n");
		my @netACs	= $networkACTable->search(['*']);
		foreach (@netACs) {
			my $netID	= &getNetID($_->{rootID}, $_->{network});
			if ($netID) {
				$networkACTable->clear();
				$networkACTable->netID($netID);
				unless ($networkACTable->update({ID => $_->{ID}})) {
					warn "Cannot update networkACTable: " . $networkACTable->errorStrs();
				}
			} else {
				$networkACTable->clear();
				unless ($networkACTable->delete({ID => $_->{ID}})) {
					warn "Cannot update networkACTable: " . $networkACTable->errorStrs();
				}
			}
		}

		unless (defined $netAC) {
			$networkACTable->clear();
			$networkACTable->netID(0);
			$networkACTable->groupID(0);
			$networkACTable->ACL(4);
			$networkACTable->insert();
			if ($networkACTable->error()) {
				warn "Cannot update networkACTable: " . $networkACTable->errorStrs();
			}
		}
	}
}

sub netv6Dec2ipv6ID {
	warn 'SUB: ' . (caller(0))[3] . ' (' . (caller(1))[3] . ")\n" if $conf->{var}->{showsubs};

	my $netv6Dec						= shift;
	my $netv6								= &netv6Dec2net($netv6Dec);
	my ($netaddress, $cidr)	= split/\//, $netv6;
	my $ipv6ID							= Net::IPv6Addr::to_string_base85($netaddress) . sprintf("%x", $cidr);

	return $ipv6ID;
}

sub getPluginConfValues {
	warn 'SUB: ' . (caller(0))[3] . ' (' . (caller(1))[3] . ")\n" if $conf->{var}->{showsubs};

	my $pluginID		= shift;
	my $netID				= shift;
	my $pluginConf	= {};

	unless (defined $pluginID) {
		warn "updatePluginConf: No pluginID given...\n";
		return {};
	}
	unless (defined $netID) {
		warn "updatePluginConf: No netID given...\n";
		return {};
	}
	my $pluginConfTable	= $conf->{var}->{TABLES}->{pluginConf};
	unless (defined $pluginConfTable) {
		warn "Cannot update Plugin Config. DB Error (pluginConf)\n";
		return 0;
	}

	my @pluginConfEntries	= $pluginConfTable->search(['*'], {pluginID => $pluginID, netID => $netID});

	unless (@pluginConfEntries) {
		my $pluginName	= &pluginID2Name($pluginID);
		&debug("No Plugin Config for Plugin '$pluginName' found!\n");
		return {};
	}

	foreach (@pluginConfEntries) {
		my $pluginConfEntry	= $_;
		$pluginConf->{$pluginConfEntry->{name}}	= $pluginConfEntry->{value};
	}

	return $pluginConf;
}

sub getPluginConfMenu {
	warn 'SUB: ' . (caller(0))[3] . ' (' . (caller(1))[3] . ")\n" if $conf->{var}->{showsubs};

	my $pluginID					= shift;
	my $global						= shift;
	my $netID							= shift;
	my $plugin						= &pluginID2Name($pluginID);
	my $pluginFilename		= &pluginID2File($pluginID);
	my $pluginInfos				= (&getPluginInfos($pluginFilename))[1];
	my $pluginConfValues	= &getPluginConfValues($pluginID, $netID);
	my $menu							= [];
	my @confMenus					= ();

	if ($global) {
		if ($pluginInfos->{RECURRENT}) {
			push @confMenus, @{$conf->{static}->{plugindefaultglobrecurrentmenu}};
			if ($#{$pluginInfos->{GLOBMENURECURRENT}} > -1) {
				push @confMenus, ({type => 'hline'}), @{$pluginInfos->{GLOBMENURECURRENT}};
			}
		} 
		if ($pluginInfos->{ONDEMAND}) {
			push @confMenus, @{$conf->{static}->{plugindefaultglobondemandmenu}};
			if ($#{$pluginInfos->{GLOBMENUONDEMAND}} > -1) {
				push @confMenus, ({type => 'hline'}), @{$pluginInfos->{GLOBMENUONDEMAND}};
			}
		}
	} else {
		if ($pluginInfos->{RECURRENT}) {
			push @confMenus, @{$conf->{static}->{plugindefaultrecurrentmenu}};
			if ($#{$pluginInfos->{MENURECURRENT}} > -1) {
				push @confMenus, ({type => 'hline'}), @{$pluginInfos->{MENURECURRENT}};
			}
		}
		if ($pluginInfos->{ONDEMAND}) {
			push @confMenus, @{$conf->{static}->{plugindefaultondemandmenu}};
			if ($#{$pluginInfos->{MENUONDEMAND}} > -1) {
				push @confMenus, ({type => 'hline'}), @{$pluginInfos->{MENUONDEMAND}};
			}
		}
	}
	foreach (@confMenus) {
		my $entry	= $_;
		# for compatibility reasons
		map { $entry->{uc($_)}	= $entry->{$_}; } keys %{$entry};
		my $label	= {
			target	=> 'key',
			type		=> 'label',
			value		=> _gettext($entry->{DESCR} || ''),
			title		=> _gettext($entry->{HELP} || ''),
		};

		if ($entry->{TYPE} eq 'textbox') {
			push @$menu, (
				{
					elements	=> [
						$label,
						{
							target		=> 'value',
							type			=> 'textfield',
							name			=> 'pluginConfName_' . $entry->{NAME},
							size			=> $entry->{SIZE} || 20,
							maxlength	=> $entry->{MAXLENGTH} || 255,
							value			=> (exists $pluginConfValues->{$entry->{NAME}}) ? $pluginConfValues->{$entry->{NAME}} : ($entry->{VALUE} || ''),
							title			=> _gettext($entry->{HELP} || ''),
						},
					],
				}
			);
		}
		elsif ($entry->{TYPE} eq 'hline') {
			push @$menu, (
				{
					value	=> {
						type		=> 'hline',
						colspan	=> 2,
					},
				},
			);
		}
		elsif ($entry->{TYPE} eq 'label') {
			push @$menu, (
				{
					elements	=> [
						{
							target	=> 'single',
							type		=> 'label',
							value		=> _gettext($entry->{VALUE}),
							title		=> _gettext($entry->{HELP} || ''),
							align		=> 'center',
							bold		=> 1,
							colspan	=> 2,
						}
					],
				}
			);
		}
		elsif ($entry->{TYPE} eq 'checkbox') {
			push @$menu, (
				{
					elements	=> [
						$label, 
						{
							target	=> 'value',
							type		=> 'checkbox',
							name		=> 'pluginConfName_' . $entry->{NAME},
							descr		=> '',
							value		=> 1,
							checked	=> (exists $pluginConfValues->{$entry->{NAME}}) ? $pluginConfValues->{$entry->{NAME}} : ($entry->{CHECKED} || 0),
							title		=> _gettext($entry->{HELP} || ''),
						},
					],
				}
			);
		}
		elsif ($entry->{TYPE} eq 'popupmenu') {
			my $values	= [];
			unless (ref $entry->{VALUE} eq 'ARRAY') {
				warn "$plugin: The Value Content for 'popupmenu' in 'Menu' has to be an Array Reference ([])\n";
				$entry->{VALUE}	= [];
			}
			foreach (@{$entry->{VALUE}}) {
				push @$values, {
					ID		=> $_,
					name	=> $_,
				}
			}
			push @$menu, (
				{
					elements	=> [
						$label, 
						{
							target		=> 'value',
							type			=> 'popupMenu',
							name			=> 'pluginConfName_' . $entry->{NAME},
							size			=> 1,
							values		=> $values,
							selected	=> (exists $pluginConfValues->{$entry->{NAME}}) ? $pluginConfValues->{$entry->{NAME}} : ($entry->{DEFAULT} || ''),
						},
					],
				}
			);
		}
	}

	push @{$menu}, (
		{
			value	=> {
				type		=> 'hline',
				colspan	=> 2,
			}
		},
		{
			elements	=> [
				{
					target		=> 'single',
					type			=> 'buttons',
					align			=> 'center',
					colspan		=> 2,
					buttons		=> [
						{
							type	=> 'submit',
							name	=> 'submitPluginConfig',
							value	=> _gettext("Submit"),
							img		=> 'submit_small.png',
						},
						{
							type	=> 'submit',
							name	=> 'abortPluginConfig',
							value	=> _gettext("Abort"),
							img		=> 'cancel_small.png',
						},
					],
				},
			],
		}
	);
	
	return $menu;
}

sub mkPluginConfig {
	warn 'SUB: ' . (caller(0))[3] . ' (' . (caller(1))[3] . ")\n" if $conf->{var}->{showsubs};

	my $global						= shift || 0;
	my $q									= $HaCi::HaCi::q;
	my $pluginID					= &getParam(1, undef, $q->param('pluginID'));
	my $netID							= &getParam(1, undef, $q->param('netID'));
	my $pluginFilename		= &pluginID2File($pluginID);
	my $pluginInfos				= (&getPluginInfos($pluginFilename))[1];
	$netID								= -1 unless defined $netID;
	my @confMenus					= ();

	if ($global) {
		if ($pluginInfos->{RECURRENT}) {
			push @confMenus, @{$conf->{static}->{plugindefaultglobrecurrentmenu}}, @{$pluginInfos->{GLOBMENURECURRENT}};
		} 
		if ($pluginInfos->{ONDEMAND}) {
			push @confMenus, @{$conf->{static}->{plugindefaultglobondemandmenu}}, @{$pluginInfos->{GLOBMENUONDEMAND}};
		}
	} else {
		if ($pluginInfos->{RECURRENT}) {
			push @confMenus, @{$conf->{static}->{plugindefaultrecurrentmenu}}, @{$pluginInfos->{MENURECURRENT}};
		}
		if ($pluginInfos->{ONDEMAND}) {
			push @confMenus, @{$conf->{static}->{plugindefaultondemandmenu}}, @{$pluginInfos->{MENUONDEMAND}};
		}
	}
	
	foreach (@confMenus) {
		my $entry	= $_;

		# for compatibility reasons
		map { $entry->{uc($_)}	= $entry->{$_}; } keys %{$entry};

		next unless exists $entry->{TYPE};
		next if exists $entry->{NODB} && $entry->{NODB};
		next if $entry->{TYPE} eq 'label' || $entry->{TYPE} eq 'hline';

		my $value	= &getParam(1, undef, $q->param('pluginConfName_' . $entry->{NAME}));
		$value		= '' unless defined $value;
		&updatePluginConf($pluginID, $netID, $entry->{NAME}, $value);
	}
	my $resetLastRun	= &getParam(1, 0, $q->param('pluginConfName_def_recurrent_resetLastRun'));
	$resetLastRun			||= &getParam(1, 0, $q->param('pluginConfName_def_glob_recurrent_resetLastRun'));

	&updatePluginLastRun($pluginID, 0, 0, '') if $resetLastRun;
}

sub updatePluginConf {
	warn 'SUB: ' . (caller(0))[3] . ' (' . (caller(1))[3] . ")\n" if $conf->{var}->{showsubs};
	
	my $pluginID	= shift;
	my $netID			= shift;
	my $name			= shift;
	my $value			= shift;

	unless (defined $pluginID) {
		warn "updatePluginConf: No pluginID given...\n";
		return 0;
	}
	unless (defined $netID) {
		warn "updatePluginConf: No netID given...\n";
		return 0;
	}
	unless (defined $name) {
		warn "updatePluginConf: No name for plugin Config Entry given...\n";
		return 0;
	}

	my $pluginConfTable	= $conf->{var}->{TABLES}->{pluginConf};
	unless (defined $pluginConfTable) {
		warn "Cannot update Plugin Config. DB Error (pluginConf)\n";
		return 0;
	}

	my $pluginConfEntry	= ($pluginConfTable->search(['ID'], {pluginID => $pluginID, netID => $netID, name => $name}))[0];
	$pluginConfTable->clear();
	$pluginConfTable->pluginID($pluginID);
	$pluginConfTable->netID($netID);
	$pluginConfTable->name($name);
	$pluginConfTable->value($value);
	if (defined $pluginConfEntry) {
		unless ($pluginConfTable->update({ID => $pluginConfEntry->{ID}})) {
			&warnl("Cannot update Plugin Configuration: " . $pluginConfTable->errorStrs());
		}
	} else {
		$pluginConfTable->insert();
		if ($pluginConfTable->error()) {
			&warnl("Cannot insert Plugin Configuration: " . $pluginConfTable->errorStrs());
		}
	}
}

sub finalizeTables {
	warn 'SUB: ' . (caller(0))[3] . ' (' . (caller(1))[3] . ")\n" if $conf->{var}->{showsubs};
	&closeTable('user');
	&closeTable('group');
	&closeTable('root');
	&closeTable('rootAC');
	&closeTable('network');
	&closeTable('networkV6');
	&closeTable('networkAC');
	&closeTable('networkPlugin');
	&closeTable('template');
	&closeTable('templateEntry');
	&closeTable('templateValue');
	&closeTable('plugin');
	&closeTable('pluginConf');
	&closeTable('pluginValue');
	&closeTable('setting');
}

sub initTables {
	warn 'SUB: ' . (caller(0))[3] . ' (' . (caller(1))[3] . ")\n" if $conf->{var}->{showsubs};

	&getTable('user');
	&getTable('group');
	&getTable('root');
	&getTable('rootAC');
	&getTable('network');
	&getTable('networkV6');
	&getTable('networkAC');
	&getTable('networkPlugin');
	&getTable('template');
	&getTable('templateEntry');
	&getTable('templateValue');
	&getTable('plugin');
	&getTable('pluginConf');
	&getTable('pluginValue');
	&getTable('setting');
}

sub initCache {
	warn 'SUB: ' . (caller(0))[3] . ' (' . (caller(1))[3] . ")\n" if $conf->{var}->{showsubs};

	my $netCache	= undef;
	my $aclCache	= undef;

	if (&getConfigValue('misc', 'disableCache')) {
		&debug("Cache disabled!");
		return ($aclCache, $netCache);
	}

	eval {
		require Cache::FastMmap;
	};
	if ($@) {
		warn "Cannot load Cache::FastMmap: $@. Trying Cache::FileCache...\n";
		eval {
			require Cache::FileCache;
		};
		if ($@) {
			warn "Cannot load Cache::FileCache: $@. => No Cache!\n";
		} else {
			eval {
				$netCache	= new Cache::FileCache({
					namespace => 'HaCi_NET'
				});
				$aclCache	= new Cache::FileCache({
					namespace => 'HaCi_ACL'
				});
			};
			if ($@) {
				warn "Something went wrong while initialising the Cache: $@\n";
			}
		}
	} else  {
		eval {
			$netCache	= new Cache::FastMmap->new(
				share_file	=> $conf->{static}->{path}->{cachefile} . '_NET' || '/tmp/HaCi.cache_NET',
				page_size		=> '1024k',
				num_pages		=> 3,
			);
			unless (defined $netCache) {
				$netCache	= new Cache::FastMmap->new(
					share_file	=> $conf->{static}->{path}->{cachefile} . '_NET' || '/tmp/HaCi.cache_NET',
					init_file		=> 1,
					page_size		=> '1024k',
					num_pages		=> 3,
				);
			}

			$aclCache	= new Cache::FastMmap->new(
				share_file	=> $conf->{static}->{path}->{cachefile} . '_ACL' || '/tmp/HaCi.cache_ACL',
				page_size		=> '1024k',
				num_pages		=> 3,
			);
			unless (defined $aclCache) {
				$aclCache	= new Cache::FastMmap->new(
					share_file	=> $conf->{static}->{path}->{cachefile} . '_ACL' || '/tmp/HaCi.cache_ACL',
					init_file		=> 1,
					page_size		=> '1024k',
					num_pages		=> 3,
				);
			}
		};
		if ($@) {
			warn "Something went wrong while initialising the Cache: $@\n";
		}
	}

	return ($aclCache, $netCache);
}

sub fillHoles {
	warn 'SUB: ' . (caller(0))[3] . ' (' . (caller(1))[3] . ")\n" if $conf->{var}->{showsubs};

	my $fromNetDec		= shift;
	my $toNetDec			= shift;
	my $ipv6					= shift;
	my $defSubnetSize	= shift || 0;
	my $newNets				= &getNetCacheEntry('FILL', 0, "$fromNetDec:$toNetDec:$ipv6:$defSubnetSize");
	my @newNets				= ();

	unless (defined $newNets) {
		my $fromIPDec							= ($ipv6) ? (&netv6Dec2IpCidr($fromNetDec))[0] : &getIPFromDec($fromNetDec);
		my $endIPDec							= ($ipv6) ? (&netv6Dec2IpCidr($toNetDec))[0] : &getIPFromDec($toNetDec);
		my ($startIP, $startCidr) = ();
		if ($ipv6) {
			($startIP, $startCidr)	= &netv6Dec2IpCidr($fromNetDec);
		} else {
			($startIP, $startCidr)	= split(/\//, &dec2net($fromNetDec));
		}
		
		my $startIPDec	= ($ipv6) ? $fromIPDec->copy() : $fromIPDec;

		if ($ipv6) {
			while ($startIPDec->bcmp($endIPDec) < 0) {
				my $ipDiff	= $endIPDec->copy()->bsub($startIPDec);
				my $exp			= $ipDiff->blog(2);
				$exp				= 128 - $defSubnetSize if $defSubnetSize > (128 - $exp);
				my $offset  = Math::BigInt->new(2)->bpow($exp);
				last if $exp < 0;
				
				while ($exp > 0) {
					last if 
						($startIPDec->copy()->bmod($offset) == 0) && 
						(
							(($startIPDec->bcmp($fromIPDec) == 0) && ((128 - $exp) > $startCidr)) || 
							(!($startIPDec->bcmp($fromIPDec) == 0))
						);
					last if ($startIPDec->copy()->badd($offset)->bcmp($endIPDec) == 1);
					$offset = Math::BigInt->new(2)->bpow(--$exp);
				}
															
				my $cidr	= 128 - $exp;
		
				my $newNet  = &ipv6DecCidr2netv6Dec($startIPDec, $cidr);
				push @newNets, $newNet;
		
				$startIPDec->badd(Math::BigInt->new(2)->bpow($exp));
			}
		} else {
			while ($startIPDec < $endIPDec) {
				my $exp     = int(log($endIPDec - $startIPDec)/log(2));
				$exp				= 32 - $defSubnetSize if $defSubnetSize > (32 - $exp);
				my $offset  = 2 ** $exp;
				last if $exp < 0;
				
				while ($exp > 0) {
					last if 
						(($startIPDec % $offset) == 0) && 
						(
							(($startIPDec == $fromIPDec) && ((32 - $exp) > $startCidr)) || 
							(!($startIPDec == $fromIPDec))
						);
					last if (($startIPDec + $offset) > $endIPDec);
					$offset = 2 ** --$exp;
				}
															
				my $cidr	= 32 - $exp;
		
				my $newNet  = &net2dec(&dec2ip($startIPDec) . "/$cidr");
				push @newNets, $newNet;
		
				$startIPDec  += 2 ** $exp;
			}
		}

		 &updateNetcache('FILL', 0, "$fromNetDec:$toNetDec:$ipv6:$defSubnetSize", \@newNets);
	} else {
		@newNets	= @{$newNets};
	}

	return @newNets;
}

sub convDatetime2time {
	warn 'SUB: ' . (caller(0))[3] . ' (' . (caller(1))[3] . ")\n" if $conf->{var}->{showsubs};

	my $datetime	= shift;
	return 0 unless $datetime =~ /^(\d{4})-(\d{2})-(\d{2}) (\d{2}):(\d{2}):(\d{2})$/;

	my ($sec, $min, $hour, $mday, $mon, $year)	= ($6, $5, $4, $3, $2, $1);
	$mon--;
	my $time	= 0;
	eval {
		$time	= timelocal($sec,$min,$hour,$mday,$mon,$year);
	};
	if ($@) {
		warn "timelocal raised an error ($sec,$min,$hour,$mday,$mon,$year): $@\n";
		return 0;
	}
	$time	= 0 unless (defined $time && $time > 0);

	return $time;
}

sub getPluginValue {
	warn 'SUB: ' . (caller(0))[3] . ' (' . (caller(1))[3] . ")\n" if $conf->{var}->{showsubs};

	my $ID			= shift;
	my $netID		= shift;
	my $name		= shift;

	my $pluginValueTable	= $conf->{var}->{TABLES}->{pluginValue};
	unless (defined $pluginValueTable) {
		warn "Cannot get Plugin Value. DB Error (pluginValue)\n";
		return 0;
	}

	my $entry = ($pluginValueTable->search(['value'], {pluginID => $ID, netID => $netID, name => $name}))[0];
	if (defined $entry) {
		return $entry->{value};
	} else {
		return '';
	}
}

sub getHaCidInfo {
	warn 'SUB: ' . (caller(0))[3] . ' (' . (caller(1))[3] . ")\n" if $conf->{var}->{showsubs};

	my $data		= {};
	my $pidFile	= $conf->{static}->{path}->{hacidpid};

	return undef unless -f $pidFile;

	return undef unless open PID, $pidFile;
	my $PID	= (<PID>)[0];
	close PID;
	chomp($PID);

	return undef unless $PID;

	my $parent	= (qx(ps --pid $PID -o "pid,pcpu,rss,etime" --no-header))[0];
	my @childs	= qx(ps --ppid $PID -o "pid,pcpu,rss,etime" --no-header);

	return undef unless $parent;

	$parent			=~ s/^\s+//;
	
	($data->{PARENT}->{PID}, 
	$data->{PARENT}->{CPU}, 
	$data->{PARENT}->{RSS}, 
	$data->{PARENT}->{TIME})	= split/\s+/, $parent;

	foreach (@childs) {
		s/^\s+//;
		my ($pid, $cpu, $rss, $time)	= split/\s+/;
		push @{$data->{CHILDS}}, {
			PID		=> $pid,
			CPU		=> $cpu,
			RSS		=> $rss,
			TIME	=> $time
		};
	}

	return $data;
}

sub nd {
	my $net	= shift;

	if ($net =~ /:/) {
		return &netv62Dec($net);
	} else {
		return &net2dec($net);
	}
}

sub dn {
	my $dec	= shift;

	if (ref($dec)) {
		return &netv6Dec2net($dec);
	} else {
		return &dec2net($dec);
	}
}

sub getFreeSubnets {
	warn 'SUB: ' . (caller(0))[3] . ' (' . (caller(1))[3] . ")\n" if $conf->{var}->{showsubs};

	my $netID					= shift;
	my $scalar				= shift || 0;
	my $subnetSize		= shift;
	my $net						= &getMaintInfosFromNet($netID);
	my $ipv6					= ($net->{ipv6ID}) ? 1 : 0;
	my $networkDec		= $net->{network};
	my $broadcast			= ($ipv6) ? &getV6BroadcastNet($networkDec, 128) : &net2dec(&dec2ip(&getBroadcastFromNet($networkDec)) . '/32');
	my $nextNetDec		= ($ipv6) ? &netv6Dec2NextNetDec($broadcast, 128) : &net2dec(&dec2ip(&getIPFromDec($broadcast) + 1) . '/32');
	my $defSubnetSize	= $net->{defSubnetSize};
	my $freeSubnetst	= {};
	my $subnetCnter		= 0;
	$defSubnetSize		= $subnetSize if defined $subnetSize;

	my @childs		= &getNetworkChilds($netID);
	my $startNet	= $networkDec;
	foreach (&sortDBEntriesBy(\@childs, 'network', 1, $ipv6)) {
		my $child			= $_;
		my $childDec	= $child->{network};
		my $childNet	= ($ipv6) ? &netv6Dec2net($childDec) : &dec2net($childDec);

		foreach (&fillHoles($startNet, $childDec, $ipv6, $defSubnetSize)) {
			my $network	= ($ipv6) ? &netv6Dec2net($_) : &dec2net($_);
			my $cidr		= (split/\//, $network, 2)[1];
			$freeSubnetst->{$subnetCnter++}	= $network if !$defSubnetSize || ($cidr == $defSubnetSize);
		}

		$startNet	= ($ipv6) ? &netv6Dec2NextNetDec($childDec, 0) : &net2dec(&dec2ip(&getBroadcastFromNet($childDec) + 1) . '/0');
	}
		
	foreach (&fillHoles($startNet, $nextNetDec, $ipv6, $defSubnetSize)) {
		my $network	= ($ipv6) ? &netv6Dec2net($_) : &dec2net($_);
		my $cidr		= (split/\//, $network, 2)[1];
		$freeSubnetst->{$subnetCnter++}	= $network if !$defSubnetSize || ($cidr == $defSubnetSize);
	}

	my @freeSubnets	= ();
	my @sorted			= ();
	if ($ipv6) {
		@sorted	= sort {Math::BigInt->new($a)<=>Math::BigInt->new($b)} keys %{$freeSubnetst};
	} else {
		@sorted	= sort {$a<=>$b} keys %{$freeSubnetst};
	}
	map {
		push @freeSubnets, $freeSubnetst->{$_};
	} @sorted;
	return ($scalar) ? $subnetCnter : @freeSubnets;
}

sub chOwnPW {
	warn 'SUB: ' . (caller(0))[3] . ' (' . (caller(1))[3] . ")\n" if $conf->{var}->{showsubs};

	my $q					= $HaCi::HaCi::q;
	my $oldPW			= &getParam(1, undef, $q->param('oldPassword'));
	my $newPW			= &getParam(1, undef, $q->param('newPassword'));
	my $newPWVal	= &getParam(1, undef, $q->param('newPasswordVal'));
	my $session		= $HaCi::HaCi::session;
	my $userName	= $session->param('username') || '';

	unless ($userName) {
		&warnl(_gettext('Sorry, Username not found!'));
		return 0;
	}

	my $user	= &getUserFromName($userName);
	unless (exists $user->{ID}) {
		&warnl(_gettext('Sorry, Username not found!'));
		return 0;
	}

	my $origPW			= $user->{password};
	my $oldPWCrypt	= &getCryptPassword($oldPW);

	unless ($oldPWCrypt eq $origPW) {
		&warnl(_gettext("Old Password is not correct!"));
		return 0;
	}

	unless ($newPW && $newPW) {
		&warnl("No Password given");
		return 0;
	}

	if ($newPW ne $newPW) {
		&warnl("Passwords are not equal");
		return 0;
	}
	
	my $userTable		= $conf->{var}->{TABLES}->{user};
	unless (defined $userTable) {
		&warnl("Cannot save User. DB Error (user)");
	}
	$userTable->clear();

	my $crypt	= &getCryptPassword($newPW);
	$userTable->password($crypt);

	my $userID	= $user->{ID} || -1;
	if ($userID < 0) {
		&warnl(_gettext('Sorry, Username not found!'));
		return 0;
	}

	$userTable->modifyFrom($session->param('username'));
	$userTable->modifyDate(&currDate('datetime'));
	&debug("Change Password for User '$userName'\n");
	unless ($userTable->update({ID => $userID})) {
		&warnl(sprintf(_gettext("Cannot change Password: %s"), $userTable->errorStrs()));
		return 0;
	} else {
		&warnl(_gettext("Successfully changed Password"));
	}

	return 1;
}

sub getSettings {
	warn 'SUB: ' . (caller(0))[3] . ' (' . (caller(1))[3] . ")\n" if $conf->{var}->{showsubs};

	my $userID		= shift;
	my $settings	= {};

	unless (defined $userID) {
		warn "No UserID given!\n";
		return {};
	}

	my $settingTable	= $conf->{var}->{TABLES}->{setting};
	unless (defined $settingTable) {
		&warnl("Cannot get settings. DB Error (setting)");
	}

	my @settingsDB	= $settingTable->search(['ID', 'param', 'value'], {userID => $userID});

	foreach (@settingsDB) {
		my $setting	= $_;
		push @{$settings->{$setting->{param}}}, $setting->{value};
	}

	return $settings;
}

sub updSettings {
	warn 'SUB: ' . (caller(0))[3] . ' (' . (caller(1))[3] . ")\n" if $conf->{var}->{showsubs};

	my $q						= $HaCi::HaCi::q;
	my $s						= $HaCi::HaCi::session;
	my $newSettings	= {};
	my $userID			= &userName2ID($s->param('username'));
	my $settings		= &getSettings($userID);

	if ($userID < 0) {
		&warnl(_gettext('Sorry, Username not found!'));
		return 0;
	}

	my $settingTable	= $conf->{var}->{TABLES}->{setting};
	unless (defined $settingTable) {
		&warnl("Cannot set settings. DB Error (setting)");
	}

	foreach ($q->param) {
		if (/^setting_(.*)$/) {
			my $param	= $1;
			@{$newSettings->{$param}}	= ($q->param($_));
		}
	}

	foreach ($q->param('settingParams')) {
		my $param	= $_;
		$newSettings->{$param}	= [0] unless exists $newSettings->{$param};
	}

	my $errors	= '';
	foreach (keys %{$settings}) {
		my $param		= $_;
		
		unless (exists $newSettings->{$param}) {
			warn "Deleting Setting $param, because it wasn't selected!\n";
			$settingTable->errorStrs('');
			unless ($settingTable->delete({userID => $userID, param => $param})) {
				$errors	.= $settingTable->errorStrs();
				next;
			}
		}
	}

	foreach (keys %{$newSettings}) {
		my $param		= $_;
		my @values	= @{$newSettings->{$param}};

		$settingTable->errorStrs('');
		unless ($settingTable->delete({userID => $userID, param => $param})) {
			$errors	.= $settingTable->errorStrs();
			next;
		}
		
		foreach (@values) {
			my $value	= $_;
			$settingTable->clear();
			$settingTable->userID($userID);
			$settingTable->param($param);
			$settingTable->value($value);
			unless ($settingTable->insert()) {
				$errors	.= "Cannot update Settings for '" . $s->param('username') . "': " . $settingTable->errorStrs();
				next;
			}
		}
	}

	if ($errors) {
		&warnl(sprintf(_gettext("Errors while updating Setting for '%s': %s"), $s->param('username'), $errors));
	}

	&updateSettingsInSession();
}

sub updateSettingsInSession {
	warn 'SUB: ' . (caller(0))[3] . ' (' . (caller(1))[3] . ")\n" if $conf->{var}->{showsubs};

	my $s					= $HaCi::HaCi::session;
	my $userID		= &userName2ID($s->param('username'));
	my $settings	= &getSettings($userID);

	$s->param('settings', $settings);
}

sub quoteHTML {
	warn 'SUB: ' . (caller(0))[3] . ' (' . (caller(1))[3] . ")\n" if $conf->{var}->{showsubs};

	my $word	= shift;
	return $word unless $word;

	if ($word =~ /&#\d+/) {
		$word	= decode_entities($word);
		$word = encode('utf8', $word);
	} else {
		$word = encode('utf8', $word) unless ref(guess_encoding($word));
	}

	$word	=~ s/&/&amp;/g;
	$word	=~ s/</&lt;/g;
	$word	=~ s/>/&gt;/g;
	$word	=~ s/"/&quot;/g;
	$word	=~ s/'/&apos;/g;

	return $word;
}

sub checkIfRootExists {
	warn 'SUB: ' . (caller(0))[3] . ' (' . (caller(1))[3] . ")\n" if $conf->{var}->{showsubs};

	my $rootName	= shift;

	my $rootTable	= $conf->{var}->{TABLES}->{root};
	unless (defined $rootTable) {
		warn "Cannot add Route. DB Error (root)\n";
		return 0;
	}

	my $root	= ($rootTable->search(['ID'], {name => $rootName}))[0];
	if (defined $root) {
		return 1;
	} else {
		return 0;
	}
}

sub flushACLCache {
	warn 'SUB: ' . (caller(0))[3] . ' (' . (caller(1))[3] . ")\n" if $conf->{var}->{showsubs};

	$HaCi::HaCi::aclCache	= {};
}

sub flushNetCache {
	warn 'SUB: ' . (caller(0))[3] . ' (' . (caller(1))[3] . ")\n" if $conf->{var}->{showsubs};

	$HaCi::HaCi::netCache	= {};
}

sub getNetCacheEntry {
	warn 'SUB: ' . (caller(0))[3] . ' (' . (caller(1))[3] . ")\n" if $conf->{var}->{showsubs};

	my $type		= shift;
	my $rootID	= shift;
	my $key			= shift;

	my $value		= $HaCi::HaCi::netCache->{$type}->{$rootID}->{$key} || undef;
	$conf->{var}->{CACHESTATS}->{$type}->{TOTAL}++;

	return $value;
}

sub tmplEntryDescr2EntryID {
	warn 'SUB: ' . (caller(0))[3] . ' (' . (caller(1))[3] . ")\n" if $conf->{var}->{showsubs};
	my $tmplID					= shift;
	my $tmplEntryDescr	= shift;

	my $tmplEntryTable	= $conf->{var}->{TABLES}->{templateEntry};
	unless (defined $tmplEntryTable) {
		warn "Cannot get TemplateEntryID. DB Error (templateEntry)\n";
		return undef;
	}

	my $entry	= ($tmplEntryTable->search(['ID'], {tmplID	=> $tmplID, description => $tmplEntryDescr}))[0];
	return (defined $entry) ? ($entry->{ID} || undef) : undef;
}

sub searchAndGetFreeSubnets {
	warn 'SUB: ' . (caller(0))[3] . ' (' . (caller(1))[3] . ")\n" if $conf->{var}->{showsubs};

	my $q						= $HaCi::HaCi::q;
	my $t						= $HaCi::GUI::init::t;
	my $subnetSize	= &getParam(1, -1, $q->param('size'));

	&search();
	my $result	= $t->{V}->{searchResult};

	my @freeSubnetst	= ();
	if (defined $result && ref($result) eq 'ARRAY') {
		foreach (@{$result}) {
			my $network			= $_;
			if ($subnetSize == -1) {
				$subnetSize	= ($network->{network} =~ /:/) ? 128 : 32;
			}
			my @freeSubnets	= &getFreeSubnets($network->{netID}, 0, $subnetSize);
			next unless @freeSubnets;

			push @freeSubnetst, @freeSubnets;
		}
	}

	my $freeSubnets		= [];
	map {
		my $ipv6	= ($_ =~ /:/) ? 1 : 0;
		push @{$freeSubnets}, {
			net => $_,
			dec => ($ipv6) ? &netv62Dec($_) : &net2dec($_),
		};
	} @freeSubnetst;

	$t->{V}->{freeSubnets}	= $freeSubnets;
}

sub checkStateRules {
		my $netID				= shift;
		my $rootID			= shift;
		my $networkDec	= shift;
		my $state				= shift;
		my $cidr				= shift;
		my $ipv6				= shift;

		&debug("Checking Network State ($rootID:" . &dn($networkDec) . " => $state)\n") if 0;

		my $states	= $conf->{static}->{misc}->{networkstates};
		foreach (@$states) {
			if ($state eq $_->{id}) {
				my $se				= $_;
				my $stateName	= &networkStateID2Name($state);
				if (exists $se->{minsize} && $cidr > $se->{minsize}) {
					&warnl(sprintf(_gettext("The minimum %s size is /%i!"), $stateName, $se->{minsize}));
					return 0;
				}
				if (exists $se->{parents}) {
					my $nok				= 1;
					my $netParent	= &getNetworkParentFromDB($rootID, $networkDec);
					if (defined $netParent) {
						my @parents	= split(/\s*,\s*/, $se->{parents});
						foreach (@parents) {
							$nok	= 0 if $_ == $netParent->{state};
						}
						if ($nok) {
							&warnl(sprintf(_gettext("%ss can only be made from allocations with a status of %s"), $stateName, join(' ' . _gettext('or') . ' ', map {&networkStateID2Name($_)} @parents)));
							return 0;
						}
					}
				}
				if (exists $se->{banparents}) {
					my @basnishedStates	= split(/\s*,\s*/, $se->{banparents});
					if (my $badNet = &checkbanishFromParents($rootID, $networkDec, \@basnishedStates)) {
							&warnl(sprintf(_gettext("%ss can only be made when there's no less specific inetnum (%s) with a status of '%s'"), $stateName, &dn($badNet->{network}), join(' ' . _gettext('or') . ' ', map {&networkStateID2Name($_)} @basnishedStates)));
							return 0;
					}
				}
				if (exists $se->{banish}) {
					my @basnishedStates	= split(/\s*,\s*/, $se->{banish});
					if (my $badNet = &checkbanishFromParents($rootID, $networkDec, \@basnishedStates)) {
							&warnl(sprintf(_gettext("%ss can only be made when there's no less specific inetnum (%s) with an 'Assigned' status"), $stateName, &dn($badNet->{network})));
							return 0;
					}
					if ($netID) {
						if (my $badNet = &checkbanishFromChilds($netID, \@basnishedStates)) {
								&warnl(sprintf(_gettext("%ss can only be made when there's no more specific inetnum (%s) with an 'Assigned' status"), $stateName, &dn($badNet->{network})));
								return 0;
						}
					}
				}
				if (exists $se->{ipv6} && !$ipv6) {
					&warnl(sprintf(_gettext("%s is a new Value for inet6num Objects and so it's not available for inetnum Objects"), $stateName));
					return 0;
				}
				return 1;
			}
		}
		&warnl("State id '$state' doesn't exists in Config!", 1);
		return 0;
}

sub checkbanishFromParents {
	my $rootID					= shift;
	my $networkDec			= shift;
	my $basnishedStates	= shift;
	my $parent					= &getNetworkParentFromDB($rootID, $networkDec);

	return 0 unless defined $parent;
	foreach (@{$basnishedStates}) {
		return $parent if $parent->{state} == $_;
	}

	return &checkbanishFromParents($rootID, $parent->{network}, $basnishedStates);
}

sub checkbanishFromChilds {
	my $netID						= shift;
	my $basnishedStates	= shift;
	my @childs					= &getNetworkChilds($netID, 0, 0);

	return 0 if $#childs == -1;

	foreach (@childs) {
		my $child	= $_;
		foreach (@{$basnishedStates}) {
			return $child if $child->{state} == $_;
		}
		my $result	= &checkbanishFromChilds($child->{ID}, $basnishedStates);
		return $result if $result;
	}
	
	return 0;
}

sub getParam {
	my $onlyScalar	= shift;
	my $ifUndef			= shift;
	my @values			= @_;

	return $ifUndef unless defined $values[0];

	if ($onlyScalar) {
		&debug("called function 'getParam' with option 'onlyScalar' AND more than one value! (" . (caller(0))[0] . '->' . (caller(0))[2] . ')') if $#values > 0;
		return $values[0];
	}

	return @values;
}

1;

# vim:ts=2:sts=2:sw=2
