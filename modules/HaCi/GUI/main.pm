package HaCi::GUI::main;

use warnings;
use strict;

use HaCi::Utils qw/
	getRoots getNextDBNetwork getWHOISData getNSData checkSpelling_Net getNrOfChilds rootID2Name getMaintInfosFromRoot getPluginValue
	getMaintInfosFromNet networkStateID2Name getNetworkTypes getTemplate getTemplateEntries tmplID2Name getTemplateData getHaCidInfo
	getGroups getGroup groupID2Name getUsers getUser userID2Name dec2bin lwd checkRight netID2Stuff getNetworkParentFromDB nd dn
	parseCSVConfigfile getID getStatus removeStatus expand getDBNetworkBefore getNetID getPlugins getPluginsForNet pluginID2Name
	updatePluginLastRun rootID2ipv6 checkRootACL checkNetACL netv6Dec2ipv6ID getPluginInfos setStatus getPluginConfMenu pluginName2ID
	getFreeSubnets pluginID2File getSettings userName2ID quoteHTML getConfigValue _gettext
/;
use HaCi::Mathematics qw/
	dec2net net2dec getBroadcastFromNet dec2ip getIPFromDec getNetmaskFromCidr getNetaddress getV6BroadcastNet ipv62dec
	netv6Dec2net getV6BroadcastIP ipv6Dec2ip netv62Dec netv6Dec2IpCidr ipv6DecCidr2NetaddressV6Dec ipv6DecCidr2netv6Dec
/;
use HaCi::Log qw/warnl debug/;
use HaCi::GUI::gettext qw/_gettext/;

require Exporter;
our @ISA        = qw(Exporter);
our @EXPORT_OK  = qw(
	mkTree mkAddRoot mkAddNet mkImportASNRoutes checkNet expandNetwork reduceNetwork expandRoot reduceRoot showPlugin mkShowStatus
	mkSubmitImportASNRoutes
);

our $conf; *conf	= \$HaCi::Conf::conf;

sub start {
	warn 'SUB: ' . (caller(0))[3] . ' (' . (caller(1))[3] . ")\n" if $conf->{var}->{showsubs};
	my $t	= $HaCi::GUI::init::t;
	my $q	= $HaCi::HaCi::q;
	my $s	= $HaCi::HaCi::session;

	if (my $func = $q->param('func')) {
		if ($func	eq 'addRoot' && &checkRight('addRoot')) {
			$t->{V}->{mainPage}	= 'addRoot';
			&mkAddRoot();
		}
		elsif ($func	eq 'addNet' && &checkRight('addNet')) {
			$t->{V}->{mainPage}	= 'addNet';
			&mkAddNet();
		}
		elsif ($func	eq 'editNet' && &checkRight('editNet')) {
			$t->{V}->{mainPage}	= 'addNet';
			&mkAddNet();
		}
		elsif ($func	eq 'splitNet' && &checkRight('editNet')) {
			$t->{V}->{mainPage}	= 'splitNet';
			&mkSplitNet();
		}
		elsif ($func	eq 'combineNets' && &checkRight('editTree')) {
			$t->{V}->{mainPage}	= 'combineNets';
			&mkCombineNets();
		}
		elsif ($func	eq 'editRoot' && &checkRight('editRoot')) {
			$t->{V}->{mainPage}	= 'addRoot';
			&mkEditRoot();
		}
		elsif ($func	eq 'delNet' && &checkRight('editNet')) {
			$t->{V}->{mainPage}	= 'delNet';
			&mkDelNet();
		}
		elsif ($func	eq 'delRoot' && &checkRight('editRoot')) {
			$t->{V}->{mainPage}	= 'delRoot';
			&mkDelRoot();
		}
		elsif ($func eq 'showAllNets') {
			$t->{V}->{mainPage} = 'showAllNets';
			&mkTree();
			&mkTreeMenu();
		}
		elsif ($func eq 'importASNRoutes' && &checkRight('impASNRoutes')) {
			$t->{V}->{mainPage} = 'importASNRoutes';
			&mkImportASNRoutes();
		}
		elsif ($func eq 'importDNS' && &checkRight('impDNS')) {
			$t->{V}->{mainPage} = 'importDNS';
			&mkImportDNS();
		}
		elsif ($func eq 'importConfig' && &checkRight('impConfig')) {
			$t->{V}->{mainPage} = 'importConfig';
			if (defined $q->param('source') && $q->param('source') eq 'csv') {
				&mkImportCSV();
			} else {
				&mkImportConfig();
			}
		}
		elsif ($func eq 'showNet' && &checkRight('showNetDet')) {
			$t->{V}->{mainPage}				= 'showNet';
			my ($rootID, $networkDec)	= &netID2Stuff($q->param('netID'));
			$s->param('currNet', $networkDec);
			$s->param('currRootID', $rootID);
			&mkShowNet();
		}
		elsif ($func eq 'showRoot' && &checkRight('showRootDet')) {
			$t->{V}->{mainPage} = 'showRoot';
			&mkShowRoot();
		}
		elsif ($func eq 'search' && &checkRight('search')) {
			$t->{V}->{mainPage} = 'search';
			&mkSearch();
		}
		elsif ($func eq 'compare' && &checkRight('search')) {
			$t->{V}->{mainPage} = 'compare';
			&mkCompare();
		}
		elsif ($func eq 'showTemplates' && &checkRight('tmplMgmt')) {
			$t->{V}->{mainPage} = 'showTemplates';
			&mkShowTemplates();
		}
		elsif ($func eq 'editTmpl' && &checkRight('tmplMgmt')) {
			$t->{V}->{mainPage} = 'editTemplate';
			&mkEditTemplate();
		}
		elsif ($func	eq 'delTmpl' && &checkRight('tmplMgmt')) {
			$t->{V}->{mainPage}	= 'delTmpl';
			&mkDelTmpl();
		}
		elsif ($func	eq 'showGroups' && &checkRight('groupMgmt')) {
			$t->{V}->{mainPage}	= 'showGroups';
			&mkShowGroups();
		}
		elsif ($func eq 'editGroup' && &checkRight('groupMgmt')) {
			$t->{V}->{mainPage} = 'editGroup';
			&mkEditGroup();
		}
		elsif ($func	eq 'delGroup' && &checkRight('groupMgmt')) {
			$t->{V}->{mainPage}	= 'delGroup';
			&mkDelGroup();
		}
		elsif ($func	eq 'delUser' && &checkRight('userMgmt')) {
			$t->{V}->{mainPage}	= 'delUser';
			&mkDelUser();
		}
		elsif ($func	eq 'showUsers' && &checkRight('userMgmt')) {
			$t->{V}->{mainPage}	= 'showUsers';
			&mkShowUsers();
		}
		elsif ($func eq 'editUser' && &checkRight('userMgmt')) {
			$t->{V}->{mainPage} = 'editUser';
			&mkEditUser();
		}
		elsif ($func	eq 'delUser' && &checkRight('userMgmt')) {
			$t->{V}->{mainPage}	= 'delUser';
			&mkDelUser();
		}
		elsif ($func	eq 'showPlugins' && &checkRight('pluginMgmt')) {
			$t->{V}->{mainPage}	= 'showPlugins';
			&mkShowPlugins();
		}
		elsif ($func eq 'showStatus') {
			$t->{V}->{mainPage} = 'showStatus';
			&mkShowStatus();
		}
		elsif ($func eq 'showAbout') {
			$t->{V}->{mainPage} = 'showAbout';
		}
		elsif ($func eq 'showPluginGlobConf') {
			$t->{V}->{mainPage} = 'showPluginConf';
			&mkShowPluginConf(1);
		}
		elsif ($func eq 'showPluginConf') {
			$t->{V}->{mainPage} = 'showPluginConf';
			&mkShowPluginConf();
		}
		elsif ($func eq 'showSubnets' && &checkRight('showNetDet')) {
			$t->{V}->{mainPage} = 'showSubnets';
			&mkShowSubnets();
		}
		elsif ($func eq 'showSettings') {
			$t->{V}->{mainPage} = 'showSettings';
			&mkShowSettings();
		}
	} else {
		$t->{V}->{mainPage} = 'showAllNets';
		&mkTree();
		&mkTreeMenu();
	}

	&mkMenu();
}

sub mkTreeMenu {
	warn 'SUB: ' . (caller(0))[3] . ' (' . (caller(1))[3] . ")\n" if $conf->{var}->{showsubs};
	my $t									= $HaCi::GUI::init::t;
	my $q									= $HaCi::HaCi::q;
	my $bEditTree					= $q->param('editTree');
	my $roots							= &getRoots();
	map {my $h=$_;$h->{name} = &quoteHTML($h->{name}); $_ = $h;} @{$roots};

	$t->{V}->{rootID2Ver}	= $roots;

	$t->{V}->{treeMenuHiddens}	= [
		{
			name	=> 'editTree',
			value	=> $bEditTree
		},
	];

	$t->{V}->{treeMenuHeader}		= _gettext("Menu");
	$t->{V}->{treeMenuFormName}	= 'treeMenu';
	$t->{V}->{treeMenu}					= [
		{
			elements	=> [
				{
					target		=> 'single',
					type			=> 'popupMenu',
					name			=> 'rootIDJump',
					size			=> 1,
					values		=> $roots,
					selected	=> (($q->param('rootID')) ? [$q->param('rootID')] : []),
					onChange	=> 'javascript:checkIfIPv6(this.value, "TREE")',
				},
				{
					target		=> 'single',
					type			=> 'textfield',
					name			=> 'jumpTo',
					size			=> 25,
					maxlength	=> 39,
					value			=> ((defined $q->param('jumpTo') && $q->param('jumpTo') ne '') ? $q->param('jumpTo') : '<' . _gettext('IP address') . '>'),
					style			=> ((defined $q->param('jumpTo')) ? '' : 'color:#AAAAAA'),
					onClick		=> ((defined $q->param('jumpTo')) ? '' : "clearTextfield('jumpTo')"),
					onKeyDown	=> "submitOnEnter(event, 'jumpToButton')",
				},
				{
					target	=> 'single',
					type		=> 'buttons',
					buttons	=> [
						{
							type	=> 'submit',
							name	=> 'jumpToButton',
							value	=> _gettext('Jump To'),
							img		=> 'jumpTo_small.png',
						},
					],
				},
				{
					target	=> 'single',
					type		=> 'vline'
				},
				{
					target	=> 'single',
					type		=> 'buttons',
					buttons	=> [
						{
							name	=> 'closeTree',
							type	=> 'submit',
							value	=> _gettext("Close Tree"),
							img		=> 'close_small.png',
						},
					],
				},
				{
					target	=> 'single',
					type		=> 'vline'
				},
				{
					target	=> 'single',
					type		=> 'buttons',
					buttons	=> [
						{
							name			=> (($bEditTree) ? 'finishEditTree' : 'editTree'),
							type			=> 'submit',
							value			=> _gettext((($bEditTree) ? "Finish Edit" : "Edit")),
							disabled	=> (&checkRight('editTree')) ? 0 : 1,
							img				=> (($bEditTree) ? 'editClose_small.png' : 'edit_small.png'),
						},
					],
				},
			]
		}
	];
	if ($bEditTree) {
		$t->{V}->{editTreeMenuHeader}		= _gettext("Edit Menu");
		$t->{V}->{editTreeMenu}					= [
			{
				elements	=> [
					{
						target	=> 'single',
						type		=> 'buttons',
						buttons	=> [
							{
								type	=> 'submit',
								name	=> 'deleteNets',
								value	=> _gettext('Delete'),
								img		=> 'del_small.png',
							},
						],
					},
					{
						target	=> 'single',
						type		=> 'vline'
					},
					{
						target	=> 'single',
						type		=> 'buttons',
						buttons	=> [
							{
								type			=> 'submit',
								name			=> 'combineNets',
								value			=> _gettext('Combine'),
								img				=> 'combine_small.png',
							},
						],
					},
					{
						target	=> 'single',
						type		=> 'vline'
					},
					{
						target	=> 'single',
						type		=> 'buttons',
						buttons	=> [
							{
								type	=> 'submit',
								name	=> 'copyNetsTo',
								value	=> _gettext('Copy'),
								img		=> 'copy_small.png',
							},
						],
					},
					{
						target	=> 'single',
						type		=> 'dline'
					},
					{
						target	=> 'single',
						type		=> 'buttons',
						buttons	=> [
							{
								type	=> 'submit',
								name	=> 'moveNetsTo',
								value	=> _gettext('Move'),
								img		=> 'move_small.png',
							},
						],
					},
					{
						target	=> 'single',
						type		=> 'label',
						value		=> _gettext("to"),
					},
					{
						target		=> 'single',
						type			=> 'popupMenu',
						name			=> 'copyToRootID',
						size			=> 1,
						values		=> $roots,
						selected	=> (($q->param('rootID')) ? [$q->param('rootID')] : []),
					},
				]
			}
		];
	}
}

sub mkTree {
	warn 'SUB: ' . (caller(0))[3] . ' (' . (caller(1))[3] . ")\n" if $conf->{var}->{showsubs};
	use HaCi::Tree;
	my $t							= $HaCi::GUI::init::t;
	my $s							= $HaCi::HaCi::session;
	my $q							= $HaCi::HaCi::q;
	my $thisScript		= $conf->{var}->{thisscript};
	my $rootTable			= $conf->{var}->{TABLES}->{root};
	my $networkTable	= $conf->{var}->{TABLES}->{network};
	my $expands				= $s->param('expands') || {};
	my $expandAll			= (defined $q->param('expandAll') && $q->param('expandAll')) ? 1 : 0;
	unless (defined $rootTable || defined $networkTable) {
		warn "Cannot generate Tree. DB Error\n";
		return 0;
	}

	my @roots	= $rootTable->search();
	
	my $tree	= new HaCi::Tree;
	foreach (@roots) {
		my $rootID	= $_->{ID};
		my $ipv6		= &rootID2ipv6($rootID);
		next unless &mkTreeAddRoot(\$tree, $_, $ipv6);
		next unless $expands->{root}->{$rootID};

		&mkTreeNetwork(\$tree, $rootID, $ipv6, (($ipv6) ? Math::BigInt->new(0) : 0), 0, 0);
	}
	$t->{V}->{tree}			= $tree->print_html();
	$t->{V}->{editTree}	= (defined $q->param('editTree')) ? $q->param('editTree') : 0;
}

sub mkTreeNetwork {
	warn 'SUB: ' . (caller(0))[3] . ' (' . (caller(1))[3] . ")\n" if $conf->{var}->{showsubs};
	my $treet						= shift;
	my $rootID					= shift;
	my $ipv6						= shift;
	my $networkDec			= shift;
	my $bAddParent			= shift || 0;
	my $bParentOnly			= shift || 0;
	my $broadcast				= ($ipv6) ? &getV6BroadcastNet($networkDec, 128) : &net2dec(&dec2ip(&getBroadcastFromNet($networkDec)) . '/32');
	my $tree						= $$treet;
	my $s								= $HaCi::HaCi::session;
	my $q								= $HaCi::HaCi::q;
	my $expands					= $s->param('expands') || {};
	my $expandAll				= (defined $q->param('expandAll') && $q->param('expandAll')) ? 1 : 0;
	my $networkDecOrig	= ($ipv6) ? $networkDec->copy() : $networkDec;

	if ($bAddParent) {
		unless ($networkDec) {
			my $root	= &getMaintInfosFromRoot($rootID);
			&mkTreeAddRoot(\$tree, $root, $ipv6);
		} else {
			my $netID			= ($ipv6) ? &getNetID($rootID, 0, &netv6Dec2ipv6ID($networkDec)) : &getNetID($rootID, $networkDec, '');
			my $networkT	= &getMaintInfosFromNet($netID);
			&mkTreeAddNetwork(\$tree, $rootID, $ipv6, $networkT);
		}
		return if $bParentOnly;
	}

	my $networkT;
	while ($networkT	= &getNextDBNetwork($rootID, $ipv6, $networkDec)) {
		$conf->{var}->{STATUS}->{DATA}	= (($ipv6) ? &netv6Dec2net($networkT->{network}) : &dec2net($networkT->{network})); &setStatus();

		last if $networkT->{network} == $networkDec || $networkT->{network} > $broadcast || !defined $networkT;
		my $bACL		= &mkTreeAddNetwork(\$tree, $rootID, $ipv6, $networkT, $networkDecOrig);
		$networkDec	= $networkT->{network};
		
		if (($expandAll || $expands->{network}->{$rootID}->{$networkDec}) && $bACL) {
			&mkTreeNetwork(\$tree, $rootID, $ipv6, (($ipv6) ? Math::BigInt->new($networkDec) : $networkDec), 0, 0);
		}
		$networkDec	= ($ipv6) ? &getV6BroadcastNet($networkDec, 128) : &net2dec(&dec2ip(&getBroadcastFromNet($networkDec)) . '/32');
		last unless $networkDec;
	}
	if ($networkDecOrig && $networkDecOrig ne $broadcast) {
		$tree->checkNetworkHoles($rootID, $ipv6, $networkDecOrig, $broadcast);
	}
}

sub mkTreeAddRoot {
	warn 'SUB: ' . (caller(0))[3] . ' (' . (caller(1))[3] . ")\n" if $conf->{var}->{showsubs};
	my $treet			= shift;
	my $root			= shift;
	my $ipv6			= shift;
	my $tree			= $$treet;
	my $expands		= $HaCi::HaCi::session->param('expands') || {};
	my $expandAll	= (defined $HaCi::HaCi::q->param('expandAll') && $HaCi::HaCi::q->param('expandAll')) ? 1 : 0;

	my $rootID		= $root->{ID};
	my $rootName	= $root->{name};
	my $rootDescr	= $root->{description};
	my $bACL			= &checkRootACL($rootID, 'r');
	
	if ($bACL) {
		$tree->setNewRoot($rootID);
		$tree->setRootName($rootID, $rootName);
		$tree->setRootDescr($rootID, $rootDescr);
		$tree->setRootExpanded($rootID, (($expandAll || $expands->{root}->{$rootID}) ? 1 : 0));
		$tree->setRootParent($rootID, ((defined &getNextDBNetwork($rootID, $ipv6, 0)) ? 1 : 0));
		$tree->setRootV6($rootID, $ipv6);
	}

	return $bACL;
}

sub subDescription {
	warn 'SUB: ' . (caller(0))[3] . ' (' . (caller(1))[3] . ")\n" if $conf->{var}->{showsubs};
	my $description	= shift;
	my $netID				= shift;

	while ($description =~ /\%\%(.*?)\%\%/) {
		my ($plugin, $name)	= split/\%/, $1;
		if ($plugin && $name) {
			my $pluginID	= &pluginName2ID($plugin);
			if ($pluginID ne '') {
				my $value	= &getPluginValue($pluginID, $netID, $name);
				$description	=~ s/\%\%.*?\%\%/$value/;
			} else {
				last;
			}
		} else {
			last;
		}
	}

	return $description;
}

sub mkTreeAddNetwork {
	warn 'SUB: ' . (caller(0))[3] . ' (' . (caller(1))[3] . ")\n" if $conf->{var}->{showsubs};
	my $treet						= shift;
	my $rootID					= shift;
	my $ipv6						= shift;
	my $networkT				= shift;
	my $networkDecOrig	= shift;
	my $tree						= $$treet;
	my $expands					= $HaCi::HaCi::session->param('expands') || {};
	my $expandAll				= (defined $HaCi::HaCi::q->param('expandAll') && $HaCi::HaCi::q->param('expandAll')) ? 1 : 0;

	my $netID					= $networkT->{ID};
	my $networkDec		= $networkT->{network};
	$networkDec				= Math::BigInt->new($networkDec) if $ipv6;
	my $network				= ($ipv6) ? &netv6Dec2net($networkDec) : &dec2net($networkDec);
	my $description		= $networkT->{description};
	my $status				= $networkT->{state};
	my $defSubnetSize	= $networkT->{defSubnetSize};
	my $bACL					= 0;
	$description			= &subDescription($description, $netID) if $description =~ /\%{2}/;

	if (&checkSpelling_Net($network, $ipv6)) {
		$bACL	= &checkNetACL($netID, 'r');
		$tree->addNet($netID, $rootID, $ipv6, $networkDec, $description, ($status || 0), $networkDecOrig, 0, $defSubnetSize);
		$tree->setNetExpanded($rootID, $ipv6, $networkDec, ((($expandAll || $expands->{network}->{$rootID}->{$networkDec}) && $bACL) ? 1 : 0));
		$tree->setNetParent($rootID, $ipv6, $networkDec, ((defined &getNextDBNetwork($rootID, $ipv6, $networkDec, 1)) ? 1 : 0));
		$tree->setInvisible($rootID, $ipv6, $networkDec, ($bACL == 0) ? 1 : 0);
	}
	return $bACL;
}

sub mkMenu {
	warn 'SUB: ' . (caller(0))[3] . ' (' . (caller(1))[3] . ")\n" if $conf->{var}->{showsubs};
	my $t						= $HaCi::GUI::init::t;
	my $s						= $HaCi::HaCi::session;
	my $thisScript	= $conf->{var}->{thisscript};
	my $menu	= [
		{
			title	=> sprintf(_gettext("Logged in as <font id='menuBoxUsername'>%s</font>"), $s->param('username')),
			entries	=> [
				{
					title	=> _gettext("Logout"),
					link	=> "$thisScript?func=logout",
					img		=> '/Images/logout.png',
				},
			],
		},
		{
			title	=> _gettext("Tree"),
			entries	=> [
				{
					title	=> _gettext("Overview"),
					link	=> "$thisScript?func=showAllNets",
					img		=> '/Images/showAll.png',
				},
				{
					title			=> _gettext("Add Root"),
					link			=> "$thisScript?func=addRoot",
					img				=> '/Images/addRoot.png',
					disabled	=> (&checkRight('addRoot')) ? 0 : 1,
				},
				{
					title			=> _gettext("Add Network"),
					link			=> "$thisScript?func=addNet",
					img				=> '/Images/addNet.png',
					disabled	=> (&checkRight('addNet')) ? 0 : 1,
				},
			],
		},
		{
			title	=> _gettext("Import"),
			entries	=> [
				{
					title			=> _gettext("ASN Routes"),
					link			=> "$thisScript?func=importASNRoutes",
					img				=> '/Images/impASNRoutes.png',
					disabled	=> (&checkRight('impASNRoutes')) ? 0 : 1,
				},
				{
					title			=> _gettext("DNS Zonefile"),
					link			=> "$thisScript?func=importDNS",
					img				=> '/Images/impDNSZoneFile.png',
					disabled	=> (&checkRight('impDNS')) ? 0 : 1,
				},
				{
					title			=> _gettext("Config"),
					link			=> "$thisScript?func=importConfig",
					img				=> '/Images/impConfig.png',
					disabled	=> (&checkRight('impConfig')) ? 0 : 1,
				},
			]
		},
		{
			title	=> _gettext("Miscellaneous"),
			entries	=> [
				{
					title			=> _gettext("Search"),
					link			=> "$thisScript?func=search",
					img				=> '/Images/search.png',
					disabled	=> (&checkRight('search')) ? 0 : 1,
				},
				{
					title			=> _gettext("Compare"),
					link			=> "$thisScript?func=compare",
					img				=> '/Images/compare.png',
					disabled	=> (&checkRight('search')) ? 0 : 1,
				},
				{
					title			=> _gettext("Flush Cache"),
					link			=> "$thisScript?func=flushCache",
					img				=> '/Images/flushACL.png',
				},
			],
		},
		{
			title	=> _gettext("Maintenance"),
			entries	=> [
				{
					title			=> _gettext("User Management"),
					link			=> "$thisScript?func=showUsers",
					img				=> '/Images/userMgmt.png',
					disabled	=> (&checkRight('userMgmt')) ? 0 : 1,
				},
				{
					title			=> _gettext("Group Management"),
					link			=> "$thisScript?func=showGroups",
					img				=> '/Images/groupMgmt.png',
					disabled	=> (&checkRight('groupMgmt')) ? 0 : 1,
				},
				{
					title			=> _gettext("Template Management"),
					link			=> "$thisScript?func=showTemplates",
					img				=> '/Images/tmplMgmt.png',
					disabled	=> (&checkRight('tmplMgmt')) ? 0 : 1,
				},
				{
					title			=> _gettext("Plugin Management"),
					link			=> "$thisScript?func=showPlugins",
					img				=> '/Images/pluginMgmt.png',
					disabled	=> (&checkRight('pluginMgmt')) ? 0 : 1,
				},
				{
					title			=> _gettext("Settings"),
					link			=> "$thisScript?func=showSettings",
					img				=> '/Images/configure.png',
					disabled	=> 0,
				},
				{
					title			=> _gettext("About HaCi"),
					link			=> "$thisScript?func=showAbout",
					img				=> '/Images/HaCi_Logo2_small.png',
					disabled	=> 0,
				},
			],
		},
	];

	$t->{V}->{menu}	= $menu;
}

