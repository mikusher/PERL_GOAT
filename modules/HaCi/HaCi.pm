package HaCi::HaCi;

use strict;
use CGI;
# use CGI::Pretty;
use CGI::Carp qw/fatalsToBrowser/;
use CGI::Session;
use CGI::Cookie;
use CGI::Ajax;
use Math::BigInt 1.87;
use Storable qw(lock_store lock_retrieve);
use Digest::MD5;
use Math::Base85;
use Encode;

use HaCi::GUI::init;
use HaCi::GUI::main qw/
	checkNet expandNetwork reduceNetwork reduceRoot expandRoot showPlugin mkShowStatus
	mkSubmitImportASNRoutes
/;
use HaCi::GUI::authentication;
use HaCi::GUI::gettext qw/_gettext/;
use HaCi::Log qw/warnl debug/;
use HaCi::Mathematics qw/
	net2dec dec2net getBroadcastFromNet getNetmaskFromCidr dec2ip ip2dec getNetaddress netv62Dec
	netv6Dec2net
/;
use HaCi::Utils qw/
	prWarnl delUser getRights importCSV compare checkDB newWindow prNewWindows setStatus removeStatus
	addRoot addNet importASNRoutes getConfig checkSpelling_Net rootID2Name rootName2ID delNet genRandBranch editRoot
	delRoot copyNetsTo delNets search checkSpelling_IP checkSpelling_CIDR saveTmpl delTmpl saveGroup delGroup saveUser
	lwd dec2bin groupID2Name checkRight importDNSTrans importDNSLocal getNetworkParentFromDB importConfig rootID2ipv6
	expand splitNet combineNets updatePluginDB getTable checkTables checkNetworkACTable checkNetACL getRoots
	mkPluginConfig initTables initCache chOwnPW updSettings updateSettingsInSession flushACLCache flushNetCache
	searchAndGetFreeSubnets getParam
/;

local our $q				= undef;
local our $pjx			= undef;
local our $session	= undef;
local our $aclCache	= undef;
local our $netCache	= undef;
local our $cache		= undef;
our $conf; *conf		= \$HaCi::Conf::conf;
my $netCacheHandle	= undef;
my $aclCacheHandle	= undef;

sub run {
	warn 'SUB: ' . (caller(0))[3] . ' (' . (caller(1))[3] . ")\n" if $conf->{var}->{showsubs};

	my $soap				= shift || 0;
	my $soapArgs		= shift || [];
	my $soapPreRun	= shift;
	my $soapPostRun	= shift;

	$conf->{var}->{soap}	= $soap;

	&getConfig();
	&init();
	&soapInit($soapArgs) if $soap;

	if (1 && $conf->{static}->{misc}->{debug}) { 
		use Data::Dumper qw/Dumper/; # Loading Dumper for Debugging...
		foreach ($q->param) {
			my $k	= $_;
			foreach ($q->param($k)) {
				warn "  $k => $_ \n"; 
			}
		}
	} # Dump

	if ($q->param('func')) {
		if ($q->param('func') eq 'logout') {
			if ($session->param('authenticated')) {
				&debug("logging out");
				&removeStatus();
				$session->delete();
				$session->flush();
				$conf->{var}->{relogin}	= 1;
				# &genNewSession();
			} else {
				&debug("allready logged out!");
			}
		}
	}
	
	&HaCi::GUI::init::init();
	&HaCi::GUI::init::setVars();

	my $t	= $HaCi::GUI::init::t;

	if (!$conf->{var}->{relogin} && &authentication()) {
		&getRights();
		&$soapPreRun($soapArgs, $q) if $soap && defined $soapPreRun;
		&checkRights();
		&main();
	} else {
		&checkTables();
		&checkNetworkACTable();
		&HaCi::GUI::authentication::login();
		$t->{V}->{page}  = 'login';
	}

	my $warnings	= '';
	$warnings			= &finalize();
	return &$soapPostRun($soapArgs, $q, $t, $warnings) if $soap && defined $soapPostRun;
}

