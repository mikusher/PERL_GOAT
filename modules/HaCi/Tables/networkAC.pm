package HaCi::Tables::networkAC;
use base 'DBIEasy';

sub TABLE { #Table Name
	'networkAC'
}

sub SETUPTABLE { # Create Table unless it doesn't exists?
	1
}

sub CREATETABLE { # Table Create Definition
	q{
  `ID` integer NOT NULL auto_increment,
	`rootID` integer NOT NULL default '0',
	`network` bigint(40) NOT NULL default '0',
	`netID` integer NOT NULL default '0',
	`groupID` integer NOT NULL default '0',
	`ACL` integer NOT NULL default '0',
  PRIMARY KEY  (`ID`),
	UNIQUE KEY (`netID`, `groupID`)
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
