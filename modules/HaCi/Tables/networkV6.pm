package HaCi::Tables::networkV6;
use base 'DBIEasy';

sub TABLE { #Table Name
	'networkV6'
}

sub SETUPTABLE { # Create Table unless it doesn't exists?
	1
}

sub CREATETABLE { # Table Create Definition
	q{
  `ID` varbinary(22) NOT NULL default '',
  `rootID` int NOT NULL default 0,
  `networkPrefix` bigint UNSIGNED NOT NULL default 0,
  `hostPart` bigint UNSIGNED NOT NULL default 0,
  `cidr` smallint NOT NULL default 0,
  PRIMARY KEY  (`ID`, `rootID`),
	UNIQUE KEY (`rootID`, `networkPrefix`,`hostPart`,`cidr`)
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
