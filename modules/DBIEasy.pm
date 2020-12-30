package DBIEasy;

use strict;
use Carp qw/carp croak/;
use DBI;

my $dbHandles		= {};
my $initConf		= {};
my $timeout			= 300;
our $lastError	= '';

BEGIN {
	no strict 'refs';
	foreach my $attr (qw/error errorStrs dbhost dbname dbuser dbpass PK dbh/) {
		*{$attr} = sub {
			my $proto		= shift;
			my $value		= shift;
			my $self		= undef;
			my $caller	= (caller)[0];
			
		  if (ref $proto) {
		  	$self	= $proto;
			  if (defined $value) {
				  $self->{$attr}	= $value;
			  } else {
			  	return $self->{$attr};
			  }
		  } else {
			  if (defined $value) {
				  $initConf->{$proto}->{$attr}	= $value;
			  } else {
			  	return $initConf->{$proto}->{$attr}	= $value;
			  }
		  }
		}
	}
}

sub new {
	my $proto		= shift;
	my $config	= shift;
	my $self		= undef;

	if (ref $proto) {
		$self	= $proto;
	} else {
		$self	= (ref $initConf->{$proto} eq 'HASH') ? $initConf->{$proto} : {};
		unless (ref $self eq 'HASH') {
			_carp("Database Error");
			return undef;
		}
		bless $self, $proto;
	}

	if (ref $config eq 'HASH') {
		$self->{CONFIG}	= $config;
	}

	return undef unless &init($self);
	
	my $dbh		= &getDBConn($self);
	
	if ($dbh) {
		$self->dbh($dbh);
		if (&initChecks($self)) {
			$self->PK(&getPK($self));
			&initSubRefs($self);
			return $self;
		}
	}
	return undef;
}

sub init {
	my $self	= shift;

	foreach ('dbhost', 'dbname', 'dbuser', 'dbpass') {
		my $key	= $_;
		unless ($self->{$key}) {
			if ($self->{CONFIG}->{$key}) {
				$self->$key($self->{CONFIG}->{$key});
			} else {
				$self->_carp("No '$key' defined");
				return 0;
			}
		}
	}
	return 1;
}

sub initSubRefs {
	my $self		= shift;
	
	no strict 'refs';
	foreach (&getColoumns($self)) {
		my $col	= $_;
		
		next unless $col;
		unless ($self->can($col)) {
			*{(ref $self) . "::$col"} = sub {
				my $self	= shift;
				my $value	= shift;
				if (defined $value) {
					$self->{COLOUMNS}->{$col}	= $value;
				} else {
					$self->{COLOUMNS}->{$col}	= undef;
				}
			}
		}
	}
}

sub getDBConn {
	my $self	= shift;
	my $dbh		= undef;

	if ($dbHandles->{$$}->{$self->dbhost}->{$self->dbname}) {
		$dbh	= $dbHandles->{$$}->{$self->dbhost}->{$self->dbname};
		$self->_carp("Taking allready connected Database Handle: $dbh ($$: " . $self->TABLE() . ")") if 0;
		$self->dbh($dbh);
		unless ($dbh->ping) {
#		unless (&checkIfTableExists($self)) {
			$self->_carp("Mhh, that old Handle doesn't smell well. Better taking a new one!");
			$dbh	= undef;
		}
	}
	unless (defined $dbh) {
		my @DSN = (
			'DBI:mysql:' .
			'database=' . $self->dbname .
			';host=' . $self->dbhost,
	    $self->dbuser, $self->dbpass
  	);
  	
		$dbh = DBI->connect(@DSN,  {
			PrintError => 0,
			AutoCommit => 1
		});
		$self->_croak($DBI::errstr) unless $dbh;
		&checkForOldHandles($dbh) if defined $dbh;
	}
	$dbHandles->{$$}->{$self->dbhost}->{$self->dbname}	= $dbh;
	$self->dbh($dbh);
	return $dbh;
}

sub initChecks {
	my $self	= shift;
	my $dbh		= $self->dbh;
	my $error	= 0;
	
	$error	= 1 unless &checkIfTableExists($self);
	
	return ($error == 0) ? 1 : 0;
}

sub clear {
	my $self	= shift;
	foreach (&getColoumns($self)) {
		$self->$_(undef);
	}
	$self->error(0);
	$self->errorStrs('');
}

sub checkIfTableExists {
	my $self	= shift;
	my $dbh		= $self->dbh;
	my $table	= $self->TABLE;

	my @tables	= $dbh->tables(undef, undef, $table);
	unless (grep {/^(`?$self->{dbname}`?.)?`?$table`?$/} @tables) {
		if ($self->SETUPTABLE) {
			$self->_carp("Table '$table' doesn't exist, try to create it...\n");
			my $createStmt	= "CREATE TABLE `$table` (" . $self->CREATETABLE . ') ENGINE=InnoDB DEFAULT CHARSET=utf8';
			$dbh->do($createStmt)	or $self->_croak($dbh->errstr);
			
			my @tables	= $dbh->tables(undef, undef, $table);
			unless (grep {/^(`?$self->{dbname}`?.)?`?$table`?$/} @tables) {
				$self->_croak("Sorry, after creating the Table '$table', it isn't there?");
				return 0;
			}
		} else {
			$self->_croak("Table '$table' doesn't exist!");
			return 0;
		}
	}
	return 1;
}

