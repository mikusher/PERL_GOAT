package HaCi::Tables::network;
use base 'DBIEasy';

sub TABLE { #Table Name
	'network'
}

sub SETUPTABLE { # Create Table unless it doesn't exists?
	1
}

sub CREATETABLE { # Table Create Definition
	q{
  `ID` int(11) NOT NULL auto_increment,
	`rootID` int (11) NOT NULL default '0',
  `network` bigint(40) NOT NULL default '0',
  `description` varchar(255) NOT NULL default '',
  `state` smallint(6) NOT NULL default '0',
  `defSubnetSize` TINYINT(4) UNSIGNED NOT NULL default '0',
  `tmplID` integer NOT NULL default '0',
  `ipv6ID` varbinary(22) NOT NULL default '',
  `createFrom` varchar(255) NOT NULL default '',
  `createDate` datetime NOT NULL default '0000-00-00 00:00:00',
  `modifyFrom` varchar(255) NOT NULL default '',
  `modifyDate` datetime NOT NULL default '0000-00-00 00:00:00',
	PRIMARY KEY  (`ID`),
	INDEX (`network`),
	UNIQUE KEY (`rootID`,`ipv6ID`, `network`)
	}
}
 
sub _log {
	my $self	= shift;
	my @msg		= @_;
	
	DBIEasy::_log($self, @msg);
}

sub _carp {
	my $self							= shift;
	my ($message, %info)	= @_;

	DBIEasy::_carp($self, $message, %info);
}

sub _croak {
	my $self							= shift;
	my ($message, %info)	= @_;

	DBIEasy::_croak($self, $message, %info);
}

1;

# vim:ts=2:sw=2:sws=2
