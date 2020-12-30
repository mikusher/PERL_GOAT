package HaCi::Tables::rootAC;
use base 'DBIEasy';

sub TABLE { #Table Name
	'rootAC'
}

sub SETUPTABLE { # Create Table unless it doesn't exists?
	1
}

sub CREATETABLE { # Table Create Definition
	q{
  `ID` integer NOT NULL auto_increment,
	`rootID` integer NOT NULL default 0,
	`groupID` integer NOT NULL default '0',
	`ACL` integer NOT NULL default '0',
  PRIMARY KEY  (`ID`),
	UNIQUE KEY (`rootID`, `groupID`)
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