sub main {
	warn 'SUB: ' . (caller(0))[3] . ' (' . (caller(1))[3] . ")\n" if $conf->{var}->{showsubs};

	&HaCi::GUI::init::setUserVars();

	if ($q->param('fname')) {	# AJAX call
		return;
	}
	
	my $t	= $HaCi::GUI::init::t;
	my $q	= $HaCi::HaCi::q;

	if ($q->param('submitAddRoot')) {
		if (&addRoot(
			&getParam(1, undef, $q->param('name')),
			&getParam(1, undef, $q->param('descr')),
			&getParam(1, 0, $q->param('ipv6')),
			&getParam(1, undef, $q->param('rootID')),
		)) {
			$q->delete('func'); $q->param('func', 'showAllNets');
		} else {
			$q->delete('func'); $q->param(
				'func', 
				((&getParam(1, 0, $q->param('editRoot'))) ? 'editRoot' : 'addRoot')
			);
		}
	}
	elsif ($q->param('submitAddNet')) {
		if (&addNet(
			&getParam(1, 0, $q->param('netID')),
			&getParam(1, undef, $q->param('rootID')),
			&getParam(1, undef, $q->param('netaddress')),
			&getParam(1, undef, $q->param('cidr')),
			&getParam(1, '', $q->param('descr')),
			&getParam(1, 0, $q->param('state')),
			&getParam(1, 0, $q->param('tmplID')),
			&getParam(1, 0, $q->param('defSubnetSize')),
			&getParam(1, 0, $q->param('forceState')),
		)) {
			$q->delete('func'); $q->param('func', 'showAllNets');
		} else {
			$q->delete('func'); $q->param('func', 'addNet');
		}
	}
	elsif ($q->param('abortAddRoot')) {
		$q->delete('func'); $q->param('func', 'showAllNets');
	}
	elsif ($q->param('abortAddNet')) {
		if ($q->param('editNet')) {
			$q->delete('func'); $q->param('func', 'showNet');
		} else {
			$q->delete('func'); $q->param('func', 'showAllNets');
		}
	}
	elsif ($q->param('checktAddNet')) {
		&checkNet(
			&getParam(1, undef, $q->param('netaddress')), 
			&getParam(1, undef, $q->param('cidr')),
		);
		if ($q->param('editNet')) {
			$q->delete('func'); $q->param('func', 'editNet');
		} else {
			$q->delete('func'); $q->param('func', 'addNet');
		}
	}
	elsif ($q->param('submitImportASNRoutes')) {
		if (
			&importASNRoutes(
				&getParam(1, undef, $q->param('asn'))
			)
		) {
			$q->delete('func'); $q->param('func', 'showAllNets');
		} else {
			$q->delete('func'); $q->param('func', 'importASNRoutes');
		}
	}
	elsif ($q->param('submitImpDNSTrans')) {
		if (&importDNSTrans()) {
			$q->delete('func'); $q->param('func', 'showAllNets');
		} else {
			$q->delete('func'); $q->param('func', 'importDNS');
		}
	}
	elsif ($q->param('submitImpDNSLocal')) {
		if (&importDNSLocal()) {
			$q->delete('func'); $q->param('func', 'showAllNets');
		} else {
			$q->delete('func'); $q->param('func', 'importDNS');
		}
	}
	elsif ($q->param('submitImpConfig')) {
		if (&importConfig()) {
			$q->delete('func'); $q->param('func', 'showAllNets');
		} else {
			$q->delete('func'); $q->param('func', 'importConfig');
		}
	}
	elsif ($q->param('impCSVChangeSep')) {
		$q->delete('func'); $q->param('func', 'importConfig');
	}
	elsif ($q->param('impCSVChangeType')) {
		$q->delete('func'); $q->param('func', 'importConfig');
	}
	elsif ($q->param('abortImpCSV')) {
		$q->delete('func'); $q->param('func', 'showAllNets');
	}
	elsif ($q->param('submitImpCSV')) {
		if (&importCSV()) {
			$q->delete('func'); $q->param('func', 'showAllNets');
		} else {
			$q->delete('func'); $q->param('func', 'importConfig');
		}
	}
	elsif ($q->param('editPluginConf')) {
		$q->delete('func'); $q->param('func', 'showPluginConf');
	}
	elsif ($q->param('editNet')) {
		$q->delete('func'); $q->param('func', 'editNet');
	}
	elsif ($q->param('splitNet')) {
		$q->delete('func'); $q->param('func', 'splitNet');
	}
	elsif ($q->param('submitSplitNet')) {
		&splitNet(
			&getParam(1, undef, $q->param('netID')),
			&getParam(1, undef, $q->param('splitCidr')),
			&getParam(1, '', $q->param('descrTemplate')),
			&getParam(1, 0, $q->param('state')),
			&getParam(1, 0, $q->param('tmplID')),
			&getParam(1, 0, $q->param('delParentNet')),
		);
		$q->delete('func'); $q->param('func', 'showAllNets');
	}
	elsif ($q->param('submitCombineNets')) {
		&combineNets();
		$q->delete('func'); $q->param('func', 'showAllNets');
	}
	elsif ($q->param('abortCombineNets')) {
		$q->delete('func'); $q->param('func', 'showAllNets');
	}
	elsif ($q->param('abortSplitNet')) {
		$q->delete('func'); $q->param('func', 'showNet');
	}
	elsif ($q->param('combineNets')) {
		my @nets	= $q->param('selectedNetworks');
		if ($#nets > 0) {
			$q->delete('func'); $q->param('func', 'combineNets');
		}
	}
	elsif ($q->param('abortEditRoot')) {
		$q->delete('func'); $q->param('func', 'showRoot');
	}
	elsif ($q->param('editRoot')) {
		$q->delete('func'); $q->param('func', 'editRoot');
	}
	elsif ($q->param('abortDelRoot')) {
		$q->delete('func'); $q->param('func', 'showRoot');
	}
	elsif ($q->param('abortDelNet')) {
		$q->delete('func'); $q->param('func', 'showNet');
	}
	elsif ($q->param('delRoot')) {
		if ($q->param('commitDelRoot')) {
			&delRoot(
				&getParam(1, undef, $q->param('rootID'))
			);
			$q->delete('func'); $q->param('func', 'showAllNets');
		} else {
			$q->delete('func'); $q->param('func', 'delRoot');
		}
	}
	elsif ($q->param('delNet')) {
		if ($q->param('commitDelNet')) {
			&delNet(
				&getParam(1, undef, $q->param('netID')), 
				((defined $q->param('withSubnets')) ? 1 : 0)
			);
			$q->delete('func'); $q->param('func', 'showAllNets');
		} else {
			$q->delete('func'); $q->param('func', 'delNet');
		}
	}
	elsif ($q->param('reduceRoot')) {
		&expand(
			'-', 
			'root', 
			&getParam(1, undef, $q->param('reduceRoot'))
		);
		$session->param('currNet', '');
		$session->param(
			'currRootID', 
			&getParam(1, undef, $q->param('reduceRoot'))
		);
	}
	elsif ($q->param('expandRoot')) {
		&expand(
			'+', 
			'root', 
			&getParam(1, undef, $q->param('expandRoot'))
		);
		$session->param('currNet', '');
		$session->param(
			'currRootID', 
			&getParam(1, undef, $q->param('expandRoot'))
		);
	}
	elsif ($q->param('reduceNetwork')) {
		&expand(
			'-', 
			'network', 
			&getParam(1, undef, $q->param('reduceNetwork')), 
			&getParam(1, undef, $q->param('rootID'))
		);
		$session->param(
			'currNet', 
			&getParam(1, undef, $q->param('reduceNetwork'))
		);
		$session->param(
			'currRootID', 
			&getParam(1, undef, $q->param('rootID'))
		);
	}
	elsif ($q->param('expandNetwork')) {
		&expand(
			'+', 
			'network', 
			&getParam(1, undef, $q->param('expandNetwork')), 
			&getParam(1, undef, $q->param('rootID'))
		);
		$session->param(
			'currNet', 
			&getParam(1, undef, $q->param('expandNetwork'))
		);
		$session->param(
			'currRootID', 
			&getParam(1, undef, $q->param('rootID'))
		);
	}
	elsif ($q->param('closeTree')) {
		&expand('-', 'ALL', 'ALL');
	}
	elsif ($q->param('jumpToButton')) {
		&expandTo(
			&getParam(1, undef, $q->param('rootIDJump')), 
			&getParam(1, undef, $q->param('jumpTo'))
		);
	}
	elsif ($q->param('genRandBranch')) {
		&genRandBranch();
		$q->delete('func'); $q->param('func', 'showAllNets');
	}
	elsif ($q->param('finishEditTree')) {
		$q->delete('editTree');
	}
	elsif ($q->param('copyNetsTo')) {
		&copyNetsTo(
			&getParam(1, undef, $q->param('copyToRootID')), 
			[$q->param('selectedNetworks')], 
			0
		);
	}
	elsif ($q->param('moveNetsTo')) {
		&copyNetsTo(
			&getParam(1, undef, $q->param('copyToRootID')), 
			[$q->param('selectedNetworks')], 
			1
		);
	}
	elsif ($q->param('deleteNets')) {
		&delNets([$q->param('selectedNetworks')]);
	}
	elsif ($q->param('searchButton')) {
		&search();
		$q->delete('func'); $q->param('func', 'search');
	}
	elsif ($q->param('compareButton')) {
		&compare();
		$q->delete('func'); $q->param('func', 'showAllNets');
	}
	elsif ($q->param('newTmpl')) {
		if ($q->param('tmplName')) {
			$q->delete('tmplID');
			my $tmplName	= &getParam(1, '', $q->param('tmplName'));
			$tmplName			=~ s/[<>&"']//g;
			$q->delete('tmplName'), $q->param('tmplName', $tmplName);
			$q->delete('func'); $q->param('func', 'editTmpl');
		} else {
			$q->delete('tmplID');
			$q->delete('func'); $q->param('func', 'showTemplates');
		}
	}
	elsif ($q->param('editNetTypeTmpl')) {
		unless (defined $q->param('tmplID')) {
			$q->delete('func'); $q->param('func', 'showTemplates');
		} else {
			$q->delete('func'); $q->param('func', 'editTmpl');
		}
	}
	elsif ($q->param('abortEditTmpl')) {
		$q->delete('func'); $q->param('func', 'showTemplates');
	}
	elsif ($q->param('submitAddTmplEntry')) {
		my $tmplID	= &saveTmpl();
		$q->delete('tmplID'); $q->param('tmplID', $tmplID);
		$q->delete('func'); $q->param('func', 'editTmpl');
	}
	elsif ($q->param('submitEditTmplEntry')) {
		my $tmplID	= &saveTmpl(1);
		$q->delete('tmplID'); $q->param('tmplID', $tmplID);
		$q->delete('func'); $q->param('func', 'editTmpl');
	}
	elsif ($q->param('submitDeleteTmplEntry')) {
		my $tmplID	= &saveTmpl(2);
		$q->delete('tmplID'); $q->param('tmplID', $tmplID);
		$q->delete('func'); $q->param('func', 'editTmpl');
	}
	elsif ($q->param('delTmpl')) {
		if ($q->param('commitDelTmpl')) {
			&delTmpl(&getParam(1, undef, $q->param('tmplID')));
			$q->delete('func'); $q->param('func', 'showTemplates');
		}
		elsif ($q->param('abortDelTmpl')) {
			$q->delete('func'); $q->param('func', 'showTemplates');
		} else {
			if ($q->param('tmplID')) {
				$q->delete('func'); $q->param('func', 'delTmpl');
			} else {
				$q->delete('func'); $q->param('func', 'showTemplates');
			}
		}
	}
	elsif ($q->param('newGroup')) {
		if ($q->param('groupName')) {
			$q->delete('groupID');
			my $groupName	= &getParam(1, '', $q->param('groupName'));
			$groupName		=~ s/[<>&"']//g;
			$q->delete('groupName'), $q->param('groupName', $groupName);
			$q->delete('func'); $q->param('func', 'editGroup');
		} else {
			$q->delete('func'); $q->param('func', 'showGroups');
		}
	}
	elsif ($q->param('editGroup')) {
		unless (defined $q->param('groupID')) {
			$q->delete('func'); $q->param('func', 'showGroups');
		} else {
			$q->delete('func'); $q->param('func', 'editGroup');
		}
	}
	elsif ($q->param('submitEditGroup')) {
		my $groupID	= &saveGroup();
		if (defined $groupID) {
			$q->delete('groupID'); $q->param('groupID', $groupID);
			$q->delete('func'); $q->param('func', 'showGroups');
		} else {
			$q->delete('func'); $q->param('func', 'editGroup');
		}
	}
	elsif ($q->param('abortEditGroup')) {
		$q->delete('func'); $q->param('func', 'showGroups');
	}
	elsif ($q->param('delGroup')) {
		if ($q->param('commitDelGroup')) {
			&delGroup(&getParam(1, undef, $q->param('groupID')));
			$q->delete('func'); $q->param('func', 'showGroups');
		}
		elsif ($q->param('abortDelGroup')) {
			$q->delete('func'); $q->param('func', 'showGroups');
		} else {
			if ($q->param('groupID')) {
				my $groupName	= &groupID2Name(&getParam(1, undef, $q->param('groupID')));
				if ($groupName eq 'Administrator') {
					$q->delete('func'); $q->param('func', 'showGroups');
				} else {
					$q->delete('func'); $q->param('func', 'delGroup');
				}
			} else {
				$q->delete('func'); $q->param('func', 'showGroups');
			}
		}
	}
	elsif ($q->param('newUser')) {
		if ($q->param('userName')) {
			$q->delete('userID');
			my $userName	= &getParam(1, '', $q->param('userName'));
			$userName			=~ s/[<>&"']//g;
			$q->delete('userName'), $q->param('userName', $userName);
			$q->delete('func'); $q->param('func', 'editUser');
		} else {
			$q->delete('func'); $q->param('func', 'showUsers');
		}
	}
	elsif ($q->param('editUser')) {
		unless (defined $q->param('userID')) {
			$q->delete('func'); $q->param('func', 'showUsers');
		} else {
			$q->delete('func'); $q->param('func', 'editUser');
		}
	}
	elsif ($q->param('submitEditUser')) {
		my $userID	= &saveUser();
		if (defined $userID) {
			$q->delete('userID'); $q->param('userID', $userID);
			$q->delete('func'); $q->param('func', 'showUsers');
		} else {
			$q->delete('func'); $q->param('func', 'editUser');
		}
	}
	elsif ($q->param('abortEditUser')) {
		$q->delete('func'); $q->param('func', 'showUsers');
	}
	elsif ($q->param('delUser')) {
		if ($q->param('commitDelUser')) {
			&delUser(&getParam(1, undef, $q->param('userID')));
			$q->delete('func'); $q->param('func', 'showUsers');
		}
		elsif ($q->param('abortDelUser')) {
			$q->delete('func'); $q->param('func', 'showUsers');
		} else {
			if ($q->param('userID')) {
				$q->delete('func'); $q->param('func', 'delUser');
			} else {
				$q->delete('func'); $q->param('func', 'showUsers');
			}
		}
	}
	elsif ($q->param('showSubnets')) {
		$q->delete('func'); $q->param('func', 'showSubnets');
	}
	elsif ($q->param('abortShowSubnets')) {
		$q->delete('func'); $q->param('func', 'showNet');
	}
	elsif ($q->param('checkDB')) {
		&checkDB();
	}
	elsif ($q->param('submitshowPlugins')) {
		&updatePluginDB();
		$q->delete('func'); $q->param('func', 'showPlugins');
	}
	elsif ($q->param('editPluginGlobConf')) {
		$q->delete('func'); $q->param('func', 'showPluginGlobConf');
	}
	elsif ($q->param('submitPluginConfig')) {
		my $global	= &getParam(1, 0, $q->param('global'));
		&mkPluginConfig($global);
		if ($global) {
			$q->delete('func'); $q->param('func', 'showPlugins');
		} else {
			$q->delete('func'); $q->param('editNet', 'Bearbeiten'); $q->param('func', 'editNet');
		}
	}
	elsif ($q->param('abortPluginConfig')) {
		my $global	= &getParam(1, 0, $q->param('global'));
		if ($global) {
			$q->delete('func'); $q->param('func', 'showPlugins');
		} else {
			$q->delete('func'); $q->param('func', 'editNet');
			$q->delete('editNet'); $q->param('editNet', 1);
		}
	}
	elsif ($q->param('abortShowSettings')) {
		$q->delete('func'); $q->param('func', 'showAllNets');
	}
	elsif ($q->param('commitChOwnPW')) {
		unless (&chOwnPW()) {
			$q->param('changeOwnPW', 1);
		}
	}
	elsif ($q->param('commitViewSettings')) {
		unless (&updSettings()) {
			$q->param('showViewSettings', 1);
		}
		&HaCi::GUI::init::setUserVars();
	}
	elsif ($q->param('searchAndGetFreeSubnets')) {
		&searchAndGetFreeSubnets();
	}
	
	if (defined $q->param('func')) {
		if ($q->param('func') eq 'addNet') {
			my $roots	= &getRoots();
			if ($#{$roots} == -1) {
				&warnl("Cannot find any Root! Please create some before you create networks\n");
				$q->delete('func'); $q->param('func', 'addRoot');
			}
		}
		elsif ($q->param('func') eq 'addNet' && $q->param('networkDec') && $q->param('rootID') && !($q->param('editNet'))) {
			my $rootID			= &getParam(1, undef, $q->param('rootID'));
			my $networkDec	= &getParam(1, undef, $q->param('networkDec'));
			my $ipv6				= &rootID2ipv6($rootID);
			$networkDec			= Math::BigInt->new($networkDec) if $ipv6;
			my $parent			= &getNetworkParentFromDB($rootID, $networkDec, $ipv6);
			unless (defined $parent) {
				warn "No Parent found!\n";
				$q->delete('func'); $q->param('func', 'showAllNets');
			} else {
				my $parentDec		= $parent->{network};
				my $parentID		= $parent->{ID};
				unless (&checkNetACL($parentID, 'w')) {
					my $network	= ($ipv6) ? &netv6Dec2net($networkDec) : &dec2net($networkDec);
					my $parent	= ($ipv6) ? &netv6Dec2net($parentDec) : &dec2net($parentDec);
					&warnl(sprintf(_gettext("Not enough rights to add this Network '%s' under '%s'"), $network, $parent));
					$q->delete('func'); $q->param('func', 'showAllNets');
				}
			}
		}
		elsif ($q->param('func') eq 'flushCache') {
			&flushACLCache();
			&flushNetCache();
			$q->delete('func'); $q->param('func', 'showAllNets');
		}
	}
	
	$HaCi::GUI::init::t->{V}->{jumpTo}  = $session->param('currRootID') . '-' . $session->param('currNet') if $session->param('currRootID') && $session->param('currNet');
	&HaCi::GUI::main::start();

	if ($q->param('newWindow') && $q->param('newWindow') eq 'showStatus') {
		$t->{V}->{page}  = 'showStatus';
	} else {
		$t->{V}->{page}  = 'main';
	}
}

sub expandTo {
	warn 'SUB: ' . (caller(0))[3] . ' (' . (caller(1))[3] . ")\n" if $conf->{var}->{showsubs};
	my $rootID				= shift;
	my $ipaddress			= shift || '';
	my $ipv6					= &rootID2ipv6($rootID);
	$ipaddress				=~ s/[^\w\.\:]//g;

	return 0 unless $ipaddress;

	unless (&checkSpelling_IP($ipaddress, $ipv6)) {
		warn "Cannot jump to. No IP Address: '$ipaddress'\n";
		return 0;
	}

	my $networkDec		= ($ipv6) ? &netv62Dec($ipaddress . '/128') : &net2dec($ipaddress . '/32');
	my $s							= $HaCi::HaCi::session;
	my $expands				= $s->param('expands') || {};
	
	my $networkTable	= $conf->{var}->{TABLES}->{network};
	unless (defined $networkTable) {
		warn "Cannot jump to network. DB Error\n";
		return 0;
	}

	my $bestMatch	= 0;
	while (my $parent	= &getNetworkParentFromDB($rootID, $networkDec, $ipv6)) {
		my $parentDec	= $parent->{network};
		&expand('+', 'network', $parentDec, $rootID) unless $expands->{network}->{$rootID}->{$parentDec};
		$bestMatch	= $parentDec unless $bestMatch;
		$networkDec	= $parentDec;
	}
	
	if ($bestMatch) {
		&expand('+', 'root', $rootID);
		$session->param('jumpTo', 1);
		$session->param('jumpToNet', $bestMatch);
		$session->param('jumpToRoot', $rootID);
		$session->param('currNet', $bestMatch);
		$session->param('currRootID', $rootID);
	} else {
		$session->clear('jumpTo');
		$session->clear('jumpToNet');
		$session->clear('jumpToRoot');
	}
}

sub hook {
	warn 'SUB: ' . (caller(0))[3] . ' (' . (caller(1))[3] . ")\n" if $conf->{var}->{showsubs};
	my ($filename, $buffer, $bytes_read, $data) = @_;
	my $percent	= int(($bytes_read * 100) / $data);
	my $status	= {
		title   => "Retrieving File '$filename'",
		percent => $percent,
		detail  => "Read $bytes_read/$data bytes of $filename",
	};
	my $statFile  = $conf->{static}->{path}->{statusfile} . '_.stat';
	eval {
		Storable::lock_store($status, $statFile) or warn "Cannot store Status ($statFile)!\n";
	}; 
	if ($@) {
		warn $@; 
	};
}

sub init {
	warn 'SUB: ' . (caller(0))[3] . ' (' . (caller(1))[3] . ")\n" if $conf->{var}->{showsubs};
	$q		= CGI->new(\&hook, $ENV{CONTENT_LENGTH});
	$pjx	= new CGI::Ajax(
		'reduceNetwork'	=> \&reduceNetwork,
		'expandNetwork'	=> \&expandNetwork,
		'reduceRoot'		=> \&reduceRoot,
		'expandRoot'		=> \&expandRoot,
		'showPlugin'		=> \&showPlugin,
		'mkShowStatus'	=> \&mkShowStatus,
	);
	$pjx->DEBUG(0);

	my %cookies = fetch CGI::Cookie;
	my $sid			= &getParam(1, undef, $q->param('sid'));
	my $sessID	= (exists $cookies{CGISESSID}) ? $cookies{CGISESSID}->value : undef;

	eval {
		$session	= CGI::Session->load($sessID) or die CGI::Session->errstr;
	};
	if ($@) {
		warn $@;
		$conf->{var}->{authenticationError} = _gettext("Session is broken");
		$conf->{var}->{relogin}	= 1;
		return;
	}
	if ( $session->is_expired ) {
		$conf->{var}->{authenticationError} = _gettext("Session is expired");
		$conf->{var}->{relogin}	= 1;
	}
	my @params	= $q->param;
	if ( $session->is_empty && $#params != -1) {
		$session = $session->new($sid);
	}
	$session->expire($conf->{static}->{misc}->{sessiontimeout});

	($aclCacheHandle, $netCacheHandle)	= &initCache();
	if (defined $netCacheHandle) {
		$netCache->{DB}		= $netCacheHandle->get('DB');
		$netCache->{NET}	= $netCacheHandle->get('NET');
		$netCache->{FILL}	= $netCacheHandle->get('FILL');
	} else {
		$netCache->{DB}		= {};
		$netCache->{NET}	= {};
		$netCache->{FILL}	= {};
	}
	$aclCache	= (defined $aclCacheHandle) ? $aclCacheHandle->get('HASH') : {};

	&initTables();

	if ($q->param('locale')) {
		$session->param('locale', $q->param('locale'));
	}
	$q->delete('jumpTo') if defined $q->param('jumpTo') && $q->param('jumpTo') eq '<IP Adresse>';
}

sub soapInit {
	my $soapArgs	= shift;
	my $user			= shift @{$soapArgs};
	my $pass			= shift @{$soapArgs};

	$q->delete('login'), $q->param('login', 1);
	$q->delete('username'), $q->param('username', $user);
	$q->delete('password'), $q->param('password', $pass);
}

sub genNewSession {
	warn 'SUB: ' . (caller(0))[3] . ' (' . (caller(1))[3] . ")\n" if $conf->{var}->{showsubs};
	my $sid		= &getParam(1, undef, $q->param('sid'));
	$session	= CGI::Session->new($sid) or die CGI::Session->errstr;
	$session->expire($conf->{static}->{misc}->{sessiontimeout});
	
	if ($q->param('locale')) {
		$session->param('locale', $q->param('locale'));
	}
}

sub authentication {
	warn 'SUB: ' . (caller(0))[3] . ' (' . (caller(1))[3] . ")\n" if $conf->{var}->{showsubs};

	use HaCi::Authentication::internal;
	my $authAdmin	= new HaCi::Authentication::internal;
	$authAdmin->session($session);
	$authAdmin->init();
	
	my $auth;
	if (($q->param('login') && $q->param('username') eq 'admin') || ($session->param('username') && $session->param('username') eq 'admin') ) {
		$auth	= $authAdmin;
	} else {
		my $temp						= (exists $conf->{user}->{auth}->{authmodule} && $conf->{user}->{auth}->{authmodule}) ? $conf->{user}->{auth}->{authmodule} : 'internal';
		$temp								= 'internal' if $temp eq 'HaCi';	# fix to be backward compatible 
		my $authModule			= "HaCi::Authentication::$temp";
		my $authModuleFile	= $conf->{static}->{path}->{authmodules} . '/' . $temp . '.pm';
		eval {
			require $authModuleFile;
		};
		if ($@) {
			$conf->{var}->{authenticationError}	= _gettext("Authentication Error");
			&warnl($@);
			return 0;
		}
		$auth	= $authModule->new();
	}
	$auth->session($session);
	
	if ($q->param('login')) {
		my $user	= &getParam(1, undef, $q->param('username'));
		my $pass	= &getParam(1, undef, $q->param('password'));
		unless (defined $user) {
			$conf->{var}->{authenticationError}	= _gettext("No User given");
			return 0;
		}
		
		$auth->user($user);
		$auth->pass($pass);
		
		if ($auth->authenticate()) {
			$conf->{var}->{authenticated}	= 1;
			&updateSettingsInSession();
			return 1;
		} else {
			return 0;
		}
	} else {
		if ($auth->isAutenticated()) {
			&debug("Allready authenticated") if 0;
			$conf->{var}->{authenticated}	= 1;
			return 1;
		} else {
			&debug("Not authenticated");
			return 0;
		}
	}
}

sub finalize {
	warn 'SUB: ' . (caller(0))[3] . ' (' . (caller(1))[3] . ")\n" if $conf->{var}->{showsubs};
	my $template	= $HaCi::GUI::init::t;
	my $cookie		= $q->cookie(
		-name		=> $session->name,
		-value	=> $session->id 
	);

	unless ($conf->{var}->{soap}) {
		my $html_output	= '';
		my $warnl				= &prWarnl();
		my $prWarnl			= ($warnl) ? '<script>showWarnl()</script>' : '';
		$template->{T}->process($conf->{static}->{path}->{templateinit}, $template->{V}, \$html_output)
			|| die $template->{T}->error();
		$html_output	= &prNewWindows(1) . $html_output . $prWarnl;
	
		if ($ENV{MOD_PERL}) {
			print $q->header(
				-cookie		=> $cookie,
				-charset	=> 'UTF-8'
			);
			print $pjx->build_html($q, $html_output);
		} else {
			$q->header();	# Bad Fix for CGI - AJAX - Cookie Bug
			print $pjx->build_html($q, $html_output, {
				-cookie		=> $cookie,
				-charset	=> 'UTF-8'
			});
		}

		print $q->Dump() if 0;
		if (0) { map { warn " $_ -> " . $q->param($_); } $q->param; } # Dump

		print '<script>var aktiv = setTimeout("refresh()", 500);</script>' if $conf->{var}->{reloadPage};
		print '<script>window.close();</script>' if $conf->{var}->{closePage};
	}

	# Cache Statistics
	if (0) {
		warn "Netcache-DB  : $conf->{var}->{CACHESTATS}->{DB}->{FAIL}/$conf->{var}->{CACHESTATS}->{DB}->{TOTAL}\n";
		warn "Netcache-NET : $conf->{var}->{CACHESTATS}->{NET}->{FAIL}/$conf->{var}->{CACHESTATS}->{NET}->{TOTAL}\n";
		warn "Netcache-FILL: $conf->{var}->{CACHESTATS}->{FILL}->{FAIL}/$conf->{var}->{CACHESTATS}->{FILL}->{TOTAL}\n";
	}

	if (defined $netCacheHandle) {
		warn "Cannot set Cache (netCache-DB!)\n" unless $netCacheHandle->set('DB', $netCache->{DB});
		warn "Cannot set Cache (netCache-FILL!)\n" unless $netCacheHandle->set('FILL', $netCache->{FILL});
		warn "Cannot set Cache (netCache-NET!)\n" unless $netCacheHandle->set('NET', $netCache->{NET});
	}

	if (defined $aclCacheHandle) {
		warn "Cannot set Cache (aclCache!)\n" unless $aclCacheHandle->set('HASH', $aclCache);
	}

	$session->clear('jumpTo');
	$session->clear('jumpToNet');
	$session->clear('jumpToRoot');
	$session->flush();

	&warnl($conf->{var}->{authenticationError}) if $conf->{var}->{authenticationError} && $conf->{var}->{soap};
	return &prWarnl(1) if $conf->{var}->{soap};
}

sub checkRights {
	warn 'SUB: ' . (caller(0))[3] . ' (' . (caller(1))[3] . ")\n" if $conf->{var}->{showsubs};
	my $q	= $HaCi::HaCi::q;
	foreach ($q->param()) {
		&delParam($_) if 
			(
				/^abortAddNet$/ ||
				/^abortDelNet$/ ||
				/^checktAddNet$/ ||
				/^submitAddNet$/
			) && !&checkRight('addNet') ||
			(
				/^commitDelNet$/ ||
				/^delNet$/ ||
				/^splitNet$/ ||
				/^submitSplitNet$/ ||
				/^abortSplitNet$/ ||
				/^editNet$/ ||
				/^editPluginConf$/ ||
				/^netFuncType$/
			) && !&checkRight('editNet') ||
			(
				/^submitAddRoot$/
			) && !&checkRight('addRoot') ||
			(
				/^abortDelRoot$/ ||
				/^abortEditRoot$/ ||
				/^commitDelRoot$/ ||
				/^delRoot$/ ||
				/^editRoot$/
			) && !&checkRight('editRoot') ||
			(
				/^abortDelGroup$/ ||
				/^abortEditGroup$/ ||
				/^commitDelGroup$/ ||
				/^delGroup$/ ||
				/^editGroup$/ ||
				/^newGroup$/ ||
				/^submitEditGroup$/
			) && !&checkRight('groupMgmt') ||
			(
				/^abortDelTmpl$/ ||
				/^abortEditTmpl$/ ||
				/^commitDelTmpl$/ ||
				/^delTmpl$/ ||
				/^editNetTypeTmpl$/ ||
				/^newTmpl$/ ||
				/^submitAddTmplEntry$/ ||
				/^submitEditTmplEntry$/ ||
				/^submitDeleteTmplEntry$/
			) && !&checkRight('tmplMgmt') ||
			(
				/^abortDelUser$/ ||
				/^abortEditUser$/ ||
				/^commitDelUser$/ ||
				/^delUser$/ ||
				/^editUser$/ ||
				/^newUser$/ ||
				/^submitEditUser$/
			) && !&checkRight('userMgmt') ||
			(
				/^submitshowPlugins$/ ||
				/^submitPluginGlobConfig$/ ||
				/^abortPluginGlobConfig$/ ||
				/^editPluginGlobConf$/
			) && !&checkRight('pluginMgmt') ||
			(
				/^copyNetsTo$/ ||
				/^moveNetsTo$/ ||
				/^copyToRootID$/ ||
				/^deleteNets$/ ||
				/^combineNets$/ ||
				/^submitCombineNets$/ ||
				/^abortCombineNets$/ ||
				/^editTree$/ ||
				/^finishEditTree$/
			) && !&checkRight('editTree') ||
			(
				/^search$/ ||
				/^compare$/
			) && !&checkRight('search') ||
			(
				/^submitImportASNRoutes$/ 
			) && !&checkRight('impASNRoutes') ||
			(
				/^getFreeSubnets$/
			) && !&checkRight('showNetDet') ||
			(
				/^submitImpDNSTrans$/ ||
				/^submitImpDNSLocal$/
			) && !&checkRight('impDNS') ||
			(
				/^submitImpConfig$/ ||
				/^impCSVChangeSep$/ ||
				/^submitImpCSV$/
			) && !&checkRight('impConfig')
	}
}

sub delParam {
	warn 'SUB: ' . (caller(0))[3] . ' (' . (caller(1))[3] . ")\n" if $conf->{var}->{showsubs};
	my $param	= shift;
	my $q			= $HaCi::HaCi::q;

	&debug("Deleting Parameter '$param'! Not enough rights!!!");
	$q->delete($param);
}

1;

# vim:ts=2:sw=2:sws=2
