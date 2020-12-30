package HaCi::Tables::templateEntry;
use base 'DBIEasy';

sub TABLE { #Table Name
	'templateEntry'
}

sub SETUPTABLE { # Create Table unless it doesn't exists?
	1
}

sub CREATETABLE { # Table Create Definition
	q{
  `ID` int(11) NOT NULL auto_increment,
	`tmplID` int(11) NOT NULL default '0',
	`type` integer NOT NULL default '0',
	`position` integer NOT NULL default '0',
	`description` varchar(255) NOT NULL default '',
	`size` integer NOT NULL default '1',
	`entries` varchar(255) NOT NULL default '',
	`rows` integer NOT NULL default '1',
	`cols` integer NOT NULL default '1',
  PRIMARY KEY  (`ID`)
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