sub mkEditRoot {
	warn 'SUB: ' . (caller(0))[3] . ' (' . (caller(1))[3] . ")\n" if $conf->{var}->{showsubs};
	my $t					= $HaCi::GUI::init::t;
	my $q					= $HaCi::HaCi::q;
	my $rootID		= $q->param('rootID');
	my $root			= &getMaintInfosFromRoot($rootID);

	my $rootACTable	= $conf->{var}->{TABLES}->{rootAC};
	unless (defined $rootACTable) {
		warn "Cannot Edit Root. DB Error (rootAC)\n";
		return 0;
	}

	my @acls	= $rootACTable->search(['groupID', 'ACL'], {rootID => $rootID});
	foreach (@acls) {
		if ($_->{ACL} == 1 || $_->{ACL} == 3) {
			$q->delete('accGroup_r_' . $_->{groupID}); $q->param('accGroup_r_' . $_->{groupID}, 1);
		}
		if ($_->{ACL} == 2 || $_->{ACL} == 3) {
			$q->delete('accGroup_w_' . $_->{groupID}); $q->param('accGroup_w_' . $_->{groupID}, 1);
		}
	}
	
	$q->delete('name'); $q->param('name', $root->{name});
	$q->delete('descr'); $q->param('descr', $root->{description});
	$q->delete('ipv6'); $q->param('ipv6', $root->{ipv6});
	$t->{V}->{addRootHiddens}	= [
		{
			name	=> 'rootID',
			value	=> $rootID
		},
		{
			name	=> 'ipv6',
			value	=> $root->{ipv6}
		},
		{
			name	=> 'editRoot',
			value	=> 1,
		},
	];

	&mkAddRoot();
}


sub mkAddRoot {
	warn 'SUB: ' . (caller(0))[3] . ' (' . (caller(1))[3] . ")\n" if $conf->{var}->{showsubs};
	my $t							= $HaCi::GUI::init::t;
	my $q							= $HaCi::HaCi::q;
	my $s							= $HaCi::HaCi::session;
	my $name					= ((defined $q->param('name')) ? &quoteHTML($q->param('name')) : '');
	my $descr					= ((defined $q->param('descr')) ? &quoteHTML($q->param('descr')) : '');
	my $ipv6					= ((defined $q->param('ipv6')) ? $q->param('ipv6') : 0);
	my $bEditRoot			= (defined $q->param('editRoot')) ? 1 : 0;
	my $nrOfNetworks	= ((defined $q->param('rootID')) ? &getNrOfChilds(0, $q->param('rootID')) : 0);

	if ($bEditRoot) {
		$t->{V}->{addRootHeader}	= sprintf(_gettext("Edit Root <b>%s</b>"), $name);
	} else {
		$t->{V}->{addRootHeader}	= _gettext("Add Root");
	}
	$t->{V}->{addRootFormName}	= 'addRoot';
	$t->{V}->{addRootMenu}			= [
		{
			elements	=> [
				{
					target	=> 'key',
					type		=> 'label',
					value		=> _gettext("Name of Root"),
				},
				{
					target		=> 'value',
					type			=> 'textfield',
					name			=> 'name',
					size			=> 20,
					maxlength	=> 255,
					value			=> $name,
					focus			=> 1,
					onKeyDown	=> "submitOnEnter(event, 'submitAddRoot')",
				}
			]
		},
		{
			elements	=> [
				{
					target	=> 'key',
					type		=> 'label',
					value		=> _gettext("Description"),
				},
				{
					target		=> 'value',
					type			=> 'textfield',
					name			=> 'descr',
					size			=> 20,
					maxlength	=> 255,
					value			=> $descr,
					onKeyDown	=> "submitOnEnter(event, 'submitAddRoot')",
				}
			]
		},
		{
			elements	=> [
				{
					target	=> 'key',
					type		=> 'label',
					value		=> _gettext("IPv6"),
				},
				{
					target		=> 'value',
					type			=> 'checkbox',
					name			=> 'ipv6',
					value			=> 1,
					descr			=> '',
					checked		=> $ipv6,
					disabled	=> ($bEditRoot && $nrOfNetworks) ? 1 : 0,
				},
			],
		},
	];

	my $groups		= {};
	foreach (@{&getGroups()}) {
		$groups->{$_->{ID}}	= $_->{name} unless $_->{name} eq 'Administrator' || $s->param('groupIDs') =~ / $_->{ID},/;
	}

	$t->{V}->{rootGroupRightsHeader}	= _gettext("Access Rights");
	$t->{V}->{rootGroupRightsMenu}		= [
		{
			elements	=> [
				{
					target	=> 'single',
					type		=> 'label',
					value		=> '<b>' . _gettext('read') . '</b>',
					width		=> '3em',
					align		=> 'center',
				},
				{
					target	=> 'single',
					type		=> 'label',
					value		=> '<b>' . _gettext('write') . '</b>',
					width		=> '5em',
					align		=> 'center',
				},
				{
					target	=> 'single',
					type		=> 'label',
					value		=> '<b>' . _gettext('Group') . '</b>',
					width		=> '8em',
				}
			]
		},
		{
			value	=> {
				type	=> 'hline',
				colspan	=> 3,
			}
		},
	];
	
	foreach (sort {$a<=>$b} keys %{$groups}) {
		push @{$t->{V}->{rootGroupRightsMenu}}, (
			{
				elements	=> [
					{
						target		=> 'single',
						type			=> 'checkbox',
						name			=> 'accGroup_r_' . $_,
						value			=> 1,
						descr			=> '',
						checked		=> (defined $q->param('accGroup_r_' . $_)) ? $q->param('accGroup_r_' . $_) : 0,
						align			=> 'center',
						width			=> '3em',
						onChange	=> "javascript:setACLs(\"$_\",\"r\")",
					},
					{
						target		=> 'single',
						type			=> 'checkbox',
						name			=> 'accGroup_w_' . $_,
						value			=> 1,
						descr			=> '',
						checked		=> (defined $q->param('accGroup_w_' . $_)) ? $q->param('accGroup_w_' . $_) : 0,
						width			=> '5em',
						align			=> 'center',
						onChange	=> "javascript:setACLs(\"$_\",\"w\")",
					},
					{
						target	=> 'single',
						type		=> 'label',
						value		=> $groups->{$_},
						width		=> '8em',
					}
				]
			},
		)
	};

	$t->{V}->{addRootButtonsMenu}	=	[
		{
			elements	=> [
				{
					target	=> 'single',
					type		=> 'buttons',
					buttons	=> [
						{
							name	=> 'submitAddRoot',
							type	=> 'submit',
							value	=> _gettext("Submit"),
							img		=> 'submit_small.png',
						},
						{
							name	=> 'abortAddRoot',
							type	=> 'submit',
							value	=> _gettext("Abort"),
							img		=> 'cancel_small.png',
						}
					]
				}
			]
		},
	];

	push @{$t->{V}->{addRootHiddens}}, (
		{
			name	=> 'func',
			value	=> 'addRoot'
		},
	);
}

