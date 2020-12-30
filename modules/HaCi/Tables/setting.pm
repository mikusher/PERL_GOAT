package HaCi::Tables::setting;
use base 'DBIEasy';

sub TABLE { #Table Name
	'setting'
}

sub SETUPTABLE { # Create Table unless it doesn't exists?
	1
}

sub CREATETABLE { # Table Create Definition
	q{
  `ID` integer NOT NULL auto_increment,
	`userID` integer NOT NULL default 0,
	`param` varchar(255) NOT NULL default '',
	`value` varchar(255) NOT NULL default '',
  PRIMARY KEY  (`ID`),
	UNIQUE KEY (`userID`, `param`, `value`)
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
