package HaCi::Tables::template;
use base 'DBIEasy';

sub TABLE { #Table Name
	'template'
}

sub SETUPTABLE { # Create Table unless it doesn't exists?
	1
}

sub CREATETABLE { # Table Create Definition
	q{
  `ID` int(11) NOT NULL auto_increment,
  `name` varchar(255) NOT NULL default '',
	`type` varchar(64) NOT NULL default '',
  `createFrom` varchar(255) NOT NULL default '',
  `createDate` datetime NOT NULL default '0000-00-00 00:00:00',
  `modifyFrom` varchar(255) NOT NULL default '',
  `modifyDate` datetime NOT NULL default '0000-00-00 00:00:00',
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