sub getPK {
	my $self	= shift;
	my $dbh		= $self->dbh;
	my $table	= $self->TABLE;
	my @PKs		= ();

	my $sth = $dbh->prepare("SHOW INDEX FROM $table");
  $sth->execute;
	$self->_croak($dbh->errstr) if $dbh->errstr;
  if ($sth) {
		my $hashRef = $sth->fetchall_hashref(['Key_name', 'Seq_in_index']);
	  foreach (keys %{$hashRef}) {
	  	my $key	= $_;
			foreach (keys %{$hashRef->{$key}}) {
		  	if ($key eq 'PRIMARY') {
		  		push @PKs, $hashRef->{$key}->{$_}->{Column_name};
		  	}
			}
	  }
  }
	if ($#PKs == -1) {
		$self->_croak("No Primary Keys in Table '$table'!");
	} else {
		return \@PKs;
	}
}

sub getShowCreate {
	my $self	= shift;
	my $dbh		= $self->dbh;
	my $table	= $self->TABLE;
	
	my $sth	= $dbh->prepare("SHOW CREATE TABLE `$table`");
	$sth->execute;
	$self->_croak($dbh->errstr) if $dbh->errstr;

	if ($sth) {
		my $showCreatet	= $sth->fetchall_arrayref([1]);
		if (defined $showCreatet) {
			my $showCreate	= $$showCreatet[0];
			return $$showCreate[0];
		} else {
			$self->_carp("Sorry, Show Create Table '$table' doesn't work!");
			return '';
		}
	}
}


sub getColoumns {
	my $self	= shift;
	my $dbh		= $self->dbh;
	my $table	= $self->TABLE;
	
	my $sth	= $dbh->prepare("DESCRIBE `$table`");
	$sth->execute;
	$self->_croak($dbh->errstr) if $dbh->errstr;

	if ($sth) {
		my $hashRef	= $sth->fetchall_hashref('Field');
		return ((defined $hashRef && ref $hashRef eq 'HASH') ? keys %{$hashRef} : ());
	} else {
		$self->_carp("Sorry, no Columns found!");
		return ();
	}
}