sub mkAddNet {
	warn 'SUB: ' . (caller(0))[3] . ' (' . (caller(1))[3] . ")\n" if $conf->{var}->{showsubs};
	my $t	= $HaCi::GUI::init::t;
	my $q	= $HaCi::HaCi::q;
	my $s	= $HaCi::HaCi::session;

	# get Globals...
	my $stats					= $conf->{static}->{misc}->{networkstates};
	my $types					= &getNetworkTypes(1);
	my $plugins				= ();
	my $availPlugins	= &getPlugins();
	my $availPluginst	= {};
	my $nrOfPlugins		= [];
	my $pluginOrders	= {};
	my $ipv6					= 0;
	my $maxSubnetSize	= &getConfigValue('gui', 'maxsubnetsize');
	my $roots					= &getRoots();
	map {my $h=$_;$h->{name} = &quoteHTML($h->{name}); $_ = $h;} @{$roots};

	my $defSubnetSizes		= [{ID => "0", name => "min"}];
	my $defSubnetSizesV6	= [{ID => "0", name => "min"}];
	map {$_->{ID} = $_->{id}} @{$stats};

	my $plugCnter	= 1;
	foreach (keys %{$availPlugins}) {
		$availPluginst->{$availPlugins->{$_}->{NAME}}	= $_; 
		if ($availPlugins->{$_}->{ACTIVE}) {
			push @{$nrOfPlugins}, {name => $plugCnter, ID => $plugCnter}; 
			$plugCnter++;
		}
	}


	# get Variables....
	my $editNet				= (defined $q->param('editNet')) ? $q->param('editNet') : 0;
	my $fillNet				= (defined $q->param('fillNet')) ? $q->param('fillNet') : 0;
	my $checktAddNet	= (defined $q->param('checktAddNet')) ? $q->param('checktAddNet') : 0;
	my $chTmplID			= (defined $q->param('chTmplID')) ? $q->param('chTmplID') : 0;
	my $submitAddNet	= (defined $q->param('submitAddNet')) ? $q->param('submitAddNet') : 0;
	my $forceState		= (defined $q->param('forceState')) ? $q->param('forceState') : 0;

	# Init variables...
	my $netaddress		= '';
	my $netmask				= '';
	my $cidr					= '';
	my $descr					= '';
	my $state					= 0;
	my $defSubnetSize	= 'min';
	my $rootID				= 0;
	my $tmplID				= 0;

	# If Fillnet
	if ($fillNet) {
		if (defined $q->param('rootID') && defined $q->param('networkDec')) {
			$rootID									= $q->param('rootID');
			my $networkDec					= $q->param('networkDec');
			$ipv6										= &rootID2ipv6($rootID);
			$networkDec							= Math::BigInt->new($networkDec) if $ipv6;
			my $network							= ($ipv6) ? &netv6Dec2net($networkDec) : &dec2net($networkDec);
			(my $ipaddress, $cidr)	= split/\//, $network;
			$netmask								= ($ipv6) ? 0 : &getNetmaskFromCidr($cidr);
			$netaddress							= ($ipv6) ? $ipaddress : &dec2ip(&getNetaddress($ipaddress, $netmask));
			$t->{V}->{addNetHeader}	= sprintf(_gettext("Add Network <b>%s</b>"), $network);
			my $newRoots						= [];

			foreach (@$roots) {
				push @$newRoots, $_ if ($_->{ipv6} && $ipv6) || (!$_->{ipv6} && !$ipv6);
			}
			$roots								= $newRoots;
		} else {
			warn "mkAddnet: (fillNet) No RootID or NetworkDec given!\n";
		}
	}

	# If editNet get Values from DB
	if ($editNet) {
		$t->{V}->{editNet}	= 1;
		my $netID	= $q->param('netID');
		
		if (defined $netID) {
			my $maintenanceInfos			= &getMaintInfosFromNet($netID);
			my $networkDec						= $maintenanceInfos->{network};
			$rootID										= $maintenanceInfos->{rootID};
			$ipv6											= ($maintenanceInfos->{ipv6ID}) ? 1 : 0;
			$tmplID										= $maintenanceInfos->{tmplID} || 0;
			$descr										= $maintenanceInfos->{description} || '';
			$state										= $maintenanceInfos->{state} || 0;
			$defSubnetSize						= $maintenanceInfos->{defSubnetSize} || 0;
			my $network								= ($ipv6) ? &netv6Dec2net($networkDec) : &dec2net($networkDec);
			(my $ipaddress, $cidr)		= split/\//, $network;
			$netmask									= ($ipv6) ? 0 : &getNetmaskFromCidr($cidr);
			$netaddress								= ($ipv6) ? $ipaddress : &dec2ip(&getNetaddress($ipaddress, $netmask));
			$t->{V}->{addNetHeader}		= sprintf(_gettext("Edit Network <b>%s</b>"), $network);
			my $newRoots							= [];

			foreach (@$roots) {
				push @$newRoots, $_ if ($_->{ipv6} && $ipv6) || (!$_->{ipv6} && !$ipv6);
			}
			$roots	= $newRoots;
			
			# Get Template Values from DB
			if ($tmplID) {
				my $error	= 0;
				my $tmplEntryTable  = $conf->{var}->{TABLES}->{templateEntry};
				unless (defined $tmplEntryTable) {
					warn "Cannot show Template Data. (Entries) DB Error\n";
					$error	= 1;
				}
				my $tmplValueTable  = $conf->{var}->{TABLES}->{templateValue};
				unless (defined $tmplValueTable) {
					warn "Cannot show Template Data. (Values) DB Error\n";
					$error	= 1;
				}
				unless ($error) {
					my @tmplEntries = $tmplEntryTable->search(['*'], {tmplID  => $tmplID});
					foreach (@tmplEntries) {
						my $tmplEntryID = $_->{ID};
						my $valueT			= ($tmplValueTable->search(['value'], {netID => $netID, tmplID  => $tmplID, tmplEntryID => $tmplEntryID}))[0];
						$q->delete('tmplEntryID_' . $tmplEntryID); $q->param('tmplEntryID_' . $tmplEntryID, ((defined $valueT) ? $valueT->{value} : ''));
					}
				}
			}
			$plugins	= &getPluginsForNet($netID);
			foreach (keys %{$plugins}) {
				$pluginOrders->{$plugins->{$_}->{sequence}}	= $_;
			}
		} else {
			warn "mkAddnet: (EditNet) No NetID given! => Free Form\n";
		}
	}

	# If checktAddNet or chTmplID or return because of bad values => get values from before
	if ($checktAddNet || $chTmplID || $submitAddNet) {
		$netaddress			= $q->param('netaddress');
		$netmask				= $q->param('netmask');
		$cidr						= $q->param('cidr');
		$descr					= $q->param('descr');
		$state					= $q->param('state');
		$defSubnetSize	= $q->param('defSubnetSize');
		$rootID					= $q->param('rootID');
		$tmplID					= $q->param('tmplID');
		$t->{V}->{addNetHeader}	= sprintf(_gettext((($editNet) ? 'Edit' : 'Add') . " Network <b>%s</b>"), $netaddress . '/' . $cidr);
	}

	# Generate default Subnet Cidr Menu
	{
		$cidr	= 0 unless $cidr;
		map {
			push @{$defSubnetSizes}, {ID => "$_", name => "$_"};
		} (($cidr + 1) .. ((32 < ($cidr + $maxSubnetSize)) ? 32 : ($cidr + $maxSubnetSize)));
		map {
			push @{$defSubnetSizesV6}, {ID => "$_", name => "$_"}
		} (($cidr + 1) .. ((128 < ($cidr + $maxSubnetSize)) ? 128 : ($cidr + $maxSubnetSize)));
	}

	# Corrections
	$descr	= &quoteHTML($descr);

	$t->{V}->{rootID2Ver}				= $roots;
	$t->{V}->{addNetHeader}		||= _gettext("Add Network");
	$t->{V}->{addNetFormName}		= 'addNet';
	$t->{V}->{addNetMenu}				= [
		{
			elements	=> [
				{
					target	=> 'key',
					type		=> 'label',
					value		=> _gettext("Target Root") . (($ipv6) ? ' (IPv6)' : ''),
				},
				{
					target		=> 'value',
					type			=> 'popupMenu',
					name			=> 'rootID',
					size			=> 1,
					values		=> $roots,
					selected	=> $rootID,
					onChange	=> 'javascript:checkIfIPv6(this.value, "ADDNET")',
					focus			=> 1,
					colspan		=> 3,
				},
			]
		},
		{
			elements	=> [
				{
					target	=> 'key',
					type		=> 'label',
					value		=> _gettext("Netaddress"),
				},
				{
					target		=> 'value',
					type			=> 'textfield',
					name			=> 'netaddress',
					size			=> 43,
					maxlength	=> 43,
					value			=> $netaddress,
					onChange	=> "javascript:setnetmask_cidr(this.value, 'netmask', 'cidr', 'netaddress')",
					colspan		=> 3,
				}
			]
		},
		{
			name			=> 'netmaskBlock',
			elements	=> [
				{
					target	=> 'key',
					type		=> 'label',
					value		=> _gettext("Netmask"),
				},
				{
					target		=> 'value',
					type			=> 'textfield',
					name			=> 'netmask',
					size			=> 15,
					maxlength	=> 15,
					value			=> $netmask,
					onChange	=> "javascript:setCIDR(this.value, 'cidr', 'netaddress', 'netmask')",
					colspan		=> 3,
				}
			]
		},
		{
			elements	=> [
				{
					target	=> 'key',
					type		=> 'label',
					value		=> _gettext("CIDR"),
				},
				{
					target		=> 'value',
					type			=> 'textfield',
					name			=> 'cidr',
					size			=> 3,
					maxlength	=> 3,
					value			=> $cidr,
					onChange	=> "javascript:setNetmask(this.value, 'netmask', 'netaddress', 'cidr')",
					colspan		=> 3,
				}
			]
		},
		{
			elements	=> [
				{
					target	=> 'key',
					type		=> 'label',
					value		=> _gettext("Description"),
				},
				{
					target		=> 'single',
					type			=> 'textfield',
					name			=> 'descr',
					size			=> 30,
					maxlength	=> 255,
					value			=> $descr,
					colspan		=> 2,
				},
				{
					target	=> 'value',
					type		=> 'buttons',
					align		=> 'center',
					buttons	=> [
						{
							name		=> 'showDescrHelper',
							type		=> '',
							onClick	=> "showDescrHelper()",
							value		=> '1',
							img			=> 'info_small.png',
							picOnly	=> 1,
							title		=> _gettext("Available Variables from the Plugins"),
						},
					],
				},
			]
		},
		{
			elements	=> [
				{
					target	=> 'key',
					type		=> 'label',
					value		=> _gettext("Status"),
				},
				{
					target		=> 'single',
					type			=> 'popupMenu',
					name			=> 'state',
					size			=> 1,
					values		=> $stats,
					selected	=> $state,
				},
				{
					target		=> 'single',
					type			=> 'checkbox',
					name			=> 'forceState',
					value			=> 1,
					descr			=> _gettext('force'),
					checked		=> $forceState,
					align			=> 'left',
				},
				{
					target	=> 'value',
					type		=> 'buttons',
					align		=> 'center',
					buttons	=> [
						{
							name		=> 'showStatusHelper',
							type		=> '',
							onClick	=> "showStatusHelper()",
							value		=> '1',
							img			=> 'info_small.png',
							picOnly	=> 1,
							title		=> _gettext("IPv4 Address Allocation and Assignment Policies"),
						},
					],
				},
			]
		},
		{
			elements	=> [
				{
					target	=> 'key',
					type		=> 'label',
					value		=> _gettext("Def. Subnet CIDR"),
				},
				{
					target		=> 'value',
					type			=> 'popupMenu',
					name			=> 'defSubnetSize',
					size			=> 1,
					values		=> (($ipv6) ? $defSubnetSizesV6 : $defSubnetSizes),
					selected	=> [$defSubnetSize],
					colspan		=> 3,
				}
			]
		},
		{
			elements	=> [
				{
					target	=> 'key',
					type		=> 'label',
					value		=> _gettext("Type"),
				},
				{
					target		=> 'value',
					type			=> 'popupMenu',
					name			=> 'tmplID',
					size			=> 1,
					values		=> $types,
					selected	=> [$tmplID],
					onChange	=> 'javascript:document.getElementById("chTmplID").value=1;submit()',
					colspan		=> 3,
				}
			]
		},
	];

	$t->{V}->{helpDescrHeader}	= _gettext("Available Variables from the Plugins");
	$t->{V}->{helpDescrMenu}		= [
		{
			elements	=> [
				{
					target	=> 'single',
					type		=> 'label',
					value		=> '',
					width		=> '0.1em',
				},
				{
					target	=> 'single',
					type		=> 'label',
					value		=> '<b>' . _gettext('Name') . '</b>',
					width		=> '3em',
					align		=> 'center',
				},
				{
					target	=> 'single',
					type		=> 'label',
					value		=> '<b>' . _gettext('Description') . '</b>',
					width		=> '8em',
					align		=> 'center',
				},
				{
					target	=> 'single',
					type		=> 'label',
					value		=> '<b>' . _gettext('Insert') . '</b>',
					width		=> '1em',
					align		=> 'center',
				}
			]
		},
		{
			value	=> {
				type		=> 'hline',
				colspan	=> 4,
			}
		},
	];

	if ($tmplID) {
		push @{$t->{V}->{addNetMenu}}, (
			{
				value	=> {
					type		=> 'hline',
					colspan	=> 2,
				}
			},
		);
		(my $menu, undef)	= &getTemplateEntries($tmplID, 1, 0, 0, 0, 1);
		push @{$t->{V}->{addNetMenu}}, @{$menu};
	}

	my $groups		= {};
	{
		my $knowNet			= 0;
		my $rootID			= 0;
		my $networkDec	= 0;
		my $netID				= 0;
		if ($fillNet && defined $q->param('rootID') && defined $q->param('networkDec')) {
			$knowNet		= 1;
			$rootID			= $q->param('rootID');
			$networkDec	= $q->param('networkDec');
			$networkDec	= Math::BigInt->new($networkDec) if $ipv6;
			my $parent	= &getNetworkParentFromDB($rootID, $networkDec, $ipv6);
			$netID			= $parent->{ID};
		}
		elsif ($editNet && defined $q->param('netID')) {
			$knowNet	= 1;
			$netID		= $q->param('netID');
		}
		foreach (@{&getGroups()}) {
			my $groupID	= $_->{ID};
			next if $_->{name} eq 'Administrator' || $s->param('groupIDs') =~ / $_->{ID},/;
	
			$groups->{$_->{ID}}->{NAME}	= $_->{name};
	
			# If checktAddNet or chTmplID or return because of bad values => get values from before
			if ($checktAddNet || $chTmplID || $submitAddNet) {
				$groups->{$_->{ID}}->{R}	= (defined $q->param('accGroup_r_' . $groupID)) ? $q->param('accGroup_r_' . $groupID) : 0;
				$groups->{$_->{ID}}->{W}	= (defined $q->param('accGroup_w_' . $groupID)) ? $q->param('accGroup_r_' . $groupID) : 0;
			} else {
				# If you know the network (fillnet, editNet) get ACLs
				if ($knowNet) {
					my $acl	= &checkNetACL($netID, 'ACL', $groupID);
					$groups->{$_->{ID}}->{R}	= ($acl == 1 || $acl == 3) ? 1 : 0;
					$groups->{$_->{ID}}->{W}	= ($acl == 2 || $acl == 3) ? 1 : 0;
				}
			}
		}
	}

	$t->{V}->{netGroupRightsHeader}	= _gettext("Access Rights");
	$t->{V}->{netGroupRightsMenu}		= [
		{
			elements	=> [
				{
					target	=> 'single',
					type		=> 'label',
					value		=> '<b>' . _gettext('read') . '</b>',
					width		=> '3em',
					align		=> 'center',
				},
				{
					target	=> 'single',
					type		=> 'label',
					value		=> '<b>' . _gettext('write') . '</b>',
					width		=> '5em',
					align		=> 'center',
				},
				{
					target	=> 'single',
					type		=> 'label',
					value		=> '<b>' . _gettext('Group') . '</b>',
					width		=> '8em',
				}
			]
		},
		{
			value	=> {
				type		=> 'hline',
				colspan	=> 3,
			}
		},
	];
	
	foreach (sort {$a<=>$b} keys %{$groups}) {
		push @{$t->{V}->{netGroupRightsMenu}}, (
			{
				elements	=> [
					{
						target		=> 'single',
						type			=> 'checkbox',
						name			=> 'accGroup_r_' . $_,
						value			=> 1,
						descr			=> '',
						checked		=> $groups->{$_}->{R},
						align			=> 'center',
						width			=> '3em',
						onChange	=> "javascript:setACLs(\"$_\",\"r\")",
					},
					{
						target		=> 'single',
						type			=> 'checkbox',
						name			=> 'accGroup_w_' . $_,
						value			=> 1,
						descr			=> '',
						checked		=> $groups->{$_}->{W},
						width			=> '5em',
						align			=> 'center',
						onChange	=> "javascript:setACLs(\"$_\",\"w\")",
					},
					{
						target	=> 'single',
						type		=> 'label',
						value		=> $groups->{$_}->{NAME},
						width		=> '8em',
					}
				]
			},
		);
		push @{$t->{V}->{addNetHiddens}}, (
			{
				name	=> 'accGroup',
				value	=> $_
			},
		);
	};

	$t->{V}->{pluginInfoBoxHeader}	= _gettext("Plugin Info");
	push @{$t->{V}->{pluginInfoBoxMenu}}, (
		{
			elements	=> [
				{
					name			=> 'pluginInfoContent',
					target		=> 'single',
					type			=> 'label',
					value			=> '',
					width			=> '100%',
					bold			=> 0,
					align			=> 'center',
					wrap			=> 1,
				},
			]
		},
		{
			value	=> {
				type		=> 'hline',
				colspan	=> 1,
				width		=> '100%',
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
							name		=> 'abortPluginInfo',
							type		=> '',
							value		=> _gettext("Abort"),
							img			=> 'cancel_small.png',
							onClick	=> "hidePluginInfo()",
							picOnly	=> 1,
							title		=> _gettext("Close Infos for Plugin"),
						},
					],
				},
			]
		}
	);

	$t->{V}->{netPluginsHeader}	= _gettext("Plugins");
	push @{$t->{V}->{netPluginsMenu}}, (
		{
			elements	=> [
				{
					target		=> 'single',
					type			=> 'label',
					value			=> _gettext("Name"),
					width			=> '10em',
					bold			=> 1,
					align			=> 'center',
				},
				{
					target		=> 'single',
					type			=> 'label',
					value			=> _gettext("active"),
					width			=> '6em',
					bold			=> 1,
					align			=> 'center',
				},
				{
					target		=> 'single',
					type			=> 'label',
					value			=> _gettext("Order"),
					width			=> '6em',
					bold			=> 1,
					align			=> 'center',
				},
				{
					target		=> 'single',
					type			=> 'label',
					value			=> _gettext("New Line"),
					width			=> '6em',
					bold			=> 1,
					align			=> 'center',
				},
				{
					target		=> 'single',
					type			=> 'label',
					value			=> _gettext("Configure"),
					width			=> '6em',
					bold			=> 1,
					align			=> 'center',
				},
				{
					target		=> 'single',
					type			=> 'label',
					value			=> _gettext("Info"),
					width			=> '6em',
					bold			=> 1,
					align			=> 'center',
				},
			]
		},
		{
			value	=> {
				type		=> 'hline',
				colspan	=> 6,
			}
		},
	);

	my $currRow	= 1;
	foreach (sort keys %{$availPluginst}) {
		my $ID					= $availPluginst->{$_};
		my $netmenu			= $availPlugins->{$ID}->{NETMENU};
		next unless $availPlugins->{$ID}->{ACTIVE};
		unless (exists $plugins->{$ID} && $plugins->{$ID}->{sequence}) {
			while (exists $pluginOrders->{$currRow}) {$currRow++};
			$pluginOrders->{$currRow}	= 1;
		}
		my $bConf	= 1 if (
			$availPlugins->{$ID}->{RECURRENT} && 
			(
				exists $conf->{static}->{plugindefaultrecurrentmenu} && 
				ref($conf->{static}->{plugindefaultrecurrentmenu}) eq 'ARRAY' && 
				$#{$conf->{static}->{plugindefaultrecurrentmenu}} != -1
			) || (
				exists $availPlugins->{$ID}->{MENURECURRENT} && 
				ref($availPlugins->{$ID}->{MENURECURRENT}) eq 'ARRAY' && 
				$#{$availPlugins->{$ID}->{MENURECURRENT}} != -1
			)
		) || (
			$availPlugins->{$ID}->{ONDEMAND} && 
			(
				exists $conf->{static}->{plugindefaultondemandmenu} && 
				ref($conf->{static}->{plugindefaultondemandmenu}) eq 'ARRAY' &&
				$#{$conf->{static}->{plugindefaultondemandmenu}} != -1
			) || (
				exists $availPlugins->{$ID}->{MENUONDEMAND} && 
				ref($availPlugins->{$ID}->{MENUONDEMAND}) eq 'ARRAY' &&
				$#{$availPlugins->{$ID}->{MENUONDEMAND}} != -1
			)
		);

		my $elements	= [];
		my $api				= (exists $availPlugins->{$ID}->{API} && ref($availPlugins->{$ID}->{API}) eq 'ARRAY') ? $availPlugins->{$ID}->{API} : [];

		foreach (@{$api}) {
			my $name	= $_->{name};
			my $descr	= $_->{descr};

			push @{$elements}, (
				{elements	=> [
					{
						target		=> 'single',
						type			=> 'label',
						value			=> '',
						width			=> '0.1em',
					},
					{
						target		=> 'single',
						type			=> 'label',
						value			=> $name,
						width			=> '3em',
						align			=> 'left',
					},
					{
						target		=> 'single',
						type			=> 'label',
						value			=> $descr,
						width			=> '8em',
						align			=> 'left',
					},
					{
						target		=> 'single',
						type			=> 'buttons',
						align			=> 'center',
						width			=> '1em',
						buttons	=> [
							{
								name		=> 'insertPluginVar',
								type		=> '',
								onClick	=> "insertPluginVar('descr','\%\%$availPlugins->{$ID}->{NAME}\%$name\%\%')",
								value		=> '1',
								img			=> 'insert_small.png',
								picOnly	=> 1,
								title		=> sprintf(_gettext("Insert '%s' from Plugin '%s'"), $name, $availPlugins->{$ID}->{NAME}),
							},
						],
					},
				]}
			);
		};

		push @{$t->{V}->{helpDescrMenu}}, (
			{
				elements	=> [
					{
						target		=> 'single',
						type			=> 'label',
						value			=> sprintf(_gettext("Plugin '%s'"), $availPlugins->{$ID}->{NAME}),
						bold			=> 1,
						colspan		=> 4,
					},
				],
			},
			@{$elements}
		) if $#{$api} != -1;

		my $pluginDescr	= &quoteHTML($availPlugins->{$ID}->{DESCR});
		$pluginDescr		=~ s/&apos;/\\&apos;/g;
		my $pluginName	= &quoteHTML($availPlugins->{$ID}->{NAME});
		$pluginName			=~ s/&apos;/\\&apos;/g;
		push @{$t->{V}->{netPluginsMenu}}, (
			{
				elements	=> [
					{
						target		=> 'single',
						type			=> 'label',
						value			=> $pluginName,
						width			=> '10em',
					},
					{
						target		=> 'single',
						type			=> 'checkbox',
						name			=> 'netPluginActives',
						value			=> $ID,
						descr			=> ($availPlugins->{$ID}->{DEFAULT}) ? ' (' . _gettext("Default") . ')' : '',
						checked		=> ($availPlugins->{$ID}->{DEFAULT}) ? 1 : ((exists $plugins->{$ID}) ? 1 : 0),
						align			=> 'left',
						width			=> '6em',
						disabled	=> ($availPlugins->{$ID}->{DEFAULT}) ? 1 : 0,
					},
					{
						target		=> 'single',
						type			=> 'popupMenu',
						name			=> 'pluginOrder_' . $ID,
						size			=> 1,
						values		=> $nrOfPlugins,
						align			=> 'center',
						width			=> '6em',
						selected	=> (exists $plugins->{$ID} && $plugins->{$ID}->{sequence}) ? [$plugins->{$ID}->{sequence}] : [$currRow],
					},
					{
						target		=> 'single',
						type			=> 'checkbox',
						name			=> 'netPluginNewLines',
						value			=> $ID,
						descr			=> '',
						checked		=> (exists $plugins->{$ID} && $plugins->{$ID}->{newLine}) ? $plugins->{$ID}->{newLine} : 0,
						align			=> 'center',
						width			=> '6em',
					},
					{
						target	=> 'single',
						type		=> 'buttons',
						align		=> 'center',
						buttons	=> [
							{
								name		=> 'editPluginConf',
								type		=> 'submit',
								onClick	=> "setPluginID('$ID')",
								value		=> '1',
								img			=> 'config_small' . (($editNet && $bConf) ? '' : '_disabled') . '.png',
								picOnly	=> 1,
								title		=> sprintf(_gettext("Configure Plugin '%s'"), $pluginName),
								disabled	=> ($editNet && $bConf) ? 0 : 1,
							},
						],
					},
					{
						target	=> 'single',
						type		=> 'buttons',
						align		=> 'center',
						buttons	=> [
							{
								name		=> 'pluginInfo',
								onClick	=> "showPluginInfo('" . ("<b>$pluginName</b><br>" . ($pluginDescr || '')) . "')",
								value		=> '1',
								img			=> 'info_small.png',
								picOnly	=> 1,
								title		=> sprintf(_gettext("Infos for Plugin '%s'"), $pluginName),
							},
						],
					},
				]
			},
		);

		if ($availPlugins->{$ID}->{DEFAULT}) {
			push @{$t->{V}->{addNetHiddens}}, (
				{
					name	=> 'netPluginActives',
					value	=> $ID
				},
			);
		}
	}

	push @{$t->{V}->{helpDescrMenu}}, (
		{
			value	=> {
				type		=> 'hline',
				colspan	=> 4,
			}
		},
		{
			elements	=> [
				{
					target	=> 'single',
					type		=> 'buttons',
					align		=> 'center',
					colspan	=> 4,
					buttons	=> [
						{
							name		=> 'pluginInfoCloser',
							onClick	=> "hideDescrHelper()",
							value		=> '1',
							img			=> 'cancel_small.png',
							picOnly	=> 1,
							title		=> _gettext("Close Overview"),
						},
					],
				},
			]
		}
	);

	$t->{V}->{helpStatusHeader}	= _gettext("IP Address Allocation and Assignment Policies");
	push @{$t->{V}->{helpStatusMenu}}, (
		{
			elements	=> [
				{
					target	=> 'single',
					type		=> 'label',
					width		=> 500,
					align		=> 'left',
					value		=> '<pre>
# <b>ALLOCATED PA</b>: This address space has been allocated to an LIR and no assignments or sub-allocations made from it are portable.
  Assignments and suballocations cannot be kept when moving to another provider.  
# <b>ALLOCATED PI</b>: This address space has been allocated to an LIR or RIR and all
  assignments made from it are portable. Assignments can be kept as long as the criteria for the original assignment are met.
  Sub-allocations cannot be made from this type of address space.
# <b>ALLOCATED UNSPECIFIED</b>: This address space has been allocated to an LIR or RIR. Assignments may be PA or PI. This status is intended to document past
  allocations where assignments of both types exist. It is avoided for new allocations. Sub-allocations cannot be made from this type of address space.
# <b>SUB-ALLOCATED PA</b>: This address space has been sub-allocated by an LIR to a downstream network operator that will make assignments from it. All
  assignments made from it are PA. They cannot be kept when moving to a service provided by another provider.
# <b>LIR-PARTITIONED PA</b>: This allows an LIR to document distribution and delegate management of allocated space within their organisation. Address space
  with a status of LIR-PARTITIONED is not considered used. When the addresses are used, a more specific inetnum should be registered.
# <b>LIR-PARTITIONED PI</b>: This allows an LIR to document distribution and delegate management of allocated space within their organisation. Address space
  with a status of LIR-PARTITIONED is not considered used. When the addresses are used, a more specific inetnum should be registered.
# <b>EARLY-REGISTRATION</b>: This is used by the RIPE Database administration when transferring pre-RIR registrations from the ARIN Database. The value can
  be changed by database users (except for ALLOCATED PA). Only the RIPE Database administrators can create objects with this value.
# <b>NOT-SET</b>: This indicates that the registration was made before the "status:" attributes became mandatory for inetnum objects. The object has not been
  updated since then. New objects cannot be created with this value. The value can be changed by database users.
# <b>ASSIGNED PA</b>: This address space has been assigned to an End User for use with services provided by the issuing LIR. It cannot be kept when terminating
  services provided by the LIR.
# <b>ASSIGNED PI</b>: This address space has been assigned to an End User and can be kept as long as the criteria for the original assignment are met.
# <b>ASSIGNED ANYCAST</b>: This address space has been assigned for use in TLD anycast networks. It cannot be kept when no longer used for TLD anycast
  services.
<br>
# <b>ALLOCATED-BY-RIR</b>: For allocations made by an RIR to an LIR.
# <b>ALLOCATED-BY-LIR</b>: For allocations made by an LIR or an LIR\'s downstream customer to another downstream organisation.
# <b>ASSIGNED</b>: For assignments made to End User sites.
<br>
> Source: <a href="http://www.ripe.net/ripe/docs/ripe-484.html" target="_new"> v4 </a> / <a href="http://www.ripe.net/ripe/docs/ripe-481.html" target="_new"> v6 </a><</pre>'
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
							onClick	=> "hideStatusHelper()",
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


	$t->{V}->{addNetButtonsMenu}	=	[
		{
			elements	=> [
				{
					target	=> 'single',
					type		=> 'buttons',
					buttons	=> [
						{
							name	=> 'submitAddNet',
							type	=> 'submit',
							value	=> _gettext("Submit"),
							img		=> 'submit_small.png',
						},
					]
				},
				{
					target	=> 'single',
					type		=> 'buttons',
					buttons	=> [
						{
							name	=> 'abortAddNet',
							type	=> 'submit',
							value	=> _gettext("Abort"),
							img		=> 'cancel_small.png',
						},
					]
				},
				{
					target	=> 'single',
					type		=> 'buttons',
					buttons	=> [
						{
							name	=> 'checktAddNet',
							type	=> 'submit',
							value	=> _gettext("Check"),
							img		=> 'check_small.png',
						},
					]
				}
			]
		},
	];

	push @{$t->{V}->{addNetHiddens}}, (
		{
			name	=> 'func',
			value	=> 'addNet'
		},
		{
			name	=> 'chTmplID',
			value	=> 0
		},
		{
			name	=> 'fillNet',
			value	=> $fillNet
		},
		{
			name	=> 'editNet',
			value	=> $editNet
		},
		{
			name	=> 'conf_maxSubnetSize',
			value	=> $maxSubnetSize
		},
	);

	if ($fillNet) {
		push @{$t->{V}->{addNetHiddens}}, (
			{
				name	=> 'networkDec',
				value	=> $q->param('networkDec')
			},
		) if defined $q->param('networkDec');
	}

	if ($editNet) {
		push @{$t->{V}->{addNetHiddens}}, (
			{
				name	=> 'netID',
				value	=> $q->param('netID')
			}
		) if defined $q->param('netID');
	}
}

sub mkImportASNRoutes {
	warn 'SUB: ' . (caller(0))[3] . ' (' . (caller(1))[3] . ")\n" if $conf->{var}->{showsubs};
	my $t				= $HaCi::GUI::init::t;
	my $q				= $HaCi::HaCi::q;
	&removeStatus();

	$t->{V}->{importASNRoutesHeader}		= _gettext("Import ASN Routes");
	$t->{V}->{importASNRoutesFormName}	= 'importASNRoutes';
	$t->{V}->{importASNRoutesMenu}			= [
		{
			elements	=> [
				{
					target	=> 'key',
					type		=> 'label',
					value		=> _gettext("AS Number"),
				},
				{
					target		=> 'value',
					type			=> 'textfield',
					name			=> 'asn',
					size			=> 5,
					maxlength	=> 5,
					value			=> ((defined $q->param('asn')) ? $q->param('asn') : ''),
					focus			=> 1,
					onKeyDown	=> "submitOnEnter(event, 'submitImportASNRoutes')",
				}
			],
		},
		{
			elements	=> [
				{
					target	=> 'key',
					type		=> 'label',
					value		=> _gettext("Only insert new"),
				},
				{
					target		=> 'value',
					type			=> 'checkbox',
					name			=> 'onlyNew',
					value			=> 1,
					descr			=> '',
					checked		=> 0,
				},
			],
		},
		{
			elements	=> [
				{
					target	=> 'key',
					type		=> 'label',
					value		=> _gettext("Remove obsoletes"),
				},
				{
					target		=> 'value',
					type			=> 'checkbox',
					name			=> 'delOld',
					value			=> 1,
					descr			=> '',
					checked		=> 0,
				},
			],
		},
	];

	$t->{V}->{importASNRoutesButtons}	= [
		{
			elements	=> [
				{
					type		=> 'buttons',
					target	=> 'single',
					buttons	=> [
						{
							name		=> 'submitImportASNRoutes',
							type		=> 'submit',
							value		=> _gettext("Import"),
							onClick	=> "showStatus(1)",
							img			=> 'import_small.png',
						},
					]
				},
				{
					type		=> 'buttons',
					target	=> 'single',
					buttons	=> [
						{
							name	=> 'abortImportASNRoutes',
							type	=> 'submit',
							value	=> _gettext("Abort"),
							img		=> 'cancel_small.png',
						},
					],
				}
			]
		},
	];
}

sub checkNet {
	warn 'SUB: ' . (caller(0))[3] . ' (' . (caller(1))[3] . ")\n" if $conf->{var}->{showsubs};
	my $netaddress	= shift;
	my $cidr				= shift;
	my $network			= "$netaddress/$cidr";
	my $whoisData		= &getWHOISData($network);
	my $ptrData			= &getNSData($netaddress);
	my $t						= $HaCi::GUI::init::t;

	$t->{V}->{checkNet}		= 1;

	$t->{V}->{addNetDNSInfoHeader}	= sprintf(_gettext("DNS Info for %s"), $ptrData->{ipaddress} || '');
	$t->{V}->{addNetDNSInfo}				= [
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
					value			=> $ptrData->{data},
				}
			]
		},
	];

	$t->{V}->{addNetWHOISInfoHeader}	= sprintf(_gettext("RIPE Info for %s"), $whoisData->{inetnum} || '');
	foreach (@{$whoisData->{data}}) {
		push @{$t->{V}->{addNetWHOISInfo}}, {
			elements	=> [
				{
					target	=> 'key',
					type		=> 'label',
					value		=> $_->{key},
				},
				{
					target		=> 'value',
					type			=> 'label',
					value			=> $_->{value},
				}
			]
		}
	}
}

