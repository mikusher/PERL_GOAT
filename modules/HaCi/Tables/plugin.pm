package HaCi::Tables::plugin;
use base 'DBIEasy';
   
sub TABLE { #Table Name
	'plugin'
}

sub SETUPTABLE { # Create Table unless it doesn't exists?
	1
}

sub CREATETABLE { # Table Create Definition
	q{
  `ID` int NOT NULL auto_increment,
  `name` varchar(255) NOT NULL default '',
  `filename` varchar(255) NOT NULL default '',
  `active` tinyint NOT NULL default 0,
  `lastRun` datetime NOT NULL default '0000-00-00 00:00:00',
  `runTime` int NOT NULL default 0,
  `lastError` varchar(255) NOT NULL default '',
  PRIMARY KEY  (`ID`),
	UNIQUE KEY (`name`)
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
