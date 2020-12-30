package HaCi::Tables::templateValue;
use base 'DBIEasy';

sub TABLE { #Table Name
	'templateValue'
}

sub SETUPTABLE { # Create Table unless it doesn't exists?
	1
}

sub CREATETABLE { # Table Create Definition
	q{
  `ID` integer NOT NULL auto_increment,
	`tmplID` integer NOT NULL default '0',
	`tmplEntryID` integer NOT NULL default '0',
	`netID` integer NOT NULL default '0',
	`value` blob NOT NULL,
  PRIMARY KEY  (`ID`),
	UNIQUE KEY (`netID`,`tmplID`,`tmplEntryID`)
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