sub mkShowNet {
	warn 'SUB: ' . (caller(0))[3] . ' (' . (caller(1))[3] . ")\n" if $conf->{var}->{showsubs};
	my $q										= $HaCi::HaCi::q;
	my $t										= $HaCi::GUI::init::t;
	my $netID								= $q->param('netID');
	return unless defined $netID;
	
	my ($rootID, $networkDec, $ipv6)	= &netID2Stuff($netID);
	my $network												= ($ipv6) ? &netv6Dec2net($networkDec) : &dec2net($networkDec);
	return unless &checkSpelling_Net($network, $ipv6);

	my $maintenanceInfos		= &getMaintInfosFromNet($netID);
	my $tmplID							= $maintenanceInfos->{tmplID} || 0;
	my $descr								= $maintenanceInfos->{description} || '';
	my $state								= $maintenanceInfos->{state} || 0;
	my $defSubnetSize				= $maintenanceInfos->{defSubnetSize} || 0;
	my ($ipaddress, $cidr)	= split(/\//, $network);
	my $netmask							= ($ipv6) ? 0 : &getNetmaskFromCidr($cidr);
	my $netaddress					= ($ipv6) ? $ipaddress : &dec2ip(&getNetaddress($ipaddress, $netmask));
	my $broadcastDec				= ($ipv6) ? &getV6BroadcastIP($networkDec) : &getBroadcastFromNet($networkDec);
	my $broadcast						= ($ipv6) ? &ipv6Dec2ip($broadcastDec) : &dec2ip($broadcastDec);
	my $nrOfAddresses				= Math::BigInt->new(2);
	my $nrOfFreeSubnets			= &getFreeSubnets($netID, 1);
	$state									= &networkStateID2Name($state);

	$nrOfAddresses->bpow((($ipv6) ? 128 : 32) - (($ipv6) ? (($cidr < 64) ? 64 : $cidr) : $cidr));
	my ($routPref, $subnet, $hostID)	= (($ipv6) ? ($ipaddress =~ /(.{14}):(.{4}):(.*)/) : ());
	$descr	= &subDescription($descr, $netID) if $descr =~ /\%{2}/;

	my $plugins			= &getPluginsForNet($netID);
	my $pluginOrder	= {};
	foreach (keys %{$plugins}) {
		my $seq	= (exists $plugins->{$_}->{sequence}) ? $plugins->{$_}->{sequence} : 0;
		push @{$pluginOrder->{$seq}}, $_;
	}

	foreach (sort {$a<=>$b} keys %{$pluginOrder}) {
		foreach (@{$pluginOrder->{$_}}) {
			my $pluginID				= $_;
			my $pluginFilename	= &pluginID2File($pluginID);
			my $pluginInfos			= (&getPluginInfos($pluginFilename))[1];
			push @{$t->{V}->{plugins}}, {
				ID			=> $pluginID,
				name		=> &pluginID2Name($pluginID),
				netID		=> $netID,
				newLine	=> (exists $plugins->{$pluginID}->{newLine}) ? $plugins->{$pluginID}->{newLine} : 0,
			} if $pluginInfos->{ACTIVE};
		}
	}

	$t->{V}->{netBasicInfoHeader}	= sprintf(_gettext("Details of Network <b>%s</b>"), $network);
	$t->{V}->{netBasicInfo}	= [
		{
			elements	=> [
				{
					target	=> 'key',
					type		=> 'label',
					value		=> _gettext("Netaddress"),
				},
				{
					target		=> 'value',
					type			=> 'label',
					value			=> $netaddress
				}
			]
		},
		($ipv6) ?
		({
			elements	=> [
				{
					target	=> 'key',
					type		=> 'label',
					value		=> _gettext("compressed"),
				},
				{
					target		=> 'value',
					type			=> 'label',
					value			=> Net::IPv6Addr::to_string_compressed($netaddress),
				}
			]
		}) : 
		({
			elements	=> [
				{
					target	=> 'key',
					type		=> 'label',
					value		=> _gettext("Netmask"),
				},
				{
					target		=> 'value',
					type			=> 'label',
					value			=> $netmask
				}
			]
		}),
		{
			elements	=> [
				{
					target	=> 'key',
					type		=> 'label',
					value		=> _gettext("CIDR"),
				},
				{
					target		=> 'value',
					type			=> 'label',
					value			=> $cidr
				}
			]
		},
		{
			elements	=> [
				{
					target	=> 'key',
					type		=> 'label',
					value		=> _gettext("Broadcast"),
				},
				{
					target		=> 'value',
					type			=> 'label',
					value			=> $broadcast
				}
			]
		},
		($ipv6) ? (
		{
			elements	=> [
				{
					target	=> 'key',
					type		=> 'label',
					value		=> _gettext("Routing Prefix"),
				},
				{
					target		=> 'value',
					type			=> 'label',
					value			=> $routPref,
				}
			]
		},
		{
			elements	=> [
				{
					target	=> 'key',
					type		=> 'label',
					value		=> _gettext("Subnet"),
				},
				{
					target		=> 'value',
					type			=> 'label',
					value			=> $subnet,
				}
			]
		},
		{
			elements	=> [
				{
					target	=> 'key',
					type		=> 'label',
					value		=> _gettext("HostID"),
				},
				{
					target		=> 'value',
					type			=> 'label',
					value			=> $hostID,
				}
			]
		}) : (),
		{
			elements	=> [
				{
					target	=> 'key',
					type		=> 'label',
					value		=> _gettext("# of available Adresses"),
				},
				{
					target		=> 'value',
					type			=> 'label',
					value			=> $nrOfAddresses,
				}
			]
		},
		{
			elements	=> [
				{
					target	=> 'key',
					type		=> 'label',
					value		=> sprintf(_gettext("# of free Subnets with CIDR '%s'"), ($defSubnetSize) ? $defSubnetSize : 'min'),
				},
				{
					target		=> 'value',
					type			=> 'label',
					value			=> $nrOfFreeSubnets,
				}
			]
		},
		{
			value	=> {
				type		=> 'hline',
				colspan => 2,
			}
		},
		{
			elements	=> [
				{
					target	=> 'key',
					type		=> 'label',
					value		=> _gettext("Description"),
				},
				{
					target		=> 'value',
					type			=> 'label',
					value			=> &quoteHTML($descr),
				}
			]
		},
		{
			elements	=> [
				{
					target	=> 'key',
					type		=> 'label',
					value		=> _gettext("Status"),
				},
				{
					target		=> 'value',
					type			=> 'label',
					value			=> $state,
				}
			]
		},
		{
			value	=> {
				type		=> 'hline',
				colspan => 2,
			}
		},
		{
			elements	=> [
				{
					target	=> 'key',
					type		=> 'label',
					value		=> _gettext("Created from"),
				},
				{
					target		=> 'value',
					type			=> 'label',
					value			=> $maintenanceInfos->{createFrom},
				}
			]
		},
		{
			elements	=> [
				{
					target	=> 'key',
					type		=> 'label',
					value		=> _gettext("Created on"),
				},
				{
					target		=> 'value',
					type			=> 'label',
					value			=> $maintenanceInfos->{createDate},
				}
			]
		},
		{
			elements	=> [
				{
					target	=> 'key',
					type		=> 'label',
					value		=> _gettext("Modified by"),
				},
				{
					target		=> 'value',
					type			=> 'label',
					value			=> $maintenanceInfos->{modifyFrom},
				}
			]
		},
		{
			elements	=> [
				{
					target	=> 'key',
					type		=> 'label',
					value		=> _gettext("Modified on"),
				},
				{
					target		=> 'value',
					type			=> 'label',
					value			=> $maintenanceInfos->{modifyDate},
				}
			]
		},
	];

	$t->{V}->{netFunctionsHeader}		= _gettext("Menu");
	$t->{V}->{netFunctionsFormName}	= "netFunctions";
	$t->{V}->{netFunctions}	= [
		{
			elements	=> [
				{
					target	=> 'single',
					type		=> 'buttons',
					buttons	=> [
						{
							name			=> 'editNet',
							type			=> 'submit',
							value			=> _gettext("Edit"),
							disabled	=> (&checkRight('editNet') && &checkNetACL($netID, 'w')) ? 0 : 1,
							img				=> 'edit_small.png',
						},
					],
				},
				{
					target	=> 'single',
					type		=> 'buttons',
					buttons	=> [
						{
							name			=> 'splitNet',
							type			=> 'submit',
							value			=> _gettext("Split"),
							disabled	=> ((($ipv6 && $cidr != 128) || (!$ipv6 && $cidr != 32)) && &checkRight('editNet') && &checkNetACL($netID, 'w')) ? 0 : 1,
							img				=> 'split_small.png',
						},
					],
				},
				{
					target	=> 'single',
					type		=> 'buttons',
					buttons	=> [
						{
							name			=> 'showSubnets',
							type			=> 'submit',
							value			=> _gettext("Show Subnets"),
							disabled	=> ((($ipv6 && $cidr != 128) || (!$ipv6 && $cidr != 32)) && (&checkRight('showNetDet'))) ? 0 : 1,
							img				=> 'showSubnets_small.png',
						},
					],
				},
				{
					target	=> 'single',
					type		=> 'buttons',
					buttons	=> [
						{
							name			=> 'delNet',
							type			=> 'submit',
							value			=> _gettext("Delete"),
							disabled	=> (&checkRight('editNet') && &checkNetACL($netID, 'w')) ? 0 : 1,
							img				=> 'del_small.png',
						},
					],
				},
				{
					target	=> 'single',
					type		=> 'buttons',
					buttons	=> [
						{
							name	=> 'abortShowNet',
							type	=> 'submit',
							value	=> _gettext("Back"),
							img		=> 'back_small.png',
						},
					],
				},
				{
					target	=> 'single',
					type		=> 'floatEnd',
				},
			]
		},
	];

	$t->{V}->{netFunctionHiddens}	= [
		{
			name	=> 'netID',
			value	=> $netID
		}
	];

	$t->{V}->{netInfoHeader}	= sprintf(_gettext("Type Infos of Network <b>%s</b>"), $network);
	$t->{V}->{netInfo}				= &getTemplateData($netID, $tmplID);
}

sub mkDelNet {
	warn 'SUB: ' . (caller(0))[3] . ' (' . (caller(1))[3] . ")\n" if $conf->{var}->{showsubs};
	my $q			= $HaCi::HaCi::q;
	my $netID	= $q->param('netID');
	return unless defined $netID;
	
	my ($rootID, $networkDec, $ipv6)	= &netID2Stuff($netID);
	my $t															= $HaCi::GUI::init::t;
	my $network												= ($ipv6) ? &netv6Dec2net($networkDec) : &dec2net($networkDec);
	my $nrOfChilds										= &getNrOfChilds($networkDec, $rootID, $ipv6);

	$t->{V}->{delNetHeader}		= sprintf(_gettext("Do you really want to delete the Network '<b>%s</b>'?"), $network);
	$t->{V}->{delNetFormName}	= 'delNet';
	$t->{V}->{delNetMenu}			= [
		{
			elements	=> [
				{
					target	=> 'key',
					type		=> 'label',
					value		=> _gettext("With all Subnets"),
				},
				{
					target		=> 'value',
					type			=> 'checkbox',
					name			=> 'withSubnets',
					value			=> 1,
					descr			=> ' (' . sprintf(_gettext("This network contains <b>%i</b> subnets"), $nrOfChilds) . ')',
					checked		=> 0,
					disabled	=> ($nrOfChilds == 0) ? 1 : 0,
				},
			],
		},
		{
			value	=> {
				type		=> 'hline',
				colspan	=> 2,
			}
		},
		{
			elements	=> [
				{
					target	=> 'single',
					type		=> 'buttons',
					align		=> 'center',
					colspan	=> 2,
					buttons	=> [
						{
							name	=> 'commitDelNet',
							type	=> 'submit',
							value	=> _gettext("Delete"),
							img		=> 'del_small.png',
						},
						{
							name	=> 'abortDelNet',
							type	=> 'submit',
							value	=> _gettext("Abort"),
							img		=> 'cancel_small.png',
						},
					],
				},
			],
		}
	];

	$t->{V}->{delNetHiddens}	= [
		{
			name	=> 'delNet',
			value	=> '1'
		},
		{
			name	=> 'netID',
			value	=> $netID
		},
	];
}

sub mkShowRoot {
	warn 'SUB: ' . (caller(0))[3] . ' (' . (caller(1))[3] . ")\n" if $conf->{var}->{showsubs};
	my $q									= $HaCi::HaCi::q;
	my $t									= $HaCi::GUI::init::t;
	my $rootID						= $q->param('rootID');
	my $rootName					= &rootID2Name($rootID);
	my $maintenanceInfos	= &getMaintInfosFromRoot($rootID);
	my $nrOfNetworks			= &getNrOfChilds(0, $rootID);

	$t->{V}->{rootInfoHeader}	= sprintf(_gettext("Details of Root <b>%s</b>"), &quoteHTML($rootName));
	$t->{V}->{rootInfo}				= [
		{
			elements	=> [
				{
					target	=> 'key',
					type		=> 'label',
					value		=> _gettext("Description"),
				},
				{
					target		=> 'value',
					type			=> 'label',
					value			=> &quoteHTML($maintenanceInfos->{description}),
				}
			]
		},
		{
			elements	=> [
				{
					target	=> 'key',
					type		=> 'label',
					value		=> _gettext("IPv6"),
				},
				{
					target		=> 'value',
					type			=> 'checkbox',
					name			=> '',
					value			=> '',
					descr			=> '',
					checked		=> $maintenanceInfos->{ipv6},
					disabled	=> 1,
				},
			]
		},
		{
			elements	=> [
				{
					target	=> 'key',
					type		=> 'label',
					value		=> _gettext("Number of Networks"),
				},
				{
					target		=> 'value',
					type			=> 'label',
					value			=> $nrOfNetworks
				}
			]
		},
		{
			value	=> {
				type		=> 'hline',
				colspan	=> 2,
			}
		},
		{
			elements	=> [
				{
					target	=> 'key',
					type		=> 'label',
					value		=> _gettext("Created from"),
				},
				{
					target		=> 'value',
					type			=> 'label',
					value			=> $maintenanceInfos->{createFrom},
				}
			]
		},
		{
			elements	=> [
				{
					target	=> 'key',
					type		=> 'label',
					value		=> _gettext("Created on"),
				},
				{
					target		=> 'value',
					type			=> 'label',
					value			=> $maintenanceInfos->{createDate},
				}
			]
		},
		{
			elements	=> [
				{
					target	=> 'key',
					type		=> 'label',
					value		=> _gettext("Modified by"),
				},
				{
					target		=> 'value',
					type			=> 'label',
					value			=> $maintenanceInfos->{modifyFrom},
				}
			]
		},
		{
			elements	=> [
				{
					target	=> 'key',
					type		=> 'label',
					value		=> _gettext("Modified on"),
				},
				{
					target		=> 'value',
					type			=> 'label',
					value			=> $maintenanceInfos->{modifyDate},
				}
			]
		},
	];

	$t->{V}->{rootFunctionsHeader}	= _gettext("Menu");
	$t->{V}->{rootFunctionFormName}	= "rootFunctionMenu";
	$t->{V}->{rootFunctions}	= [
		{
			elements	=> [
				{
					target	=> 'single',
					type		=> 'buttons',
					align		=> 'center',
					buttons	=> [
						{
							name			=> 'editRoot',
							type			=> 'submit',
							value			=> _gettext("Edit"),
							disabled	=> (&checkRight('editRoot') && &checkRootACL($rootID, 'w')) ? 0 : 1,
							img				=> 'edit_small.png',
						},
					],
				},
				{
					target	=> 'single',
					type		=> 'buttons',
					align		=> 'center',
					buttons	=> [
						{
							name			=> 'delRoot',
							type			=> 'submit',
							value			=> _gettext("Delete"),
							disabled	=> (&checkRight('editRoot') && &checkRootACL($rootID, 'w')) ? 0 : 1,
							img				=> 'del_small.png',
						},
					],
				},
				{
					target	=> 'single',
					type		=> 'buttons',
					align		=> 'center',
					buttons	=> [
						{
							name	=> 'abortShowRoot',
							type	=> 'submit',
							value	=> _gettext("Back"),
							img		=> 'back_small.png',
						},
					],
				},
			]
		},
	];

	$t->{V}->{rootFunctionHiddens}	= [
		{
			name	=> 'rootID',
			value	=> $rootID
		}
	];
}

sub mkDelRoot {
	warn 'SUB: ' . (caller(0))[3] . ' (' . (caller(1))[3] . ")\n" if $conf->{var}->{showsubs};
	my $t						= $HaCi::GUI::init::t;
	my $q						= $HaCi::HaCi::q;
	my $rootID			= $q->param('rootID');
	my $rootName		= &quoteHTML(&rootID2Name($rootID));
	my $nrOfChilds	= &getNrOfChilds(0, $rootID);

	$t->{V}->{delRootHeader}		= sprintf(_gettext("Do you really want to delete the Root <b>%s</b>?"), $rootName);
	$t->{V}->{delRootFormName}	= 'delRoot';
	$t->{V}->{delRootMenu}			= [
		{
			elements	=> [
				{
					target	=> 'single',
					type		=> 'label',
					value		=> sprintf(_gettext("This Root has <b>%i</b> Subnets"), $nrOfChilds),
				},
			],
		},
		{
			value	=> {
				type		=> 'hline',
				colspan	=> 1,
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
							name	=> 'commitDelRoot',
							type	=> 'submit',
							value	=> _gettext("Delete"),
							img		=> 'del_small.png',
						},
						{
							name	=> 'abortDelRoot',
							type	=> 'submit',
							value	=> _gettext("Abort"),
							img		=> 'cancel_small.png',
						},
					],
				},
			],
		}
	];

	$t->{V}->{delRootHiddens}	= [
		{
			name	=> 'delRoot',
			value	=> '1'
		},
		{
			name	=> 'rootID',
			value	=> $rootID
		},
	];
}

sub mkSearch {
	warn 'SUB: ' . (caller(0))[3] . ' (' . (caller(1))[3] . ")\n" if $conf->{var}->{showsubs};
	my $t						= $HaCi::GUI::init::t;
	my $q						= $HaCi::HaCi::q;
	my $searchValue	= ((defined $q->param('search')) ? $q->param('search') : '');
	my $stats				= $conf->{static}->{misc}->{networkstates};
	my $state				= (defined $q->param('state')) ? $q->param('state') : -1;
	my $tmplID			= (defined $q->param('tmplID')) ? $q->param('tmplID') : -1;
	my $types				= &getNetworkTypes(1);
	$searchValue		=~ s/"/&#34;/g;
	unshift @{$types}, {ID => -1, name  => '[ALL]'};

	map {$_->{ID}	= $_->{id}} @{$stats};
	unshift @{$stats}, {ID => -1, name => '[ALL]'};
	
	$t->{V}->{searchHeader}					= _gettext("Search");
	$t->{V}->{searchResultHeader}		= _gettext("Result");
	$t->{V}->{gettext_network}			= _gettext("Network");
	$t->{V}->{gettext_description}	= _gettext("Description");
	$t->{V}->{gettext_state}				= _gettext("Status");
	$t->{V}->{searchFormName}				= 'search';
	$t->{V}->{buttonFocus}					= 'searchButton';
	$t->{V}->{searchMenu}						=	[
		{	
			elements	=> [
				{
					target	=> 'single',
					type			=> 'textfield',
					name			=> 'search',
					size			=> 40,
					maxlength	=> 255,
					value			=> $searchValue,
					focus			=> 1,
					onKeyDown	=> "submitOnEnter(event, 'searchButton')",
					colspan		=> 2,
					align			=> 'center',
				},
			],
		},
		{
			elements	=> [
				{
					target	=> 'key',
					type		=> 'label',
					value		=> _gettext("Wildcard"),
				},
				{
					target	=> 'value',
					type		=> 'label',
					value		=> '*',
					bold		=> 1,
				},
			],
		},
		{
			elements	=> [
				{
					target	=> 'key',
					type		=> 'label',
					value		=> _gettext("Exact"),
				},
				{
					target		=> 'value',
					type			=> 'checkbox',
					name			=> 'exact',
					value			=> 1,
					descr			=> '',
					checked		=> ((defined $q->param('exact')) ? 1 : 0),
				},
			],
		},
		{
			elements	=> [
				{
					target	=> 'key',
					type		=> 'label',
					value		=> _gettext("Fuzzy Search"),
				},
				{
					target		=> 'value',
					type			=> 'checkbox',
					name			=> 'fuzzy',
					value			=> 1,
					descr			=> '', 
					checked		=> ((defined $q->param('fuzzy')) ? 1 : 0),
				}
			]
		},
		{
			elements	=> [
				{
					target	=> 'key',
					type		=> 'label',
					value		=> _gettext("Status"),
				},
				{
					target		=> 'value',
					type			=> 'popupMenu',
					name			=> 'state',
					size			=> 1,
					values		=> $stats,
					selected	=> [$state],
				}
			]
		},
		{
			elements	=> [
				{
					target	=> 'key',
					type		=> 'label',
					value		=> _gettext("Type"),
				},
				{
					target		=> 'value',
					type			=> 'popupMenu',
					name			=> 'tmplID',
					size			=> 1,
					values		=> $types,
					selected	=> $tmplID,
					onChange	=> 'javascript:document.getElementById("chTmplID").value=1;submit()',
					colspan		=> 2,
				}
			]
		},
	];

	if ($tmplID) {
		push @{$t->{V}->{searchMenu}}, (
			{
				value	=> {
					type		=> 'hline',
					colspan	=> 2,
				}
			},
		);
		(my $menu, undef)	= &getTemplateEntries($tmplID, 1, 0, 0, 1, 1);
		push @{$t->{V}->{searchMenu}}, @{$menu};
	}

	push @{$t->{V}->{searchMenu}}, (
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
					buttons	=> [
						{
							name	=> 'searchButton',
							type	=> 'submit',
							value	=> _gettext("Search"),
							img		=> 'search_small.png',
						},
					]
				}
			]
		}
	);

	push @{$t->{V}->{searchHiddens}}, (
		{
			name	=> 'func',
			value	=> 'search'
		},
		{
			name	=> 'chTmplID',
			value	=> 0
		},
	);
}

sub mkShowTemplates {
	warn 'SUB: ' . (caller(0))[3] . ' (' . (caller(1))[3] . ")\n" if $conf->{var}->{showsubs};
	my $t	= $HaCi::GUI::init::t;
	my $q	= $HaCi::HaCi::q;

	my $netTypes	= &getNetworkTypes();
	$t->{V}->{newTemplateHeader}		= _gettext("New Template");
	$t->{V}->{newTemplateFormName}	= 'newTemplate';
	$t->{V}->{newTemplateMenu}			=	[
		{	
			elements	=> [
				{
					target	=> 'single',
					type		=> 'label',
					value		=> _gettext("Name"),
				},
				{
					target		=> 'single',
					type			=> 'textfield',
					name			=> 'tmplName',
					size			=> 20,
					maxlength	=> 255,
				},
				{
					target	=> 'single',
					type		=> 'buttons',
					buttons	=> [
						{
							name	=> 'newTmpl',
							type	=> 'submit',
							value	=> _gettext("New"),
							img		=> 'add-template_small.png',
						},
					]
				}
			],
		},
	];

	$t->{V}->{newTemplateHiddens}	= [
		{
			name	=> 'tmplType',
			value	=> 'Nettype'
		},
	];

	$t->{V}->{netTypeTemplatesHeader}		= _gettext("Templates");
	$t->{V}->{netTypeTemplatesFormName}	= 'netTypeTmpl';
	$t->{V}->{netTypeTemplatesMenu}			=	[
		{
			elements	=> [
				{
					target		=> 'single',
					type			=> 'popupMenu',
					name			=> 'tmplID',
					size			=> 1,
					values		=> $netTypes,
					colspan		=> 3,
					align			=> 'center',
				},
			],
		},
		{
			value	=> {
				type		=> 'hline',
				colspan	=> 1,
			}
		},
		{
			elements	=> [
				{
					target	=> 'single',
					type		=> 'buttons',
					colspan	=> 3,
					align		=> 'center',
					buttons	=> [
						{
							name	=> 'editNetTypeTmpl',
							type	=> 'submit',
							value	=> _gettext("Edit"),
							img		=> 'edit_small.png',
						},
						{
							name	=> 'delTmpl',
							type	=> 'submit',
							value	=> _gettext("Delete"),
							img		=> 'del_small.png',
						},
					],
				},
			],
		}
	];

	$t->{V}->{netTypeTemplatesHiddens}	= [
		{
			name	=> 'tmplType',
			value	=> 'Nettype'
		},
	];
}

sub mkEditTemplate {
	warn 'SUB: ' . (caller(0))[3] . ' (' . (caller(1))[3] . ")\n" if $conf->{var}->{showsubs};
	my $t					= $HaCi::GUI::init::t;
	my $q					= $HaCi::HaCi::q;
	my $tmplID		= (defined $q->param('tmplID')) ? $q->param('tmplID') : undef;
	my $tmplName	= (defined $q->param('tmplName') && $q->param('tmplName')) ? $q->param('tmplName') : &tmplID2Name($tmplID);
	my $tmpl			= &getTemplate($tmplID);
	my $types			= [
		{ID	=> 0, name	=> _gettext('HLine')},
		{ID	=> 1, name	=> _gettext('Textfield')},
		{ID	=> 2, name	=> _gettext('Textarea')},
		{ID	=> 3, name	=> _gettext('Popup-Menu')},
		{ID	=> 4, name	=> _gettext('Text')},
	];
	$t->{V}->{maxPositions}	= $tmpl->{MaxPosition};

	$t->{V}->{templateHeader}	= ((defined $q->param('newTmpl')) ? (_gettext("New")) : '') . sprintf(_gettext("Template '<b>%s</b>' for '<b>%s</b>'"), $tmplName, _gettext($q->param('tmplType') || ''));
	$t->{V}->{templateMenu}		=	[
		{
			elements	=> [
				{
					target	=> 'key',
					type		=> 'label',
					value		=> _gettext("Created from"),
				},
				{
					target		=> 'value',
					type			=> 'label',
					value			=> $tmpl->{createFrom},
				}
			]
		},
		{
			elements	=> [
				{
					target	=> 'key',
					type		=> 'label',
					value		=> _gettext("Created on"),
				},
				{
					target		=> 'value',
					type			=> 'label',
					value			=> $tmpl->{createDate},
				}
			]
		},
		{
			elements	=> [
				{
					target	=> 'key',
					type		=> 'label',
					value		=> _gettext("Modified by"),
				},
				{
					target		=> 'value',
					type			=> 'label',
					value			=> $tmpl->{modifyFrom},
				}
			]
		},
		{
			elements	=> [
				{
					target	=> 'key',
					type		=> 'label',
					value		=> _gettext("Modified on"),
				},
				{
					target		=> 'value',
					type			=> 'label',
					value			=> $tmpl->{modifyDate},
				}
			]
		},
	];
	
	$t->{V}->{editTemplateFormName}	= 'editTmpl';
	$t->{V}->{gettext_Templates}		= _gettext("Templates");
	$t->{V}->{editTemplateHeader}		= _gettext("Structure");
	$t->{V}->{editTemplateMenu}		=	[
		{
			elements	=> [
				{
					target		=> 'key',
					type			=> 'label',
					value			=> _gettext("Position"),
				},
				{
					target		=> 'value',
					type			=> 'popupMenu',
					name			=> 'position',
					size			=> 1,
					values		=> $tmpl->{Positions},
					onChange	=> "javacsript:chkTmplPosition($tmpl->{MaxPosition});updTmplParamsFromPreview()",
				},
			],
		},
		{
			elements	=> [
				{
					target	=> 'key',
					type		=> 'label',
					value		=> _gettext("Type"),
				},
				{
					target		=> 'value',
					type			=> 'popupMenu',
					name			=> 'TmplEntryType',
					size			=> 1,
					values		=> $types,
					onChange	=> 'javacsript:updTmplParams();',
				},
			],
		},
		{
			value	=> {
				type	=> 'hline',
				colspan	=> 2,
			}
		},
		{
			elements	=> [
				{
					target	=> 'single',
					type		=> 'buttons',
					colspan	=> 2,
					align		=> 'center',
					buttons	=> [
						{
							name	=> 'submitAddTmplEntry',
							type	=> 'submit',
							value	=> _gettext("Add"),
							img		=> 'submit_small.png',
						},
						{
							name	=> 'submitEditTmplEntry',
							type	=> 'submit',
							value	=> _gettext("Replace"),
							img		=> 'replace_small.png',
						},
						{
							name	=> 'submitDeleteTmplEntry',
							type	=> 'submit',
							value	=> _gettext("Delete"),
							img		=> 'del_small.png',
						},
						{
							name	=> 'abortEditTmpl',
							type	=> 'submit',
							value	=> _gettext("Back"),
							img		=> 'back_small.png',
						},
					],
				},
			],
		}
	];

	$t->{V}->{editTemplateHiddens}	= [
		{
			name	=> 'tmplName',
			value	=> $q->param('tmplName') || '',
		},
		{
			name	=> 'tmplType', 
			value	=> $q->param('tmplType') || '',
		},
		{
			name	=> 'tmplEntryID',
			value	=> ''
		},
	];

	push @{$t->{V}->{editTemplateHiddens}}, (
		{
			name	=> 'tmplID',
			value	=> $q->param('tmplID')
		},
	) if defined $tmplID;

	$t->{V}->{editTemplateEntryHeader}		= _gettext("Parameters");
	$t->{V}->{editTemplateEntryMenu}			=	[
		{
			elements	=> [
				{
					target	=> 'key',
					type		=> 'label',
					value		=> _gettext("Description"),
				},
				{
					target		=> 'value',
					type			=> 'textfield',
					name			=> 'TmplEntryParamDescr',
					size			=> 20,
					maxlength	=> 255,
				},
			],
		},
		{
			elements	=> [
				{
					target	=> 'key',
					type		=> 'label',
					value		=> _gettext("Size"),
				},
				{
					target		=> 'value',
					type			=> 'textfield',
					name			=> 'TmplEntryParamSize',
					size			=> 3,
					maxlength	=> 3,
				},
			],
		},
		{
			elements	=> [
				{
					target	=> 'key',
					type		=> 'label',
					value		=> _gettext("Entries (separated with semicolons)"),
				},
				{
					target		=> 'value',
					type			=> 'textfield',
					name			=> 'TmplEntryParamEntries',
					size			=> 20,
					maxlength	=> 255,
				},
			],
		},
		{
			elements	=> [
				{
					target	=> 'key',
					type		=> 'label',
					value		=> _gettext("Rows"),
				},
				{
					target		=> 'value',
					type			=> 'textfield',
					name			=> 'TmplEntryParamRows',
					size			=> 3,
					maxlength	=> 3,
				},
			],
		},
		{
			elements	=> [
				{
					target	=> 'key',
					type		=> 'label',
					value		=> _gettext("Columns"),
				},
				{
					target		=> 'value',
					type			=> 'textfield',
					name			=> 'TmplEntryParamCols',
					size			=> 3,
					maxlength	=> 3,
				},
			],
		}
	];

	$t->{V}->{templatePreviewHeader}		= _gettext("Preview");
	($t->{V}->{templatePreviewMenu}, $t->{V}->{templatePreviewHiddens})	=	&getTemplateEntries($q->param('tmplID'), 0, 1, 0, 0, 1);
}