sub search {
	my $self			= shift;
  my $qryCols		= shift || ['*'];
  my $qryRestr	= shift || 0;
  my $bLike			= shift || 0;
	my $appStr		= shift || 0;
	my $distinct	= shift || 0;
  my $pk				= $self->PK;
	my $dbh				= $self->dbh;
  my @rows			= ();
  my @whereStr	= ();
	my $con				= 'AND';	
	my $cs				= '';

	foreach (@$pk) {
		my $pkt	= $_;
		push @$qryCols, $pkt unless grep {/^$pkt$/} @$qryCols;
	}

 	if ($qryRestr) { 
	  if (ref $qryRestr eq 'HASH') {
		  foreach (keys %{$qryRestr}) {
				if ($_ eq '%CON%') {
					$con	= $qryRestr->{$_};
				}
				elsif ($_ eq '%CS%') {
					$cs		= $qryRestr->{$_};
				} else {
			 	 	push @whereStr, $_ . (($bLike) ? ' LIKE ' : ' = ') . "'" . $qryRestr->{$_} . "'";
				}
		  }
	  }
	  elsif (ref $qryRestr eq '') {
	  	$whereStr[0]	= $qryRestr;
	  }
 	}
	map {$_	= 'binary ' . $_;} @whereStr if $cs;
 
  my $prStr			= "SELECT " . (($distinct) ? 'DISTINCT ' : '') . join(',', @$qryCols) . ' FROM ' . $self->TABLE . (($#whereStr > -1) ? ' WHERE ' . join(" $con ", @whereStr) : '');
	$prStr	.= ' ' . $appStr if $appStr;

	warn "STRING: " . join('', split(/\n/, $prStr)) . "\n" if 0;
	
  my $sth				= $dbh->prepare($prStr);
  $self->_carp($dbh->errstr()) if $dbh->errstr();
 
  $sth->execute;
  $self->_carp($dbh->errstr()) if $dbh->errstr();
  
  my $hashRef = $sth->fetchall_hashref($pk);
  $self->_carp($dbh->errstr()) if $dbh->errstr();

	my $pkCnter	= 1;
	push @rows, &getRows($self, $hashRef, $pkCnter);
  
  return @rows;
}

sub getRows {
	my $self		= shift;
	my $hashRef	= shift;
	my $pkCnter	= shift;
	my @rows		= ();

	return @rows unless ref $hashRef eq 'HASH';

  foreach (keys %{$hashRef}) {
		if ($pkCnter < ($#{$self->{PK}} + 1)) {
			push @rows, &getRows($self, $hashRef->{$_}, ($pkCnter + 1));
		} else {
			push @rows, $hashRef->{$_};
		}
  }

	return @rows;
}

sub insert {
	my $self	= shift;
	
	return &modify($self, 'INSERT');
}

sub replace {
	my $self	= shift;
	
	return &modify($self, 'REPLACE');
}

sub update {
	my $self			= shift;
	my $rowRestr	= shift;
	my $bLike			= shift;
	my $appStr		= shift || 0;
	
	return &modify($self, 'UPDATE', $rowRestr, $bLike, $appStr);
}

sub delete {
	my $self			= shift;
	my $rowRestr	= shift;
	my $bLike			= shift;
	my $appStr		= shift || 0;
	
	return &modify($self, 'DELETE', $rowRestr, $bLike, $appStr);
}

sub modify {
	my $self			= shift;
	my $type			= shift;
  my $rowRestr	= shift || 0;
  my $bLike			= shift || 0;
	my $appStr		= shift || 0;
	my $dbh				= $self->dbh;
	my $table			= $self->TABLE;
	my @adds			= ();
  my @whereStr	= ();
	my $modStr		= $type;
	my $con				= 'AND';
	$modStr			 .= ' INTO' if $type eq 'INSERT' || $type eq 'REPLACE';
	$modStr			 .= ' FROM' if $type eq 'DELETE';
	$modStr			 .= ' ' . $table;
	$modStr			 .= ' SET ' if $type eq 'INSERT' || $type eq 'REPLACE' || $type eq 'UPDATE';
	
 	if ($rowRestr) { 
	  if (ref $rowRestr eq 'HASH') {
		  foreach (keys %{$rowRestr}) {
				my $row	= $_;
				if ($row eq 'CON') {
					$con	= $rowRestr->{CON};
				} else {
		  		push @whereStr, $row . (($bLike) ? ' LIKE ' : ' = ') . "'" . $rowRestr->{$row} . "'";
				}
		  }
	  }
	  elsif (ref $rowRestr eq '') {
	  	$whereStr[0]	= $rowRestr;
	  }
 	}
  
	$self->_log("$type in $table") if 0;
	
	foreach (keys %{$self->{COLOUMNS}}) {
		my $value	= $self->{COLOUMNS}->{$_};

		if (defined $value) {
			$value	= $dbh->quote($value);
			push @adds, "$_=$value";
		}
	}
	$modStr	.= join(', ', @adds) if $type eq 'INSERT' || $type eq 'REPLACE' || $type eq 'UPDATE';
	$modStr	.= ' WHERE ' . join(" $con ", @whereStr) if $#whereStr > -1;
	$modStr	.= ' ' . $appStr if $appStr;
	
	warn  $modStr if 0;
	my $rows	= $dbh->do($modStr);
  $self->_carp($dbh->errstr()) if $dbh->errstr();
  return $rows;
}

sub alter {
	my $self		= shift;
	my $altStr	= shift;
	my $dbh			= $self->dbh;

	warn $altStr if 0;
	my $rows	= $dbh->do($altStr);
  $self->_carp($dbh->errstr()) if $dbh->errstr();
  return $rows;
}

sub _log {
	_carp(@_);
}

sub _carp {
	my $self							= shift;
	my ($message, %info)	= @_;
	if (UNIVERSAL::isa($self, 'UNIVERSAL')) {
		$self->error(1);
		$self->errorStrs($message);
		$lastError	.= $message;
		warn "DB " . (ref $self) . ' [' . (caller(4))[3] . '->' . (caller(3))[3] . '->' . (caller(2))[3] . "]: $message";
	} else {
		Carp::carp($message || $self);
	}
	return;
}

sub _croak {
	my $self							= shift;
	my ($message, %info)	= @_;
	chomp($message);
	if (UNIVERSAL::isa($self, 'UNIVERSAL')) {
		$self->error(1);
		$self->errorStrs($message);
		$lastError	.= $message;
		warn "DB " . (ref $self) . ": $message\n";
	} else {
		Carp::croak($message || $self);
	}
	return;
}

sub checkForOldHandles {
	my $dbh	= shift;

	my $sth_sh_proc	= $dbh->prepare("show full processlist");
	my $sth_kill		= $dbh->prepare("kill ?");

	unless ($sth_sh_proc->execute()) {
		_carp("Unable to execute show procs [" . $dbh->errstr() . "]");
		return 0;
	}
	while (my $row = $sth_sh_proc->fetchrow_hashref()) {
		if ($row->{Command}	eq 'Sleep' && $row->{Time} > $timeout) {
			my $id	= $row->{Id};
			$sth_kill->execute($id);
		}
	}

	return 1;
}

END {
	foreach (keys %{$dbHandles}) {
		my $host	= $_;
		foreach (keys %{$dbHandles->{$$}->{$host}}) {
			my $name	= $_;
			if ($dbHandles->{$$}->{$host}->{$name}) {
				_carp("Disconnecting from DB $host:$name") if 0;
				$dbHandles->{$$}->{$host}->{$name}->disconnect();
			}
		}
	}
}

1;

# vim:ts=2:sts=2:sw=2
