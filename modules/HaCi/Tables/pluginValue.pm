package HaCi::Tables::pluginValue;
use base 'DBIEasy';

sub TABLE { #Table Name
	'pluginValue'
}

sub SETUPTABLE { # Create Table unless it doesn't exists?
	1
}

sub CREATETABLE { # Table Create Definition
	q{
	`ID` INT NOT NULL AUTO_INCREMENT,
	`netID` INT NOT NULL ,
	`pluginID` INT NOT NULL ,
	`origin` INT NOT NULL ,
	`name` VARCHAR( 255 ) NOT NULL ,
	`value` TEXT NOT NULL ,
  PRIMARY KEY  (`ID`),
	UNIQUE KEY (`netID`,`pluginID`,`name`)
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