sub mkDelTmpl {
	warn 'SUB: ' . (caller(0))[3] . ' (' . (caller(1))[3] . ")\n" if $conf->{var}->{showsubs};
	my $t						= $HaCi::GUI::init::t;
	my $q						= $HaCi::HaCi::q;
	my $tmplID			= $q->param('tmplID');
	my $tmplName		= &tmplID2Name($tmplID);

	$t->{V}->{delTmplHeader}		= sprintf(_gettext("Do you really want to delete the Template <b>%s</b>?"), $tmplName);
	$t->{V}->{delTmplFormName}	= 'delTmpl';
	$t->{V}->{delTmplMenu}			= [
		{
			elements	=> [
				{
					target	=> 'single',
					type		=> 'buttons',
					buttons	=> [
						{
							name	=> 'commitDelTmpl',
							type	=> 'submit',
							value	=> _gettext("Delete"),
						},
						{
							name	=> 'abortDelTmpl',
							type	=> 'submit',
							value	=> _gettext("Abort"),
						},
					],
				},
			],
		}
	];

	$t->{V}->{delTmplHiddens}	= [
		{
			name	=> 'delTmpl',
			value	=> '1'
		},
		{
			name	=> 'tmplID',
			value	=> $tmplID
		},
	];
}

sub mkShowGroups {
	warn 'SUB: ' . (caller(0))[3] . ' (' . (caller(1))[3] . ")\n" if $conf->{var}->{showsubs};
	my $t	= $HaCi::GUI::init::t;
	my $q	= $HaCi::HaCi::q;

	my $groups	= &getGroups();
	$t->{V}->{newGroupHeader}		= _gettext("New Group");
	$t->{V}->{newGroupFormName}	= 'showGroup';
	$t->{V}->{newGroupMenu}			=	[
		{	
			elements	=> [
				{
					target	=> 'single',
					type		=> 'label',
					value		=> _gettext("Name"),
				},
				{
					target		=> 'single',
					type			=> 'textfield',
					name			=> 'groupName',
					size			=> 20,
					maxlength	=> 255,
				},
				{
					target	=> 'single',
					type		=> 'buttons',
					buttons	=> [
						{
							name	=> 'newGroup',
							type	=> 'submit',
							value	=> _gettext("New"),
							img		=> 'add-group_small.png',
						},
					]
				}
			],
		},
	];

	$t->{V}->{showGroupsHeader}		= _gettext("Groups");
	$t->{V}->{showGroupsFormName}	= 'newGroup';
	$t->{V}->{showGroupsMenu}			=	[
		{
			elements	=> [
				{
					target		=> 'single',
					type			=> 'popupMenu',
					name			=> 'groupID',
					size			=> 1,
					values		=> $groups,
					colspan		=> 3,
					align			=> 'center',
				},
			],
		},
		{
			value	=> {
				type		=> 'hline',
				colspan	=> 1,
			}
		},
		{
			elements	=> [
				{
					target	=> 'single',
					type		=> 'buttons',
					colspan	=> 3,
					align		=> 'center',
					buttons	=> [
						{
							name	=> 'editGroup',
							type	=> 'submit',
							value	=> _gettext("Edit"),
							img		=> 'edit_small.png',
						},
						{
							name	=> 'delGroup',
							type	=> 'submit',
							value	=> _gettext("Delete"),
							img		=> 'del_small.png',
						},
					],
				},
			],
		}
	];

}


sub mkEditGroup {
	warn 'SUB: ' . (caller(0))[3] . ' (' . (caller(1))[3] . ")\n" if $conf->{var}->{showsubs};
	my $t					= $HaCi::GUI::init::t;
	my $q					= $HaCi::HaCi::q;
	my $groupID		= (defined $q->param('groupID')) ? $q->param('groupID') : undef;
	my $groupName	= (defined $q->param('groupName') && $q->param('groupName')) ? $q->param('groupName') : &groupID2Name($groupID);
	my $group			= &getGroup($groupID);
	my $bAdmin		= 1 if $groupName eq 'Administrator';

	if (defined $q->param('editGroup')) {
		if (defined $groupID) {
			my $groupTable	= $conf->{var}->{TABLES}->{group};
			unless (defined $groupTable) {
				warn "Cannot Edit Group. DB Error\n";
				return 0;
			}
			my $group	= ($groupTable->search(['*'], {ID => $groupID}))[0];
			$q->delete('groupDescr'); $q->param('groupDescr', $group->{description});
			my $cnter			= 0;
			my $cryptStr	= substr($group->{permissions}, 1, length($group->{permissions}) - 1);
			my $permStr		= &dec2bin(&lwd($cryptStr));
			foreach (split//, substr($permStr, 1, length($permStr) - 1)) {
				if ($_ || $bAdmin) {
					$q->delete('groupPerm_' . $cnter); $q->param('groupPerm_' . $cnter, 1);
				}
				$cnter++;
			}
		}
	}

	my $groupDescr							= ((defined $q->param('groupDescr')) ? $q->param('groupDescr') : '');
	$groupDescr									=~ s/"/&#34;/g;
	$t->{V}->{editGroupHeader}	= ((defined $q->param('newGroup')) ? (_gettext("New ")) : '') . sprintf(_gettext("Group '<b>%s</b>'"), $groupName);
	$t->{V}->{editGroupMenu}		=	[
		{
			elements	=> [
				{
					target	=> 'key',
					type		=> 'label',
					value		=> _gettext("Name"),
				},
				{
					target		=> 'value',
					type			=> 'label',
					value			=> $groupName
				}
			]
		},
		{
			elements	=> [
				{
					target	=> 'key',
					type		=> 'label',
					value		=> _gettext("Description"),
				},
				{
					target		=> 'value',
					type			=> 'textfield',
					name			=> 'groupDescr',
					size			=> 25,
					maxlength	=> 255,
					value			=> $groupDescr,
				},
			],
		},
		{
			value	=> {
				type		=> 'hline',
				colspan	=> 2,
			}
		},
		{
			elements	=> [
				{
					target	=> 'key',
					type		=> 'label',
					value		=> _gettext("Created from"),
				},
				{
					target		=> 'value',
					type			=> 'label',
					value			=> $group->{createFrom},
				}
			]
		},
		{
			elements	=> [
				{
					target	=> 'key',
					type		=> 'label',
					value		=> _gettext("Created on"),
				},
				{
					target		=> 'value',
					type			=> 'label',
					value			=> $group->{createDate},
				}
			]
		},
		{
			elements	=> [
				{
					target	=> 'key',
					type		=> 'label',
					value		=> _gettext("Modified by"),
				},
				{
					target		=> 'value',
					type			=> 'label',
					value			=> $group->{modifyFrom},
				}
			]
		},
		{
			elements	=> [
				{
					target	=> 'key',
					type		=> 'label',
					value		=> _gettext("Modified on"),
				},
				{
					target		=> 'value',
					type			=> 'label',
					value			=> $group->{modifyDate},
				}
			]
		},
	];

	$t->{V}->{editGroupPermHeader}	= _gettext("Permissions");
	my $rightsSort	= {};
	foreach (keys %{$conf->{static}->{rights}}) {
		$rightsSort->{$conf->{static}->{rights}->{$_}->{order}}	= $_;
	}
	foreach (sort {$a<=>$b} keys %{$rightsSort}) {
		my $cnter	= $rightsSort->{$_};
		push @{$t->{V}->{editGroupPermMenu}}, (
			{
				elements	=> [
					{
						target		=> 'single',
						type			=> 'checkbox',
						name			=> 'groupPerm_' . $cnter,
						value			=> 1,
						descr			=> ' ' . _gettext($conf->{static}->{rights}->{$cnter}->{long}),
						checked		=> (defined $q->param('groupPerm_' . $cnter)) ? $q->param('groupPerm_' . $cnter) : 0,
						disabled	=> ($bAdmin) ? 1 : 0,
					}
				]
			},
		)
	};

	$t->{V}->{editGroupButtonsMenu}	=	[
		{
			elements	=> [
				{
					target	=> 'single',
					type		=> 'buttons',
					buttons	=> [
						{
							name	=> 'submitEditGroup',
							type	=> 'submit',
							value	=> _gettext("Submit"),
							img		=> 'submit_small.png',
						},
						{
							name	=> 'abortEditGroup',
							type	=> 'submit',
							value	=> _gettext("Abort"),
							img		=> 'cancel_small.png',
						},
					],
				},
			],
		}
	];

	$t->{V}->{editGroupHiddens}	= [
		{
			name	=> 'groupName',
			value	=> $groupName
		},
	];
	push @{$t->{V}->{editGroupHiddens}}, (
		{
			name	=> 'groupID',
			value	=> $q->param('groupID')
		},
	) if defined $groupID;
}

sub mkDelGroup {
	warn 'SUB: ' . (caller(0))[3] . ' (' . (caller(1))[3] . ")\n" if $conf->{var}->{showsubs};
	my $t						= $HaCi::GUI::init::t;
	my $q						= $HaCi::HaCi::q;
	my $groupID			= $q->param('groupID');
	my $groupName		= &groupID2Name($groupID);

	$t->{V}->{delGroupHeader}		= sprintf(_gettext("Do you really want to delete the Group <b>%s</b>?"), $groupName);
	$t->{V}->{delGroupFormName}	= 'delGroup';
	$t->{V}->{delGroupMenu}			= [
		{
			elements	=> [
				{
					target	=> 'single',
					type		=> 'buttons',
					buttons	=> [
						{
							name	=> 'commitDelGroup',
							type	=> 'submit',
							value	=> _gettext("Delete"),
							img		=> 'del_small.png',
						},
						{
							name	=> 'abortDelGroup',
							type	=> 'submit',
							value	=> _gettext("Abort"),
							img		=> 'cancel_small.png',
						},
					],
				},
			],
		}
	];

	$t->{V}->{delGroupHiddens}	= [
		{
			name	=> 'delGroup',
			value	=> '1'
		},
		{
			name	=> 'groupID',
			value	=> $groupID
		},
	];
}

sub mkDelUser {
	warn 'SUB: ' . (caller(0))[3] . ' (' . (caller(1))[3] . ")\n" if $conf->{var}->{showsubs};
	my $t						= $HaCi::GUI::init::t;
	my $q						= $HaCi::HaCi::q;
	my $userID			= $q->param('userID');
	my $userName		= &userID2Name($userID);

	$t->{V}->{delUserHeader}		= sprintf(_gettext("Do you really want to delete the User <b>%s</b>?"), $userName);
	$t->{V}->{delUserFormName}	= 'delUser';
	$t->{V}->{delUserMenu}			= [
		{
			elements	=> [
				{
					target	=> 'single',
					type		=> 'buttons',
					buttons	=> [
						{
							name	=> 'commitDelUser',
							type	=> 'submit',
							value	=> _gettext("Delete"),
							img		=> 'del_small.png',
						},
						{
							name	=> 'abortDelUser',
							type	=> 'submit',
							value	=> _gettext("Abort"),
							img		=> 'cancel_small.png',
						},
					],
				},
			],
		}
	];

	$t->{V}->{delUserHiddens}	= [
		{
			name	=> 'delUser',
			value	=> '1'
		},
		{
			name	=> 'userID',
			value	=> $userID
		},
	];
}

sub mkShowUsers {
	warn 'SUB: ' . (caller(0))[3] . ' (' . (caller(1))[3] . ")\n" if $conf->{var}->{showsubs};
	my $t	= $HaCi::GUI::init::t;
	my $q	= $HaCi::HaCi::q;

	my $users		= &getUsers();

	$t->{V}->{newUserHeader}		= _gettext("New User");
	$t->{V}->{newUserFormName}	= 'newUser';
	$t->{V}->{newUserMenu}			=	[
		{	
			elements	=> [
				{
					target	=> 'single',
					type		=> 'label',
					value		=> _gettext("Name"),
				},
				{
					target		=> 'single',
					type			=> 'textfield',
					name			=> 'userName',
					size			=> 20,
					maxlength	=> 255,
				},
				{
					target	=> 'single',
					type		=> 'buttons',
					buttons	=> [
						{
							name	=> 'newUser',
							type	=> 'submit',
							value	=> _gettext("New"),
							img		=> 'add-user_small.png',
						},
					]
				}
			],
		},
	];

	$t->{V}->{showUsersHeader}		= _gettext("Users");
	$t->{V}->{showUsersFormName}	= 'showUsers';
	$t->{V}->{showUsersMenu}			=	[
		{
			elements	=> [
				{
					target		=> 'single',
					type			=> 'popupMenu',
					name			=> 'userID',
					size			=> 1,
					values		=> $users,
					colspan		=> 3,
					align			=> 'center',
				},
			],
		},
		{
			value	=> {
				type		=> 'hline',
				colspan	=> 1,
			}
		},
		{
			elements	=> [
				{
					target	=> 'single',
					type		=> 'buttons',
					buttons	=> [
						{
							name	=> 'editUser',
							type	=> 'submit',
							value	=> _gettext("Edit"),
							img		=> 'edit_small.png',
						},
						{
							name	=> 'delUser',
							type	=> 'submit',
							value	=> _gettext("Delete"),
							img		=> 'del_small.png',
						},
					],
				},
			],
		}
	];
}

sub mkEditUser {
	warn 'SUB: ' . (caller(0))[3] . ' (' . (caller(1))[3] . ")\n" if $conf->{var}->{showsubs};
	my $t					= $HaCi::GUI::init::t;
	my $q					= $HaCi::HaCi::q;
	my $userID		= (defined $q->param('userID')) ? $q->param('userID') : undef;
	my $userName	= (defined $q->param('userName') && $q->param('userName')) ? $q->param('userName') : &userID2Name($userID);
	my $user			= &getUser($userID);
	my $groups		= {};
	foreach (@{&getGroups()}) {
		$groups->{$_->{ID}}	= $_->{name};
	}

	if (defined $q->param('editUser')) {
		my $userTable	= $conf->{var}->{TABLES}->{user};
		unless (defined $userTable) {
			warn "Cannot Edit User. DB Error\n";
			return 0;
		}
		my $user	= ($userTable->search(['*'], {ID => $userID}))[0];
		$q->delete('userDescr'); $q->param('userDescr', $user->{description});
		foreach (split(/, /, $user->{groupIDs})) {
			s/\D//g;
			$q->delete('userGroup_' . $_); $q->param('userGroup_' . $_, 1);
		}
	}

	my $userDescr							= ((defined $q->param('userDescr')) ? $q->param('userDescr') : '');
	$userDescr								=~ s/"/&#34;/g;
	$t->{V}->{gettext_userpassword}	= _gettext("Password is only for buildin 'HaCi' authentication!");
	$t->{V}->{editUserHeader}				= ((defined $q->param('newUser')) ? (_gettext("New ")) : '') . sprintf(_gettext("User '<b>%s</b>'"), $userName);
	$t->{V}->{editUserMenu}					=	[
		{
			elements	=> [
				{
					target	=> 'key',
					type		=> 'label',
					value		=> _gettext("Name"),
				},
				{
					target		=> 'value',
					type			=> 'label',
					value			=> $userName
				}
			]
		},
		{
			elements	=> [
				{
					target	=> 'key',
					type		=> 'label',
					value		=> _gettext("Password"),
				},
				{
					target		=> 'value',
					type			=> 'passwordfield',
					name			=> 'password1',
					size			=> 25,
					maxlength	=> 255,
				},
			],
		},
		{
			elements	=> [
				{
					target	=> 'key',
					type		=> 'label',
					value		=> _gettext("Password Validation"),
				},
				{
					target		=> 'value',
					type			=> 'passwordfield',
					name			=> 'password2',
					size			=> 25,
					maxlength	=> 255,
				},
			],
		},
		{
			elements	=> [
				{
					target	=> 'key',
					type		=> 'label',
					value		=> _gettext("Description"),
				},
				{
					target		=> 'value',
					type			=> 'textfield',
					name			=> 'userDescr',
					size			=> 25,
					maxlength	=> 255,
					value			=> $userDescr
				},
			],
		},
		{
			value	=> {
				type		=> 'hline',
				colspan	=> 2,
			}
		},
		{
			elements	=> [
				{
					target	=> 'key',
					type		=> 'label',
					value		=> _gettext("Created from"),
				},
				{
					target		=> 'value',
					type			=> 'label',
					value			=> $user->{createFrom},
				}
			]
		},
		{
			elements	=> [
				{
					target	=> 'key',
					type		=> 'label',
					value		=> _gettext("Created on"),
				},
				{
					target		=> 'value',
					type			=> 'label',
					value			=> $user->{createDate},
				}
			]
		},
		{
			elements	=> [
				{
					target	=> 'key',
					type		=> 'label',
					value		=> _gettext("Modified by"),
				},
				{
					target		=> 'value',
					type			=> 'label',
					value			=> $user->{modifyFrom},
				}
			]
		},
		{
			elements	=> [
				{
					target	=> 'key',
					type		=> 'label',
					value		=> _gettext("Modified on"),
				},
				{
					target		=> 'value',
					type			=> 'label',
					value			=> $user->{modifyDate},
				}
			]
		},
	];

	$t->{V}->{editUserGroupsHeader}	= _gettext("Group Association");
	foreach (sort {$a<=>$b} keys %{$groups}) {
		push @{$t->{V}->{editUserGroupsMenu}}, (
			{
				elements	=> [
					{
						target		=> 'single',
						type			=> 'checkbox',
						name			=> 'userGroup_' . $_,
						value			=> 1,
						descr			=> ' ' . $groups->{$_},
						checked		=> (defined $q->param('userGroup_' . $_)) ? $q->param('userGroup_' . $_) : 0,
					}
				]
			},
		)
	};

	$t->{V}->{editUserButtonsMenu}	=	[
		{
			elements	=> [
				{
					target	=> 'single',
					type		=> 'buttons',
					buttons	=> [
						{
							name	=> 'submitEditUser',
							type	=> 'submit',
							value	=> _gettext("Submit"),
							img		=> 'submit_small.png',
						},
						{
							name	=> 'abortEditUser',
							type	=> 'submit',
							value	=> _gettext("Abort"),
							img		=> 'cancel_small.png',
						},
					],
				},
			],
		}
	];

	$t->{V}->{editUserHiddens}	= [
		{
			name	=> 'userName',
			value	=> $userName
		},
	];

	push @{$t->{V}->{editUserHiddens}}, (
		{
			name	=> 'userID',
			value	=> $q->param('userID')
		},
	) if defined $userID;
}

sub mkImportDNS {
	warn 'SUB: ' . (caller(0))[3] . ' (' . (caller(1))[3] . ")\n" if $conf->{var}->{showsubs};
	my $t				= $HaCi::GUI::init::t;
	my $q				= $HaCi::HaCi::q;
	my $stats		= $conf->{static}->{misc}->{networkstates};
	my $roots		= &getRoots();
	unshift @{$roots}, {ID => -1, name => '[' . _gettext('NEW') . ']'};
	map {my $h=$_;$h->{name} = &quoteHTML($h->{name}); $_ = $h;} @{$roots};

	map {$_->{ID}	= $_->{id}} @{$stats};

	$t->{V}->{importDNSHeader}				= _gettext("Import from DNS Zonefiles");
	$t->{V}->{importDNSTransHeader}		= _gettext("Zonefile Transfer");
	$t->{V}->{importDNSTransFormName}	= 'importDNSTrans';
	$t->{V}->{importDNSTransMenu}			= [
		{
			elements	=> [
				{
					target	=> 'key',
					type		=> 'label',
					value		=> _gettext("Nameserver"),
				},
				{
					target		=> 'value',
					type			=> 'textfield',
					name			=> 'nameserver',
					size			=> 15,
					maxlength	=> 256,
					value			=> ((defined $q->param('nameserver')) ? $q->param('nameserver') : ''),
					focus			=> 1,
				}
			]
		},
		{
			elements	=> [
				{
					target	=> 'key',
					type		=> 'label',
					value		=> _gettext("Domain"),
				},
				{
					target		=> 'value',
					type			=> 'textfield',
					name			=> 'domain',
					size			=> 10,
					maxlength	=> 256,
					value			=> ((defined $q->param('domain')) ? $q->param('domain') : ''),
					focus			=> 1,
				}
			]
		},
		{
			elements	=> [
				{
					target	=> 'key',
					type		=> 'label',
					value		=> _gettext("Target Root"),
				},
				{
					target		=> 'value',
					type			=> 'popupMenu',
					name			=> 'targetRoot',
					size			=> 1,
					values		=> $roots,
					selected	=> ((defined $q->param('targetRoot')) ? [$q->param('targetRoot')] : []),
				},
			]
		},
		{
			elements	=> [
				{
					target	=> 'key',
					type		=> 'label',
					value		=> _gettext("Status"),
				},
				{
					target		=> 'value',
					type			=> 'popupMenu',
					name			=> 'state',
					size			=> 1,
					values		=> $stats,
					selected	=> ((defined $q->param('state')) ? [$q->param('state')] : []),
				}
			]
		},
	];

	$t->{V}->{importDNSTransButtons}	= [
		{
			elements	=> [
				{
					target	=> 'single',
					type		=> 'buttons',
					buttons	=> [
						{
							name		=> 'submitImpDNSTrans',
							type		=> 'submit',
							value		=> _gettext("Start"),
							onClick	=> "showStatus(1);",
							img			=> 'submit_small.png',
						},
					],
				},
				{
					type		=> 'buttons',
					target	=> 'single',
					buttons	=> [
						{
							name	=> 'abortImpDNSTrans',
							type	=> 'submit',
							value	=> _gettext("Back"),
							img		=> 'back_small.png',
						},
					],
				}
			],
		}
	];


	$t->{V}->{importDNSLocalHeader}		= _gettext("Local Zonefile");
	$t->{V}->{importDNSLocalFormName}	= 'importDNSLocal';
	$t->{V}->{importDNSLocalFormType}	= 'multipart/form-data';
	$t->{V}->{importDNSLocalMenu}			= [
		{
			elements	=> [
				{
					target	=> 'key',
					type		=> 'label',
					value		=> _gettext("Zonefile"),
				},
				{
					target		=> 'value',
					type			=> 'file',
					name			=> 'zonefile',
					size			=> 25,
					maxlength	=> 64000,
					value			=> ((defined $q->param('domain')) ? $q->param('domain') : ''),
					focus			=> 1,
				}
			]
		},
		{
			elements	=> [
				{
					target	=> 'key',
					type		=> 'label',
					value		=> _gettext("Origin (optional)"),
				},
				{
					target		=> 'single',
					type			=> 'textfield',
					name			=> 'origin',
					size			=> 25,
					maxlength	=> 255,
					value			=> ((defined $q->param('origin')) ? $q->param('origin') : ''),
				},
			]
		},
		{
			elements	=> [
				{
					target	=> 'key',
					type		=> 'label',
					value		=> _gettext("Target Root"),
				},
				{
					target		=> 'value',
					type			=> 'popupMenu',
					name			=> 'targetRoot',
					size			=> 1,
					values		=> $roots,
					selected	=> ((defined $q->param('targetRoot')) ? [$q->param('targetRoot')] : []),
				},
			]
		},
		{
			elements	=> [
				{
					target	=> 'key',
					type		=> 'label',
					value		=> _gettext("Status"),
				},
				{
					target		=> 'value',
					type			=> 'popupMenu',
					name			=> 'state',
					size			=> 1,
					values		=> $stats,
					selected	=> ((defined $q->param('state')) ? [$q->param('state')] : []),
				}
			]
		},
	];

	$t->{V}->{importDNSLocalButtons}	= [
		{
			elements	=> [
				{
					type		=> 'buttons',
					target	=> 'single',
					buttons	=> [
						{
							name		=> 'submitImpDNSLocal',
							type		=> 'submit',
							value		=> _gettext("Start"),
							onClick	=> "showStatus(1);",
							img			=> 'submit_small.png',
						},
					],
				},
				{
					type		=> 'buttons',
					target	=> 'single',
					buttons	=> [
						{
							name	=> 'abortImpDNSLocal',
							type	=> 'submit',
							value	=> _gettext("Back"),
							img		=> 'back_small.png',
						},
					],
				}
			]
		},
	];
}

