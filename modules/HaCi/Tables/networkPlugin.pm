package HaCi::Tables::networkPlugin;
use base 'DBIEasy';

sub TABLE { #Table Name
	'networkPlugin'
}

sub SETUPTABLE { # Create Table unless it doesn't exists?
	1
}

sub CREATETABLE { # Table Create Definition
	q{
  `ID` integer NOT NULL auto_increment,
	`netID` integer NOT NULL default '0',
	`pluginID` integer NOT NULL default '0',
	`sequence` integer NOT NULL default '0',
	`newLine` tinyint NOT NULL default '0',
  PRIMARY KEY  (`ID`),
	UNIQUE KEY (`netID`, `pluginID`)
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