sub mkImportConfig {
	warn 'SUB: ' . (caller(0))[3] . ' (' . (caller(1))[3] . ")\n" if $conf->{var}->{showsubs};
	my $t				= $HaCi::GUI::init::t;
	my $q				= $HaCi::HaCi::q;
	my $stats		= $conf->{static}->{misc}->{networkstates};
	my $roots		= &getRoots();
	unshift @{$roots}, {ID => -1, name => '[' . _gettext('NEW') . ']'};
	my $sources	= [
		{ID => 'cisco', name => 'cisco'},
		{ID => 'juniper', name => 'juniper'},
		{ID => 'foundry', name => 'foundry'},
		{ID => 'csv', name => 'csv'},
	];

	map {$_->{ID}	= $_->{id}} @{$stats};

	$t->{V}->{importConfigHeader}		= _gettext("Import from Config File");
	$t->{V}->{importConfigFormName}	= 'importConfig';
	$t->{V}->{importConfigFormType}	= 'multipart/form-data';
	$t->{V}->{importConfigMenu}			= [
		{
			elements	=> [
				{
					target	=> 'key',
					type		=> 'label',
					value		=> _gettext("Config"),
				},
				{
					target		=> 'value',
					type			=> 'file',
					name			=> 'config',
					size			=> 25,
					maxlength	=> 64000,
					value			=> ((defined $q->param('config')) ? $q->param('config') : ''),
					focus			=> 1,
				}
			]
		},
		{
			elements	=> [
				{
					target	=> 'key',
					type		=> 'label',
					value		=> _gettext("Source"),
				},
				{
					target		=> 'value',
					type			=> 'popupMenu',
					name			=> 'source',
					size			=> 1,
					values		=> $sources,
					selected	=> ((defined $q->param('source')) ? [$q->param('source')] : []),
				}
			]
		},
		{
			elements	=> [
				{
					target	=> 'key',
					type		=> 'label',
					value		=> _gettext("Status"),
				},
				{
					target		=> 'value',
					type			=> 'popupMenu',
					name			=> 'state',
					size			=> 1,
					values		=> $stats,
					selected	=> ((defined $q->param('state')) ? [$q->param('state')] : []),
				}
			]
		},
		{
			elements	=> [
				{
					target	=> 'key',
					type		=> 'label',
					value		=> _gettext("Target Root"),
				},
				{
					target		=> 'value',
					type			=> 'popupMenu',
					name			=> 'targetRoot',
					size			=> 1,
					values		=> $roots,
					selected	=> ((defined $q->param('targetRoot')) ? [$q->param('targetRoot')] : []),
				},
			]
		},
	];

	$t->{V}->{importConfigButtons}	= [
		{
			elements	=> [
				{
					type		=> 'buttons',
					target	=> 'single',
					align		=> 'center',
					colspan	=> 2,
					buttons	=> [
						{
							name		=> 'submitImpConfig',
							type		=> 'submit',
							value		=> _gettext("Start"),
							onClick	=> "showStatus(1);",
							img			=> 'submit_small.png',
						},
					],
				},
				{
					type		=> 'buttons',
					target	=> 'single',
					buttons	=> [
						{
							name	=> 'abortImpConfig',
							type	=> 'submit',
							value	=> _gettext("Back"),
							img		=> 'back_small.png',
						},
					],
				}
			]
		},
	];
}

sub mkImportCSV {
	warn 'SUB: ' . (caller(0))[3] . ' (' . (caller(1))[3] . ")\n" if $conf->{var}->{showsubs};
	my $t					= $HaCi::GUI::init::t;
	my $q					= $HaCi::HaCi::q;
	my $id				= (defined $q->param('configFileID')) ? $q->param('configFileID') : $conf->{var}->{exportID};
	my @data			= &parseCSVConfigfile($id, 1);
	$conf->{var}->{STATUS}->{STATUS}	= 'FINISH'; $conf->{var}->{STATUS}->{PERCENT} = 100; &setStatus();

	my $nrOfCols	= $conf->{var}->{nrOfCols};
	my $netTypes	= &getNetworkTypes(1);
	my $descrs		= (defined $q->param('tmplID') && $q->param('tmplID')) ? &getTemplateEntries($q->param('tmplID'), 0, 0, 1, 0, 1) : {};
	my @cols			= (
		{ID => 0, name => ''},
		{ID => -1, name => 'network'}, 
		{ID => -2, name => 'status'},
		{ID => -3, name => 'description'},
	);
	foreach (keys %{$descrs}) {
		push @cols, {ID => $_, name => $descrs->{$_}}
	}
	&removeStatus();

	$t->{V}->{csvPreview}					= _gettext("CSV Preview");
	$t->{V}->{gettext_noContent}	= _gettext("Cannot parse any CSV Data");
	$t->{V}->{csvData}						= \@data;
	$t->{V}->{cols}								= \@cols;
	$t->{V}->{nrOfCols}						= $nrOfCols;
	$t->{V}->{noCSVContent}				= 1 if $#data == -1;
	$t->{V}->{importCSVFormName}	= 'importCVSMenu';
	$t->{V}->{importCSVHeader}		= _gettext("Separator");
	$t->{V}->{importCSVMenu}			= [
		{
			elements	=> [
				{
					target		=> 'single',
					type			=> 'textfield',
					name			=> 'sep',
					size			=> 1,
					maxlength	=> 1,
					value			=> ((defined $q->param('sep')) ? $q->param('sep') : ''),
				},
				{
					type		=> 'buttons',
					buttons	=> [
						{
							name	=> 'impCSVChangeSep',
							type	=> 'submit',
							value	=> _gettext("Change"),
							img		=> 'change_small.png',
						},
					],
				}
			]
		},
	];

	$t->{V}->{importCSVTypeHeader}	= _gettext("Nettype");
	$t->{V}->{importCSVTypeMenu}		= [
		{
			elements	=> [
				{
					target		=> 'single',
					type			=> 'popupMenu',
					name			=> 'tmplID',
					size			=> 1,
					values		=> $netTypes,
					selected	=> ((defined $q->param('tmplID')) ? [$q->param('tmplID')] : []),
				},
				{
					type		=> 'buttons',
					buttons	=> [
						{
							name	=> 'impCSVChangeType',
							type	=> 'submit',
							value	=> _gettext("Change"),
							img		=> 'change_small.png',
						},
					],
				}
			]
		},
	];

	$t->{V}->{importCSVButtonMenu}	= [
		{
			elements	=> [
				{
					type		=> 'buttons',
					buttons	=> [
						{
							name		=> 'submitImpCSV',
							type		=> 'submit',
							value		=> _gettext("Import"),
							onClick	=> "showStatus(1);",
							img			=> 'import_small.png',
						},
						{
							name	=> 'abortImpCSV',
							type	=> 'submit',
							value	=> _gettext("Abort"),
							img		=> 'cancel_small.png',
						},
					],
				}
			]
		},
	];
	
	push @{$t->{V}->{importCSVHiddens}}, (
		{
			name	=> 'config',
			value	=> $q->param('config')
		},
		{
			name	=> 'source',
			value	=> $q->param('source')
		},
		{
			name	=> 'state',
			value	=> $q->param('state')
		},
		{
			name	=> 'targetRoot',
			value	=> $q->param('targetRoot')
		},
		{
			name	=> 'configFileID',
			value	=> $id
		},
	) 
}

sub mkCompare {
	warn 'SUB: ' . (caller(0))[3] . ' (' . (caller(1))[3] . ")\n" if $conf->{var}->{showsubs};
	my $t				= $HaCi::GUI::init::t;
	my $q				= $HaCi::HaCi::q;
	my $roots		= &getRoots();
	map {my $h=$_;$h->{name} = &quoteHTML($h->{name}); $_ = $h;} @{$roots};
	&removeStatus();

	$t->{V}->{compareHeader}		= _gettext("Compare");
	$t->{V}->{compareFormName}	= 'compare';
	$t->{V}->{compareMenu}			= [
		{
			elements	=> [
				{
					target	=> 'key',
					type		=> 'label',
					value		=> _gettext("Source"),
				},
				{
					target		=> 'value',
					type			=> 'popupMenu',
					name			=> 'leftRootID',
					size			=> 1,
					values		=> $roots,
					selected	=> ((defined $q->param('leftRootID')) ? [$q->param('leftRootID')] : []),
				},
				{
					target	=> 'key',
					type		=> 'label',
					value		=> _gettext("Target"),
				},
				{
					target		=> 'value',
					type			=> 'popupMenu',
					name			=> 'rightRootID',
					size			=> 1,
					values		=> $roots,
					selected	=> ((defined $q->param('rightRootID')) ? [$q->param('rightRootID')] : []),
				},
				{
					target	=> 'key',
					type		=> 'label',
					value		=> _gettext("Save result under"),
				},
				{
					target		=> 'value',
					type			=> 'textfield',
					name			=> 'resultName',
					size			=> 10,
					maxlength	=> 256,
					value			=> ((defined $q->param('resultName')) ? $q->param('resultName') : ''),
					focus			=> 1,
				},
			]
		}
	];

	$t->{V}->{compareButtons}	= [
		{
			elements	=> [
				{
					type		=> 'buttons',
					target	=> 'single',
					buttons	=> [
						{
							name		=> 'compareButton',
							type		=> 'submit',
							value		=> _gettext("Compare"),
							onClick	=> "showStatus(1);",
							img			=> 'compare_small.png',
						},
					],
				},
				{
					type		=> 'buttons',
					target	=> 'single',
					buttons	=> [
						{
							name	=> 'abortCompareButton',
							type	=> 'submit',
							value	=> _gettext("Back"),
							img		=> 'back_small.png',
						},
					],
				}
			],
		},
	];
}

sub expandNetwork {
	warn 'SUB: ' . (caller(0))[3] . ' (' . (caller(1))[3] . ")\n" if $conf->{var}->{showsubs};
	my $rootID			= shift;
	my $networkDec	= shift;
	my $level				= shift;
	my $bEditTree		= shift;
	my $s						= $HaCi::HaCi::session;
	my $q						= $HaCi::HaCi::q;
	$q->delete('editTree'); $q->param('editTree', $bEditTree);
	$conf->{var}->{STATUS}	= {TITLE => 'Expanding Network...', STATUS => 'Runnung...'}; &setStatus();

	&expand('+', 'network', $networkDec, $rootID);
	$s->param('currNet', $networkDec);
	$s->param('currRootID', $rootID);
	
	my $return	= &genTreeNetwork($rootID, $networkDec, $level);
	$conf->{var}->{STATUS}->{STATUS}	= 'FINISH'; &setStatus();
	return $return;
}

sub genTreeNetwork {
	warn 'SUB: ' . (caller(0))[3] . ' (' . (caller(1))[3] . ")\n" if $conf->{var}->{showsubs};
	my $rootID			= shift;
	my $networkDec	= shift;
	my $level				= shift;
	my $parentOnly	= shift || 0;
	my $t						= $HaCi::GUI::init::t;
	my $tree				= new HaCi::Tree;
	my $ipv6				= &rootID2ipv6($rootID);

	unless ($conf->{var}->{authenticated}) {
		warn "Not Authenticated!\n";
		return _gettext("Not Authenticated!!!");
	}

	$tree->setNewRoot($rootID) if $networkDec;
	$tree->setRootV6($rootID, $ipv6) if $networkDec;
	&mkTreeNetwork(\$tree, $rootID, $ipv6, (($ipv6) ? Math::BigInt->new($networkDec) : $networkDec), 1, $parentOnly);

	$t->{V}->{editTree}	= (defined $HaCi::HaCi::q->param('editTree') && $HaCi::HaCi::q->param('editTree')) ? 1 : 0;
	$t->{V}->{root}			= $tree->print_html_root($rootID) if $networkDec == 0;
	$t->{V}->{networks}	= $tree->print_html_networks($rootID, $level, $networkDec);
	$t->{V}->{page}			= ($networkDec) ? 'treeNetworkTable' : 'treeRootNetworkTable';
	$t->{V}->{noHeader}	= 1;

	my $html_output = '';
	$t->{T}->process($conf->{static}->{path}->{templateinit}, $t->{V}, \$html_output)
		|| die $t->{T}->error();

	return $html_output;
}

sub reduceNetwork {
	warn 'SUB: ' . (caller(0))[3] . ' (' . (caller(1))[3] . ")\n" if $conf->{var}->{showsubs};
	my $rootID			= shift;
	my $networkDec	= shift;
	my $level				= shift;
	my $bEditTree		= shift;
	my $s						= $HaCi::HaCi::session;
	my $q						= $HaCi::HaCi::q;
	$q->delete('editTree'); $q->param('editTree', $bEditTree);

	return _gettext("Not Authenticated!!!") unless $conf->{var}->{authenticated};

	&expand('-', 'network', $networkDec, $rootID);
	$s->param('currNet', $networkDec);
	$s->param('currRootID', $rootID);

	return &genTreeNetwork($rootID, $networkDec, $level, 1);
}

sub expandRoot {
	warn 'SUB: ' . (caller(0))[3] . ' (' . (caller(1))[3] . ")\n" if $conf->{var}->{showsubs};
	my $rootID			= shift;
	my $bEditTree		= shift;
	my $s						= $HaCi::HaCi::session;
	my $q						= $HaCi::HaCi::q;
	$q->delete('editTree'); $q->param('editTree', $bEditTree);

	return _gettext("Not Authenticated!!!") unless $conf->{var}->{authenticated};

	&expand('+', 'root', $rootID);
	$s->param('currNet', '');
	$s->param('currRootID', $rootID);

	return &genTreeNetwork($rootID, 0, 0);
}

sub reduceRoot {
	warn 'SUB: ' . (caller(0))[3] . ' (' . (caller(1))[3] . ")\n" if $conf->{var}->{showsubs};
	my $rootID			= shift;
	my $bEditTree		= shift;
	my $s						= $HaCi::HaCi::session;
	my $q						= $HaCi::HaCi::q;
	$q->delete('editTree'); $q->param('editTree', $bEditTree);

	return _gettext("Not Authenticated!!!") unless $conf->{var}->{authenticated};

	&expand('-', 'root', $rootID);
	$s->param('currNet', '');
	$s->param('currRootID', $rootID);
	
	return &genTreeNetwork($rootID, 0, 0, 1);
}

sub mkSplitNet {
	warn 'SUB: ' . (caller(0))[3] . ' (' . (caller(1))[3] . ")\n" if $conf->{var}->{showsubs};
	my $q										= $HaCi::HaCi::q;
	my $t										= $HaCi::GUI::init::t;
	my $netID								= $q->param('netID');
	return unless defined $netID;
	
	my $types													= &getNetworkTypes(1);
	my $stats													= $conf->{static}->{misc}->{networkstates};
	my ($rootID, $networkDec, $ipv6)	= &netID2Stuff($netID);
	my $network												= ($ipv6) ? &netv6Dec2net($networkDec) : &dec2net($networkDec);
	return unless &checkSpelling_Net($network, $ipv6);

	map {$_->{ID} = $_->{id}} @{$stats};

	my $maintenanceInfos		= &getMaintInfosFromNet($netID);
	my $tmplID							= $maintenanceInfos->{tmplID} || 0;
	my $descr								= $maintenanceInfos->{description} || '';
	my $stateNr							= $maintenanceInfos->{state} || 0;
	my ($ipaddress, $cidr)	= split(/\//, $network);
	my $netmask							= ($ipv6) ? 0 : &getNetmaskFromCidr($cidr);
	my $netaddress					= ($ipv6) ? $ipaddress : &dec2ip(&getNetaddress($ipaddress, $netmask));
	my $broadcast						= ($ipv6) ? &getV6BroadcastIP($networkDec) : &dec2ip(&getBroadcastFromNet($networkDec));
	my $state								= &networkStateID2Name($stateNr);


	my $availPlugins	= &getPlugins();
	my $availPluginst	= {};

	foreach (keys %{$availPlugins}) {
		$availPluginst->{$availPlugins->{$_}->{NAME}}	= $_; 
	}

	$t->{V}->{netBasicInfoHeader}	= sprintf(_gettext("Details of Network <b>%s</b>"), $network);
	$t->{V}->{netBasicInfo}	= [
		{
			elements	=> [
				{
					target	=> 'key',
					type		=> 'label',
					value		=> _gettext("Network"),
				},
				{
					target		=> 'value',
					type			=> 'label',
					value			=> $network
				}
			]
		},
		{
			elements	=> [
				{
					target	=> 'key',
					type		=> 'label',
					value		=> _gettext("Netaddress"),
				},
				{
					target		=> 'value',
					type			=> 'label',
					value			=> $netaddress
				}
			]
		},
		{
			elements	=> [
				{
					target	=> 'key',
					type		=> 'label',
					value		=> _gettext("CIDR"),
				},
				{
					target		=> 'value',
					type			=> 'label',
					value			=> $cidr
				}
			]
		},(($ipv6) ? () : 
		({
			elements	=> [
				{
					target	=> 'key',
					type		=> 'label',
					value		=> _gettext("Netmask"),
				},
				{
					target		=> 'value',
					type			=> 'label',
					value			=> $netmask
				}
			]
		})),
		{
			elements	=> [
				{
					target	=> 'key',
					type		=> 'label',
					value		=> _gettext("Broadcast"),
				},
				{
					target		=> 'value',
					type			=> 'label',
					value			=> $broadcast
				}
			]
		},
		{
			value	=> {
				type		=> 'hline',
				colspan	=> 2,
			}
		},
		{
			elements	=> [
				{
					target	=> 'key',
					type		=> 'label',
					value		=> _gettext("Description"),
				},
				{
					target		=> 'value',
					type			=> 'label',
					value			=> $descr,
				}
			]
		},
		{
			elements	=> [
				{
					target	=> 'key',
					type		=> 'label',
					value		=> _gettext("Status"),
				},
				{
					target		=> 'value',
					type			=> 'label',
					value			=> $state,
				}
			]
		},
		{
			value	=> {
				type		=> 'hline',
				colspan	=> 2,
			}
		},
		{
			elements	=> [
				{
					target	=> 'key',
					type		=> 'label',
					value		=> _gettext("Created from"),
				},
				{
					target		=> 'value',
					type			=> 'label',
					value			=> $maintenanceInfos->{createFrom},
				}
			]
		},
		{
			elements	=> [
				{
					target	=> 'key',
					type		=> 'label',
					value		=> _gettext("Created on"),
				},
				{
					target		=> 'value',
					type			=> 'label',
					value			=> $maintenanceInfos->{createDate},
				}
			]
		},
		{
			elements	=> [
				{
					target	=> 'key',
					type		=> 'label',
					value		=> _gettext("Modified by"),
				},
				{
					target		=> 'value',
					type			=> 'label',
					value			=> $maintenanceInfos->{modifyFrom},
				}
			]
		},
		{
			elements	=> [
				{
					target	=> 'key',
					type		=> 'label',
					value		=> _gettext("Modified on"),
				},
				{
					target		=> 'value',
					type			=> 'label',
					value			=> $maintenanceInfos->{modifyDate},
				}
			]
		},
	];

	$t->{V}->{splitNetHeader}		= _gettext("Split Details");
	$t->{V}->{splitNetFormName}	= 'splitNetMenu';
	$t->{V}->{splitNetMenu}			= [
		{
			elements	=> [
				{
					target		=> 'single',
					type			=> 'label',
					value			=> _gettext("Split Network into these pieces:"),
					colspan		=> 3,
					align			=> 'center',
					bold			=> 1,
					underline	=> 1,
				},
			]
		},
	];

	my $elements	= [];
	
	my @values	= ();
	for (($cidr + 1) .. (($ipv6) ? 128 : 32)) {
		my $amount	= 2**($_ - $cidr);
		push @values, {
			value	=> $_,
			label	=> "$amount * /$_"
		};
		last if $amount > 1024;
	}
	push @{$t->{V}->{splitNetMenu}}, (
		{
			elements	=> [
				{
					target		=> 'single',
					type			=> 'radio',
					name			=> 'splitCidr',
					values		=> \@values,
					cr				=> 1,
					selected	=> ($cidr + 1),
					colspan		=> 3,
					align			=> 'center',
				}
			]
		},
		{
			value	=> {
				type		=> 'hline',
				colspan	=> 3,
			}
		},
		{
			elements	=> [
				{
					target		=> 'single',
					type			=> 'label',
					value			=> _gettext("Settings for the new Networks"),
					colspan		=> 3,
					align			=> 'center',
					bold			=> 1,
					underline	=> 1,
				},
			]
		},
		{
			elements	=> [
				{
					target	=> 'key',
					type		=> 'label',
					value		=> _gettext("Template for the Descriptions"),
				},
				{
					target		=> 'single',
					type			=> 'textfield',
					name			=> 'descrTemplate',
					size			=> 20,
					maxlength	=> 255,
					value			=> $descr . ' %d',
				},
				{
					target	=> 'value',
					type		=> 'buttons',
					align		=> 'left',
					buttons	=> [
						{
							name		=> 'showDescrHelper',
							type		=> '',
							onClick	=> "showDescrHelper()",
							value		=> '1',
							img			=> 'info_small.png',
							picOnly	=> 1,
							title		=> _gettext("Available Variables from the Plugins"),
						},
					],
				},
			]
		},
		{
			elements	=> [
				{
					target	=> 'key',
					type		=> 'label',
					value		=> _gettext("Status"),
				},
				{
					target		=> 'value',
					type			=> 'popupMenu',
					name			=> 'state',
					size			=> 1,
					values		=> $stats,
					selected	=> $stateNr,
					colspan		=> 2,
				}
			]
		},
		{
			elements	=> [
				{
					target	=> 'key',
					type		=> 'label',
					value		=> _gettext("Type"),
				},
				{
					target		=> 'value',
					type			=> 'popupMenu',
					name			=> 'tmplID',
					size			=> 1,
					values		=> $types,
					selected	=> [$tmplID],
					colspan		=> 2,
				}
			]
		},
		{
			value	=> {
				type		=> 'hline',
				colspan	=> 3,
			}
		},
		{
			elements	=> [
				{
					target	=> 'key',
					type		=> 'label',
					value		=> _gettext("Delete this network"),
				},
				{
					target		=> 'value',
					type			=> 'checkbox',
					name			=> 'delParentNet',
					value			=> 1,
					descr			=> '',
					checked		=> 0,
					colspan		=> 2,
				},
			],
		},
	);

	$t->{V}->{helpDescrHeader}	= _gettext("Available Variables from the Plugins");
	$t->{V}->{helpDescrMenu}		= [
		{
			elements	=> [
				{
					target	=> 'single',
					type		=> 'label',
					value		=> '',
					width		=> '0.1em',
				},
				{
					target	=> 'single',
					type		=> 'label',
					value		=> '<b>' . _gettext('Name') . '</b>',
					width		=> '3em',
					align		=> 'center',
				},
				{
					target	=> 'single',
					type		=> 'label',
					value		=> '<b>' . _gettext('Description') . '</b>',
					width		=> '8em',
					align		=> 'center',
				},
				{
					target	=> 'single',
					type		=> 'label',
					value		=> '<b>' . _gettext('Insert') . '</b>',
					width		=> '1em',
					align		=> 'center',
				}
			]
		},
		{
			value	=> {
				type		=> 'hline',
				colspan	=> 4,
			}
		},
	];

	foreach (sort keys %{$availPluginst}) {
		my $ID					= $availPluginst->{$_};
		next unless $availPlugins->{$ID}->{ACTIVE};

		my $elements	= [];
		my $api				= (exists $availPlugins->{$ID}->{API} && ref($availPlugins->{$ID}->{API}) eq 'ARRAY') ? $availPlugins->{$ID}->{API} : [];

		foreach (@{$api}) {
			my $name	= $_->{name};
			my $descr	= $_->{descr};

			push @{$elements}, (
				{elements	=> [
					{
						target		=> 'single',
						type			=> 'label',
						value			=> '',
						width			=> '0.1em',
					},
					{
						target		=> 'single',
						type			=> 'label',
						value			=> $name,
						width			=> '3em',
						align			=> 'left',
					},
					{
						target		=> 'single',
						type			=> 'label',
						value			=> $descr,
						width			=> '8em',
						align			=> 'left',
					},
					{
						target		=> 'single',
						type			=> 'buttons',
						align			=> 'center',
						width			=> '1em',
						buttons	=> [
							{
								name		=> 'insertPluginVar',
								type		=> '',
								onClick	=> "insertPluginVar('descrTemplate','\%\%$availPlugins->{$ID}->{NAME}\%$name\%\%')",
								value		=> '1',
								img			=> 'insert_small.png',
								picOnly	=> 1,
								title		=> sprintf(_gettext("Insert '%s' from Plugin '%s'"), $name, $availPlugins->{$ID}->{NAME}),
							},
						],
					},
				]},
			);
		};

		push @{$t->{V}->{helpDescrMenu}}, (
			{
				elements	=> [
					{
						target		=> 'single',
						type			=> 'label',
						value			=> sprintf(_gettext("Plugin '%s'"), $availPlugins->{$ID}->{NAME}),
						bold			=> 1,
						colspan		=> 4,
					},
				],
			},
			@{$elements}
		) if $#{$api} != -1;
	}

	push @{$t->{V}->{helpDescrMenu}}, (
		{
			value	=> {
				type		=> 'hline',
				colspan	=> 4,
			}
		},
		{
			elements	=> [
				{
					target	=> 'single',
					type		=> 'buttons',
					align		=> 'center',
					colspan	=> 4,
					buttons	=> [
						{
							name		=> 'pluginInfoCloser',
							onClick	=> "hideDescrHelper()",
							value		=> '1',
							img			=> 'cancel_small.png',
							picOnly	=> 1,
							title		=> _gettext("Close Overview"),
						},
					],
				},
			]
		}
	);

	$t->{V}->{splitNetButtonsMenu}	=	[
		{
			elements	=> [
				{
					target	=> 'single',
					type		=> 'buttons',
					buttons	=> [
						{
							name		=> 'submitSplitNet',
							type		=> 'submit',
							value		=> _gettext("Split"),
							img			=> 'split_small.png',
							onClick	=> 'showStatus(1)',
						},
						{
							name	=> 'abortSplitNet',
							type	=> 'submit',
							value	=> _gettext("Abort"),
							img		=> 'cancel_small.png',
						}
					]
				}
			]
		},
	];

	$t->{V}->{splitNetHiddens}	= [
		{
			name	=> 'netID',
			value	=> $netID
		}
	];
}

sub mkCombineNets {
	warn 'SUB: ' . (caller(0))[3] . ' (' . (caller(1))[3] . ")\n" if $conf->{var}->{showsubs};
	my $q				= $HaCi::HaCi::q;
	my $t				= $HaCi::GUI::init::t;
	my $types		= &getNetworkTypes(1);
	my $stats		= $conf->{static}->{misc}->{networkstates};
	my $oneOK		= 0;

	map {$_->{ID}	= $_->{id}} @{$stats};

	$t->{V}->{combineNetsHeader}		= _gettext("Combine Networks");
	$t->{V}->{combineNetsFormName}	= 'combineNetsMenu';

	my $box		= {};
	foreach ($q->param('selectedNetworks')) {
		my ($network, $rootID)	= split/_/, $_, 2;
		my $ipv6								= &rootID2ipv6($rootID);
		my $networkDec					= ($ipv6) ? &netv62Dec($network) : &net2dec($network);
		my $parent							= &getNetworkParentFromDB($rootID, $networkDec, $ipv6);
		my $parentDec						= (defined $parent) ? $parent->{network} : 0;
# warn "COMBINE $network -> " . &dec2net($parentDec) . "\n";
		$box->{$rootID}->{IPV6}	= $ipv6;
		push @{$box->{$rootID}->{PARENTS}->{$parentDec}}, $networkDec;
	}

	my $cnter		= 0;
	my $box1		= {};
	my $lastNet	= undef;
	foreach (sort {$a<=>$b} keys %{$box}) {
		my $rootID	= $_;
		my $ipv6		= $box->{$rootID}->{IPV6};
		my @parents	= ();
		if ($ipv6) {
			@parents	= sort {Math::BigInt->new($a)<=>Math::BigInt->new($b)} keys %{$box->{$rootID}->{PARENTS}};
		} else {
			@parents	= sort {$a<=>$b} keys %{$box->{$rootID}->{PARENTS}};
		}
		foreach (@parents) {
			my $parent	= $_;
			my @nets		= ();
			if ($ipv6) {
				@nets	= sort {Math::BigInt->new($a)<=>Math::BigInt->new($b)} @{$box->{$rootID}->{PARENTS}->{$parent}};
			} else {
				@nets	= sort {$a<=>$b} @{$box->{$rootID}->{PARENTS}->{$parent}};
			}
			foreach (@nets) {
				my $currNet	= $_;
				if (defined $lastNet) {
					my $netBefore	= &getDBNetworkBefore($rootID, $currNet, $ipv6, 1);
					$cnter++ if $lastNet != $netBefore;
				}
				push @{$box1->{$rootID}->{NETS}->{$cnter}}, $currNet;
				$box1->{$rootID}->{IPV6}	= $ipv6;
				$lastNet									= $currNet;
			}
		}
	}

	my $transCnter	= 0;
	foreach (sort {$a<=>$b} keys %{$box1}) {
		my $rootID	= $_;
		my $ipv6		= $box1->{$rootID}->{IPV6};
		foreach (sort {$a<=>$b} keys %{$box1->{$rootID}->{NETS}}) {
			my $cnter						= $_;
			my $first						= ${$box1->{$rootID}->{NETS}->{$cnter}}[0];
			$first							= Math::BigInt->new($first) if $ipv6;
			my $last						= ${$box1->{$rootID}->{NETS}->{$cnter}}[-1];
			$last								= Math::BigInt->new($last) if $ipv6;
			my $cidr						= $first % 256;
			my $firstNetaddress	= ($ipv6) ? (&netv6Dec2IpCidr($first))[0] : &getIPFromDec($first);
			my $lastBroadcast		= ($ipv6) ? &getV6BroadcastIP($last) : &getBroadcastFromNet($last);
			my $descr						= '';
			my $stateNr					= 0,
			my $tmplID					= 0;
			my $base						= Math::BigInt->new(2);
			my $currIPT					= ($ipv6) ? Math::BigInt->new($firstNetaddress) : $firstNetaddress;
			my $currNetaddress	= ($ipv6) ? &ipv6DecCidr2NetaddressV6Dec($currIPT, $cidr) : &getNetaddress($currIPT, &getNetmaskFromCidr($cidr));
			my $currIP					= ($ipv6) ? $currNetaddress->copy()->badd($base->copy()->bpow(128 - $cidr)) : $currNetaddress + (2**(32 - $cidr));
# warn "First: " . &dec2ip($firstNetaddress) . " - " . &dec2net($last) ." (currIP: " . &dec2ip($currIP) .  ") < (LASTBROADCAST: " . &dec2ip($lastBroadcast) . ")\n";	

			while ($currIP <= $lastBroadcast) {
				last if $cidr < 1;
				$cidr--;
				$currNetaddress	= ($ipv6) ? &ipv6DecCidr2NetaddressV6Dec($currIPT, $cidr) : &getNetaddress($currIPT, &getNetmaskFromCidr($cidr));
				$currIP					= ($ipv6) ? $currNetaddress->copy()->badd($base->copy()->bpow(128 - $cidr)) : $currNetaddress + (2**(32 - $cidr));
			}
	
			my $newNetRevisedIPDec	= ($ipv6) ? &ipv6DecCidr2NetaddressV6Dec($firstNetaddress, $cidr) : &getNetaddress($firstNetaddress, &getNetmaskFromCidr($cidr));
			my $newNetRevisedNetDec	= ($ipv6) ? &ipv6DecCidr2netv6Dec($newNetRevisedIPDec, $cidr) : &net2dec(&dec2ip($newNetRevisedIPDec) . '/' . $cidr);
			my $newNetRevised				= ($ipv6) ? &netv6Dec2net(&ipv6DecCidr2netv6Dec($newNetRevisedIPDec, $cidr)) : &dec2ip($newNetRevisedIPDec) . '/' . $cidr;
			my $newNetBroadcast			= ($ipv6) ? &getV6BroadcastNet(&ipv6DecCidr2netv6Dec($newNetRevisedIPDec, $cidr), 128) : &net2dec(&dec2ip(&getBroadcastFromNet(&net2dec($newNetRevised))) . '/' . 32);
# warn "NEW: " . &dec2net($newNetRevisedNetDec) . "\n";

			if ($transCnter) {
				push @{$t->{V}->{combineNetsMenu}}, (
					{
						value	=> {
							type	=> 'hline'
						}
					},
				);
			}
	
			push @{$t->{V}->{combineNetsMenu}}, (
				{
					elements	=> [
						{
							target		=> 'single',
							type			=> 'label',
							bold			=> 1,
							underline	=> 1,
							align			=> 'center',
							colspan		=> 2,
							value			=> sprintf(_gettext("%i. Block"), ($transCnter + 1))
						},
					]
				},
			);
	
			my $cnter1	= 0;
			my @nets		= ();
			if ($ipv6) {
				@nets	= sort {Math::BigInt->new($a)<=>Math::BigInt->new($b)} @{$box1->{$rootID}->{NETS}->{$cnter}};
			} else {
				@nets	= sort {$a<=>$b} @{$box1->{$rootID}->{NETS}->{$cnter}};
			}
			foreach (@nets) {
				my $networkDec				= $_;
				my $ipv6ID						= ($ipv6) ? &netv6Dec2ipv6ID($networkDec) : '';
				my $netID							= &getNetID($rootID, $networkDec, $ipv6ID);
				my $maintenanceInfos	= &getMaintInfosFromNet($netID);
				push @{$t->{V}->{combineNetsMenu}}, (
					{
						elements	=> [
							{
								type		=> 'label',
								hidden	=> 1,
								noShow	=> 1,
								name		=> 'combineNets_' . $transCnter . '_source',
								value		=> $networkDec,
							},
							{
								target	=> 'key',
								type		=> 'label',
								value		=> ($cnter1) ? '+' : '&nbsp;'
							},
							{
								target		=> 'value',
								type			=> 'label',
								value			=> (($ipv6) ? &netv6Dec2net($networkDec) : &dec2net($networkDec)) . ' (' . $maintenanceInfos->{description} . ')',
							}
						]
					},
				);
				$cnter1++;
			}

			my $bOK				= 1;
			my $error			= '';
			my $ipv6ID		= ($ipv6) ? &netv6Dec2ipv6ID($newNetRevisedNetDec) : '';
			my $netID			= &getNetID($rootID, $newNetRevisedNetDec, $ipv6ID);
			if (defined $netID && $netID) {
				$bOK		= 0;
				$error	= _gettext("This Network allready exists!");
			}
			my $netBefore	= &getDBNetworkBefore($rootID, $first, $ipv6);
			if (defined $netBefore && $netBefore > $newNetRevisedNetDec) {
				$bOK		= 0;
				$error	.= '<br>' if $error;
				$error	.= sprintf(_gettext("Foreign Networks will be <br>included (e.g. '%s')"), (($ipv6) ? &netv6Dec2net($netBefore) : &dec2net($netBefore)));
			}
			my $netNext	= &getNextDBNetwork($rootID, $ipv6, $last);
			if (defined $netNext && $netNext->{network} < $newNetBroadcast) {
				$bOK		= 0;
				$error	.= '<br>' if $error;
				$error	.= sprintf(_gettext("Foreign Networks will be <br>included (e.g. '%s')"), (($ipv6) ? &netv6Dec2net($netNext->{network}) : &dec2net($netNext->{network})));
			}

			$oneOK	||= $bOK;
			push @{$t->{V}->{combineNetsMenu}}, (
				{
					elements	=> [
						{
							type		=> 'label',
							hidden	=> 1,
							noShow	=> 1,
							name		=> 'combineNets_' . $transCnter . '_rootID',
							value		=> $rootID,
						},
						{
							type		=> 'label',
							hidden	=> 1,
							noShow	=> 1,
							name		=> 'combineNets_' . $transCnter . '_result',
							value		=> $newNetRevisedNetDec,
						},
						{
							target	=> 'key',
							type		=> 'label',
							bold		=> 1,
							value		=> '='
						},
						{
							target	=> 'value',
							type		=> 'label',
							bold		=> 1,
							color		=> '#' . (($bOK) ? '00AA00' : 'AA0000'),
							value		=> $newNetRevised . (($bOK) ? '' : ' (' . $error . ')'),
						},
					]
				},
				{
					elements	=> [
						{
							target	=> 'key',
							type		=> 'label',
							value		=> _gettext("Combine these networks"),
						},
						{
							target		=> 'value',
							type			=> 'checkbox',
							name			=> 'combineNetsNr',
							value			=> $transCnter,
							descr			=> '',
							checked		=> 0,
							disabled	=> ($bOK) ? 0 : 1,
						},
					],
				},
			);
			push @{$t->{V}->{combineNetsMenu}}, (
				{
					elements	=> [
						{
							target		=> 'single',
							type			=> 'label',
							bold			=> 1,
							underline	=> 1,
							value			=> _gettext("Settings for the new Network"),
							colspan		=> 2,
							align			=> 'center',
						},
					]
				},
				{
					elements	=> [
						{
							target	=> 'key',
							type		=> 'label',
							value		=> _gettext("Description"),
						},
						{
							target		=> 'value',
							type			=> 'textfield',
							name			=> 'combineNets_' . $transCnter . '_descr',
							size			=> 20,
							maxlength	=> 255,
							value			=> $descr,
						}
					]
				},
				{
					elements	=> [
						{
							target	=> 'key',
							type		=> 'label',
							value		=> _gettext("Status"),
						},
						{
							target		=> 'value',
							type			=> 'popupMenu',
							name			=> 'combineNets_' . $transCnter . '_state',
							size			=> 1,
							values		=> $stats,
							selected	=> $stateNr,
						}
					]
				},
				{
					elements	=> [
						{
							target	=> 'key',
							type		=> 'label',
							value		=> _gettext("Type"),
						},
						{
							target		=> 'value',
							type			=> 'popupMenu',
							name			=> 'combineNets_' . $transCnter . '_tmplID',
							size			=> 1,
							values		=> $types,
							selected	=> [$tmplID],
						}
					]
				},
			) if $bOK;

			$transCnter++;
		}
	}
	
	$t->{V}->{combineNetsButtonsMenu}	=	[
		{
			elements	=> [
				{
					target	=> 'single',
					type		=> 'buttons',
					buttons	=> [
						{
							name			=> 'submitCombineNets',
							type			=> 'submit',
							value			=> _gettext("Combine Networks"),
							disabled	=> ($oneOK) ? 0 : 1,
							img				=> 'combine_small.png',
						},
						{
							name	=> 'abortCombineNets',
							type	=> 'submit',
							value	=> _gettext("Abort"),
							img		=> 'cancel_small.png',
						}
					]
				}
			]
		},
	];
}

sub mkShowPlugins {
	warn 'SUB: ' . (caller(0))[3] . ' (' . (caller(1))[3] . ")\n" if $conf->{var}->{showsubs};
	my $t					= $HaCi::GUI::init::t;
	my $plugins		= &getPlugins();
	my $hacidInfo	= &getHaCidInfo();

	push @{$t->{V}->{floatingPopupMenu}}, (
		{
			elements	=> [
				{
					name			=> 'floatingPopupContent',
					target		=> 'single',
					type			=> 'label',
					value			=> '',
					width			=> '100%',
					bold			=> 0,
					align			=> 'center',
					wrap			=> 1,
				},
			]
		},
		{
			value	=> {
				type		=> 'hline',
				colspan	=> 1,
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
							name		=> 'hideFloatingPopup',
							type		=> '',
							value		=> _gettext("Abort"),
							img			=> 'cancel_small.png',
							onClick	=> "hideFloatingPopup()",
							picOnly	=> 1,
							title		=> _gettext("Close Error Details"),
						},
					],
				},
			]
		}
	);

	$t->{V}->{showPluginsHeader}		= _gettext("Plugins");
	$t->{V}->{showPluginsFormName}	= 'editPlugins';

	push @{$t->{V}->{showPluginsMenu}}, (
		{
			elements	=> [
				{
					target		=> 'single',
					type			=> 'label',
					value			=> _gettext("Name"),
					width			=> '15em',
					bold			=> 1,
					align			=> 'center',
				},
				{
					target	=> 'single',
					width		=> '0.5em',
					type		=> 'vline',
					align		=> 'center',
				},
				{
					target		=> 'single',
					type			=> 'label',
					value			=> _gettext("Version"),
					width			=> '4em',
					bold			=> 1,
					align			=> 'center',
				},
				{
					target	=> 'single',
					width		=> '0.5em',
					type		=> 'vline',
					align		=> 'center',
				},
				{
					target		=> 'single',
					type			=> 'label',
					value			=> _gettext("active"),
					width			=> '4em',
					bold			=> 1,
					align			=> 'center',
				},
				{
					target	=> 'single',
					width		=> '0.5em',
					type		=> 'vline',
					align		=> 'center',
				},
				{
					target		=> 'single',
					type			=> 'label',
					value			=> _gettext("default"),
					width			=> '4em',
					bold			=> 1,
					align			=> 'center',
				},
				{
					target	=> 'single',
					width		=> '0.5em',
					type		=> 'vline',
					align		=> 'center',
				},
				{
					target		=> 'single',
					type			=> 'label',
					value			=> _gettext("Configure"),
					width			=> '2em',
					bold			=> 1,
					align			=> 'center',
				},
				{
					target	=> 'single',
					width		=> '0.5em',
					type		=> 'vline',
					align		=> 'center',
				},
				{
					target		=> 'single',
					type			=> 'label',
					value			=> _gettext("on Demand"),
					width			=> '6em',
					bold			=> 1,
					align			=> 'center',
				},
				{
					target	=> 'single',
					width		=> '0.5em',
					type		=> 'vline',
					align		=> 'center',
				},
				{
					target		=> 'single',
					type			=> 'label',
					value			=> _gettext("recurrent"),
					width			=> '5em',
					bold			=> 1,
					align			=> 'center',
				},
				{
					target	=> 'single',
					width		=> '0.5em',
					type		=> 'vline',
					align		=> 'center',
				},
				{
					target		=> 'single',
					type			=> 'label',
					value			=> _gettext("last Run"),
					width			=> '10em',
					bold			=> 1,
					align			=> 'center',
				},
				{
					target	=> 'single',
					width		=> '0.5em',
					type		=> 'vline',
					align		=> 'center',
				},
				{
					target		=> 'single',
					type			=> 'label',
					value			=> _gettext("Runtime"),
					width			=> '10em',
					bold			=> 1,
					align			=> 'center',
				},
				{
					target	=> 'single',
					width		=> '0.5em',
					type		=> 'vline',
					align		=> 'center',
				},
				{
					target		=> 'single',
					type			=> 'label',
					value			=> _gettext("Error"),
					width			=> '10em',
					bold			=> 1,
					align			=> 'center',
				},
			]
		},
	);

	my $box	= {};
	foreach (keys %{$plugins}) { $box->{$plugins->{$_}->{NAME}}	= $_; }

	foreach (sort keys %{$box}) {
		my $ID					= $box->{$_};
		my $error				= $plugins->{$ID}->{LASTERROR};

		my $globConf		= 1 if 
			($plugins->{$ID}->{RECURRENT} && ($#{$conf->{static}->{plugindefaultglobrecurrentmenu}} != -1 || $#{$plugins->{$ID}->{GLOBMENURECURRENT}} != -1)) ||
			($plugins->{$ID}->{ONDEMAND} && ($#{$conf->{static}->{plugindefaultglobondemandmenu}} != -1 || $#{$plugins->{$ID}->{GLOBMENUONDEMAND}} != -1));

		$error		=~ s/'/\\'/g;
		$error		=~ s/"//g;
		$error		=~ s/\n/\\n/g;
		$error		=~ s/\r/\\r/g;
		$error		= '<code>' . $error . '</code>';
		push @{$t->{V}->{showPluginsMenu}}, (
			{
				elements	=> [
					{
						target		=> 'single',
						type			=> 'label',
						value			=> $plugins->{$ID}->{NAME},
						width			=> '15em',
					},
					{
						target	=> 'single',
						width		=> '0.5em',
						type		=> 'label',
						value		=> '&nbsp;',
						align			=> 'center',
					},
					{
						target		=> 'single',
						type			=> 'label',
						value			=> $plugins->{$ID}->{VERSION},
						width			=> '4em',
						align			=> 'center',
					},
					{
						target	=> 'single',
						width		=> '0.5em',
						type		=> 'label',
						value		=> '&nbsp;',
						align			=> 'center',
					},
					{
						target		=> 'single',
						type			=> 'checkbox',
						name			=> 'pluginActives',
						value			=> $ID,
						descr			=> '',
						checked		=> $plugins->{$ID}->{ACTIVE},
						width			=> '4em',
						align			=> 'center',
					},
					{
						target	=> 'single',
						width		=> '0.5em',
						type		=> 'label',
						value		=> '&nbsp;',
						align			=> 'center',
					},
					{
						target		=> 'single',
						type			=> 'checkbox',
						name			=> 'pluginDefaults',
						value			=> $ID,
						descr			=> '',
						checked		=> $plugins->{$ID}->{DEFAULT},
						width			=> '4em',
						disabled	=> ($plugins->{$ID}->{ONDEMAND}) ? 0 : 1,
						align			=> 'center',
					},
					{
						target	=> 'single',
						width		=> '0.5em',
						type		=> 'label',
						value		=> '&nbsp;',
						align			=> 'center',
					},
					{
						target	=> 'single',
						type		=> 'buttons',
						align		=> 'center',
						buttons	=> [
							{
								name			=> 'editPluginGlobConf',
								type			=> 'submit',
								onClick		=> "setPluginID('$ID')",
								value			=> '1',
								img				=> 'config_small.png',
								img				=> 'config_small' . (($globConf) ? '' : '_disabled') . '.png',
								picOnly		=> 1,
								title			=> sprintf(_gettext("Configure Plugin '%s'"), $plugins->{$ID}->{NAME}),
								disabled	=> ($globConf) ? 0 : 1,
							},
						],
					},
					{
						target	=> 'single',
						width		=> '0.5em',
						type		=> 'vline',
						align		=> 'center',
					},
					{
						target		=> 'single',
						type			=> 'checkbox',
						name			=> '',
						value			=> '',
						descr			=> '',
						checked		=> $plugins->{$ID}->{ONDEMAND},
						width			=> '6em',
						disabled	=> 1,
						align			=> 'center',
					},
					{
						target	=> 'single',
						width		=> '0.5em',
						type		=> 'label',
						value		=> '&nbsp;',
						align			=> 'center',
					},
					{
						target		=> 'single',
						type			=> 'checkbox',
						name			=> '',
						value			=> '',
						descr			=> '',
						checked		=> $plugins->{$ID}->{RECURRENT},
						width			=> '5em',
						disabled	=> 1,
						align			=> 'center',
					},
					{
						target	=> 'single',
						width		=> '0.5em',
						type		=> 'label',
						value		=> '&nbsp;',
						align			=> 'center',
					},
					{
						target		=> 'single',
						type			=> 'label',
						value			=> $plugins->{$ID}->{LASTRUN},
						width			=> '10em',
						align			=> 'center',
					},
					{
						target	=> 'single',
						width		=> '0.5em',
						type		=> 'label',
						value		=> '&nbsp;',
						align			=> 'center',
					},
					{
						target		=> 'single',
						type			=> 'label',
						value			=> $plugins->{$ID}->{RUNTIME} . 's',
						width			=> '10em',
						align			=> 'left',
					},
					{
						target	=> 'single',
						width		=> '0.5em',
						type		=> 'label',
						value		=> '&nbsp;',
						align			=> 'center',
					},
					{
						target	=> 'single',
						type		=> 'buttons',
						align		=> 'center',
						buttons	=> [
							{
								name			=> 'pluginInfo',
								onClick		=> "showFloatingPopup('" . sprintf(_gettext("Error Details for Plugin %s"), $plugins->{$ID}->{NAME}) . "', '$error')",
								value			=> '1',
								img				=> ($plugins->{$ID}->{LASTERROR}) ? 'info_small.png' : 'info_small_disabled.png',
								picOnly		=> 1,
								title			=> _gettext("Error Details"),
								disabled	=> ($plugins->{$ID}->{LASTERROR}) ? 0 : 1,
							},
						],
					},
				]
			},
		);
	}

	$t->{V}->{showPluginsButtonsMenu}	=	[
		{
			elements	=> [
				{
					target	=> 'single',
					type		=> 'buttons',
					buttons	=> [
						{
							name	=> 'submitshowPlugins',
							type	=> 'submit',
							value	=> _gettext("Submit"),
							img		=> 'submit_small.png',
						},
						{
							name	=> 'abortshowPlugins',
							type	=> 'submit',
							value	=> _gettext("Back"),
							img		=> 'back_small.png',
						}
					]
				}
			]
		},
	];

	$t->{V}->{HaCidInfoHeader}	= _gettext('HaCi Daemon Infos');
	if (defined $hacidInfo) {
		push @{$t->{V}->{HaCidInfoMenu}}, (
			{
				elements	=> [
					{
						target		=> 'single',
						type			=> 'label',
						value			=> _gettext("PID"),
						width			=> '5em',
						bold			=> 1,
						align			=> 'center',
					},
					{
						target	=> 'single',
						width		=> '0.5em',
						type		=> 'vline',
						align		=> 'center',
					},
					{
						target		=> 'single',
						type			=> 'label',
						value			=> _gettext("CPU"),
						width			=> '5em',
						bold			=> 1,
						align			=> 'center',
					},
					{
						target	=> 'single',
						width		=> '0.5em',
						type		=> 'vline',
						align		=> 'center',
					},
					{
						target		=> 'single',
						type			=> 'label',
						value			=> _gettext("RSS"),
						width			=> '5em',
						bold			=> 1,
						align			=> 'center',
					},
					{
						target	=> 'single',
						width		=> '0.5em',
						type		=> 'vline',
						align		=> 'center',
					},
					{
						target		=> 'single',
						type			=> 'label',
						value			=> _gettext("TIME"),
						width			=> '5em',
						bold			=> 1,
						align			=> 'center',
					},
				],
			},
			{
				elements	=> [
					{
						target		=> 'single',
						type			=> 'label',
						value			=> $hacidInfo->{PARENT}->{PID},
						width			=> '5em',
					},
					{
						target	=> 'single',
						width		=> '0.5em',
						type		=> 'label',
						value		=> '&nbsp;',
						align			=> 'center',
					},
					{
						target		=> 'single',
						type			=> 'label',
						value			=> $hacidInfo->{PARENT}->{CPU} . '%',
						width			=> '5em',
					},
					{
						target	=> 'single',
						width		=> '0.5em',
						type		=> 'label',
						value		=> '&nbsp;',
						align			=> 'center',
					},
					{
						target		=> 'single',
						type			=> 'label',
						value			=> $hacidInfo->{PARENT}->{RSS} . ' kb',
						width			=> '5em',
					},
					{
						target	=> 'single',
						width		=> '0.5em',
						type		=> 'label',
						value		=> '&nbsp;',
						align			=> 'center',
					},
					{
						target		=> 'single',
						type			=> 'label',
						value			=> $hacidInfo->{PARENT}->{TIME},
						width			=> '5em',
					},
				],
			},
		);

		if ($#{$hacidInfo->{CHILDS}} > -1) {
			push @{$t->{V}->{HaCidInfoMenu}}, (
				{
					value	=> {
						type		=> 'hline',
						colspan	=> 7,
					}
				},
				{
					elements	=> [
						{
							target		=> 'single',
							type			=> 'label',
							value			=> _gettext("Childs"),
							width			=> '5em',
							colspan		=> 7,
							bold			=> 1,
						},
					]
				},
			);
		}

		foreach (@{$hacidInfo->{CHILDS}}) {
			my $hash	= $_;
			push @{$t->{V}->{HaCidInfoMenu}}, (
				{
					elements	=> [
						{
							target		=> 'single',
							type			=> 'label',
							value			=> $hash->{PID},
							width			=> '5em',
						},
						{
							target	=> 'single',
							width		=> '0.5em',
							type		=> 'label',
							value		=> '&nbsp;',
							align			=> 'center',
						},
						{
							target		=> 'single',
							type			=> 'label',
							value			=> $hash->{CPU} . '%',
							width			=> '5em',
						},
						{
							target	=> 'single',
							width		=> '0.5em',
							type		=> 'label',
							value		=> '&nbsp;',
							align			=> 'center',
						},
						{
							target		=> 'single',
							type			=> 'label',
							value			=> $hash->{RSS} . ' kb',
							width			=> '5em',
						},
						{
							target	=> 'single',
							width		=> '0.5em',
							type		=> 'label',
							value		=> '&nbsp;',
							align			=> 'center',
						},
						{
							target		=> 'single',
							type			=> 'label',
							value			=> $hash->{TIME},
							width			=> '5em',
						},
					],
				},
			);
		}
	} else {
		push @{$t->{V}->{HaCidInfoMenu}}, (
			{
				elements	=> [
					{
						target		=> 'single',
						type			=> 'label',
						value			=> _gettext("The HaCi Daemon is not started."),
						width			=> '5em',
						bold			=> 1,
						align			=> 'center',
					},
				]
			}
		);
	}
}

sub showPlugin {
	warn 'SUB: ' . (caller(0))[3] . ' (' . (caller(1))[3] . ")\n" if $conf->{var}->{showsubs};
	my $pluginID						= shift;
	my $netID								= shift;
	my $t										= $HaCi::GUI::init::t;
	my $maintenanceInfos		= &getMaintInfosFromNet($netID);
	my $plugin							= &pluginID2Name($pluginID);
	my $pluginFilename			= &pluginID2File($pluginID);
	my $pluginInfos					= (&getPluginInfos($pluginFilename))[1];
	my $error								= $pluginInfos->{ERROR} || '';

	return if !$pluginInfos->{ACTIVE} && !$pluginInfos->{ERROR};

	unless ($error) {
		eval {
			require "HaCi/Plugins/$pluginFilename.pm";
		};
		if ($@) {
			$error	= "Cannot load Plugin: $plugin: $@";
			warn "$error\n";
		}
	}

	my $plug;

	unless ($error) {
		eval {
			$plug	= "HaCi::Plugins::$plugin"->new($pluginID, $conf->{var}->{TABLES}->{pluginValue});
		};
		if ($@) {
			$error	= "Error while initiating Module: $@";
			warn "$error\n";
		}
	}

	unless ($error) {
		if ($pluginInfos->{ONDEMAND}) {
			my $lastRun	= time;
			eval {
				$plug->run_onDemand($maintenanceInfos);
			};
			if ($@) {
				$error	= "Error while running Module: $@";
				warn "$error\n";
			}
			unless ($plug->can('ERROR')) {
				warn "Plugin '$plugin' has no ERROR Method!\n";
			} else {
				if ($plug->ERROR()) {
					unless ($plug->can('ERRORSTR')) {
						warn "Plugin '$plugin' has no ERRORSTR Method!\n";
					} else {
						$error	= "Error while running Module: " . $plug->ERRORSTR();
						warn "$error\n";
					}
				}
			}
			&updatePluginLastRun($pluginID, $lastRun, (time - $lastRun), $error);
		}
	}

	my $plugShow	= {
		HEADER	=> '',
		BODY		=> []
	};

	unless ($error) {
		eval {
			$plugShow	= $plug->show($netID);
		};
		if ($@) {
			$error	.= "Error while loading Module Output: $@";
			warn "$error\n";
		}
	}

	if ($error && !$conf->{user}->{gui}->{showerrordetails}) {
		$error	= sprintf(_gettext("Error while loading Plugin '%s'. Details in Error Logfile."), $plugin);
	}

	$t->{V}->{plugin}	= {
		HEADER	=> $plugShow->{HEADER},
		BODY		=> (($error) ? [{elements=>[{target=>'single',type=>'label',value=>"<i><font color='#AA0000'><pre>" . $error . "</pre></font></i>"}]}] : $plugShow->{BODY}),
	};
	$t->{V}->{page}			= 'showPlugin';
	$t->{V}->{pluginID}	= $pluginID;
	$t->{V}->{noHeader}	= 1;

	my $html_output = '';
	$t->{T}->process($conf->{static}->{path}->{templateinit}, $t->{V}, \$html_output)
		|| die $t->{T}->error();
	return $html_output;
}

sub mkShowStatus {
	warn 'SUB: ' . (caller(0))[3] . ' (' . (caller(1))[3] . ")\n" if $conf->{var}->{showsubs};
	my $fresh					= shift || 0;
	my $status				= ($fresh) ? {STATUS	=> 'Starting...'} : &getStatus();

	unless ($fresh) {
		$status->{STATUS}	= 'FINISH' unless exists $status->{STATUS} && $status->{STATUS};
	}
	$status->{DATA}		= '' unless exists $status->{DATA};
	$status->{TITLE}	= '' unless exists $status->{TITLE};
	my $returnStr			= $status->{TITLE} . ': ' . $status->{DATA};
	$returnStr				.= " ($status->{PERCENT}%)" if $status->{PERCENT};
	$returnStr				= '' unless $returnStr;
	return ($status->{STATUS}, $returnStr);
}

sub mkShowPluginConf {
	warn 'SUB: ' . (caller(0))[3] . ' (' . (caller(1))[3] . ")\n" if $conf->{var}->{showsubs};
	my $global		= shift || 0;
	my $q					= $HaCi::HaCi::q;
	my $t					= $HaCi::GUI::init::t;
	my $pluginID	= $q->param('pluginID');
	my $netID			= $q->param('netID');
	my $plugin		= &pluginID2Name($pluginID);
	$netID				= -1 unless defined $netID;
	my ($rootID, $networkDec, $ipv6);
	($rootID, $networkDec, $ipv6)	= &netID2Stuff($netID) if $netID != -1;
	my $network		= ($global) ? '' : ($ipv6) ? &netv6Dec2net($networkDec) : &dec2net($networkDec);

	$t->{V}->{pluginConfHeader}		= sprintf(_gettext((($global) ? 'Global ' : '') . "Configuration of '%s'" . (($global) ? '' : " for '%s'")), $plugin, $network);
	$t->{V}->{pluginConfMenu}			= &getPluginConfMenu($pluginID, $global, $netID);
	$t->{V}->{pluginConfFormName}	= 'pluginConf';

	$t->{V}->{pluginConfHiddens}	= [
		{
			name	=> 'pluginID',
			value	=> $pluginID
		},
		{
			name	=> 'global',
			value	=> $global
		},
		{
			name	=> 'netID',
			value	=> $netID
		},
	];
}

sub mkShowSubnets {
	warn 'SUB: ' . (caller(0))[3] . ' (' . (caller(1))[3] . ")\n" if $conf->{var}->{showsubs};
	my $q							= $HaCi::HaCi::q;
	my $t							= $HaCi::GUI::init::t;
	my $thisScript		= $conf->{var}->{thisscript};
	my $maxSubnetSize	= &getConfigValue('gui', 'maxsubnetsize');
	my $netID					= $q->param('netID');
	my $net						= &getMaintInfosFromNet($netID);
	my $ipv6					= ($net->{ipv6ID}) ? 1 : 0;
	my $subnetSize		= (defined $q->param('subnetSize')) ? $q->param('subnetSize') : $net->{defSubnetSize};
	my $network				= ($ipv6) ? &netv6Dec2net($net->{network}) : &dec2net($net->{network});
	my $cidr					= (split/\//, $network, 2)[1];
	my @freeSubnetst	= &getFreeSubnets($netID, 0, $subnetSize);
	my $freeSubnets		= [];
	my $subnetSizes		= [{ID => 0, name => 'min'}];
	my $subnetSizesV6	= [{ID => 0, name => 'min'}];

	map {
		push @{$freeSubnets}, {
			net	=> $_,
			dec	=> ($ipv6) ? &netv62Dec($_) : &net2dec($_),
		};
	} @freeSubnetst;

	# Generate Subnet Cidr Menu
	{
		$cidr	= 0 unless $cidr;
		map {
			push @{$subnetSizes}, {ID => $_, name => $_}
		} (($cidr + 1) .. ((32 < ($cidr + $maxSubnetSize)) ? 32 : ($cidr + $maxSubnetSize)));
		map {
			push @{$subnetSizesV6}, {ID => $_, name => $_}
		} (($cidr + 1) .. ((128 < ($cidr + $maxSubnetSize)) ? 128 : ($cidr + $maxSubnetSize)));
	}

	$t->{V}->{showSubnetsHeader}			= sprintf(_gettext("Show free Subnets of '%s' with CIDR '%s'"), $network, ($subnetSize) ? $subnetSize : 'min');
	$t->{V}->{freeSubnetsHeader}			= _gettext("Free Subnets");
	$t->{V}->{showSubnetsFormName}		= 'showSubnets';
	$t->{V}->{buttonFocus}						= 'showSubnets';
	$t->{V}->{freeSubnets}						= $freeSubnets;
	$t->{V}->{noResults}							= ($#freeSubnetst == -1) ? 1 : 0;
	$t->{V}->{gettext_subnet}					= _gettext('Subnet');
	$t->{V}->{gettext_nr}							= _gettext('No.');
	$t->{V}->{gettext_create}					= _gettext('Create');
	$t->{V}->{gettext_nothing_found}	= _gettext('No free Subnets with this CIDR available');
	$t->{V}->{rootID}									= $net->{rootID};
	$t->{V}->{thisScript}							= $thisScript;
	$t->{V}->{showSubnetsMenu}				=	[
		{
			elements	=> [
				{
					target	=> 'key',
					type		=> 'label',
					value		=> _gettext("CIDR"),
				},
				{
					target		=> 'value',
					type			=> 'popupMenu',
					name			=> 'subnetSize',
					size			=> 1,
					values		=> ($ipv6) ? $subnetSizesV6 : $subnetSizes,
					selected	=> $subnetSize,
				},
			]
		},
		{
			value	=> {
				type		=> 'hline',
				colspan	=> 2,
			}
		},
		{
			elements	=> [
				{
					target	=> 'single',
					type		=> 'buttons',
					colspan	=> 2,
					align		=> 'center',
					buttons	=> [
						{
							name	=> 'showSubnets',
							type	=> 'submit',
							value	=> _gettext("Show"),
							img		=> 'showSubnets_small.png',
						},
						{
							name	=> 'abortShowSubnets',
							type	=> 'submit',
							value	=> _gettext("Back"),
							img		=> 'back_small.png',
						}
					]
				}
			],
		},
	];

	$t->{V}->{showSubnetsHiddens}	= [
		{
			name	=> 'netID',
			value	=> $netID
		},
	];
}

sub mkShowSettings {
	warn 'SUB: ' . (caller(0))[3] . ' (' . (caller(1))[3] . ")\n" if $conf->{var}->{showsubs};

	my $q					= $HaCi::HaCi::q;
	my $t					= $HaCi::GUI::init::t;
	my $subMenu		= '';

	if ($q->param('changeOwnPW')) {
		$subMenu	= 'chOwnPW';
		&mkChOwnPW();
	}
	elsif ($q->param('showViewSettings')) {
		$subMenu	= 'showViewSettings';
		&mkShowViewSettings();
	}


	$t->{V}->{settingsMenuHeader}		= _gettext("Menu");
	$t->{V}->{settingsMenuFormName}	= "settingsMenu";
	$t->{V}->{settingsSubMenu}			= $subMenu;
	$t->{V}->{settingsMenu}					= [
		{
			elements	=> [
				{
					target	=> 'single',
					type		=> 'buttons',
					buttons	=> [
						{
							name			=> 'changeOwnPW',
							type			=> 'submit',
							value			=> _gettext("Change own Password"),
							img				=> 'password_small.png',
						},
						{
							name			=> 'showViewSettings',
							type			=> 'submit',
							value			=> _gettext("View"),
							img				=> 'showSettingsView_small.png',
						},
						{
							name	=> 'abortShowSettings',
							type	=> 'submit',
							value	=> _gettext("Back"),
							img		=> 'back_small.png',
						},
					],
				},
			]
		},
	];

	$t->{V}->{settingsMenuHiddens}	= [
		{
			name	=> 'func',
			value	=> 'showSettings'
		}
	];
}

sub mkChOwnPW {
	warn 'SUB: ' . (caller(0))[3] . ' (' . (caller(1))[3] . ")\n" if $conf->{var}->{showsubs};

	my $q				= $HaCi::HaCi::q;
	my $t				= $HaCi::GUI::init::t;

	$t->{V}->{chOwnPWHeader}		= _gettext("Change own Password");
	$t->{V}->{chOwnPWFormName}	= "chOwnPW";
	$t->{V}->{chOwnPW}					= [
		{
			elements	=> [
				{
					target	=> 'key',
					type		=> 'label',
					value		=> _gettext("Old Password"),
				},
				{
					target		=> 'value',
					type			=> 'passwordfield',
					name			=> 'oldPassword',
					size			=> 25,
					maxlength	=> 255,
					focus			=> 1,
				},
			],
		},
		{
			elements	=> [
				{
					target	=> 'key',
					type		=> 'label',
					value		=> _gettext("New Password"),
				},
				{
					target		=> 'value',
					type			=> 'passwordfield',
					name			=> 'newPassword',
					size			=> 25,
					maxlength	=> 255,
				},
			],
		},
		{
			elements	=> [
				{
					target	=> 'key',
					type		=> 'label',
					value		=> _gettext("Password Validation"),
				},
				{
					target		=> 'value',
					type			=> 'passwordfield',
					name			=> 'newPasswordVal',
					size			=> 25,
					maxlength	=> 255,
					onKeyDown	=> "submitOnEnter(event, 'commitChOwnPW')",
				},
			],
		},
		{
			value	=> {
				type	=> 'hline',
				colspan	=> 2,
			}
		},
		{
			elements	=> [
				{
					target	=> 'single',
					type		=> 'buttons',
					align		=> 'center',
					colspan	=> 2,
					buttons	=> [
						{
							name	=> 'commitChOwnPW',
							type	=> 'submit',
							value	=> _gettext("Change"),
							img		=> 'change_small.png',
						},
						{
							name	=> 'abortChOwnPW',
							type	=> 'submit',
							value	=> _gettext("Abort"),
							img		=> 'cancel_small.png',
						},
					],
				},
			],
		}
	];

	$t->{V}->{chOwnPWHiddens}	= [
		{
			name	=> 'func',
			value	=> 'showSettings'
		}
	];
}

sub mkShowViewSettings {
	warn 'SUB: ' . (caller(0))[3] . ' (' . (caller(1))[3] . ")\n" if $conf->{var}->{showsubs};

	my $q								= $HaCi::HaCi::q;
	my $t								= $HaCi::GUI::init::t;
	my $layouts					= $conf->{static}->{gui}->{layouts} || [];
	my $s								= $HaCi::HaCi::session;
	my $settings				= $s->param('settings');
	my $layout					= (defined $settings && exists $settings->{layout}) ? ${$settings->{layout}}[0] : $conf->{user}->{gui}->{style} || $conf->{static}->{gui}->{style};
	my $bShowTreeStruct	= (defined $settings && exists $settings->{bShowTreeStruct}) ? ${$settings->{bShowTreeStruct}}[0] : $conf->{user}->{gui}->{showTreeStructure} || 0;
	my @temps						= (defined $settings && exists $settings->{temp}) ? @{$settings->{temp}} : [];

	map {$_->{ID} = $_->{id}} @{$layouts};

	$t->{V}->{viewSettingsHeader}		= _gettext("View Settings");
	$t->{V}->{viewSettingsFormName}	= "viewSettings";
	$t->{V}->{viewSettings}					= [
		{
			elements	=> [
				{
					target	=> 'key',
					type		=> 'label',
					value		=> _gettext("Layout"),
				},
				{
					target		=> 'single',
					type			=> 'popupMenu',
					name			=> 'setting_layout',
					size			=> 1,
					values		=> $layouts,
					selected	=> $layout,
				},
			],
		},
		{
			elements	=> [
				{
					target	=> 'key',
					type		=> 'label',
					value		=> _gettext("Show Tree Structure"),
				},
				{
					target		=> 'value',
					type			=> 'checkbox',
					name			=> 'setting_bShowTreeStruct',
					value			=> 1,
					descr			=> '',
					checked		=> $bShowTreeStruct,
					disabled	=> 0,
				},
			],
		},
		{
			value	=> {
				type	=> 'hline',
				colspan	=> 5,
			}
		},
		{
			elements	=> [
				{
					target	=> 'single',
					type		=> 'buttons',
					align		=> 'center',
					colspan	=> 5,
					buttons	=> [
						{
							name	=> 'commitViewSettings',
							type	=> 'submit',
							value	=> _gettext("Change"),
							img		=> 'change_small.png',
						},
						{
							name	=> 'abortViewSettings',
							type	=> 'submit',
							value	=> _gettext("Abort"),
							img		=> 'cancel_small.png',
						},
					],
				},
			],
		}
	];

	$t->{V}->{viewSettingsHiddens}	= [
		{
			name	=> 'func',
			value	=> 'showSettings'
		},
		{
			name	=> 'settingParams',
			value	=> 'layout'
		},
		{
			name	=> 'settingParams',
			value	=> 'bShowTreeStruct'
		},
	];
}

1;

# vim:ts=2:sw=2:sws=2
